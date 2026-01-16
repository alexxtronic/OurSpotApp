import SwiftUI

/// Main app entry point
@main
struct FriendMapApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var authService = AuthService()
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var planStore = PlanStore()
    @StateObject private var notificationRouter = NotificationRouter.shared
    @StateObject private var dmService = DirectMessageService()
    @StateObject private var blockService = BlockService()
    
    @State private var showLaunchScreen = true
    
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
            ZStack {
                ContentView()
                    .environmentObject(authService)
                    .environmentObject(sessionStore)
                    .environmentObject(planStore)
                    .environmentObject(notificationRouter)
                    .environmentObject(dmService)
                    .environmentObject(blockService)
                    .task {
                        // Register for push notifications if authorized
                        if authService.isAuthenticated {
                            await PushNotificationManager.registerIfAuthorized()
                        }
                    }
                    .onChange(of: authService.isAuthenticated) { isAuthenticated in
                        if isAuthenticated {
                            Task {
                                await PushNotificationManager.registerIfAuthorized()
                            }
                        } else {
                            Task {
                                await DeviceTokenService.shared.clearToken()
                            }
                        }
                    }
                
                // Animated launch screen overlay
                if showLaunchScreen {
                    LaunchScreenCoordinator {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showLaunchScreen = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
    }
}
