import Foundation
import Auth
import PostgREST

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
    
    /// Auth client instance
    static let authClient: AuthClient? = {
        guard isSupabaseConfigured,
              let url = URL(string: "\(supabaseURL)/auth/v1") else {
            Logger.warning("Supabase not configured - running in offline mode")
            return nil
        }
        
        Logger.info("Initializing Supabase auth client...")
        
        let configuration = AuthClient.Configuration(
            url: url,
            headers: ["apikey": supabaseAnonKey, "Authorization": "Bearer \(supabaseAnonKey)"],
            flowType: .pkce,
            localStorage: UserDefaultsAuthStorage()
        )
        
        return AuthClient(configuration: configuration)
    }()
    
    /// PostgREST client instance
    static let postgrest: PostgrestClient? = {
        guard isSupabaseConfigured,
              let url = URL(string: "\(supabaseURL)/rest/v1") else {
            return nil
        }
        
        return PostgrestClient(
            url: url,
            headers: ["apikey": supabaseAnonKey, "Authorization": "Bearer \(supabaseAnonKey)"],
            logger: nil
        )
    }()
}

/// Auth storage using UserDefaults
final class UserDefaultsAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let key = "ourspot.auth"
    
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
