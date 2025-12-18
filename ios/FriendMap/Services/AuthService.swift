import Foundation
import AuthenticationServices
import Supabase

/// Service for handling authentication with Supabase
@MainActor
final class AuthService: NSObject, ObservableObject {
    @Published var currentSession: Session?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    
    private var authStateTask: Task<Void, Never>?
    
    override init() {
        super.init()
        setupAuthStateListener()
    }
    
    deinit {
        authStateTask?.cancel()
    }
    
    // MARK: - Auth State Listener
    
    private func setupAuthStateListener() {
        guard let supabase = Config.supabase else {
            Logger.warning("Supabase not configured - auth disabled")
            return
        }
        
        authStateTask = Task {
            for await (event, session) in supabase.auth.authStateChanges {
                Logger.info("Auth state changed: \(event)")
                self.currentSession = session
                self.isAuthenticated = session != nil
            }
        }
        
        // Check for existing session
        Task {
            do {
                let session = try await supabase.auth.session
                self.currentSession = session
                self.isAuthenticated = true
                Logger.info("Restored existing session")
            } catch {
                Logger.info("No existing session")
            }
        }
    }
    
    // MARK: - Sign In with Apple
    
    func signInWithApple() async {
        guard let supabase = Config.supabase else {
            self.error = "Supabase not configured"
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            // Use Supabase's built-in Apple auth
            try await supabase.auth.signInWithOAuth(provider: .apple) { url in
                // Return the redirect URL for the auth flow
                return url
            }
            Logger.info("Sign in with Apple initiated")
        } catch {
            Logger.error("Sign in with Apple failed: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Email Sign In (Development fallback)
    
    func signInWithEmail(email: String, password: String) async {
        guard let supabase = Config.supabase else {
            self.error = "Supabase not configured"
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            let session = try await supabase.auth.signIn(email: email, password: password)
            self.currentSession = session
            self.isAuthenticated = true
            Logger.info("Signed in with email: \(email)")
        } catch {
            Logger.error("Email sign in failed: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Email Sign Up
    
    func signUpWithEmail(email: String, password: String, name: String) async {
        guard let supabase = Config.supabase else {
            self.error = "Supabase not configured"
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: ["name": .string(name)]
            )
            
            if let session = response.session {
                self.currentSession = session
                self.isAuthenticated = true
                Logger.info("Signed up with email: \(email)")
            } else {
                Logger.info("Check email for confirmation link")
                self.error = "Check your email to confirm your account"
            }
        } catch {
            Logger.error("Email sign up failed: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Sign Out
    
    func signOut() async {
        guard let supabase = Config.supabase else { return }
        
        do {
            try await supabase.auth.signOut()
            self.currentSession = nil
            self.isAuthenticated = false
            Logger.info("Signed out")
        } catch {
            Logger.error("Sign out failed: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Current User ID
    
    var currentUserId: UUID? {
        currentSession?.user.id
    }
}
