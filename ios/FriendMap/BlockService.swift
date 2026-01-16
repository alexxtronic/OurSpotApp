import Foundation
import SwiftUI

/// Service for managing blocked users locally (privacy/safety feature)
@MainActor
final class BlockService: ObservableObject {
    @Published private(set) var blockedUserIds: Set<String> = []
    
    private let blockedUsersKey = "BlockedUserIds"
    
    init() {
        loadBlockedUsers()
    }
    
    // MARK: - Public API
    
    func block(userId: String) {
        // Prevent blocking yourself if ever attempted, though UI shouldn't allow it
        // Add to set
        blockedUserIds.insert(userId)
        saveBlockedUsers()
        
        // Post notification so other parts of the app can react immediately if needed
        Foundation.NotificationCenter.default.post(name: .didBlockUser, object: nil, userInfo: ["userId": userId])
        
        Logger.info("Blocked user: \(userId)")
    }
    
    func unblock(userId: String) {
        blockedUserIds.remove(userId)
        saveBlockedUsers()
        Logger.info("Unblocked user: \(userId)")
    }
    
    func isBlocked(userId: String) -> Bool {
        return blockedUserIds.contains(userId)
    }
    
    // MARK: - Persistence
    
    private func loadBlockedUsers() {
        if let savedIds = UserDefaults.standard.stringArray(forKey: blockedUsersKey) {
            blockedUserIds = Set(savedIds)
        }
    }
    
    private func saveBlockedUsers() {
        UserDefaults.standard.set(Array(blockedUserIds), forKey: blockedUsersKey)
    }
}

extension Notification.Name {
    static let didBlockUser = Notification.Name("didBlockUser")
}
