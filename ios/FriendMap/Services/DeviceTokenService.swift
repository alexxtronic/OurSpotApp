import Foundation
import Security

/// Manages APNs device token persistence and sync to backend
@MainActor
final class DeviceTokenService: ObservableObject {
    static let shared = DeviceTokenService()
    
    private let supabase = Config.supabase
    private let keychainKey = "com.ourspot.apns.deviceToken"
    
    @Published var isRegistered = false
    
    private init() {}
    
    // MARK: - Token Management
    
    /// Register device token with backend
    func registerToken(_ token: String) async {
        // Check if token changed
        let previousToken = getStoredToken()
        if previousToken == token {
            Logger.info("APNs token unchanged, skipping registration")
            isRegistered = true
            return
        }
        
        // Store new token
        storeToken(token)
        
        // Sync to backend
        await syncTokenToBackend(token)
    }
    
    /// Sync token to Supabase
    private func syncTokenToBackend(_ token: String) async {
        guard let supabase = supabase else {
            Logger.warning("Supabase not configured, skipping token sync")
            return
        }
        
        guard let session = try? await supabase.auth.session else {
            Logger.warning("No auth session, cannot sync device token")
            return
        }
        
        let userId = session.user.id
        
        do {
            // Upsert token (insert or update on conflict)
            try await supabase
                .from("device_tokens")
                .upsert(DeviceTokenDTO(
                    user_id: userId,
                    apns_token: token,
                    platform: "ios",
                    last_seen_at: ISO8601DateFormatter().string(from: Date())
                ), onConflict: "user_id, apns_token")
                .execute()
            
            Logger.info("Device token synced to backend")
            isRegistered = true
        } catch {
            Logger.error("Failed to sync device token: \(error.localizedDescription)")
        }
    }
    
    /// Clear token on sign out
    func clearToken() async {
        guard let token = getStoredToken() else { return }
        
        // Remove from backend
        if let supabase = supabase {
            do {
                try await supabase
                    .from("device_tokens")
                    .delete()
                    .eq("apns_token", value: token)
                    .execute()
            } catch {
                Logger.error("Failed to delete device token: \(error.localizedDescription)")
            }
        }
        
        // Clear from keychain
        deleteStoredToken()
        isRegistered = false
    }
    
    // MARK: - Keychain Storage
    
    private func storeToken(_ token: String) {
        let data = token.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            Logger.error("Failed to store token in keychain: \(status)")
        }
    }
    
    private func getStoredToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    private func deleteStoredToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - DTO

private struct DeviceTokenDTO: Encodable {
    let user_id: UUID
    let apns_token: String
    let platform: String
    let last_seen_at: String
}
