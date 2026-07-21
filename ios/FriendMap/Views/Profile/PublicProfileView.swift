import SwiftUI
import Supabase

// MARK: - ViewModel (with static cache for guaranteed single-load)

/// ViewModel for PublicProfileView that handles all data loading with proper load-once semantics.
/// Uses a STATIC CACHE to ensure the same ViewModel instance is reused for the same userId,
/// even when SwiftUI recreates the view struct multiple times.
@MainActor
final class PublicProfileViewModel: ObservableObject {
    // MARK: - Static Cache (persists across ALL view recreations)
    private static var cache: [UUID: PublicProfileViewModel] = [:]
    
    static func getInstance(for userId: UUID) -> PublicProfileViewModel {
        if let existing = cache[userId] {
            return existing
        }
        let new = PublicProfileViewModel(userId: userId)
        cache[userId] = new
        return new
    }
    
    /// Clears cache when navigating away (call from onDisappear if needed)
    static func clearCache(for userId: UUID? = nil) {
        if let userId = userId {
            cache.removeValue(forKey: userId)
        } else {
            cache.removeAll()
        }
    }
    
    let userId: UUID
    
    // MARK: - Published State
    @Published var user: UserProfile?
    @Published var isLoading = true
    @Published var followersCount: Int = 0
    @Published var followingCount: Int = 0
    @Published var isFollowing = false
    
    // Rating state
    @Published var myRating: Int?
    @Published var targetUserRatingAverage: Double = 0.0
    @Published var targetUserRatingCount: Int = 0
    
    // MARK: - Private State (persists in cache!)
    private var hasLoaded = false
    private let userService = UserService()
    
    private init(userId: UUID) {
        self.userId = userId
    }
    
    /// Loads data only once. Safe to call multiple times.
    func loadDataIfNeeded(currentUserId: UUID) async {
        // Critical: Only load ONCE - this flag persists because it's in the class, not the view
        guard !hasLoaded else { return }
        hasLoaded = true
        
        HapticManager.lightTap()
        
        // Run all fetches concurrently
        async let profileFetch = userService.fetchPublicProfile(userId: userId)
        async let statsFetch = fetchStats()
        async let followCheck: () = checkIfFollowing(currentUserId: currentUserId)
        async let ratingFetch: () = fetchRatings(currentUserId: currentUserId)
        
        // Await all
        let (fetchedUser, stats, _, _) = await (try? profileFetch, statsFetch, followCheck, ratingFetch)
        
        // Batch update all state at once with animation
        withAnimation(.easeOut(duration: 0.3)) {
            user = fetchedUser
            followersCount = stats.followers
            followingCount = stats.following
            isLoading = false
        }
    }
    
    // MARK: - Stats Fetching
    
    private func fetchStats() async -> (followers: Int, following: Int) {
        guard let supabase = Config.supabase else { return (0, 0) }
        
        do {
            async let followersFetch: [FollowDTO] = supabase
                .from("follows")
                .select()
                .eq("following_id", value: userId.uuidString)
                .execute()
                .value
            
            async let followingFetch: [FollowDTO] = supabase
                .from("follows")
                .select()
                .eq("follower_id", value: userId.uuidString)
                .execute()
                .value
            
            let (followers, following) = try await (followersFetch, followingFetch)
            return (followers.count, following.count)
        } catch {
            Logger.error("Failed to fetch stats: \(error.localizedDescription)")
            return (0, 0)
        }
    }
    
    // MARK: - Follow State
    
    private func checkIfFollowing(currentUserId: UUID) async {
        guard let supabase = Config.supabase else { return }
        
        do {
            let response: [FollowDTO] = try await supabase
                .from("follows")
                .select()
                .eq("follower_id", value: currentUserId.uuidString)
                .eq("following_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            
            isFollowing = !response.isEmpty
        } catch {
            Logger.error("Follow check failed: \(error.localizedDescription)")
        }
    }
    
    func toggleFollow(currentUserId: UUID) async {
        let myService = FollowService(userId: currentUserId)
        
        if isFollowing {
            if await myService.unfollow(userId: userId) {
                isFollowing = false
                followersCount -= 1
            }
        } else {
            if await myService.follow(userId: userId) {
                isFollowing = true
                followersCount += 1
            }
        }
    }
    
    // MARK: - Ratings
    
    private func fetchRatings(currentUserId: UUID) async {
        await fetchAggregateRating()
        
        if userId != currentUserId {
            await fetchMyRating(currentUserId: currentUserId)
        }
    }
    
    private func fetchAggregateRating() async {
        guard let supabase = Config.supabase else { return }
        
        do {
            let response: [UserRatingDTO] = try await supabase
                .from("user_ratings")
                .select()
                .eq("rated_id", value: userId)
                .execute()
                .value
            
            let ratings = response.map { Double($0.rating) }
            targetUserRatingCount = ratings.count
            targetUserRatingAverage = ratings.isEmpty ? 0.0 : ratings.reduce(0, +) / Double(ratings.count)
        } catch {
            Logger.error("Error fetching aggregate rating: \(error.localizedDescription)")
        }
    }
    
    private func fetchMyRating(currentUserId: UUID) async {
        guard let supabase = Config.supabase else { return }
        
        do {
            let response: [UserRatingDTO] = try await supabase
                .from("user_ratings")
                .select()
                .eq("rater_id", value: currentUserId)
                .eq("rated_id", value: userId)
                .execute()
                .value
            
            myRating = response.first?.rating
        } catch {
            Logger.error("Error fetching my rating: \(error.localizedDescription)")
        }
    }
    
    func rateUser(rating: Int) async {
        guard let supabase = Config.supabase,
              let currentUserId = supabase.auth.currentUser?.id else { return }
        
        let ratingEntry = UserRatingInsertDTO(
            rater_id: currentUserId,
            rated_id: userId,
            rating: rating
        )
        
        do {
            try await supabase
                .from("user_ratings")
                .upsert(ratingEntry, onConflict: "rater_id, rated_id")
                .execute()
            
            myRating = rating
            
            // Refresh aggregate rating
            await fetchAggregateRating()
            
            // Update profile with new rating
            let updateDTO = ProfileRatingUpdateDTO(
                rating_average: targetUserRatingAverage,
                rating_count: targetUserRatingCount
            )
            
            try await supabase
                .from("profiles")
                .update(updateDTO)
                .eq("id", value: userId)
                .execute()
        } catch {
            Logger.error("Error rating user: \(error.localizedDescription)")
        }
    }
}

// MARK: - View

/// View for displaying another user's profile
struct PublicProfileView: View {
    let userId: UUID
    
    @StateObject private var viewModel: PublicProfileViewModel
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var blockService: BlockService
    @Environment(\.dismiss) private var dismiss
    
    // Sheet presentation state
    @State private var showUserList = false
    @State private var selectedListTitle = ""
    @State private var selectedListUsers: [UserProfile] = []
    @State private var showRatingPicker = false
    @State private var showBlockAlert = false
    @State private var showReportAlert = false
    @State private var showReportConfirmation = false
    
    // DM state
    @State private var showDMChat = false
    
    init(userId: UUID) {
        self.userId = userId
        // Use static cache to ensure same ViewModel instance is reused
        self._viewModel = StateObject(wrappedValue: PublicProfileViewModel.getInstance(for: userId))
    }
    
    var body: some View {
        // NavigationStack {
            ZStack {
                // MARK: - Premium Animated Background
                premiumBackground
                
                ScrollView {
                    if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 50)
                    } else if let user = viewModel.user {
                        VStack(spacing: 0) {
                            // MARK: - Header Card with Glass Effect
                            ZStack {
                                // Vibe color background
                                if let colorHex = user.profileColor, let vibeColor = Color(hex: colorHex) {
                                    RoundedRectangle(cornerRadius: 32)
                                        .fill(vibeColor.opacity(0.15))
                                }
                                
                                // Glass card background
                                RoundedRectangle(cornerRadius: 32)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 32)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        .white.opacity(0.3),
                                                        .white.opacity(0.05)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                                
                                VStack(spacing: DesignSystem.Spacing.md) {
                                    // Avatar with glow ring
                                    premiumAvatar(user: user)
                                    
                                    // Name with message button
                                    HStack(spacing: DesignSystem.Spacing.sm) {
                                        Text(user.name)
                                            .font(.system(size: 28, weight: .bold, design: .rounded))
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [
                                                        DesignSystem.Colors.textPrimary,
                                                        DesignSystem.Colors.textPrimary.opacity(0.8)
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                        
                                        if userId != sessionStore.currentUser.id {
                                            Button {
                                                showDMChat = true
                                            } label: {
                                                Image(systemName: "envelope.fill")
                                                    .font(.title2)
                                                    .foregroundColor(DesignSystem.Colors.primaryFallback)
                                                    .padding(8)
                                                    .background(
                                                        Circle()
                                                            .fill(.ultraThinMaterial)
                                                    )
                                            }
                                        }
                                        
                                        // Instagram Button
                                        if let handle = user.instagramHandle, !handle.isEmpty,
                                           let encodedHandle = handle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                                           let instagramURL = URL(string: "https://instagram.com/\(encodedHandle)") {
                                            Link(destination: instagramURL) {
                                                Image(systemName: "camera.aperture")
                                                    .font(.title2)
                                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                                    .padding(8)
                                                    .background(
                                                        Circle()
                                                            .fill(.ultraThinMaterial)
                                                    )
                                            }
                                        }
                                    }
                                    
                                    // Stats Row with Glass Pills
                                    statsRow
                                    
                                    // Follow Button
                                    if userId != sessionStore.currentUser.id {
                                        followButton
                                    }
                                }
                                .padding(.vertical, DesignSystem.Spacing.xl)
                                .padding(.horizontal, DesignSystem.Spacing.lg)
                            }
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.top, DesignSystem.Spacing.md)
                            
                            // MARK: - Reputation Section
                            reputationCard
                                .padding(.top, DesignSystem.Spacing.lg)
                            
                            // MARK: - Bio Section
                            if !user.bio.isEmpty {
                                bioCard(user: user)
                                    .padding(.top, DesignSystem.Spacing.md)
                            }
                            
                            // MARK: - Details Grid
                            detailsGrid(user: user)
                                .padding(.top, DesignSystem.Spacing.md)
                            
                            Spacer(minLength: 50)
                            
                            // Safety Actions
                            if userId != sessionStore.currentUser.id {
                                safetyActions
                                    .padding(.top, DesignSystem.Spacing.xl)
                            }
                        }
                        .padding(.bottom, DesignSystem.Spacing.lg)
                    } else {
                        VStack {
                            Image(systemName: "person.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                            Text("User not found")
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 50)
                    }
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
            .onAppear {
                // Load data only once - ViewModel tracks this internally
                Task {
                    await viewModel.loadDataIfNeeded(currentUserId: sessionStore.currentUser.id)
                }
            }
            .alert("Block User", isPresented: $showBlockAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Block", role: .destructive) {
                    Task {
                        await blockService.block(userId: userId.uuidString)
                    }
                    dismiss()
                }
            } message: {
                Text("They will not be able to see your profile or content. This action is reversible.")
            }
            .alert("Report User", isPresented: $showReportAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Report", role: .destructive) {
                    Task {
                        do {
                            // Call backend service
                            try await ReportService.shared.reportUser(
                                reportingUserId: sessionStore.currentUser.id,
                                reportedUserId: userId,
                                reason: "Community Guidelines Violation" // You might want to add a picker for this
                            )
                            
                            // Show confirmation
                            await MainActor.run {
                                showReportConfirmation = true
                            }
                        } catch {
                            Logger.error("Failed to report user: \(error.localizedDescription)")
                            // You might want to show an error alert here too
                        }
                    }
                }
            } message: {
                Text("Report this user for violating community guidelines? Local law enforcement may be notified if immediate danger is detected.")
            }
            .alert("Thanks for reporting", isPresented: $showReportConfirmation) {
                Button("Done", role: .cancel) {}
            } message: {
                Text("We've received your report and will review it within 24 hours.")
            }
        //}
        .sheet(isPresented: $showUserList) {
            UserListView(title: selectedListTitle, users: selectedListUsers)
        }
        .sheet(isPresented: $showRatingPicker) {
            StarRatingPickerView(
                userName: viewModel.user?.name ?? "User",
                currentRating: viewModel.myRating,
                onSubmit: { rating in
                    Task {
                        await viewModel.rateUser(rating: rating)
                    }
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showDMChat) {
            NavigationStack {
                DirectMessageChatView(otherUser: (
                    id: userId,
                    name: viewModel.user?.name ?? "User",
                    avatar: viewModel.user?.avatarUrl
                ))
            }
        }
    }
    
    // MARK: - Premium Background
    private var premiumBackground: some View {
        ZStack {
            // Base dark gradient
            LinearGradient(
                colors: [
                    DesignSystem.Colors.adaptive(dark: Color(hex: "#0a0a0a") ?? .black, light: Color(hex: "#f8f9fa") ?? .white),
                    DesignSystem.Colors.adaptive(dark: Color(hex: "#1a1a2e") ?? .black, light: Color(hex: "#e9ecef") ?? .white)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // User's vibe color glow
            if let colorHex = viewModel.user?.profileColor, let vibeColor = Color(hex: colorHex) {
                // Top glow orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [vibeColor.opacity(0.4), vibeColor.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: 100, y: -150)
                    .blur(radius: 60)
                
                // Bottom accent orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [vibeColor.opacity(0.25), vibeColor.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .offset(x: -120, y: 400)
                    .blur(radius: 50)
            } else {
                // Default purple/blue glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#667eea")?.opacity(0.3) ?? .purple.opacity(0.3),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: 100, y: -100)
                    .blur(radius: 60)
            }
        }
    }
    
    // MARK: - Premium Avatar with Glow Ring
    private func premiumAvatar(user: UserProfile) -> some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            (Color(hex: user.profileColor ?? "#667eea") ?? .purple).opacity(0.5),
                            .clear
                        ],
                        center: .center,
                        startRadius: 50,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
            
            // Animated gradient ring
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Color(hex: "#667eea") ?? .purple,
                            Color(hex: "#764ba2") ?? .purple,
                            Color(hex: "#66d3e4") ?? .cyan,
                            Color(hex: "#f093fb") ?? .pink,
                            Color(hex: "#667eea") ?? .purple
                        ],
                        center: .center
                    ),
                    lineWidth: 4
                )
                .frame(width: 120, height: 120)
            
            // Inner glass ring
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: 1)
                .frame(width: 112, height: 112)
            
            // Avatar
            AvatarView(
                name: user.name,
                size: 100,
                url: URL(string: user.avatarUrl ?? ""),
                assetName: nil
            )
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        }
    }
    
    // MARK: - Stats Row with Glass Pills
    private var statsRow: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            statPill(
                value: viewModel.followersCount,
                label: "Followers",
                action: {
                    Task {
                        selectedListTitle = "Followers"
                        let service = FollowService(userId: userId)
                        selectedListUsers = await service.fetchFollowersList()
                        showUserList = true
                    }
                }
            )
            
            // Divider
            Rectangle()
                .fill(.white.opacity(0.2))
                .frame(width: 1, height: 30)
            
            statPill(
                value: viewModel.followingCount,
                label: "Following",
                action: {
                    Task {
                        selectedListTitle = "Following"
                        let service = FollowService(userId: userId)
                        selectedListUsers = await service.fetchFollowingList()
                        showUserList = true
                    }
                }
            )
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
    
    private func statPill(value: Int, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(value)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Text(label)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .frame(minWidth: 80)
        }
    }
    
    // MARK: - Follow Button
    private var followButton: some View {
        Button {
            toggleFollow()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: viewModel.isFollowing ? "checkmark" : "plus")
                    .font(.subheadline.bold())
                Text(viewModel.isFollowing ? "Following" : "Follow")
                    .font(.headline)
            }
            .foregroundColor(viewModel.isFollowing ? .white.opacity(0.8) : .white)
            .frame(width: 180)
            .padding(.vertical, 14)
            .background(
                Group {
                    if viewModel.isFollowing {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(.white.opacity(0.2), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#667eea") ?? .purple,
                                        Color(hex: "#764ba2") ?? .purple
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
            )
            .shadow(color: viewModel.isFollowing ? .clear : Color(hex: "#667eea")?.opacity(0.4) ?? .purple.opacity(0.4), radius: 10, x: 0, y: 5)
        }
    }
    
    // MARK: - Reputation Card
    private var reputationCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    Text("⭐ REPUTATION")
                        .font(.caption.bold())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .tracking(1)
                    Spacer()
                }
                
                HStack(spacing: 8) {
                    // Star visualization
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: Double(star) <= viewModel.targetUserRatingAverage ? "star.fill" : 
                                  Double(star) - 0.5 <= viewModel.targetUserRatingAverage ? "star.leadinghalf.filled" : "star")
                                .foregroundColor(.yellow)
                                .font(.title3)
                        }
                    }
                    
                    Text(String(format: "%.1f", viewModel.targetUserRatingAverage))
                        .font(.title2.bold())
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("(\(viewModel.targetUserRatingCount) reviews)")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                // Leave Review Button
                if userId != sessionStore.currentUser.id {
                    if let myRating = viewModel.myRating {
                        HStack(spacing: 4) {
                            Text("Your rating:")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= myRating ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    
                    Button {
                        showRatingPicker = true
                    } label: {
                        Text(viewModel.myRating != nil ? "Update Review" : "Leave a Review")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(Color(hex: "#667eea") ?? .purple)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
    
    // MARK: - Bio Card
    private func bioCard(user: UserProfile) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("📝 ABOUT")
                        .font(.caption.bold())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .tracking(1)
                    Spacer()
                }
                
                Text(user.bio)
                    .font(.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary.opacity(0.9))
                    .lineSpacing(4)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
    
    // MARK: - Details Grid
    private func detailsGrid(user: UserProfile) -> some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // 2-Column Grid
            if user.countryOfBirth != nil || true {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    if let country = user.countryOfBirth {
                        GlassDetailCard(emoji: "🌍", title: "From", value: country)
                    }
                    GlassDetailCard(emoji: "🎂", title: "Age", value: "\(user.age)")
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
            
            // Full-width cards
            if let song = user.favoriteSong {
                GlassDetailCard(emoji: "🎵", title: "Anthem", value: song)
                    .padding(.horizontal, DesignSystem.Spacing.md)
            }
            
            if let fact = user.funFact {
                GlassDetailCard(emoji: "💡", title: "Fun Fact", value: fact)
                    .padding(.horizontal, DesignSystem.Spacing.md)
            }
        }
    }
    
    // MARK: - Safety Actions
    private var safetyActions: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Group {
                if blockService.isBlocked(userId: userId.uuidString) {
                    Button {
                        Task { await blockService.unblock(userId: userId.uuidString) }
                    } label: {
                        Text("Unblock User")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .cornerRadius(12)
                    }
                } else {
                    Button {
                        showBlockAlert = true
                    } label: {
                        Text("Block User")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.9))
                            .cornerRadius(12)
                    }
                }
                
                Button {
                    showReportAlert = true
                } label: {
                    Text("Report User")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.9))
                        .cornerRadius(12)
                }
            }
            .shadow(radius: 2)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom)
    }

    
    private func toggleFollow() {
        Task {
            await viewModel.toggleFollow(currentUserId: sessionStore.currentUser.id)
        }
    }
}

// MARK: - Components

struct DetailCard: View {
    let emoji: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(emoji)
                    .font(.title2)
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Text(value)
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Material.regular)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

// MARK: - Glass Components for Premium Profile

struct GlassCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.25),
                                        .white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}

struct GlassDetailCard: View {
    let emoji: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Emoji in glass bubble
            Text(emoji)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(.white.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .tracking(0.5)
                
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
}
