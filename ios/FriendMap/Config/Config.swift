import Foundation
import Auth

/// Configuration and Supabase client initialization
/// Reads from Config.plist - create from Config.example.plist
enum Config {
    private static var configDict: [String: Any]? = {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            Logger.warning("Config.plist not found. Using placeholder values.")
            return nil
        }
        return dict
    }()
    
    /// Supabase project URL
    static var supabaseURL: String {
        configDict?["SUPABASE_URL"] as? String ?? ""
    }
    
    /// Supabase anonymous key
    static var supabaseAnonKey: String {
        configDict?["SUPABASE_ANON_KEY"] as? String ?? ""
    }
    
    /// Returns true if Supabase is properly configured
    static var isSupabaseConfigured: Bool {
        !supabaseURL.isEmpty && !supabaseAnonKey.isEmpty
    }
    
    /// Shared Auth client instance
    static let authClient: AuthClient? = {
        guard isSupabaseConfigured,
              let url = URL(string: "\(supabaseURL)/auth/v1") else {
            Logger.warning("Supabase not configured - running in offline mode")
            return nil
        }
        
        Logger.info("Initializing Supabase auth client...")
        return AuthClient(
            url: url,
            headers: ["apikey": supabaseAnonKey],
            localStorage: AuthLocalStorage()
        )
    }()
    
    /// Base URL for PostgREST
    static var postgrestURL: URL? {
        guard isSupabaseConfigured else { return nil }
        return URL(string: "\(supabaseURL)/rest/v1")
    }
}

/// Simple auth storage using UserDefaults
final class AuthLocalStorage: AuthLocalStorageProtocol {
    private let key = "ourspot.auth.session"
    
    func store(key: String, value: Data) throws {
        UserDefaults.standard.set(value, forKey: "\(self.key).\(key)")
    }
    
    func retrieve(key: String) throws -> Data? {
        UserDefaults.standard.data(forKey: "\(self.key).\(key)")
    }
    
    func remove(key: String) throws {
        UserDefaults.standard.removeObject(forKey: "\(self.key).\(key)")
    }
}
