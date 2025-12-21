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
                                await planStore.loadPlans(currentUserId: sessionStore.currentUser.id)
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
    
    @State private var showCreatePlanSheet = false
    @State private var showConfetti = false
    @State private var planCountBeforeSheet = 0
    
    // ... (rest of body)
    
    private var mainTabView: some View {
        ZStack(alignment: .bottom) {
            TabView {
                MapView()
                    .tabItem {
                        Label("Map", systemImage: "map.fill")
                    }
                
                EventGroupsView()
                    .tabItem {
                        Label("Groups", systemImage: "person.2.fill")
                    }
                
                // Placeholder for center spacing - completely invisible
                Color.clear
                    .tabItem {
                        Text(" ") // Invisible placeholder
                    }
                    .disabled(true)
                
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
            
            // Custom Center Button - Liquid Glass Style
            Button {
                showCreatePlanSheet = true
            } label: {
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.cyan.opacity(0.4),
                                    Color.teal.opacity(0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 35
                            )
                        )
                        .frame(width: 70, height: 70)
                        .blur(radius: 4)
                    
                    // Glass circle
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.6),
                                            Color.cyan.opacity(0.3),
                                            Color.teal.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: .cyan.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    // Plus icon
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .teal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .buttonStyle(PressButtonStyle())
            .offset(y: 2)
        }
        .sheet(isPresented: $showCreatePlanSheet, onDismiss: {
            // Only show confetti if a plan was actually created
            if planStore.plans.count > planCountBeforeSheet {
                showConfetti = true
            }
        }) {
            CreatePlanView()
                .onAppear {
                    planCountBeforeSheet = planStore.plans.count
                }
        }
        .confetti(isShowing: $showConfetti)
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

// MARK: - Press Animation Button Style
struct PressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
        .environmentObject(SessionStore())
        .environmentObject(PlanStore())
}
