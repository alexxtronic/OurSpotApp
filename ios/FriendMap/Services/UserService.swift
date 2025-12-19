import Foundation
import Supabase

/// Service for fetching other users' profiles
@MainActor
final class UserService: ObservableObject {
    
    func fetchPublicProfile(userId: UUID) async throws -> UserProfile? {
        guard let supabase = Config.supabase else { return nil }
        
        // Fetch profile
        let response: [ProfileDTO] = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .execute()
            .value
        
        guard let profile = response.first else { return nil }
        
        // Map to domain model
        return UserProfile(
            id: profile.id,
            name: profile.name,
            age: profile.age ?? 0,
            bio: profile.bio ?? "",
            avatarLocalAssetName: nil,
            avatarUrl: profile.avatar_url,
            countryOfBirth: profile.country_of_birth,
            favoriteSong: profile.favorite_song,
            funFact: profile.fun_fact,
            profileColor: profile.profile_color,
            followersCount: profile.followers_count ?? 0,
            followingCount: profile.following_count ?? 0,
            onboardingCompleted: profile.onboarding_completed ?? false
        )
    }
}

// MARK: - DTOs

private struct ProfileDTO: Decodable {
    let id: UUID
    let name: String
    let age: Int?
    let bio: String?
    let avatar_url: String?
    let followers_count: Int?
    let following_count: Int?
    let onboarding_completed: Bool?
    let country_of_birth: String?
    let favorite_song: String?
    let fun_fact: String?
    let profile_color: String?
}
