import SwiftUI
import PhotosUI

/// Premium onboarding flow shown after sign-up
struct OnboardingView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    var onComplete: () -> Void
    
    @State private var currentStep = 0
    @State private var animateContent = false
    
    // Profile fields
    @State private var displayName = ""
    @State private var bio = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarImage: Image?
    @State private var avatarData: Data?
    @State private var isUploadingPhoto = false
    @FocusState private var isTextFieldFocused: Bool
    
    private let totalSteps = 5
    
    var body: some View {
        ZStack {
            // Background - tap to dismiss keyboard
            Color.white
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            
            VStack(spacing: 0) {
                // Progress dots
                progressDots
                    .padding(.top, 16)
                
                // Content
                TabView(selection: $currentStep) {
                    welcomeScreen.tag(0)
                    howItWorksScreen.tag(1)
                    chatScreen.tag(2)
                    trustScreen.tag(3)
                    profileScreen.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
            }
        }
        .ignoresSafeArea(.keyboard) // Don't let keyboard push up content
        .onChange(of: currentStep) { _, _ in
            HapticManager.lightTap()
            animateContent = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    animateContent = true
                }
            }
            // Update keyboard blocking logic
            updateKeyboardMonitor(for: currentStep)
        }
        .onAppear {
            // Pre-fill name if available
            if !sessionStore.currentUser.name.isEmpty && sessionStore.currentUser.name != "New User" {
                displayName = sessionStore.currentUser.name
            }
            
            // Initial keyboard setup
            hideKeyboard()
            updateKeyboardMonitor(for: currentStep)
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3)) {
                animateContent = true
            }
        }
        .onDisappear {
             removeKeyboardMonitor()
        }
    }
    
    // MARK: - Keyboard Monitoring
    
    // Store the observer token
    @State private var keyboardObserver: NSObjectProtocol?
    
    private func updateKeyboardMonitor(for step: Int) {
        // Always remove existing first to avoid duplicates
        removeKeyboardMonitor()
        
        // If we are on the first few screens (0-3), BLOCK the keyboard
        // If we are on Profile screen (4), ALLOW the keyboard
        if step < 4 {
            keyboardObserver = Foundation.NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
                hideKeyboard()
            }
        }
    }
    
    private func removeKeyboardMonitor() {
        if let observer = keyboardObserver {
            Foundation.NotificationCenter.default.removeObserver(observer)
            keyboardObserver = nil
        }
    }
    
    // MARK: - Progress Dots
    
    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? Color.orange : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(step == currentStep ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3), value: currentStep)
            }
        }
    }
    
    // MARK: - Screen 1: Welcome
    
    private var welcomeScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Logo
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .scaleEffect(animateContent ? 1.0 : 0.5)
                .opacity(animateContent ? 1.0 : 0)
            
            // Headline
            Text("Never go out alone again")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .opacity(animateContent ? 1.0 : 0)
                .offset(y: animateContent ? 0 : 20)
            
            // Subhead
            Text("No creeps allowed")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.gray)
                .opacity(animateContent ? 1.0 : 0)
                .offset(y: animateContent ? 0 : 20)
            
            // Bullets
            VStack(alignment: .leading, spacing: 12) {
                bulletPoint("Public map where anyone can ask to join")
                bulletPoint("Peer reviewed members")
                bulletPoint("New friends for life")
            }
            .padding(.top, 16)
            .opacity(animateContent ? 1.0 : 0)
            .offset(y: animateContent ? 0 : 20)
            
            Spacer()
            Spacer()
            
            // Next button
            nextButton()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Screen 2: How It Works
    
    private var howItWorksScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(animateContent ? 1.0 : 0.5)
                .opacity(animateContent ? 1.0 : 0)
            
            Text("Drop a plan on the map")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .opacity(animateContent ? 1.0 : 0)
            
            VStack(alignment: .leading, spacing: 16) {
                featureRow(icon: "clock", text: "Pick a time + place. Keep it simple.")
                featureRow(icon: "globe", text: "Keep it public, allow anyone to request to join & make new friends!")
                featureRow(icon: "lock", text: "...or make it private and only people you invite can see it")
            }
            .padding(.top, 8)
            .opacity(animateContent ? 1.0 : 0)
            .offset(y: animateContent ? 0 : 20)
            
            Spacer()
            Spacer()
            
            nextButton()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Screen 3: Chat
    
    private var chatScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Chat bubble visual
            ZStack {
                // Background bubbles
                HStack(spacing: -20) {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .fill(Color.yellow.opacity(0.2))
                        .frame(width: 80, height: 80)
                }
                
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .scaleEffect(animateContent ? 1.0 : 0.5)
            .opacity(animateContent ? 1.0 : 0)
            
            Text("Private group chat lets you\ncoordinate before meeting")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .opacity(animateContent ? 1.0 : 0)
            
            Text("All chats are temporary & deleted\nafter the event is over")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .opacity(animateContent ? 1.0 : 0)
                .offset(y: animateContent ? 0 : 10)
            
            Spacer()
            Spacer()
            
            nextButton()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Screen 4: Trust/Safety
    
    private var trustScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // High-five image
            Image("HighFiveHands")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .scaleEffect(animateContent ? 1.0 : 0.5)
                .opacity(animateContent ? 1.0 : 0)
            
            Text("This is NOT a dating app.")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .opacity(animateContent ? 1.0 : 0)
            
            Text("Users are reviewed by the community,\nno creeps allowed")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .opacity(animateContent ? 1.0 : 0)
                .offset(y: animateContent ? 0 : 10)
            
            Spacer()
            Spacer()
            
            nextButton()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Screen 5: Profile Setup
    
    private var profileScreen: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("Let's set up your profile")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .opacity(animateContent ? 1.0 : 0)
            
            // Photo picker
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack {
                    if let avatarImage = avatarImage {
                        avatarImage
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    // Edit badge
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 40, y: 40)
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        avatarData = data
                        if let uiImage = UIImage(data: data) {
                            avatarImage = Image(uiImage: uiImage)
                        }
                    }
                }
            }
            .scaleEffect(animateContent ? 1.0 : 0.8)
            .opacity(animateContent ? 1.0 : 0)
            
            // Name field
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.caption)
                    .foregroundColor(.black.opacity(0.6))
                    .fontWeight(.medium)
                
                TextField("Your name", text: $displayName)
                    .font(.body)
                    .foregroundColor(.black)
                    .focused($isTextFieldFocused)
                    .padding(16)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }
            .padding(.top, 8)
            .opacity(animateContent ? 1.0 : 0)
            
            // Bio field (optional)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Bio")
                        .font(.caption)
                        .foregroundColor(.black.opacity(0.6))
                        .fontWeight(.medium)
                    Text("(optional)")
                        .font(.caption)
                        .foregroundColor(.black.opacity(0.4))
                }
                
                TextField("I like to go out for coffee...", text: $bio, axis: .vertical)
                    .font(.body)
                    .foregroundColor(.black)
                    .focused($isTextFieldFocused)
                    .lineLimit(3...5)
                    .padding(16)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }
            .opacity(animateContent ? 1.0 : 0)
            
            Spacer()
            
            // Let's Go button
            Button {
                completeOnboarding()
            } label: {
                HStack {
                    if isUploadingPhoto {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Let's Go!")
                            .font(.headline)
                        Image(systemName: "arrow.right")
                            .font(.headline)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .orange.opacity(0.3), radius: 8, y: 4)
            }
            .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || isUploadingPhoto)
            .opacity(displayName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 32)
        .onTapGesture {
            isTextFieldFocused = false
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isTextFieldFocused = false
                }
                .foregroundColor(.orange)
                .fontWeight(.semibold)
            }
        }
    }
    
    // MARK: - Components
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 20))
            
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.black.opacity(0.7))
        }
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.orange)
                .frame(width: 28)
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.black.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func nextButton() -> some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentStep += 1
            }
        } label: {
            HStack {
                Text("Next")
                    .font(.headline)
                Image(systemName: "arrow.right")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.orange, .yellow],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .orange.opacity(0.3), radius: 8, y: 4)
        }
        .padding(.bottom, 32)
    }
    
    // MARK: - Complete Onboarding
    
    private func completeOnboarding() {
        // Safe to remove monitor now
        removeKeyboardMonitor()
        
        isUploadingPhoto = true
        HapticManager.success()
        
        Task {
            // Upload avatar if selected
            var avatarUrl: String? = nil
            if let avatarData = avatarData {
                avatarUrl = await uploadAvatar(data: avatarData)
            }
            
            // Save profile via SessionStore
            await MainActor.run {
                // Double check removal
                removeKeyboardMonitor()
                
                sessionStore.completeOnboardingWithProfile(
                    name: displayName.trimmingCharacters(in: .whitespaces),
                    bio: bio.isEmpty ? nil : bio,
                    avatarUrl: avatarUrl
                )
                
                onComplete()
            }
        }
    }
    
    private func uploadAvatar(data: Data) async -> String? {
        guard let supabase = Config.supabase else { return nil }
        
        let fileName = "\(sessionStore.currentUser.id.uuidString)-\(Date().timeIntervalSince1970).jpg"
        
        do {
            try await supabase.storage
                .from("avatars")
                .upload(
                    path: fileName,
                    file: data,
                    options: .init(contentType: "image/jpeg")
                )
            
            let publicUrl = try supabase.storage
                .from("avatars")
                .getPublicURL(path: fileName)
            
            return publicUrl.absoluteString
        } catch {
            Logger.error("Failed to upload avatar: \(error)")
            return nil
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { window in
                window.endEditing(true)
                window.rootViewController?.view.endEditing(true)
            }
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .environmentObject(SessionStore())
}
