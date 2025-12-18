import SwiftUI

/// Main content view with auth routing and tab bar navigation
struct ContentView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var planStore: PlanStore
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                // Main app with tabs
                mainTabView
                    .onAppear {
                        syncProfileIfNeeded()
                    }
            } else if Config.supabase == nil {
                // Offline mode - skip auth
                mainTabView
            } else {
                // Not authenticated - show sign in
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
            // Get name from user metadata if available
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
