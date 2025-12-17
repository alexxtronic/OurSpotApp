import SwiftUI

/// Main content view with tab bar navigation
struct ContentView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    
    var body: some View {
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
        .environmentObject(SessionStore())
        .environmentObject(PlanStore())
}
