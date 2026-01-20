import SwiftUI
import CryptoKit
import AuthenticationServices

/// Sign in screen with Apple and email options
struct SignInView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.colorScheme) var colorScheme
    
    @State private var showEmailForm = false
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    
    // Focus state to control keyboard
    enum FormField {
        case name, email, password
    }
    @FocusState private var focusedField: FormField?
    
    // Apple Sign-In nonce for security
    @State private var currentNonce: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()
                
                // Logo and title
                VStack(spacing: DesignSystem.Spacing.md) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                    
                    Text("OurSpot")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    
                    Text("Meet new friends in any city")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Auth buttons
                VStack(spacing: DesignSystem.Spacing.md) {
                    // FIRST - Guest login (most prominent for easy access)
                    Button {
                        Task {
                            await authService.signInAnonymously()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                            Text("Continue as Guest")
                        }
                        .font(.headline)
                        .foregroundColor(.white) // Keep white on colored button
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(DesignSystem.Colors.primaryFallback)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                    }
                    
                    // "or create an account" text (No dividers, larger font)
                    Text("or create an account")
                        .font(.system(size: 16, weight: .medium)) // ~40% larger than caption (11-12pt)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding(.vertical, 4)
                    
                    // Sign in with Apple
                    // Use adaptive style: White for Dark Mode (visibility), Black for Light Mode
                    SignInWithAppleButton(type: .signIn, style: colorScheme == .dark ? .white : .black) { request in
                        let nonce = randomNonceString()
                        currentNonce = nonce
                        request.requestedScopes = [.email, .fullName]
                        request.nonce = sha256(nonce)
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                               let identityToken = appleIDCredential.identityToken,
                               let tokenString = String(data: identityToken, encoding: .utf8),
                               let nonce = currentNonce {
                                Task {
                                    await authService.signInWithApple(idToken: tokenString, nonce: nonce)
                                }
                            }
                        case .failure(let error):
                            Logger.error("Apple Sign-In failed: \(error.localizedDescription)")
                        }
                    }
                    .frame(height: 50)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .stroke(colorScheme == .dark ? Color.white : Color.black, lineWidth: 1)
                    )
                    
                    // Email sign in button
                    Button {
                        showEmailForm = true
                        isSignUp = false
                    } label: {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("Continue with Email")
                        }
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(DesignSystem.Colors.inputBackground)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                
                // Error display
                if let error = authService.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Terms
                VStack(spacing: 4) {
                    Text("By continuing, you agree to our")
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    HStack(spacing: 4) {
                        Link("Terms of Service", destination: URL(string: "https://alexxtronic.github.io/ourspot-legal/terms-of-service.html")!)
                        Text("and")
                        Link("Privacy Policy", destination: URL(string: "https://alexxtronic.github.io/ourspot-legal/privacy-policy.html")!)
                    }
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.md)
            }
            .sheet(isPresented: $showEmailForm) {
                emailFormSheet
            }
            .overlay {
                if authService.isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }
            .background(DesignSystem.Colors.screenBackground)
        }
        .background(DesignSystem.Colors.screenBackground.ignoresSafeArea())
        // Removed .preferredColorScheme(.dark) to enable Light Mode support
    }
    
    private var emailFormSheet: some View {
        NavigationStack {
            Form {
                if isSignUp {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .autocapitalization(.words)
                        .focused($focusedField, equals: .name)
                }
                
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .focused($focusedField, equals: .email)
                
                SecureField("Password", text: $password)
                    .textContentType(isSignUp ? .newPassword : .password)
                    .focused($focusedField, equals: .password)
                
                if let error = authService.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle(isSignUp ? "Create Account" : "Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        focusedField = nil // Dismiss keyboard
                        showEmailForm = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isSignUp ? "Create" : "Sign In") {
                        // IMMEDIATELY dismiss keyboard before async work
                        focusedField = nil
                        
                        Task {
                            if isSignUp {
                                await authService.signUpWithEmail(email: email, password: password, name: name)
                            } else {
                                await authService.signInWithEmail(email: email, password: password)
                            }
                            if authService.isAuthenticated {
                                // Wait for keyboard to fully dismiss
                                try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
                                showEmailForm = false
                            }
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || (isSignUp && name.isEmpty))
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    isSignUp.toggle()
                } label: {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.primaryFallback)
                }
                .padding()
            }
        }
        .presentationDetents([.medium])
    }
}

// Sign in with Apple button wrapper

struct SignInWithAppleButton: UIViewRepresentable {
    let type: ASAuthorizationAppleIDButton.ButtonType
    let style: ASAuthorizationAppleIDButton.Style
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void
    
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: type, style: style)
        button.addTarget(context.coordinator, action: #selector(Coordinator.handleTap), for: .touchUpInside)
        return button
    }
    
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let parent: SignInWithAppleButton
        
        init(_ parent: SignInWithAppleButton) {
            self.parent = parent
        }
        
        @objc func handleTap() {
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            parent.onRequest(request)
            
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
        
        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? UIWindow()
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            parent.onCompletion(.success(authorization))
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            parent.onCompletion(.failure(error))
        }
    }
}

// MARK: - Nonce Generation for Apple Sign-In

/// Generates a random nonce string for Apple Sign-In security
private func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    var randomBytes = [UInt8](repeating: 0, count: length)
    let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    if errorCode != errSecSuccess {
        fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
    }
    
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    let nonce = randomBytes.map { byte in
        charset[Int(byte) % charset.count]
    }
    return String(nonce)
}

/// Creates a SHA256 hash of the nonce for Apple Sign-In
private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    return hashedData.compactMap { String(format: "%02x", $0) }.joined()
}

#Preview {
    SignInView()
        .environmentObject(AuthService())
}
