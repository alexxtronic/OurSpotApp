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

/// Manages in-app notifications
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
    
    // MARK: - Public Methods
    
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
        }
    }
    
    func markAllAsRead() {
        for index in notifications.indices {
            notifications[index].isRead = true
        }
        updateUnreadCount()
        saveToStorage()
    }
    
    func clearAll() {
        notifications.removeAll()
        updateUnreadCount()
        saveToStorage()
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
