import Foundation
import Supabase

/// Service for managing follows/social relationships
@MainActor
final class FollowService: ObservableObject {
    @Published var followers: [UUID] = []
    @Published var following: [UUID] = []
    @Published var followersCount: Int = 0
    @Published var followingCount: Int = 0
    
    private let userId: UUID
    
    init(userId: UUID) {
        self.userId = userId
    }
    
    // MARK: - Fetch Counts
    
    func fetchCounts() async {
        guard let supabase = Config.supabase else { return }
        
        do {
            // Get following count
            let followingResponse: [FollowDTO] = try await supabase
                .from("follows")
                .select()
                .eq("follower_id", value: userId.uuidString)
                .execute()
                .value
            
            // Get followers count
            let followersResponse: [FollowDTO] = try await supabase
                .from("follows")
                .select()
                .eq("following_id", value: userId.uuidString)
                .execute()
                .value
            
            self.followingCount = followingResponse.count
            self.followersCount = followersResponse.count
            self.following = followingResponse.map { $0.following_id }
            self.followers = followersResponse.map { $0.follower_id }
            
            Logger.info("Loaded \(followersCount) followers, \(followingCount) following")
        } catch {
            Logger.error("Failed to fetch follow counts: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Follow/Unfollow
    
    func follow(userId targetUserId: UUID) async -> Bool {
        guard let supabase = Config.supabase else { return false }
        
        do {
            try await supabase
                .from("follows")
                .insert(FollowInsertDTO(follower_id: userId, following_id: targetUserId))
                .execute()
            
            followingCount += 1
            following.append(targetUserId)
            Logger.info("Followed user: \(targetUserId)")
            return true
        } catch {
            Logger.error("Failed to follow: \(error.localizedDescription)")
            return false
        }
    }
    
    func unfollow(userId targetUserId: UUID) async -> Bool {
        guard let supabase = Config.supabase else { return false }
        
        do {
            try await supabase
                .from("follows")
                .delete()
                .eq("follower_id", value: userId.uuidString)
                .eq("following_id", value: targetUserId.uuidString)
                .execute()
            
            followingCount -= 1
            following.removeAll { $0 == targetUserId }
            Logger.info("Unfollowed user: \(targetUserId)")
            return true
        } catch {
            Logger.error("Failed to unfollow: \(error.localizedDescription)")
            return false
        }
    }
    
    func isFollowing(_ targetUserId: UUID) -> Bool {
        following.contains(targetUserId)
    }
}

// MARK: - DTOs

private struct FollowDTO: Decodable {
    let id: UUID
    let follower_id: UUID
    let following_id: UUID
}

private struct FollowInsertDTO: Encodable {
    let follower_id: UUID
    let following_id: UUID
}
