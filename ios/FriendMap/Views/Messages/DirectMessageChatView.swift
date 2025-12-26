import SwiftUI

/// 1:1 Direct message chat view between two users
struct DirectMessageChatView: View {
    let otherUser: (id: UUID, name: String, avatar: String?)
    
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var dmService: DirectMessageService  // Use shared instance!
    
    @State private var messages: [DirectMessage] = []
    @State private var messageText = ""
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                }
                .onChange(of: messages.count) { _ in
                    scrollToBottom(proxy: scrollProxy)
                }
                .onAppear {
                    scrollToBottom(proxy: scrollProxy)
                }
            }
            
            Divider()
            
            // Input bar
            inputBar
        }
        .navigationTitle(otherUser.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    AvatarView(
                        name: otherUser.name,
                        size: 32,
                        url: URL(string: otherUser.avatar ?? "")
                    )
                    Text(otherUser.name)
                        .font(.headline)
                }
            }
        }
        .task {
            await loadMessages()
        }
    }
    
    // MARK: - Message Bubble
    
    private func messageBubble(_ message: DirectMessage) -> some View {
        let isFromMe = message.senderId == sessionStore.currentUser.id
        
        return HStack {
            if isFromMe { Spacer(minLength: 60) }
            
            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 2) {
                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isFromMe 
                            ? DesignSystem.Colors.primaryFallback
                            : DesignSystem.Colors.secondaryBackground
                    )
                    .foregroundColor(isFromMe ? .white : .primary)
                    .cornerRadius(18)
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !isFromMe { Spacer(minLength: 60) }
        }
    }
    
    // MARK: - Input Bar
    
    private var inputBar: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            TextField("Message...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(DesignSystem.Colors.secondaryBackground)
                .cornerRadius(20)
                .lineLimit(1...5)
            
            Button {
                Task { await sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(
                        messageText.trimmingCharacters(in: .whitespaces).isEmpty 
                            ? .gray 
                            : DesignSystem.Colors.primaryFallback
                    )
            }
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Actions
    
    private func loadMessages() async {
        isLoading = true
        messages = await dmService.fetchMessages(
            with: otherUser.id,
            currentUserId: sessionStore.currentUser.id
        )
        isLoading = false
        
        // Mark as read
        await dmService.markAsRead(
            from: otherUser.id,
            currentUserId: sessionStore.currentUser.id
        )
    }
    
    private func sendMessage() async {
        let content = messageText.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }
        
        messageText = "" // Clear immediately
        HapticManager.lightTap()
        
        if let newMessage = await dmService.sendMessage(
            to: otherUser.id,
            from: sessionStore.currentUser.id,
            content: content
        ) {
            messages.append(newMessage)
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = messages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DirectMessageChatView(otherUser: (
            id: UUID(),
            name: "Test User",
            avatar: nil
        ))
        .environmentObject(SessionStore())
    }
}
