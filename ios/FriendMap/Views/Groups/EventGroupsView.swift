import SwiftUI

/// Groups tab showing events the user is attending with group chat access
struct EventGroupsView: View {
    @EnvironmentObject private var planStore: PlanStore
    @EnvironmentObject private var sessionStore: SessionStore
    
    var body: some View {
        NavigationStack {
            Group {
                if displayItems.isEmpty {
                    emptyState
                } else {
                    eventsList
                }
            }
            .navigationTitle("Event Chats")
            .task {
                await planStore.loadEventChats(currentUserId: sessionStore.currentUser.id)
            }
            .refreshable {
                await planStore.loadEventChats(currentUserId: sessionStore.currentUser.id)
            }
            // Force refresh when RSVP 'going' count changes or plans update
            .id(goingEventsHash)
        }
    }
    
    /// Creates a unique hash based on which events user is going to - triggers refresh on any RSVP change
    private var goingEventsHash: Int {
        var hasher = Hasher()
        hasher.combine(planStore.plans.count)
        for (planId, status) in planStore.rsvpStatus where status == .going {
            hasher.combine(planId)
        }
        // Also include attendee sets
        for (planId, attendees) in planStore.attendees where attendees.contains(sessionStore.currentUser.id) {
            hasher.combine(planId)
        }
        return hasher.finalize()
    }
    
    /// Combine myEvents (from RSVP/host status) with chat metadata from backend
    /// Sorted by latest message first, then by event start date for events without messages
    private var displayItems: [EventChat] {
        // Use myEvents as the base - these are events user is going to or hosting
        let chatMetadata = Dictionary(uniqueKeysWithValues: planStore.eventChats.map { ($0.plan.id, $0) })
        
        let items = myEvents.map { plan -> EventChat in
            // Enrich with chat data if available
            if let chatData = chatMetadata[plan.id] {
                return chatData
            }
            // No chat history yet - create basic EventChat
            return EventChat(plan: plan, unreadCount: 0, lastMessageAt: nil, lastMessagePreview: nil)
        }
        
        // Sort: events with messages first (by latest message), then events without messages (by start date)
        return items.sorted { lhs, rhs in
            switch (lhs.lastMessageAt, rhs.lastMessageAt) {
            case let (lhsTime?, rhsTime?):
                // Both have messages - newest first
                return lhsTime > rhsTime
            case (nil, _?):
                // lhs has no messages, rhs does - rhs goes first
                return false
            case (_?, nil):
                // lhs has messages, rhs doesn't - lhs goes first
                return true
            case (nil, nil):
                // Neither has messages - sort by start date (soonest first)
                return lhs.plan.startsAt < rhs.plan.startsAt
            }
        }
    }
    
    /// Events user is attending (RSVP = going) or hosting
    private var myEvents: [Plan] {
        planStore.plans.filter { plan in
            // Include if user is the host
            if plan.hostUserId == sessionStore.currentUser.id {
                return true
            }
            // Include if user RSVP'd as going
            if planStore.rsvpStatus[plan.id] == .going {
                return true
            }
            // Also check if user is in the attendees list (synced from backend)
            if planStore.attendees[plan.id]?.contains(sessionStore.currentUser.id) == true {
                return true
            }
            return false
        }
        .filter { $0.startsAt > Date() } // Only upcoming
        .sorted { $0.startsAt < $1.startsAt }
    }
    
    private var eventsList: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md) {
                ForEach(displayItems) { chat in
                    NavigationLink(destination: GroupChatView(plan: chat.plan)) {
                        eventRow(chat)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
    }
    
    private func eventRow(_ chat: EventChat) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Emoji
            Text(chat.plan.emoji)
                .font(.system(size: 36))
                .frame(width: 50, height: 50)
                .background(DesignSystem.Colors.secondaryBackground)
                .cornerRadius(DesignSystem.CornerRadius.md)
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.plan.title)
                        .font(.headline)
                        .foregroundColor(.primary)
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
                        .foregroundColor(chat.unreadCount > 0 ? .primary : .secondary)
                        .lineLimit(1)
                        .fontWeight(chat.unreadCount > 0 ? .medium : .regular)
                } else {
                    Text(chat.plan.startsAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Unread Badge or Chevron
            if chat.unreadCount > 0 {
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
        .background(DesignSystem.Colors.secondaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.lg)
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
}

#Preview {
    EventGroupsView()
        .environmentObject(PlanStore())
        .environmentObject(SessionStore())
}

