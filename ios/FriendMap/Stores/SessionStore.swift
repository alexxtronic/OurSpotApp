import Foundation
import SwiftUI

/// Manages the current user session
@MainActor
final class SessionStore: ObservableObject {
    @Published var currentUser: UserProfile
    @Published var isInviteVerified: Bool = true // Mock true for now
    
    private let userDefaultsKey = "friendmap.currentUser"
    
    init() {
        // Load from UserDefaults or use placeholder
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let user = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.currentUser = user
        } else {
            self.currentUser = UserProfile.placeholder
        }
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
    
    private func saveToUserDefaults() {
        if let data = try? JSONEncoder().encode(currentUser) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            Logger.info("User profile saved")
        }
    }
}
