import Foundation
import SwiftUI
import Supabase

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
        guard let supabase = Config.supabase else {
            Logger.warning("Supabase not configured - using local profile")
            // Update local profile with ID
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
                    avatarLocalAssetName: nil
                )
                saveToUserDefaults()
                Logger.info("Profile fetched from Supabase")
            } else {
                // Profile doesn't exist, create one
                await createProfile(userId: userId, email: email, name: name)
            }
        } catch {
            Logger.error("Failed to fetch profile: \(error.localizedDescription)")
            // Use local profile as fallback
            currentUser = UserProfile(
                id: userId,
                name: name ?? "User",
                age: 25,
                bio: "Hello! I'm new to OurSpot.",
                avatarLocalAssetName: nil
            )
        }
        
        isLoading = false
    }
    
    /// Create a new profile in Supabase
    private func createProfile(userId: UUID, email: String?, name: String?) async {
        guard let supabase = Config.supabase else { return }
        
        let newProfile = UserProfile(
            id: userId,
            name: name ?? "New User",
            age: 25,
            bio: "Hello! I'm new to OurSpot.",
            avatarLocalAssetName: nil
        )
        
        do {
            try await supabase
                .from("profiles")
                .insert(ProfileInsertDTO(
                    id: userId,
                    email: email ?? "",
                    name: newProfile.name,
                    age: newProfile.age,
                    bio: newProfile.bio
                ))
                .execute()
            
            self.currentUser = newProfile
            saveToUserDefaults()
            Logger.info("Profile created in Supabase")
        } catch {
            Logger.error("Failed to create profile: \(error.localizedDescription)")
            self.currentUser = newProfile
        }
    }
    
    // MARK: - Local Updates
    
    func updateProfile(name: String, age: Int, bio: String) {
        currentUser.name = name
        currentUser.age = age
        currentUser.bio = bio
        saveToUserDefaults()
        
        // Sync to Supabase in background
        Task {
            await syncProfileToSupabase()
        }
    }
    
    private func syncProfileToSupabase() async {
        guard let supabase = Config.supabase else { return }
        
        do {
            try await supabase
                .from("profiles")
                .update(ProfileUpdateDTO(
                    name: currentUser.name,
                    age: currentUser.age,
                    bio: currentUser.bio
                ))
                .eq("id", value: currentUser.id.uuidString)
                .execute()
            
            Logger.info("Profile synced to Supabase")
        } catch {
            Logger.error("Failed to sync profile: \(error.localizedDescription)")
        }
    }
    
    func updateAvatar(_ assetName: String?) {
        currentUser.avatarLocalAssetName = assetName
        saveToUserDefaults()
    }
    
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

// MARK: - DTOs for Supabase

private struct ProfileDTO: Decodable {
    let id: UUID
    let name: String
    let age: Int?
    let bio: String?
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
