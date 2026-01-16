import SwiftUI

/// Groups tab showing events the user is attending with group chat access
/// Organized by sections: Happening Now, Today, This Week, Later, Archived
struct EventGroupsView: View {
    @EnvironmentObject private var planStore: PlanStore
    @EnvironmentObject private var sessionStore: SessionStore
    @Binding var selectedTab: ContentView.Tab
    
    // Filter state
    @State private var searchText = ""
    @State private var showSearchBar = false
    
    var body: some View {
        NavigationStack {
            Group {
                if allActiveEvents.isEmpty && archivedEvents.isEmpty {
                    emptyState
                } else {
                    eventsList
                }
            }
            .navigationTitle("Event Chats")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showSearchBar.toggle()
                            if !showSearchBar {
                                searchText = ""
                            }
                        }
                    } label: {
                        Image(systemName: showSearchBar ? "xmark.circle.fill" : "magnifyingglass")
                            .foregroundColor(.primary)
                    }
                }
            }
            .task {
                await planStore.loadEventChats(currentUserId: sessionStore.currentUser.id)
            }
            .refreshable {
                await planStore.loadEventChats(currentUserId: sessionStore.currentUser.id)
            }
            .id(goingEventsHash)
        }
    }
    
    // MARK: - Time-based categorization
    
    private var now: Date { Date() }
    
    /// Events that are "live" - started within last 10 hours
    private var liveEvents: [EventChat] {
        filteredEvents.filter { chat in
            let hoursSinceStart = now.timeIntervalSince(chat.plan.startsAt) / 3600
            return hoursSinceStart >= 0 && hoursSinceStart < 10
        }
    }
    
    /// Events happening later today (not live yet)
    private var todayEvents: [EventChat] {
        let calendar = Calendar.current
        return filteredEvents.filter { chat in
            let isToday = calendar.isDateInToday(chat.plan.startsAt)
            let hasntStarted = chat.plan.startsAt > now
            return isToday && hasntStarted
        }
    }
    
    /// Events in next 7 days (excluding today)
    private var thisWeekEvents: [EventChat] {
        let calendar = Calendar.current
        let startOfTomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now))!
        
        return filteredEvents.filter { chat in
            chat.plan.startsAt >= startOfTomorrow && chat.plan.startsAt < endOfWeek
        }
    }
    
    /// Events more than a week away
    private var laterEvents: [EventChat] {
        let calendar = Calendar.current
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now))!
        
        return filteredEvents.filter { chat in
            chat.plan.startsAt >= endOfWeek
        }
    }
    
    /// Archived events - more than 10 hours since start (read-only after 24 hours)
    private var archivedEvents: [EventChat] {
        displayItems.filter { chat in
            let hoursSinceStart = now.timeIntervalSince(chat.plan.startsAt) / 3600
            return hoursSinceStart >= 10
        }
    }
    
    /// All non-archived events for filtering (events up to 10 hours after start)
    private var allActiveEvents: [EventChat] {
        displayItems.filter { chat in
            let hoursSinceStart = now.timeIntervalSince(chat.plan.startsAt) / 3600
            return hoursSinceStart < 10
        }
    }
    
    /// Filtered by search text
    private var filteredEvents: [EventChat] {
        if searchText.isEmpty {
            return allActiveEvents
        }
        return allActiveEvents.filter { chat in
            chat.plan.title.localizedCaseInsensitiveContains(searchText) ||
            chat.plan.hostName.localizedCaseInsensitiveContains(searchText) ||
            chat.plan.locationName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Views
    
    private var eventsList: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Search bar (animated)
                if showSearchBar {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search events...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.tertiaryBackground)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Live Events Section (rainbow highlight)
                if !liveEvents.isEmpty {
                    eventSection(title: "🔴 Happening Now", events: liveEvents, isLive: true)
                }
                
                // Today Section
                if !todayEvents.isEmpty {
                    eventSection(title: "📅 Today", events: todayEvents)
                }
                
                // This Week Section
                if !thisWeekEvents.isEmpty {
                    eventSection(title: "📆 This Week", events: thisWeekEvents)
                }
                
                // Later Section
                if !laterEvents.isEmpty {
                    eventSection(title: "🗓️ Later", events: laterEvents)
                }
                
                // Archived Section (collapsed by default)
                if !archivedEvents.isEmpty {
                    archivedSection
                }
            }
            .padding(.vertical, DesignSystem.Spacing.md)
        }
    }
    
    private func eventSection(title: String, events: [EventChat], isLive: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.secondary)
                .padding(.horizontal, DesignSystem.Spacing.md)
            
            ForEach(events) { chat in
                NavigationLink(destination: GroupChatView(plan: chat.plan, selectedTab: $selectedTab)) {
                    eventRow(chat, isLive: isLive)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
        }
    }
    
    @State private var showArchivedEvents = false
    
    private var archivedSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showArchivedEvents.toggle()
                }
            } label: {
                HStack {
                    Text("📦 Archived (\(archivedEvents.count))")
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: showArchivedEvents ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
            
            if showArchivedEvents {
                ForEach(archivedEvents) { chat in
                    NavigationLink(destination: GroupChatView(plan: chat.plan, selectedTab: $selectedTab)) {
                        eventRow(chat, isArchived: true)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                }
            }
        }
    }
    
    private func eventRow(_ chat: EventChat, isLive: Bool = false, isArchived: Bool = false) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Emoji with optional live rainbow border
            ZStack {
                if isLive {
                    // Rainbow border for live events - matches rounded corner icon
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md + 3)
                        .stroke(
                            AngularGradient(
                                colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 56, height: 56)
                }
                
                Text(chat.plan.emoji)
                    .font(.system(size: 32))
                    .frame(width: 50, height: 50)
                    .background(DesignSystem.Colors.secondaryBackground)
                    .cornerRadius(DesignSystem.CornerRadius.md)
            }
            .opacity(isArchived ? 0.6 : 1.0)
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.plan.title)
                        .font(.headline)
                        .foregroundColor(isArchived ? .secondary : .primary)
                    
                    if isLive {
                        Text("LIVE")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                    }
                    
                    if isArchived {
                        Text("READ ONLY")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    if let lastMsgTime = chat.lastMessageAt {
                        Text(lastMsgTime.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let preview = chat.lastMessagePreview {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundColor(chat.unreadCount > 0 && !isArchived ? .primary : .secondary)
                        .lineLimit(1)
                        .fontWeight(chat.unreadCount > 0 && !isArchived ? .medium : .regular)
                } else {
                    Text(chat.plan.startsAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Unread Badge or Chevron
            if chat.unreadCount > 0 && !isArchived {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 24, height: 24)
                    Text("\(min(chat.unreadCount, 99))")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                }
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(isLive ? Color.orange.opacity(0.1) : DesignSystem.Colors.secondaryBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .stroke(
                    isLive 
                        ? AngularGradient(
                            colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                            center: .center
                          )
                        : AngularGradient(colors: [.clear], center: .center),
                    lineWidth: isLive ? 2 : 0
                )
        )
    }
    
    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Events Yet")
                .font(.title2.bold())
            
            Text("When you RSVP to events, they'll appear here with group chat access.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Data
    
    private var goingEventsHash: Int {
        var hasher = Hasher()
        hasher.combine(planStore.plans.count)
        for (planId, status) in planStore.rsvpStatus where status == .going {
            hasher.combine(planId)
        }
        for (planId, attendees) in planStore.attendees where attendees.contains(sessionStore.currentUser.id) {
            hasher.combine(planId)
        }
        return hasher.finalize()
    }
    
    private var displayItems: [EventChat] {
        let chatMetadata = Dictionary(uniqueKeysWithValues: planStore.eventChats.map { ($0.plan.id, $0) })
        
        let items = myEvents.map { plan -> EventChat in
            if let chatData = chatMetadata[plan.id] {
                return chatData
            }
            return EventChat(plan: plan, unreadCount: 0, lastMessageAt: nil, lastMessagePreview: nil)
        }
        
        return items.sorted { lhs, rhs in
            switch (lhs.lastMessageAt, rhs.lastMessageAt) {
            case let (lhsTime?, rhsTime?):
                return lhsTime > rhsTime
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            case (nil, nil):
                return lhs.plan.startsAt < rhs.plan.startsAt
            }
        }
    }
    
    private var myEvents: [Plan] {
        planStore.plans.filter { plan in
            if plan.hostUserId == sessionStore.currentUser.id {
                return true
            }
            if planStore.rsvpStatus[plan.id] == .going {
                return true
            }
            if planStore.attendees[plan.id]?.contains(sessionStore.currentUser.id) == true {
                return true
            }
            return false
        }
        .sorted { $0.startsAt < $1.startsAt }
    }
}

#Preview {
    EventGroupsView(selectedTab: .constant(.groups))
        .environmentObject(PlanStore())
        .environmentObject(SessionStore())
}
