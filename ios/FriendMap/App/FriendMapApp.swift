import SwiftUI

/// Main app entry point
@main
struct FriendMapApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var planStore = PlanStore()
    
    init() {
        Logger.info("OurSpot app initializing...")
        
        if Config.isSupabaseConfigured {
            Logger.info("Supabase configured - online mode")
        } else {
            Logger.warning("Supabase not configured - running in offline/mock mode")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(sessionStore)
                .environmentObject(planStore)
        }
    }
}
