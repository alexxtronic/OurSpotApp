import SwiftUI
import Auth

/// Main content view with auth routing and tab bar navigation
struct ContentView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var planStore: PlanStore
    
    @State private var showOnboarding = false
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                if !sessionStore.currentUser.onboardingCompleted && Config.authClient != nil {
                    // Show onboarding for new users
                    OnboardingView(isComplete: $showOnboarding)
                        .onChange(of: showOnboarding) { _, completed in
                            if completed {
                                sessionStore.currentUser.onboardingCompleted = true
                            }
                        }
                } else {
                    mainTabView
                        .onAppear {
                            syncProfileIfNeeded()
                        }
                }
            } else if Config.authClient == nil {
                // Offline mode - skip auth
                mainTabView
            } else {
                SignInView()
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
    
    private func syncProfileIfNeeded() {
        guard let session = authService.currentSession else { return }
        
        Task {
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
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
        .environmentObject(SessionStore())
        .environmentObject(PlanStore())
}
