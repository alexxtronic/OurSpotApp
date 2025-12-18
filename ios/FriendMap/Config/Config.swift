import Foundation
import Supabase

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
    
    /// Shared Supabase client instance
    static let supabase: SupabaseClient? = {
        guard isSupabaseConfigured,
              let url = URL(string: supabaseURL) else {
            Logger.warning("Supabase not configured - running in offline mode")
            return nil
        }
        
        Logger.info("Initializing Supabase client...")
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: supabaseAnonKey
        )
    }()
}
