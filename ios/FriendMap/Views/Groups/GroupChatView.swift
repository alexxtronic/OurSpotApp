import SwiftUI

/// Group chat view for a specific event
struct GroupChatView: View {
    let plan: Plan
    
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var chatService = ChatService()
    
    @State private var messageText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Event header
            eventHeader
            
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
            
            // Message input
            messageInput
        }
        .navigationTitle("Event Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await chatService.fetchMessages(for: plan.id)
                chatService.subscribe(to: plan.id)
            }
        }
        .onDisappear {
            chatService.unsubscribe()
        }
    }
    
    private var eventHeader: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Text(plan.emoji)
                .font(.system(size: 32))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.title)
                    .font(.headline)
                Text(plan.startsAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.secondaryBackground)
    }
    
    private func messageRow(_ message: ChatMessage) -> some View {
        let isMe = message.userId == sessionStore.currentUser.id
        
        return HStack {
            if isMe { Spacer() }
            
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                if !isMe {
                    Text(message.userName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(message.content)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(isMe ? DesignSystem.Colors.primaryFallback : DesignSystem.Colors.secondaryBackground)
                    .foregroundColor(isMe ? .white : .primary)
                    .cornerRadius(DesignSystem.CornerRadius.lg)
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !isMe { Spacer() }
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
    
    private func sendMessage() async {
        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let content = messageText
        messageText = "" // Clear immediately for UX
        
        await chatService.sendMessage(
            planId: plan.id,
            userId: sessionStore.currentUser.id,
            content: content
        )
    }
}

/// Chat message model
struct ChatMessage: Identifiable {
    let id: UUID
    let planId: UUID
    let userId: UUID
    let userName: String
    let content: String
    let timestamp: Date
}

#Preview {
    NavigationStack {
        GroupChatView(plan: MockData.samplePlans[0])
            .environmentObject(SessionStore())
    }
}
