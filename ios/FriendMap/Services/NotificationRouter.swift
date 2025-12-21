import Foundation
import SwiftUI

/// Routes incoming push notifications to appropriate screens
@MainActor
final class NotificationRouter: ObservableObject {
    static let shared = NotificationRouter()
    
    /// Currently viewing plan ID (to suppress notifications)
    @Published var currentlyViewingPlanId: String?
    
    /// Pending deep link to process after app is ready
    @Published var pendingDeepLink: NotificationDeepLink?
    
    private init() {}
    
    // MARK: - Notification Handling
    
    /// Handle notification tap and route to appropriate screen
    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let planIdString = userInfo["plan_id"] as? String,
              let planId = UUID(uuidString: planIdString) else {
            Logger.warning("Invalid notification payload: missing plan_id")
            return
        }
        
        let deepLink = NotificationDeepLink(
            type: .chatMessage,
            planId: planId,
            messageId: (userInfo["message_id"] as? String).flatMap { UUID(uuidString: $0) }
        )
        
        // Set pending deep link - will be processed by ContentView
        pendingDeepLink = deepLink
        
        // Haptic feedback
        HapticManager.lightTap()
        
        Logger.info("Routing to plan chat: \(planId)")
    }
    
    /// Clear pending deep link after processing
    func clearPendingDeepLink() {
        pendingDeepLink = nil
    }
    
    /// Mark a plan as currently being viewed
    func enterPlanChat(_ planId: UUID) {
        currentlyViewingPlanId = planId.uuidString
    }
    
    /// Clear currently viewing plan
    func leavePlanChat() {
        currentlyViewingPlanId = nil
    }
}

// MARK: - Deep Link Model

struct NotificationDeepLink: Identifiable, Equatable {
    let id = UUID()
    let type: NotificationType
    let planId: UUID
    let messageId: UUID?
    
    enum NotificationType {
        case chatMessage
        case rsvpUpdate
        case planUpdate
    }
}

// MARK: - Push Notification Permission

enum PushNotificationManager {
    
    /// Request push notification permission
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            
            if granted {
                // Register for remote notifications on main thread
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                Logger.info("Push notification permission granted")
            } else {
                Logger.info("Push notification permission denied")
            }
            
            return granted
        } catch {
            Logger.error("Push permission request failed: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Check current authorization status
    static func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
    
    /// Register for push if already authorized
    static func registerIfAuthorized() async {
        let status = await checkAuthorizationStatus()
        if status == .authorized {
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}
