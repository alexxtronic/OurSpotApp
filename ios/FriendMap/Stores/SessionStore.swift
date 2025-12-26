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
                // Fix: Race condition handling
                // If local onboarding is explicitly true, don't overwrite it with false from a potentially stale fetch
                let serverOnboardingCompleted = profile.onboarding_completed ?? false
                let finalOnboardingCompleted = self.currentUser.onboardingCompleted ? true : serverOnboardingCompleted
                
                self.currentUser = UserProfile(
                    id: profile.id,
                    name: profile.name,
                    age: profile.age ?? 25,
                    bio: profile.bio ?? "",
                    avatarLocalAssetName: nil,
                    avatarUrl: profile.avatar_url,
                    countryOfBirth: profile.country_of_birth,
                    favoriteSong: profile.favorite_song,
                    funFact: profile.fun_fact,
                    profileColor: profile.profile_color,
                    followersCount: profile.followers_count ?? 0,
                    followingCount: profile.following_count ?? 0,
                    ratingAverage: profile.rating_average ?? 0.0,
                    ratingCount: profile.rating_count ?? 0,
                    onboardingCompleted: finalOnboardingCompleted
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
    
    func updateProfile(name: String, age: Int, bio: String, countryOfBirth: String?, favoriteSong: String?, funFact: String?, profileColor: String?) {
        currentUser.name = name
        currentUser.age = age
        currentUser.bio = bio
        currentUser.countryOfBirth = countryOfBirth
        currentUser.favoriteSong = favoriteSong
        currentUser.funFact = funFact
        currentUser.profileColor = profileColor
        saveToUserDefaults()
        
        // Sync to Supabase in background
        Task {
            guard let supabase = Config.supabase else { return }
            do {
                try await supabase
                    .from("profiles")
                    .update(ProfileUpdateDTO(
                        name: name,
                        age: age,
                        bio: bio,
                        onboarding_completed: currentUser.onboardingCompleted,
                        country_of_birth: countryOfBirth,
                        fun_fact: funFact,
                        referral_source: currentUser.referralSource,
                        favorite_song: favoriteSong,
                        profile_color: profileColor
                    ))
                    .eq("id", value: currentUser.id.uuidString)
                    .execute()
                Logger.info("Profile synced to Supabase")
            } catch {
                Logger.error("Profile sync failed: \(error.localizedDescription)")
            }
        }
    }
    
    func updateAvatar(url: String) async {
        // Trigger UI refresh immediately
        await MainActor.run {
            objectWillChange.send()
            currentUser.avatarUrl = url
        }
        saveToUserDefaults()
        
        guard let supabase = Config.supabase else { return }
        do {
            try await supabase
                .from("profiles")
                .update(ProfileUpdateDTO(
                    name: currentUser.name,
                    age: currentUser.age,
                    bio: currentUser.bio,
                    avatar_url: url
                ))
                .eq("id", value: currentUser.id.uuidString)
                .execute()
            Logger.info("Avatar URL synced to Supabase")
        } catch {
            Logger.error("Failed to sync avatar URL: \(error.localizedDescription)")
        }
    }
    
    func updateAvatar(_ assetName: String?) {
        currentUser.avatarLocalAssetName = assetName
        saveToUserDefaults()
    }
    
    func updateNotificationPreferences(notificationsEnabled: Bool, chatNotificationsEnabled: Bool) async {
        currentUser.notificationsEnabled = notificationsEnabled
        currentUser.chatNotificationsEnabled = chatNotificationsEnabled
        saveToUserDefaults()
        
        guard let supabase = Config.supabase else { return }
        do {
            try await supabase
                .from("profiles")
                .update([
                    "notifications_enabled": notificationsEnabled,
                    "chat_notifications_enabled": chatNotificationsEnabled
                ])
                .eq("id", value: currentUser.id.uuidString)
                .execute()
            Logger.info("Notification preferences synced to Supabase")
        } catch {
            Logger.error("Failed to sync notification preferences: \(error.localizedDescription)")
        }
    }
    
    func completeOnboarding(age: Int?, countryOfBirth: String?, funFact: String?, referralSource: String?) {
        if let age = age, age > 0 {
            currentUser.age = age
        }
        currentUser.countryOfBirth = countryOfBirth
        currentUser.funFact = funFact
        currentUser.referralSource = referralSource
        currentUser.onboardingCompleted = true
        saveToUserDefaults()
        
        // Fix: Sync to Supabase immediately to prevent overwriting on next fetch
        Task {
            guard let supabase = Config.supabase else { return }
            do {
                try await supabase
                    .from("profiles")
                    .update(ProfileUpdateDTO(
                        name: currentUser.name,
                        age: currentUser.age,
                        bio: currentUser.bio,
                        avatar_url: currentUser.avatarUrl,
                        onboarding_completed: true,
                        country_of_birth: countryOfBirth,
                        fun_fact: funFact,
                        referral_source: referralSource
                    ))
                    .eq("id", value: currentUser.id.uuidString)
                    .execute()
                Logger.info("Onboarding status synced to Supabase")
            } catch {
                Logger.error("Failed to sync onboarding status: \(error.localizedDescription)")
            }
        }
    }
    
    /// Complete onboarding with profile data (name, bio, avatar)
    func completeOnboardingWithProfile(name: String, bio: String?, avatarUrl: String?) {
        currentUser.name = name
        if let bio = bio {
            currentUser.bio = bio
        }
        if let avatarUrl = avatarUrl {
            currentUser.avatarUrl = avatarUrl
        }
        currentUser.onboardingCompleted = true
        saveToUserDefaults()
        
        // Sync to Supabase
        Task {
            guard let supabase = Config.supabase else { return }
            do {
                try await supabase
                    .from("profiles")
                    .update(ProfileUpdateDTO(
                        name: name,
                        age: currentUser.age,
                        bio: bio ?? currentUser.bio,
                        avatar_url: avatarUrl,
                        onboarding_completed: true
                    ))
                    .eq("id", value: currentUser.id.uuidString)
                    .execute()
                Logger.info("Profile onboarding synced to Supabase")
            } catch {
                Logger.error("Failed to sync profile onboarding: \(error.localizedDescription)")
            }
        }
    }
    
    func clearSession() {
        currentUser = UserProfile.placeholder
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        // Clear notifications to prevent next user from seeing them
        NotificationCenter.shared.clearAll()
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
    let avatar_url: String?
    let followers_count: Int?
    let following_count: Int?
    let rating_average: Double?
    let rating_count: Int?
    let onboarding_completed: Bool?
    let country_of_birth: String?
    let favorite_song: String?
    let fun_fact: String?
    let profile_color: String?
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
    var avatar_url: String?
    var onboarding_completed: Bool?
    var country_of_birth: String?
    var fun_fact: String?
    var referral_source: String?
    var favorite_song: String?
    var profile_color: String?
}
