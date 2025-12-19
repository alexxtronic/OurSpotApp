import Foundation
import SwiftUI
import Supabase

/// Manages the current user session and profile sync
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
    
    // MARK: - Profile Sync
    
    func syncProfile(userId: UUID, email: String?, name: String?) async {
        // Update local profile
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
        
        guard let supabase = Config.supabase else {
            Logger.warning("Supabase not configured - using local profile")
            return
        }
        
        isLoading = true
        
        do {
            // Try to fetch existing profile
            let response: [ProfileDTO] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .execute()
                .value
            
            if let profile = response.first {
                self.currentUser = UserProfile(
                    id: profile.id,
                    name: profile.name,
                    age: profile.age ?? 25,
                    bio: profile.bio ?? "",
                    avatarLocalAssetName: nil,
                    followersCount: profile.followers_count ?? 0,
                    followingCount: profile.following_count ?? 0,
                    onboardingCompleted: profile.onboarding_completed ?? false
                )
                saveToUserDefaults()
                Logger.info("Profile fetched from Supabase")
            } else {
                // Create profile
                try await supabase
                    .from("profiles")
                    .insert(ProfileInsertDTO(
                        id: userId,
                        email: email ?? "",
                        name: currentUser.name,
                        age: currentUser.age,
                        bio: currentUser.bio
                    ))
                    .execute()
                Logger.info("Profile created in Supabase")
            }
        } catch {
            Logger.error("Profile sync failed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func updateProfile(name: String, age: Int, bio: String) {
        currentUser.name = name
        currentUser.age = age
        currentUser.bio = bio
        saveToUserDefaults()
        
        // Sync to Supabase in background
        Task {
            guard let supabase = Config.supabase else { return }
            do {
                try await supabase
                    .from("profiles")
                    .update(ProfileUpdateDTO(name: name, age: age, bio: bio))
                    .eq("id", value: currentUser.id.uuidString)
                    .execute()
                Logger.info("Profile synced to Supabase")
            } catch {
                Logger.error("Profile sync failed: \(error.localizedDescription)")
            }
        }
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

// MARK: - DTOs

private struct ProfileDTO: Decodable {
    let id: UUID
    let name: String
    let age: Int?
    let bio: String?
    let followers_count: Int?
    let following_count: Int?
    let onboarding_completed: Bool?
}

private struct ProfileInsertDTO: Encodable {
    let id: UUID
    let email: String
    let name: String
    let age: Int
    let bio: String
}

private struct ProfileUpdateDTO: Encodable {
    let name: String
    let age: Int
    let bio: String
}
