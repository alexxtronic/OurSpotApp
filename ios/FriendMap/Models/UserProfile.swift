import Foundation

/// Represents a user profile in the app
struct UserProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var age: Int
    var bio: String
    var avatarLocalAssetName: String?
    var avatarUrl: String? // Remote URL from Supabase
    
    // Enhanced profile fields
    var countryOfBirth: String?
    var favoriteSong: String?
    var funFact: String?
    var profileColor: String?
    
    // Social stats
    var followersCount: Int
    var followingCount: Int
    
    // Ratings
    var ratingAverage: Double
    var ratingCount: Int
    
    // Onboarding
    var onboardingCompleted: Bool
    var referralSource: String?
    
    init(
        id: UUID,
        name: String,
        age: Int,
        bio: String,
        avatarLocalAssetName: String? = nil,
        avatarUrl: String? = nil,
        countryOfBirth: String? = nil,
        favoriteSong: String? = nil,
        funFact: String? = nil,
        profileColor: String? = nil,
        followersCount: Int = 0,
        followingCount: Int = 0,
        ratingAverage: Double = 0.0,
        ratingCount: Int = 0,
        onboardingCompleted: Bool = false,
        referralSource: String? = nil
    ) {
        self.id = id
        self.name = name
        self.age = age
        self.bio = bio
        self.avatarLocalAssetName = avatarLocalAssetName
        self.avatarUrl = avatarUrl
        self.countryOfBirth = countryOfBirth
        self.favoriteSong = favoriteSong
        self.funFact = funFact
        self.profileColor = profileColor
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.ratingAverage = ratingAverage
        self.ratingCount = ratingCount
        self.onboardingCompleted = onboardingCompleted
        self.referralSource = referralSource
    }
    
    static let placeholder = UserProfile(
        id: UUID(),
        name: "New User",
        age: 25,
        bio: "Hello! I'm new to OurSpot.",
        avatarLocalAssetName: nil
    )
}
