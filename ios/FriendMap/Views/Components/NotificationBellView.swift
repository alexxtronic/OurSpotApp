import SwiftUI

/// Bell icon with badge showing notification dropdown
struct NotificationBellView: View {
    @ObservedObject private var notificationCenter = NotificationCenter.shared
    @State private var showDropdown = false
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                showDropdown.toggle()
            }
            HapticManager.lightTap()
        } label: {
            ZStack(alignment: .topTrailing) {
                // Glass bubble background matching filter icons
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 50, height: 50)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    Image(systemName: "bell.fill")
                        .font(.title3)
                        .foregroundColor(.primary)
                }
                
                // Red badge
                if notificationCenter.unreadCount > 0 {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 20, height: 20)
                        Text(notificationCenter.unreadCount > 9 ? "9+" : "\(notificationCenter.unreadCount)")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                    }
                    .offset(x: 4, y: -4)
                }
            }
        }
        .popover(isPresented: $showDropdown) {
            NotificationDropdownView()
                .frame(minWidth: 300, minHeight: 200)
        }
    }
}

/// Dropdown list of notifications
struct NotificationDropdownView: View {
    @ObservedObject private var notificationCenter = NotificationCenter.shared
    @EnvironmentObject private var planStore: PlanStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: Plan?
    
    var body: some View {
        NavigationStack {
            Group {
                if notificationCenter.notifications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No notifications yet")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(notificationCenter.notifications) { notification in
                            NotificationRowView(notification: notification)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    handleNotificationTap(notification)
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !notificationCenter.notifications.isEmpty {
                        Button("Clear All") {
                            notificationCenter.clearAll()
                        }
                        .foregroundColor(.red)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if notificationCenter.unreadCount > 0 {
                        Button("Mark Read") {
                            notificationCenter.markAllAsRead()
                        }
                    }
                }
            }
            .sheet(item: $selectedPlan) { plan in
                PlanDetailsView(plan: plan)
            }
        }
    }
    
    private func handleNotificationTap(_ notification: AppNotification) {
        notificationCenter.markAsRead(notification)
        
        // Navigate to the related plan
        if let planId = notification.relatedPlanId {
            if let plan = planStore.plans.first(where: { $0.id == planId }) {
                selectedPlan = plan
            }
        }
    }
}

/// Single notification row
struct NotificationRowView: View {
    let notification: AppNotification
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon based on type
            Image(systemName: iconForType(notification.type))
                .font(.title2)
                .foregroundColor(colorForType(notification.type))
                .frame(width: 40, height: 40)
                .background(colorForType(notification.type).opacity(0.15))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.message)
                    .font(.subheadline)
                    .fontWeight(notification.isRead ? .regular : .semibold)
                    .lineLimit(2)
                
                Text(timeAgo(notification.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !notification.isRead {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
        .opacity(notification.isRead ? 0.7 : 1.0)
    }
    
    private func iconForType(_ type: AppNotification.NotificationType) -> String {
        switch type {
        case .eventInvite: return "envelope.fill"
        case .chatMessage: return "message.fill"
        case .rsvpUpdate: return "person.badge.plus.fill"
        case .newFollower: return "person.fill.checkmark"
        }
    }
    
    private func colorForType(_ type: AppNotification.NotificationType) -> Color {
        switch type {
        case .eventInvite: return .purple
        case .chatMessage: return .blue
        case .rsvpUpdate: return .green
        case .newFollower: return .orange
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NotificationBellView()
}
