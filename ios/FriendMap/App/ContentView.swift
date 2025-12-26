import SwiftUI

/// Main content view with auth routing and tab bar navigation
struct ContentView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var planStore: PlanStore
    @EnvironmentObject private var notificationRouter: NotificationRouter
    @EnvironmentObject private var dmService: DirectMessageService
    
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
                        .onOpenURL { url in
                            handleDeepLink(url)
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
            }
        }
        .onChange(of: authService.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                Task {
                    await syncProfileIfNeeded()
                    await NotificationCenter.shared.fetchNotifications(for: sessionStore.currentUser.id)
                    await dmService.fetchConversations(currentUserId: sessionStore.currentUser.id)
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
                
                EventGroupsView()
                    .tabItem {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                    }
                    .tag(Tab.groups)
                    .badge(dmService.totalUnreadCount > 0 ? dmService.totalUnreadCount : 0)
                
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
            
            // Custom Center Button - Liquid Glass Style
            Button {
                showCreatePlanSheet = true
            } label: {
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.cyan.opacity(0.4),
                                    Color.teal.opacity(0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 25,
                                endRadius: 44
                            )
                        )
                        .frame(width: 88, height: 88)
                        .blur(radius: 4)
                    
                    // Glass circle
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.6),
                                            Color.cyan.opacity(0.3),
                                            Color.teal.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: .cyan.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    // Plus icon
                    Image(systemName: "plus")
                        .font(.title.bold())
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .teal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
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
                
                Logger.info("First plan created! hasSeenTabCoachMarks = \(hasSeenTabCoachMarks)")
                
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
    
    private func handleDeepLink(_ url: URL) {
        // Format: ourspot://plan/{uuid}
        guard url.scheme == "ourspot",
              url.host == "plan",
              let planIdString = url.pathComponents.last,
              let planId = UUID(uuidString: planIdString) else {
            return
        }
        
        // Find plan locally
        if let plan = planStore.plans.first(where: { $0.id == planId }) {
            deepLinkPlan = plan
        } else {
            // In a real app, you would fetch the plan from Supabase here
            Logger.warning("Deep link plan not found locally: \(planId)")
        }
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

// MARK: - Press Animation Button Style
struct PressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
        .environmentObject(SessionStore())
        .environmentObject(PlanStore())
}
