import SwiftUI

/// View showing all DM conversations for the current user
struct DirectMessagesListView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var dmService: DirectMessageService  // Use shared instance!
    
    @State private var selectedConversation: DMConversation?
    
    var body: some View {
        NavigationStack {
            Group {
                if dmService.conversations.isEmpty {
                    emptyState
                } else {
                    conversationsList
                }
            }
            .navigationTitle("Messages")
            .task {
                await dmService.fetchConversations(currentUserId: sessionStore.currentUser.id)
            }
            .refreshable {
                await dmService.fetchConversations(currentUserId: sessionStore.currentUser.id)
            }
        }
    }
    
    // MARK: - Conversations List
    
    private var conversationsList: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(dmService.conversations) { conversation in
                    NavigationLink {
                        DirectMessageChatView(otherUser: (
                            id: conversation.otherUserId,
                            name: conversation.otherUserName,
                            avatar: conversation.otherUserAvatar
                        ))
                    } label: {
                        conversationRow(conversation)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
    }
    
    private func conversationRow(_ conversation: DMConversation) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Avatar
            AvatarView(
                name: conversation.otherUserName,
                size: 52,
                url: URL(string: conversation.otherUserAvatar ?? "")
            )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.otherUserName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if let lastAt = conversation.lastMessageAt {
                        Text(formatTime(lastAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let lastMessage = conversation.lastMessageContent {
                    HStack(spacing: 4) {
                        if conversation.lastMessageIsFromMe(currentUserId: sessionStore.currentUser.id) {
                            Text("You:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Text(lastMessage)
                            .font(.subheadline)
                            .foregroundColor(conversation.unreadCount > 0 ? .primary : .secondary)
                            .fontWeight(conversation.unreadCount > 0 ? .medium : .regular)
                            .lineLimit(1)
                    }
                }
            }
            
            // Unread badge
            if conversation.unreadCount > 0 {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 24, height: 24)
                    Text("\(min(conversation.unreadCount, 99))")
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
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Messages Yet")
                .font(.title2.bold())
            
            Text("Start a conversation by visiting a friend's profile and tapping the message icon.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

#Preview {
    DirectMessagesListView()
        .environmentObject(SessionStore())
        .environmentObject(DirectMessageService())
}
