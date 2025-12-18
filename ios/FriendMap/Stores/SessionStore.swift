import Foundation
import SwiftUI
import Auth
import PostgREST

/// Manages the current user session and profile sync with Supabase
@MainActor
final class SessionStore: ObservableObject {
    @Published var currentUser: UserProfile
    @Published var isLoading = false
    
    private let userDefaultsKey = "ourspot.currentUser"
    
    init() {
        // Load from UserDefaults as initial cache
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let user = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.currentUser = user
        } else {
            self.currentUser = UserProfile.placeholder
        }
    }
    
    // MARK: - Supabase Profile Sync
    
    /// Fetch or create profile for authenticated user
    func syncProfile(userId: UUID, email: String?, name: String?) async {
        guard Config.isSupabaseConfigured,
              let postgrestURL = Config.postgrestURL else {
            Logger.warning("Supabase not configured - using local profile")
            return
        }
        
        isLoading = true
        
        // For now, just update local profile with auth info
        // Full PostgREST integration can be added later
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
        
        isLoading = false
        Logger.info("Profile synced for user: \(userId)")
    }
    
    // MARK: - Local Updates
    
    func updateProfile(name: String, age: Int, bio: String) {
        currentUser.name = name
        currentUser.age = age
        currentUser.bio = bio
        saveToUserDefaults()
        Logger.info("Profile updated locally")
    }
    
    func updateAvatar(_ assetName: String?) {
        currentUser.avatarLocalAssetName = assetName
        saveToUserDefaults()
    }
    
    /// Clear local session on sign out
    func clearSession() {
        currentUser = UserProfile.placeholder
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        Logger.info("Session cleared")
    }
    
    private func saveToUserDefaults() {
        if let data = try? JSONEncoder().encode(currentUser) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
