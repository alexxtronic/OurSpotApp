import Foundation
import SwiftUI
import Supabase

/// Service for managing blocked users locally (privacy/safety feature)
@MainActor
final class BlockService: ObservableObject {
    @Published private(set) var blockedUserIds: Set<String> = []
    
    private let blockedUsersKey = "BlockedUserIds"
    private var currentUserId: UUID?
    private var supabase: SupabaseClient? { Config.supabase }
    
    init() {
        loadBlockedUsers()
    }
    
    /// Syncs blocks from Supabase for the current user.
    func refresh(userId: UUID) async {
        currentUserId = userId
        
        guard let supabase = supabase else {
            loadBlockedUsers()
            return
        }
        
        do {
            let rows: [BlockRowDTO] = try await supabase
                .from("blocks")
                .select("blocked_id")
                .eq("blocker_id", value: userId.uuidString)
                .execute()
                .value
            
            blockedUserIds = Set(rows.map { $0.blocked_id.uuidString })
            saveBlockedUsers()
        } catch {
            Logger.error("Failed to refresh blocks: \(error.localizedDescription)")
            loadBlockedUsers()
        }
    }
    
    /// Clears cached blocks (e.g. on sign out).
    func clear() {
        blockedUserIds.removeAll()
        saveBlockedUsers()
        currentUserId = nil
    }
    
    // MARK: - Public API
    
    func block(userId: String) async {
        // Prevent blocking yourself if ever attempted, though UI shouldn't allow it
        guard userId != currentUserId?.uuidString else { return }
        
        // Add to set
        blockedUserIds.insert(userId)
        saveBlockedUsers()
        
        // Post notification so other parts of the app can react immediately if needed
        Foundation.NotificationCenter.default.post(name: Notification.Name.didBlockUser, object: nil, userInfo: ["userId": userId])
        
        Logger.info("Blocked user: \(userId)")
        
        // Sync to Supabase
        guard let supabase = supabase, let currentUserId = currentUserId, let blockedUUID = UUID(uuidString: userId) else { return }
        
        do {
            try await supabase
                .from("blocks")
                .upsert(BlockInsertDTO(blocker_id: currentUserId, blocked_id: blockedUUID))
                .execute()
        } catch {
            Logger.error("Failed to sync block to Supabase: \(error.localizedDescription)")
        }
    }
    
    func unblock(userId: String) async {
        blockedUserIds.remove(userId)
        saveBlockedUsers()
        Logger.info("Unblocked user: \(userId)")
        
        guard let supabase = supabase, let currentUserId = currentUserId else { return }
        
        do {
            try await supabase
                .from("blocks")
                .delete()
                .eq("blocker_id", value: currentUserId.uuidString)
                .eq("blocked_id", value: userId)
                .execute()
        } catch {
            Logger.error("Failed to remove block from Supabase: \(error.localizedDescription)")
        }
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

// MARK: - DTOs

private struct BlockRowDTO: Decodable {
    let blocked_id: UUID
}

private struct BlockInsertDTO: Encodable {
    let blocker_id: UUID
    let blocked_id: UUID
}

extension Notification.Name {
    static let didBlockUser = Notification.Name("didBlockUser")
}
