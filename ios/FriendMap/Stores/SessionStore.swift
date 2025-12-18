import Foundation
import SwiftUI

/// Manages the current user session (local only for now)
@MainActor
final class SessionStore: ObservableObject {
    @Published var currentUser: UserProfile
    @Published var isLoading = false
    
    private let userDefaultsKey = "ourspot.currentUser"
    
    init() {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let user = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.currentUser = user
        } else {
            self.currentUser = UserProfile.placeholder
        }
    }
    
    /// Sync profile (placeholder for Supabase integration)
    func syncProfile(userId: UUID, email: String?, name: String?) async {
        // TODO: Add Supabase profile sync
        if currentUser.id != userId {
            currentUser = UserProfile(
                id: userId,
                name: name ?? "User",
                age: 25,
                bio: "Hello! I'm new to OurSpot.",
                avatarLocalAssetName: nil
            )
            saveToUserDefaults()
        }
        Logger.info("Profile synced for user: \(userId)")
    }
    
    func updateProfile(name: String, age: Int, bio: String) {
        currentUser.name = name
        currentUser.age = age
        currentUser.bio = bio
        saveToUserDefaults()
    }
    
    func updateAvatar(_ assetName: String?) {
        currentUser.avatarLocalAssetName = assetName
        saveToUserDefaults()
    }
    
    func clearSession() {
        currentUser = UserProfile.placeholder
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
    
    private func saveToUserDefaults() {
        if let data = try? JSONEncoder().encode(currentUser) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
