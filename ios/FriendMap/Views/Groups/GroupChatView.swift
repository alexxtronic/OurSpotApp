import SwiftUI

/// Group chat view for a specific event
/// Supports read-only mode for archived events (24hrs+ after start)
struct GroupChatView: View {
    let plan: Plan
    @Binding var selectedTab: ContentView.Tab
    
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var planStore: PlanStore
    @StateObject private var chatService = ChatService()
    
    @State private var messageText = ""
    @State private var selectedUserId: UUID?
    
    /// Whether this chat is archived (10+ hours since event start - matches event visibility)
    private var isArchived: Bool {
        let hoursSinceStart = Date().timeIntervalSince(plan.startsAt) / 3600
        return hoursSinceStart >= 10
    }
    
    /// Whether the event is "live" (0-10 hours since start)
    private var isLive: Bool {
        let hoursSinceStart = Date().timeIntervalSince(plan.startsAt) / 3600
        return hoursSinceStart >= 0 && hoursSinceStart < 10
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Event header with live/archived status - TAPPABLE to go to map
            Button {
                // Navigate to map with this event
                planStore.planToShowOnMap = plan
                selectedTab = .map
                HapticManager.lightTap()
            } label: {
                eventHeader
            }
            .buttonStyle(.plain)
            
            Divider()
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(chatService.messages) { message in
                            messageRow(message)
                                .id(message.id)
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                }
                .onChange(of: chatService.messages.count) { _, _ in
                    if let lastMessage = chatService.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Message input or archived notice
            if isArchived {
                archivedNotice
            } else {
                messageInput
            }
        }
        .navigationTitle("Event Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await chatService.fetchMessages(for: plan.id)
                chatService.subscribe(to: plan.id)
                chatService.markChatAsRead(planId: plan.id, userId: sessionStore.currentUser.id)
            }
        }
        .onDisappear {
            chatService.unsubscribe()
            chatService.markChatAsRead(planId: plan.id, userId: sessionStore.currentUser.id)
        }
        .sheet(item: selectedUserIdFromWrapper) { wrapper in
            PublicProfileView(userId: wrapper.id)
        }
    }

    private var selectedUserIdFromWrapper: Binding<IdentifiableUUID?> {
        Binding(
            get: { selectedUserId.map { IdentifiableUUID(id: $0) } },
            set: { selectedUserId = $0?.id }
        )
    }
    
    private var eventHeader: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Emoji with optional rainbow border for live events
            ZStack {
                if isLive {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 42, height: 42)
                }
                
                Text(plan.emoji)
                    .font(.system(size: 28))
                    .frame(width: 36, height: 36)
            }
            .opacity(isArchived ? 0.6 : 1.0)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(plan.title)
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
                        Text("ARCHIVED")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(4)
                    }
                }
                
                Text(plan.startsAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Tap indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            isLive 
                ? Color.orange.opacity(0.1) 
                : DesignSystem.Colors.secondaryBackground
        )
    }
    
    private func messageRow(_ message: ChatMessage) -> some View {
        let isMe = message.userId == sessionStore.currentUser.id
        
        return HStack(alignment: .bottom, spacing: 8) {
            if !isMe {
                Button {
                    selectedUserId = message.userId
                } label: {
                    AvatarView(
                        name: message.userName,
                        size: 32,
                        url: URL(string: message.userAvatarUrl ?? "")
                    )
                }
            } else {
                Spacer()
            }
            
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                if !isMe {
                    Text(message.userName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }
                
                HStack(alignment: .bottom, spacing: 4) {
                    if isMe && message.status == .failed {
                        Button {
                            Task { await chatService.retryMessage(message) }
                        } label: {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Text(message.content)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(isMe ? DesignSystem.Colors.chatUserBubble : DesignSystem.Colors.chatOtherBubble)
                        .foregroundColor(isMe ? .white : .primary)
                        .cornerRadius(DesignSystem.CornerRadius.lg)
                        .opacity(message.status == .sending ? 0.7 : 1.0)
                }
                
                if message.status == .failed {
                    Text("Failed to send")
                        .font(.caption2)
                        .foregroundColor(.red)
                        .padding(isMe ? .trailing : .leading, 4)
                } else {
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(isMe ? .trailing : .leading, 4)
                }
            }
            
            if !isMe {
                Spacer()
            }
        }
    }
    
    private var messageInput: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            TextField("Message...", text: $messageText)
                .textFieldStyle(.plain)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.tertiaryBackground)
                .cornerRadius(DesignSystem.CornerRadius.lg)
            
            Button {
                Task {
                    await sendMessage()
                }
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.white)
                    .padding(DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.primaryFallback)
                    .clipShape(Circle())
            }
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.secondaryBackground)
    }
    
    private var archivedNotice: some View {
        HStack {
            Image(systemName: "archivebox.fill")
                .foregroundColor(.secondary)
            Text("This chat is archived and read-only")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.secondaryBackground)
    }
    
    private func sendMessage() async {
        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard !isArchived else { return } // Safety check
        
        let content = messageText
        messageText = "" // Clear immediately for UX
        
        await chatService.sendMessage(
            planId: plan.id,
            userId: sessionStore.currentUser.id,
            content: content,
            userName: sessionStore.currentUser.name,
            userAvatarUrl: sessionStore.currentUser.avatarUrl
        )
    }
}

/// Chat message model
struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let planId: UUID
    let userId: UUID
    let userName: String
    let userAvatarUrl: String?
    let content: String
    let timestamp: Date
    var status: MessageStatus = .sent
    
    enum MessageStatus {
        case sending
        case sent
        case failed
    }
}

struct IdentifiableUUID: Identifiable {
    let id: UUID
}

#Preview {
    NavigationStack {
        GroupChatView(plan: MockData.samplePlans[0], selectedTab: .constant(.groups))
            .environmentObject(SessionStore())
            .environmentObject(PlanStore())
    }
}
