import SwiftUI

/// Groups tab showing events the user is attending with group chat access
struct EventGroupsView: View {
    @EnvironmentObject private var planStore: PlanStore
    @EnvironmentObject private var sessionStore: SessionStore
    
    var body: some View {
        NavigationStack {
            Group {
                if myEvents.isEmpty {
                    emptyState
                } else {
                    eventsList
                }
            }
            .navigationTitle("My Events")
        }
    }
    
    /// Events user is attending (RSVP = going)
    private var myEvents: [Plan] {
        planStore.upcomingPlans.filter { plan in
            plan.hostUserId == sessionStore.currentUser.id ||
            planStore.rsvpStatus[plan.id] == .going
        }
    }
    
    private var eventsList: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md) {
                ForEach(myEvents) { plan in
                    NavigationLink(destination: GroupChatView(plan: plan)) {
                        eventRow(plan)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
    }
    
    private func eventRow(_ plan: Plan) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Emoji
            Text(plan.emoji)
                .font(.system(size: 36))
                .frame(width: 50, height: 50)
                .background(DesignSystem.Colors.secondaryBackground)
                .cornerRadius(DesignSystem.CornerRadius.md)
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(plan.startsAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Chat indicator
            VStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundColor(DesignSystem.Colors.primaryFallback)
                Text("Chat")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
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
