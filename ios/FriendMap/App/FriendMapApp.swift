import SwiftUI

/// Main app entry point
@main
struct FriendMapApp: App {
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var planStore = PlanStore()
    
    init() {
        Logger.info("OurSpot app initializing...")
        
        // Check Supabase config (unused today, but validates the loader)
        if Config.isSupabaseConfigured {
            Logger.info("Supabase configured")
        } else {
            Logger.warning("Supabase not configured - running in mock mode")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionStore)
                .environmentObject(planStore)
        }
    }
}
