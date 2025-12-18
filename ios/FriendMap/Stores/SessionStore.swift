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
            return
        }
        
        isLoading = true
        
        do {
            // Try to fetch existing profile
            let response: UserProfile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            self.currentUser = response
            saveToUserDefaults()
            Logger.info("Profile fetched from Supabase")
        } catch {
            // Profile doesn't exist, create one
            Logger.info("Creating new profile for \(userId)")
            await createProfile(userId: userId, email: email, name: name)
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
                .insert([
                    "id": userId.uuidString,
                    "email": email ?? "",
                    "name": newProfile.name,
                    "age": newProfile.age,
                    "bio": newProfile.bio
                ])
                .execute()
            
            self.currentUser = newProfile
            saveToUserDefaults()
            Logger.info("Profile created in Supabase")
        } catch {
            Logger.error("Failed to create profile: \(error.localizedDescription)")
            // Use local profile as fallback
            self.currentUser = newProfile
        }
    }
    
    // MARK: - Local Updates
    
    func updateProfile(name: String, age: Int, bio: String) async {
        currentUser.name = name
        currentUser.age = age
        currentUser.bio = bio
        saveToUserDefaults()
        
        // Sync to Supabase
        guard let supabase = Config.supabase else { return }
        
        do {
            try await supabase
                .from("profiles")
                .update([
                    "name": name,
                    "age": age,
                    "bio": bio
                ])
                .eq("id", value: currentUser.id.uuidString)
                .execute()
            
            Logger.info("Profile updated in Supabase")
        } catch {
            Logger.error("Failed to sync profile update: \(error.localizedDescription)")
        }
    }
    
    func updateAvatar(_ assetName: String?) {
        currentUser.avatarLocalAssetName = assetName
        saveToUserDefaults()
        // TODO: Upload to Supabase storage when implemented
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
