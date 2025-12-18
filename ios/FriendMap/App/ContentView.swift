import SwiftUI

/// Main content view with tab bar navigation
struct ContentView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var planStore: PlanStore
    
    var body: some View {
        Group {
            if authService.isAuthenticated || !Config.isSupabaseConfigured {
                // Show main app (skip auth in offline mode)
                mainTabView
            } else {
                // Show sign in
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
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
        .environmentObject(SessionStore())
        .environmentObject(PlanStore())
}
