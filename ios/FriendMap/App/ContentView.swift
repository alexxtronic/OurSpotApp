import SwiftUI

/// Main content view with auth routing and tab bar navigation
struct ContentView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var planStore: PlanStore
    @EnvironmentObject private var notificationRouter: NotificationRouter
    @EnvironmentObject private var dmService: DirectMessageService
    @EnvironmentObject private var blockService: BlockService
    
    @State private var deepLinkPlan: Plan?
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                if sessionStore.isLoading {
                    ProgressView("Loading Profile...")
                } else if sessionStore.currentUser.onboardingCompleted || Config.supabase == nil {
                    mainTabView
                        .onAppear {
                            Task {
                                await planStore.loadPlans(currentUserId: sessionStore.currentUser.id)
                                await dmService.fetchConversations(currentUserId: sessionStore.currentUser.id)
                            }
                        }
                        .sheet(item: $deepLinkPlan) { plan in
                            PlanDetailsView(plan: plan)
                        }
                        .onChange(of: planStore.planToShowOnMap) { plan in
                            if let plan = plan {
                                deepLinkPlan = plan
                                // Nil it so that the same plan can be triggered again (e.g. if sheet is dismissed and re-opened)
                                planStore.planToShowOnMap = nil
                            }
                        }
                } else {
                    // Show onboarding for new users
                    OnboardingView {
                        // This callback is called when onboarding completes
                        sessionStore.objectWillChange.send()
                    }
                    .onAppear {
                        // Force dismiss any keyboard from sign-in
                        UIApplication.shared.connectedScenes
                            .compactMap { $0 as? UIWindowScene }
                            .flatMap { $0.windows }
                            .forEach { $0.endEditing(true) }
                    }
                }
            } else if Config.supabase == nil {
                // Offline mode - skip auth
                mainTabView
            } else {
                SignInView()
            }
        }
        .task {
            if authService.isAuthenticated {
                await syncProfileIfNeeded()
                // Fetch notifications for the current user
                await NotificationCenter.shared.fetchNotifications(for: sessionStore.currentUser.id)
                await dmService.fetchConversations(currentUserId: sessionStore.currentUser.id)
                await blockService.refresh(userId: sessionStore.currentUser.id)
            }
        }
        .onChange(of: authService.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                Task {
                    await syncProfileIfNeeded()
                    await NotificationCenter.shared.fetchNotifications(for: sessionStore.currentUser.id)
                    await dmService.fetchConversations(currentUserId: sessionStore.currentUser.id)
                    await blockService.refresh(userId: sessionStore.currentUser.id)
                }
            }
        }
        .onChange(of: notificationRouter.pendingDeepLink) { deepLink in
            if let deepLink = deepLink {
                handleNotificationDeepLink(deepLink)
            }
        }
    }
    
    @State private var showCreatePlanSheet = false
    @State private var showConfetti = false
    @State private var planCountBeforeSheet = 0
    @State private var isKeyboardVisible = false
    @State private var selectedTab: Tab = .map
    @State private var previousTab: Tab = .map
    
    // Tab coach marks for onboarding
    @AppStorage("hasSeenTabCoachMarks") private var hasSeenTabCoachMarks = false
    @State private var currentCoachMarkStep: TabCoachMarkStep = .none
    @State private var coachMarkBounce = false
    
    enum Tab: Int {
        case map = 0
        case groups = 1
        case create = 2  // Placeholder - should never be selected
        case plans = 3
        case profile = 4
    }
    
    enum TabCoachMarkStep {
        case none
        case chat      // "Tap here to join the temporary event group chat"
        case plans     // "Tap here to get an overview of your events"
    }
    
    private var mainTabView: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                MapView()
                    .tabItem {
                        Image(systemName: "map.fill")
                    }
                    .tag(Tab.map)
                
                EventGroupsView(selectedTab: $selectedTab)
                    .tabItem {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                    }
                    .tag(Tab.groups)
                    .badge(planStore.totalEventChatUnreadCount > 0 ? planStore.totalEventChatUnreadCount : 0)
                
                // Placeholder for center spacing - redirect to create sheet
                Color.clear
                    .tabItem {
                        Text(" ")
                    }
                    .tag(Tab.create)
                
                PlansView(selectedTab: $selectedTab)
                    .tabItem {
                        Image(systemName: "calendar")
                            .font(.title2)
                    }
                    .tag(Tab.plans)
                    .badge(planStore.invitationCount > 0 ? planStore.invitationCount : 0)
                
                ProfileView()
                    .tabItem {
                        Image(systemName: "person.fill")
                            .font(.title2)
                    }
                    .tag(Tab.profile)
            }
            .tint(DesignSystem.Colors.primaryFallback)
            .onChange(of: selectedTab) { newTab in
                // Intercept center tab selection and show create sheet instead
                if newTab == .create {
                    selectedTab = previousTab
                    showCreatePlanSheet = true
                } else {
                    previousTab = newTab
                }
            }
            
            // Custom Center Button - Orange Gradient Brand Style
            Button {
                showCreatePlanSheet = true
            } label: {
                ZStack {
                    // Outer glow - warm orange
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.55, blue: 0.1).opacity(0.5),
                                    Color(red: 0.9, green: 0.4, blue: 0.05).opacity(0.25),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 25,
                                endRadius: 44
                            )
                        )
                        .frame(width: 88, height: 88)
                        .blur(radius: 5)
                    
                    // Glass circle with orange gradient fill
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.65, blue: 0.2),  // Light orange (top)
                                    Color(red: 0.9, green: 0.45, blue: 0.05)  // Dark orange (bottom)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.7),
                                            Color(red: 1.0, green: 0.8, blue: 0.4).opacity(0.4),
                                            Color(red: 0.85, green: 0.35, blue: 0.0).opacity(0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: Color(red: 0.9, green: 0.4, blue: 0.0).opacity(0.4), radius: 12, x: 0, y: 6)
                    
                    // Plus icon - white for contrast
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                }
            }
            .buttonStyle(PressButtonStyle())
            .offset(y: 22) // Dead centered in console, aligned with other elements
            .opacity(isKeyboardVisible ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: isKeyboardVisible)
        }
        .onReceive(Foundation.NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(Foundation.NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .sheet(isPresented: $showCreatePlanSheet, onDismiss: {
            // Only show confetti if a plan was actually created
            if planStore.plans.count > planCountBeforeSheet {
                showConfetti = true
                Logger.info("Plan created! hasSeenTabCoachMarks = \(hasSeenTabCoachMarks)")
                
                // Trigger tab coach marks after first plan creation
                if !hasSeenTabCoachMarks {
                    Logger.info("Triggering tab coach marks sequence...")
                    // Delay slightly so confetti plays first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        Logger.info("Setting currentCoachMarkStep to .chat")
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            currentCoachMarkStep = .chat
                        }
                        // Start bounce animation
                        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                            coachMarkBounce = true
                        }
                    }
                }
            }
        }) {
            CreatePlanView()
                .onAppear {
                    planCountBeforeSheet = planStore.plans.count
                }
        }
        .confetti(isShowing: $showConfetti)
        .overlay {
            // Tab coach marks overlay
            if currentCoachMarkStep != .none {
                tabCoachMarkOverlay
            }
        }
        .onAppear {
            // Force dismiss keyboard on app launch just in case
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    // MARK: - Tab Coach Mark Overlay
    
    private var tabCoachMarkOverlay: some View {
        ZStack {
            // Semi-transparent background - tap to advance
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    advanceCoachMark()
                }
            
            VStack {
                Spacer()
                
                // Coach mark content
                VStack(spacing: 12) {
                    // Message card
                    VStack(spacing: 8) {
                        Text(coachMarkTitle)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                        
                        // Hint to tap
                        Text("Tap anywhere to continue")
                            .font(.caption)
                            .foregroundColor(.black.opacity(0.6))
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: .orange.opacity(0.4), radius: 12, y: 4)
                    
                    // Animated arrow pointing down at the correct tab
                    Image(systemName: "arrow.down")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.orange)
                        .offset(x: coachMarkArrowXOffset, y: coachMarkBounce ? 10 : 0)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 60) // Position above tab bar icons
            }
        }
        .transition(.opacity)
    }
    
    private var coachMarkArrowXOffset: CGFloat {
        // Position arrow to point at correct tab icon
        // Tab bar is roughly: Map (-150), Chat (-75), + (0), Plans (75), Profile (150)
        switch currentCoachMarkStep {
        case .chat:
            return -75 // Point at chat icon (second from left)
        case .plans:
            return 75 // Point at plans/calendar icon (second from right)
        case .none:
            return 0
        }
    }
    
    private var coachMarkTitle: String {
        switch currentCoachMarkStep {
        case .chat:
            return "Tap here to join the group chat!"
        case .plans:
            return "Tap here to get an overview of all events!"
        case .none:
            return ""
        }
    }
    
    private var coachMarkArrowOffset: CGFloat {
        // Offset arrow to point at correct tab
        switch currentCoachMarkStep {
        case .chat:
            return -80 // Point at chat tab (2nd from left)
        case .plans:
            return 80 // Point at plans tab (2nd from right)
        case .none:
            return 0
        }
    }
    
    private func advanceCoachMark() {
        switch currentCoachMarkStep {
        case .chat:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentCoachMarkStep = .plans
            }
        case .plans:
            hasSeenTabCoachMarks = true
            withAnimation(.easeOut(duration: 0.3)) {
                currentCoachMarkStep = .none
                coachMarkBounce = false
            }
        case .none:
            break
        }
        HapticManager.lightTap()
    }
    
    private func handleNotificationDeepLink(_ deepLink: NotificationDeepLink) {
        // Find the plan
        if let plan = planStore.plans.first(where: { $0.id == deepLink.planId }) {
            // If it's a chat notification, switch to Groups tab and open chat
            // OR just present the details view which has a chat button?
            // User likely wants to go straight to chat.
            
            if deepLink.type == .chatMessage {
                deepLinkPlan = plan // This opens PlanDetailsView
                // Ideally we'd navigate to GroupChatView directly or PlanDetailsView -> Chat
            } else {
                deepLinkPlan = plan
            }
            
            // Clear the pending link
            notificationRouter.clearPendingDeepLink()
        } else {
            // Plan might not be loaded yet if it's new
            Task {
                // Force reload plans
                await planStore.loadPlans(currentUserId: sessionStore.currentUser.id)
                
                // Try again main actor
                if let plan = planStore.plans.first(where: { $0.id == deepLink.planId }) {
                    deepLinkPlan = plan
                    notificationRouter.clearPendingDeepLink()
                }
            }
        }
    }
    
    private func syncProfileIfNeeded() async {
        guard let session = authService.currentSession else { return }
        
        var name: String? = nil
        if let metadata = session.user.userMetadata["name"] {
            if case .string(let stringValue) = metadata {
                name = stringValue
            }
        }
        
        await sessionStore.syncProfile(
            userId: session.user.id,
            email: session.user.email,
            name: name
        )
    }
}

// MARK: - Premium Press Animation Button Style
struct PressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Scale with satisfying compression curve
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            // Subtle push-down rotation for depth
            .rotation3DEffect(
                .degrees(configuration.isPressed ? 5 : 0),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.5
            )
            // Brightness boost on press for "glow" effect
            .brightness(configuration.isPressed ? 0.05 : 0)
            // Slightly reduced opacity for depth
            .opacity(configuration.isPressed ? 0.95 : 1.0)
            // Premium spring animation - snappy press, bouncy release
            .animation(
                configuration.isPressed
                    ? .spring(response: 0.15, dampingFraction: 0.7, blendDuration: 0.05) // Quick press
                    : .spring(response: 0.35, dampingFraction: 0.55, blendDuration: 0.1), // Bouncy release
                value: configuration.isPressed
            )
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
        .environmentObject(SessionStore())
        .environmentObject(PlanStore())
}
