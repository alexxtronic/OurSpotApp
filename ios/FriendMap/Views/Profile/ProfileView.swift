import SwiftUI

import PhotosUI // Add import

/// Profile tab for editing user profile
struct ProfileView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var planStore: PlanStore
    @StateObject private var storageService = StorageService() // Storage Service
    
    @State private var name: String = ""
    @State private var age: String = ""
    @State private var bio: String = ""
    @State private var countryOfBirth: String = ""
    @State private var favoriteSong: String = ""
    @State private var funFact: String = ""
    @State private var profileColor: String = ""
    @State private var instagramHandle: String = ""
    
    @State private var selectedItem: PhotosPickerItem? // Picker State
    @State private var isUploading = false
    @State private var displayedAvatarUrl: String? = nil // Local state for immediate photo display
    
    @State private var showBlockAlert = false
    @State private var showSaveConfirmation = false
    @State private var showChangePasswordSheet = false
    @State private var errorMessage: String? // For upload errors
    
    // User List State
    @State private var showUserList = false
    @State private var selectedListTitle = ""
    @State private var selectedListUsers: [UserProfile] = []
    
    // DM inbox state
    @EnvironmentObject private var dmService: DirectMessageService  // Use shared instance!
    @State private var dmUnreadCount: Int = 0
    
    // Keyboard state for dismiss button
    @State private var isKeyboardVisible = false

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Avatar section
                        avatarSection
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        profileForm
                        
                        accountSection
                        
                        safetySection
                        
                        signOutSection
                        
                        legalLinksSection
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle("Your Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                     ToolbarItem(placement: .navigationBarTrailing) {
                         if showSaveConfirmation {
                             Image(systemName: "checkmark")
                                 .foregroundColor(.green)
                         } else {
                             Button("Save") {
                                 saveProfile()
                             }
                         }
                     }
                }
            }
            
            // Floating keyboard dismiss button
            if isKeyboardVisible {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            HapticManager.lightTap()
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.7))
                                )
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 12)
                    }
                }
                .transition(.opacity)
            }
        }
        .onReceive(Foundation.NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(Foundation.NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .sheet(isPresented: $showUserList) {
            UserListView(title: selectedListTitle, users: selectedListUsers)
        }
        .sheet(isPresented: $showChangePasswordSheet) {
            ChangePasswordView()
        }
        .onAppear {
            loadProfile()
            // Refresh DM unread count every time profile appears
            Task {
                await dmService.fetchConversations(currentUserId: sessionStore.currentUser.id)
                dmUnreadCount = dmService.totalUnreadCount
            }
        }
    }

    // ... 
    
    private var avatarSection: some View {
        ZStack {
            // Vibe color background
            if let colorHex = sessionStore.currentUser.profileColor, !colorHex.isEmpty,
               let vibeColor = Color(hex: colorHex) {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                    .fill(vibeColor.opacity(0.15))
                    .frame(height: 280)
            }
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                if isUploading {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 100, height: 100)
                        ProgressView()
                    }
                } else {
                    AvatarView(
                        name: name.isEmpty ? "User" : name,
                        size: 100,
                        url: URL(string: displayedAvatarUrl ?? ""),
                        assetName: sessionStore.currentUser.avatarLocalAssetName
                    )
                }
                
                // Follower/Following stats with DM inbox
                VStack(spacing: 0) {
                HStack(spacing: DesignSystem.Spacing.xl) {
                    // Messages Inbox
                    NavigationLink {
                        DirectMessagesListView()
                    } label: {
                        VStack {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "envelope.fill")
                                    .font(.title2)
                                    .foregroundColor(DesignSystem.Colors.primaryFallback)
                                
                                // Unread badge
                                if dmUnreadCount > 0 {
                                    ZStack {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 18, height: 18)
                                        Text("\(min(dmUnreadCount, 99))")
                                            .font(.caption2.bold())
                                            .foregroundColor(.white)
                                    }
                                    .offset(x: 8, y: -8)
                                }
                            }
                            Text("Messages")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button {
                        fetchFollowers()
                    } label: {
                        VStack {
                            Text("\(sessionStore.currentUser.followersCount)")
                                .font(.title2.bold())
                                .foregroundColor(.primary)
                            Text("Followers")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button {
                        fetchFollowing()
                    } label: {
                        VStack {
                            Text("\(sessionStore.currentUser.followingCount)")
                                .font(.title2.bold())
                                .foregroundColor(.primary)
                            Text("Following")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.sm)
                
                // Reputation score - below followers
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("REPUTATION")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.subheadline)
                        Text(String(format: "%.1f", sessionStore.currentUser.ratingAverage))
                            .font(.headline.bold())
                        Text("(\(sessionStore.currentUser.ratingCount))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                }
                }
                .padding(4)
                
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Change Photo", systemImage: "camera.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .onChange(of: selectedItem) { newItem in
                    Task {
                        if let newItem = newItem {
                            await handleAvatarSelection(item: newItem)
                        }
                    }
                }
            }
            .padding(.vertical, DesignSystem.Spacing.md)
        }
    }
    
    private func handleAvatarSelection(item: PhotosPickerItem) async {
        isUploading = true
        errorMessage = nil
        
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                // Compress and resize image to max 500KB file size
                guard let compressedData = compressImage(data: data) else {
                    errorMessage = "Failed to process image"
                    isUploading = false
                    return
                }
                
                // Clear old avatar from cache if exists
                if let oldUrl = sessionStore.currentUser.avatarUrl {
                    StorageService.clearCachedAvatar(for: URL(string: oldUrl))
                }
                
                // 1. Upload compressed image (also deletes old file)
                if let url = try await storageService.uploadAvatar(data: compressedData, userId: sessionStore.currentUser.id) {
                     // 2. Update local state immediately for instant visual feedback
                     displayedAvatarUrl = url.absoluteString
                     
                     // 3. Update Profile with new URL (also syncs to backend)
                     await sessionStore.updateAvatar(url: url.absoluteString)
                     
                     // 4. Refresh plans so new avatar shows in event cards
                     await planStore.loadPlans(currentUserId: sessionStore.currentUser.id)
                }
            }
        } catch {
            errorMessage = "Failed to upload photo: \(error.localizedDescription)"
        }
        
        isUploading = false
        selectedItem = nil // Reset picker
    }
    
    /// Compress and resize image to max 500KB file size
    /// - Parameters:
    ///   - data: Original image data
    ///   - maxDimension: Maximum width/height in pixels (default 800)
    ///   - maxFileSize: Maximum file size in bytes (default 500KB = 512000)
    private func compressImage(data: Data, maxSize: CGFloat = 800, quality: CGFloat = 0.8) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        
        let maxFileSize = 512_000 // 500KB in bytes
        
        // Calculate new size maintaining aspect ratio
        let size = image.size
        let ratio = min(maxSize / size.width, maxSize / size.height)
        
        // Only resize if image is larger than max size
        let newSize: CGSize
        if ratio < 1 {
            newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        } else {
            newSize = size
        }
        
        // Resize image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let resized = resizedImage else { return nil }
        
        // Iteratively compress with decreasing quality until under maxFileSize
        var compressionQuality: CGFloat = quality
        var compressedData = resized.jpegData(compressionQuality: compressionQuality)
        
        while let data = compressedData, data.count > maxFileSize && compressionQuality > 0.1 {
            compressionQuality -= 0.1
            compressedData = resized.jpegData(compressionQuality: compressionQuality)
            Logger.debug("📷 Compressing avatar: quality=\(compressionQuality), size=\(data.count / 1024)KB")
        }
        
        if let finalData = compressedData {
            Logger.info("✅ Avatar compressed: \(finalData.count / 1024)KB, quality=\(compressionQuality)")
        }
        
        return compressedData
    }
    
    // ... (rest of view)
    
    private var profileForm: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            
            // Bio - Reordered to top
            VStack(alignment: .leading, spacing: 4) {
                Text("Bio")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Tell friends about yourself...", text: $bio, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.tertiaryBackground)
                    .cornerRadius(DesignSystem.CornerRadius.sm)
            }
            
            Divider()
            
            SectionCard(title: "Profile") { // Renamed from Enhanced Profile
                VStack(spacing: DesignSystem.Spacing.md) {
                    
                    // Name & Age
                    HStack(spacing: DesignSystem.Spacing.md) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Name", text: $name)
                                .textContentType(.name)
                                .padding(DesignSystem.Spacing.sm)
                                .background(DesignSystem.Colors.tertiaryBackground)
                                .cornerRadius(DesignSystem.CornerRadius.sm)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Age")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Age", text: $age)
                                .keyboardType(.numberPad)
                                .frame(width: 60)
                                .padding(DesignSystem.Spacing.sm)
                                .background(DesignSystem.Colors.tertiaryBackground)
                                .cornerRadius(DesignSystem.CornerRadius.sm)
                        }
                    }
                    
                    // Country Picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Country of Birth")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Menu {
                            Picker("Country", selection: $countryOfBirth) {
                                Text("Select Country").tag("")
                                ForEach(CountryInfo.all) { country in
                                    Text("\(country.flag) \(country.name)").tag(country.flag)
                                }
                            }
                        } label: {
                            HStack {
                                Text(countryOfBirth.isEmpty ? "Select Country" : countryOfBirth)
                                    .foregroundColor(countryOfBirth.isEmpty ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(DesignSystem.Spacing.sm)
                            .background(DesignSystem.Colors.tertiaryBackground)
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                        }
                    }
                    
                    // Favorite Song
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Favorite Song")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Your current jam", text: $favoriteSong)
                            .padding(DesignSystem.Spacing.sm)
                            .background(DesignSystem.Colors.tertiaryBackground)
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                    }
                    
                    // Fun Fact
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fun Fact")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Something interesting...", text: $funFact)
                            .padding(DesignSystem.Spacing.sm)
                            .background(DesignSystem.Colors.tertiaryBackground)
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                    }

                    // Instagram Handle
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Instagram (Optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Text("@")
                                .foregroundColor(.secondary)
                            TextField("username", text: $instagramHandle)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                        }
                        .padding(DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.tertiaryBackground)
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                    }

                    
                    // Profile Color Grid
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Vibe Color")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(DesignSystem.VibeColors.allHex, id: \.self) { hex in
                                    Button {
                                        profileColor = hex
                                    } label: {
                                        Circle()
                                            .fill(Color(hex: hex) ?? .gray)
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.primary, lineWidth: profileColor == hex ? 3 : 0)
                                            )
                                            .shadow(radius: 2)
                                    }
                                }
                            }
                            .padding(4)
                        }
                    }
                }
            }
        }
    }
    
    private var accountSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Divider()
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Account")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                // Email display
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.secondary)
                    // Display "Guest" if no email is attached (Guest account)
                    Text(authService.currentSession?.user.email ?? "Guest")
                        .font(.subheadline)
                    Spacer()
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.tertiaryBackground)
                .cornerRadius(DesignSystem.CornerRadius.sm)
                
                // Change Password button
                Button {
                    showChangePasswordSheet = true
                } label: {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.blue)
                        Text("Change Password")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.tertiaryBackground)
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                }
            }
        }
        .padding(.top, DesignSystem.Spacing.md)
    }
    
    private var safetySection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("Safety")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Block and Report options appear when viewing other users' profiles.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, DesignSystem.Spacing.lg)
    }
    
    @State private var showDeleteConfirmation = false

    // ... (keep existing body until signOutSection)

    private var signOutSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Divider()
                .padding(.vertical, DesignSystem.Spacing.md)
            
            Button(role: .destructive) {
                Task {
                    await authService.signOut()
                    sessionStore.clearSession()
                }
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                        .fontWeight(.medium)
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(DesignSystem.Spacing.md)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .stroke(Color.red, lineWidth: 1.5)
                )
            }
            
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Delete Account")
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(DesignSystem.Spacing.md)
                .background(Color.red)
                .cornerRadius(DesignSystem.CornerRadius.md)
            }
            .padding(.top, 8)
        }
        .padding(.top, DesignSystem.Spacing.md)
        .alert("Delete Account?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("This action cannot be undone. All your plans, messages, and friendships will be permanently removed.")
        }
    }
    
    // MARK: - Legal Links (App Store Required)
    
    private var legalLinksSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Divider()
                .padding(.vertical, DesignSystem.Spacing.md)
            
            HStack(spacing: DesignSystem.Spacing.lg) {
                Link("Privacy", destination: URL(string: "https://alexxtronic.github.io/ourspot-legal/privacy-policy.html")!)
                Text("•").foregroundColor(.secondary)
                Link("Terms", destination: URL(string: "https://alexxtronic.github.io/ourspot-legal/terms-of-service.html")!)
                Text("•").foregroundColor(.secondary)
                Link("Support", destination: URL(string: "mailto:ourspothelper@gmail.com")!)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Text("OurSpot v1.0")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.top, DesignSystem.Spacing.xs)
        }
        .padding(.bottom, DesignSystem.Spacing.lg)
    }
    
    private func deleteAccount() {
        Task {
            do {
                try await authService.deleteAccount()
                sessionStore.clearSession()
            } catch {
                // In a real app, show error alert
                Logger.error("Failed to delete account: \(error.localizedDescription)") 
            }
        }
    }
    
    // Avatar picker removed - using PhotosPicker instead
    
    private func fetchFollowers() {
        Task {
            let service = FollowService(userId: sessionStore.currentUser.id)
            selectedListUsers = await service.fetchFollowersList()
            selectedListTitle = "Followers"
            showUserList = true
        }
    }
    
    private func fetchFollowing() {
        Task {
            let service = FollowService(userId: sessionStore.currentUser.id)
            selectedListUsers = await service.fetchFollowingList()
            selectedListTitle = "Following"
            showUserList = true
        }
    }
    
    private func loadProfile() {
        let user = sessionStore.currentUser
        name = user.name
        age = String(user.age)
        bio = user.bio
        countryOfBirth = user.countryOfBirth ?? ""
        favoriteSong = user.favoriteSong ?? ""
        funFact = user.funFact ?? ""
        instagramHandle = user.instagramHandle ?? ""
        profileColor = user.profileColor ?? ""
        displayedAvatarUrl = user.avatarUrl
    }
    
    private func saveProfile() {
        let ageInt = Int(age) ?? sessionStore.currentUser.age
        sessionStore.updateProfile(
            name: name,
            age: ageInt,
            bio: bio,
            countryOfBirth: countryOfBirth.isEmpty ? nil : countryOfBirth,
            favoriteSong: favoriteSong.isEmpty ? nil : favoriteSong,
            funFact: funFact.isEmpty ? nil : funFact,
            instagramHandle: instagramHandle.isEmpty ? nil : instagramHandle,
            profileColor: profileColor.isEmpty ? nil : profileColor
        )
        showSaveConfirmation = true
        
        // Reset save button after 2 seconds so user can save again
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSaveConfirmation = false
        }
    }
}

// MARK: - ChangePasswordView

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Old Password", text: $oldPassword)
                } header: {
                    Text("Verify Identity")
                } footer: {
                    Text("Please enter your current password to continue.")
                }
                
                Section {
                    SecureField("New Password", text: $newPassword)
                    SecureField("Confirm New Password", text: $confirmPassword)
                } header: {
                    Text("New Password")
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Section {
                    Button {
                        changePassword()
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Update Password")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(isLoading || oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your password has been updated successfully.")
            }
        }
    }
    
    private func changePassword() {
        guard newPassword == confirmPassword else {
            errorMessage = "New passwords do not match."
            return
        }
        
        guard newPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            // 1. Verify old password by re-authenticating
            if let email = authService.currentSession?.user.email {
                await authService.signInWithEmail(email: email, password: oldPassword)
                
                if authService.error != nil {
                    errorMessage = "Incorrect old password."
                    isLoading = false
                    return
                }
                
                // 2. Update to new password
                do {
                    try await authService.updatePassword(newPassword)
                    showSuccessAlert = true
                } catch {
                    errorMessage = error.localizedDescription
                }
            } else {
                errorMessage = "Could not verify user email."
            }
            
            isLoading = false
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(SessionStore())
        .environmentObject(AuthService())
}
