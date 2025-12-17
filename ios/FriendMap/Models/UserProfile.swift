import Foundation

/// Represents a user profile in the app
struct UserProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var age: Int
    var bio: String
    var avatarLocalAssetName: String?
    
    static let placeholder = UserProfile(
        id: UUID(),
        name: "New User",
        age: 25,
        bio: "Hello! I'm new to FriendMap.",
        avatarLocalAssetName: nil
    )
}
