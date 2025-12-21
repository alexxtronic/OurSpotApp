import UIKit
import UserNotifications

/// AppDelegate for handling push notifications
/// Uses UIApplicationDelegateAdaptor pattern with SwiftUI
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    // MARK: - App Lifecycle
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set notification delegate for foreground handling
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    // MARK: - Push Notification Registration
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Convert token to string
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Logger.info("APNs device token: \(tokenString)")
        
        // Send to DeviceTokenService
        Task {
            await DeviceTokenService.shared.registerToken(tokenString)
        }
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Logger.error("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        Logger.info("Received notification in foreground: \(userInfo)")
        
        // Check if we should show the notification
        // Don't show if user is already viewing the same chat
        if let planId = userInfo["plan_id"] as? String,
           NotificationRouter.shared.currentlyViewingPlanId == planId {
            // User is already in this chat, just play sound
            completionHandler([.sound])
        } else {
            // Show banner, sound, and badge
            completionHandler([.banner, .sound, .badge])
        }
    }
    
    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Logger.info("Notification tapped: \(userInfo)")
        
        // Route to the appropriate screen
        NotificationRouter.shared.handleNotificationTap(userInfo: userInfo)
        
        completionHandler()
    }
}
