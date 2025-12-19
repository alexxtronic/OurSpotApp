import SwiftUI

/// Main content view with auth routing and tab bar navigation
struct ContentView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var planStore: PlanStore
    
    @State private var deepLinkPlan: Plan?
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                if sessionStore.isLoading {
                    ProgressView("Loading Profile...")
                } else if sessionStore.currentUser.onboardingCompleted || Config.supabase == nil {
                    mainTabView
                        .onAppear {
                            Task {
                                await planStore.loadPlans()
                            }
                        }
                        .sheet(item: $deepLinkPlan) { plan in
                            PlanDetailsView(plan: plan)
                        }
                        .onOpenURL { url in
                            handleDeepLink(url)
                        }
                } else {
                    // Show onboarding for new users
                    OnboardingView {
                        // This callback is called when onboarding completes
                        sessionStore.objectWillChange.send()
                    }
                }
            } else if Config.supabase == nil {
                // Offline mode - skip auth
                mainTabView
            } else {
                SignInView()
            }
        }
        .task {
            if authService.isAuthenticated {
                await syncProfileIfNeeded()
            }
        }
        .onChange(of: authService.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                Task {
                    await syncProfileIfNeeded()
                }
            }
        }
    }
    
    private var mainTabView: some View {
        TabView {
            MapView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
            
            EventGroupsView()
                .tabItem {
                    Label("Groups", systemImage: "person.2.fill")
                }
            
            PlansView()
                .tabItem {
                    Label("Plans", systemImage: "calendar")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .tint(DesignSystem.Colors.primaryFallback)
    }
    
    private func handleDeepLink(_ url: URL) {
        // Format: ourspot://plan/{uuid}
        guard url.scheme == "ourspot",
              url.host == "plan",
              let planIdString = url.pathComponents.last,
              let planId = UUID(uuidString: planIdString) else {
            return
        }
        
        // Find plan locally
        if let plan = planStore.plans.first(where: { $0.id == planId }) {
            deepLinkPlan = plan
        } else {
            // In a real app, you would fetch the plan from Supabase here
            Logger.warning("Deep link plan not found locally: \(planId)")
        }
    }
    
    private func syncProfileIfNeeded() async {
        guard let session = authService.currentSession else { return }
        
        var name: String? = nil
        if let metadata = session.user.userMetadata["name"] {
            if case .string(let stringValue) = metadata {
                name = stringValue
            }
        }
        
        await sessionStore.syncProfile(
            userId: session.user.id,
            email: session.user.email,
            name: name
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
        .environmentObject(SessionStore())
        .environmentObject(PlanStore())
}
