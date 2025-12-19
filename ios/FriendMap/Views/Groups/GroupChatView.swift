import SwiftUI

/// Group chat view for a specific event
struct GroupChatView: View {
    let plan: Plan
    
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Event header
            eventHeader
            
            Divider()
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(messages) { message in
                            messageRow(message)
                                .id(message.id)
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
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
            loadMockMessages()
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
                sendMessage()
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
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let newMessage = ChatMessage(
            id: UUID(),
            planId: plan.id,
            userId: sessionStore.currentUser.id,
            userName: sessionStore.currentUser.name,
            content: messageText,
            timestamp: Date()
        )
        
        messages.append(newMessage)
        messageText = ""
        
        // TODO: Send to Supabase
    }
    
    private func loadMockMessages() {
        // Mock messages for demo
        messages = [
            ChatMessage(
                id: UUID(),
                planId: plan.id,
                userId: UUID(),
                userName: "Alex",
                content: "Hey! Can't wait for this event 🎉",
                timestamp: Date().addingTimeInterval(-3600)
            ),
            ChatMessage(
                id: UUID(),
                planId: plan.id,
                userId: UUID(),
                userName: "Sam",
                content: "Same here! Should we meet up before?",
                timestamp: Date().addingTimeInterval(-1800)
            )
        ]
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
