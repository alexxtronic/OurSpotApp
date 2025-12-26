import Foundation
import SwiftUI

/// Represents an in-app notification
struct AppNotification: Identifiable, Codable, Equatable {
    let id: UUID
    let type: NotificationType
    let title: String
    let message: String
    let timestamp: Date
    let relatedPlanId: UUID?
    let relatedUserId: UUID?
    var isRead: Bool
    
    enum NotificationType: String, Codable {
        case eventInvite     // Someone invited you to an event
        case chatMessage     // New message in event chat
        case rsvpUpdate      // Someone RSVP'd to your event
        case newFollower     // Someone followed you
    }
    
    static func eventInvite(from userName: String, eventName: String, planId: UUID, userId: UUID) -> AppNotification {
        AppNotification(
            id: UUID(),
            type: .eventInvite,
            title: "Event Invite",
            message: "\(userName) invited you to \(eventName)",
            timestamp: Date(),
            relatedPlanId: planId,
            relatedUserId: userId,
            isRead: false
        )
    }
    
    static func chatMessage(from userName: String, eventName: String, planId: UUID, userId: UUID) -> AppNotification {
        AppNotification(
            id: UUID(),
            type: .chatMessage,
            title: "New Message",
            message: "\(userName) messaged in \(eventName)",
            timestamp: Date(),
            relatedPlanId: planId,
            relatedUserId: userId,
            isRead: false
        )
    }
}

// MARK: - Supabase DTO

struct AppNotificationDTO: Codable {
    let id: UUID
    let user_id: UUID
    let type: String
    let title: String
    let message: String
    let related_plan_id: UUID?
    let related_user_id: UUID?
    let is_read: Bool
    let created_at: Date
    
    func toAppNotification() -> AppNotification {
        AppNotification(
            id: id,
            type: AppNotification.NotificationType(rawValue: type) ?? .eventInvite,
            title: title,
            message: message,
            timestamp: created_at,
            relatedPlanId: related_plan_id,
            relatedUserId: related_user_id,
            isRead: is_read
        )
    }
}

struct AppNotificationInsertDTO: Codable {
    let user_id: UUID
    let type: String
    let title: String
    let message: String
    let related_plan_id: UUID?
    let related_user_id: UUID?
}

/// Manages in-app notifications with Supabase sync
@MainActor
class NotificationCenter: ObservableObject {
    static let shared = NotificationCenter()
    
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    
    private let storageKey = "app_notifications"
    private let maxNotifications = 50
    
    private init() {
        loadFromStorage()
    }
    
    // MARK: - Fetch from Supabase
    
    /// Fetch notifications for a specific user from Supabase
    func fetchNotifications(for currentUserId: UUID) async {
        Logger.info("📥 fetchNotifications called for user: \(currentUserId)")
        
        // Clear local cache first to prevent stale data from previous user
        notifications = []
        unreadCount = 0
        
        guard let supabase = Config.supabase else {
            Logger.error("❌ Supabase not configured, cannot fetch notifications")
            return
        }
        
        do {
            Logger.info("📥 Querying app_notifications table with explicit user_id filter")
            let response: [AppNotificationDTO] = try await supabase
                .from("app_notifications")
                .select()
                .eq("user_id", value: currentUserId.uuidString)
                .order("created_at", ascending: false)
                .limit(maxNotifications)
                .execute()
                .value
            
            Logger.info("📥 Fetched \(response.count) notifications for user \(currentUserId)")
            notifications = response.map { $0.toAppNotification() }
            updateUnreadCount()
            Logger.info("📥 Unread count: \(unreadCount)")
            saveToStorage() // Cache locally
            
        } catch {
            Logger.error("❌ Failed to fetch notifications: \(error.localizedDescription)")
            // Don't fall back to local storage - it might have stale data from another user
        }
    }
    
    // MARK: - Send to Other User
    
    /// Store a notification in Supabase for a SPECIFIC user (not the current user)
    func sendNotificationToUser(userId: UUID, notification: AppNotification) async {
        Logger.info("🔔 sendNotificationToUser called for userId: \(userId)")
        guard let supabase = Config.supabase else {
            Logger.error("❌ Supabase not configured, cannot send notification")
            return
        }
        
        let dto = AppNotificationInsertDTO(
            user_id: userId,
            type: notification.type.rawValue,
            title: notification.title,
            message: notification.message,
            related_plan_id: notification.relatedPlanId,
            related_user_id: notification.relatedUserId
        )
        
        Logger.info("🔔 Inserting notification: type=\(notification.type.rawValue), title=\(notification.title)")
        
        do {
            try await supabase
                .from("app_notifications")
                .insert(dto)
                .execute()
            
            Logger.info("✅ Notification stored in Supabase for user \(userId): \(notification.title)")
        } catch {
            Logger.error("❌ Failed to send notification: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Local Only (for testing/fallback)
    
    func addNotification(_ notification: AppNotification) {
        notifications.insert(notification, at: 0)
        
        // Keep only the most recent notifications
        if notifications.count > maxNotifications {
            notifications = Array(notifications.prefix(maxNotifications))
        }
        
        updateUnreadCount()
        saveToStorage()
        
        // Haptic feedback
        HapticManager.lightTap()
    }
    
    func markAsRead(_ notification: AppNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].isRead = true
            updateUnreadCount()
            saveToStorage()
            
            // Also update in Supabase
            Task {
                await markAsReadInSupabase(notificationId: notification.id)
            }
        }
    }
    
    func markAllAsRead() {
        for index in notifications.indices {
            notifications[index].isRead = true
        }
        updateUnreadCount()
        saveToStorage()
        
        // Also update in Supabase
        Task {
            await markAllAsReadInSupabase()
        }
    }
    
    func clearAll() {
        notifications.removeAll()
        updateUnreadCount()
        saveToStorage()
    }
    
    // MARK: - Supabase Updates
    
    private func markAsReadInSupabase(notificationId: UUID) async {
        guard let supabase = Config.supabase else { return }
        
        do {
            try await supabase
                .from("app_notifications")
                .update(["is_read": true])
                .eq("id", value: notificationId)
                .execute()
        } catch {
            Logger.error("Failed to mark notification as read in Supabase: \(error.localizedDescription)")
        }
    }
    
    private func markAllAsReadInSupabase() async {
        guard let supabase = Config.supabase else { return }
        
        do {
            try await supabase
                .from("app_notifications")
                .update(["is_read": true])
                .eq("is_read", value: false)
                .execute()
        } catch {
            Logger.error("Failed to mark all notifications as read: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead }.count
    }
    
    private func saveToStorage() {
        if let encoded = try? JSONEncoder().encode(notifications) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadFromStorage() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([AppNotification].self, from: data) {
            notifications = decoded
            updateUnreadCount()
        }
    }
}
