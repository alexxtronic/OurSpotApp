import Foundation
import Supabase

/// Service for Direct Messaging operations with Supabase
@MainActor
final class DirectMessageService: ObservableObject {
    
    @Published var conversations: [DMConversation] = []
    @Published var totalUnreadCount: Int = 0
    
    private var supabase: SupabaseClient? { Config.supabase }
    
    // MARK: - Fetch Conversations
    
    /// Fetches all DM conversations for the current user
    func fetchConversations(currentUserId: UUID) async {
        guard let supabase = supabase else { return }
        
        do {
            let response: [DMConversationDTO] = try await supabase
                .rpc("get_dm_conversations", params: ["current_user_id": currentUserId])
                .execute()
                .value
            
            conversations = response.map { $0.toDMConversation() }
            totalUnreadCount = conversations.reduce(0) { $0 + $1.unreadCount }
            
            // Trigger notifications for unread messages
            checkForUnreadMessages()
            
            Logger.info("Loaded \(conversations.count) DM conversations")
        } catch {
            Logger.error("Failed to fetch DM conversations: \(error.localizedDescription)")
        }
    }
    
    private func checkForUnreadMessages() {
        for conversation in conversations where conversation.unreadCount > 0 {
            // Check if we already have a notification for this user
            let hasNotification = NotificationCenter.shared.notifications.contains {
                $0.type == .chatMessage && $0.relatedUserId == conversation.otherUserId
            }
            
            if !hasNotification {
                let notification = AppNotification(
                    id: UUID(),
                    type: .chatMessage,
                    title: "New Message",
                    message: "You have \(conversation.unreadCount) new message\(conversation.unreadCount == 1 ? "" : "s") from \(conversation.otherUserName)",
                    timestamp: conversation.lastMessageAt ?? Date(),
                    relatedPlanId: nil,
                    relatedUserId: conversation.otherUserId,
                    isRead: false
                )
                NotificationCenter.shared.addNotification(notification)
            }
        }
    }
    
    // MARK: - Fetch Messages
    
    /// Fetches message history with a specific user
    func fetchMessages(with otherUserId: UUID, currentUserId: UUID) async -> [DirectMessage] {
        guard let supabase = supabase else { return [] }
        
        do {
            let response: [DirectMessageDTO] = try await supabase
                .from("direct_messages")
                .select()
                .or("and(sender_id.eq.\(currentUserId),recipient_id.eq.\(otherUserId)),and(sender_id.eq.\(otherUserId),recipient_id.eq.\(currentUserId))")
                .order("created_at", ascending: true)
                .execute()
                .value
            
            return response.map { $0.toDirectMessage() }
        } catch {
            Logger.error("Failed to fetch DM history: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Send Message
    
    /// Sends a direct message to another user
    func sendMessage(to recipientId: UUID, from senderId: UUID, content: String) async -> DirectMessage? {
        guard let supabase = supabase else { return nil }
        
        let dto = DirectMessageInsertDTO(
            sender_id: senderId,
            recipient_id: recipientId,
            content: content
        )
        
        do {
            let response: [DirectMessageDTO] = try await supabase
                .from("direct_messages")
                .insert(dto)
                .select()
                .execute()
                .value
            
            if let created = response.first {
                Logger.debug("Sent DM to \(recipientId)")
                return created.toDirectMessage()
            }
            return nil
        } catch {
            Logger.error("Failed to send DM: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Mark as Read
    
    /// Marks all messages from a user as read
    func markAsRead(from senderId: UUID, currentUserId: UUID) async {
        guard let supabase = supabase else { return }
        
        do {
            try await supabase
                .from("direct_messages")
                .update(["is_read": true])
                .eq("sender_id", value: senderId)
                .eq("recipient_id", value: currentUserId)
                .eq("is_read", value: false)
                .execute()
            
            // Update local unread count
            if let index = conversations.firstIndex(where: { $0.otherUserId == senderId }) {
                var updated = conversations[index]
                totalUnreadCount -= updated.unreadCount
                // Create a new conversation with 0 unread
                conversations[index] = DMConversation(
                    id: updated.id,
                    otherUserId: updated.otherUserId,
                    otherUserName: updated.otherUserName,
                    otherUserAvatar: updated.otherUserAvatar,
                    lastMessageContent: updated.lastMessageContent,
                    lastMessageAt: updated.lastMessageAt,
                    lastMessageSenderId: updated.lastMessageSenderId,
                    unreadCount: 0
                )
            }
            
            Logger.debug("Marked messages from \(senderId) as read")
        } catch {
            Logger.error("Failed to mark DMs as read: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Check Mutual Follow
    
    /// Checks if the current user and another user mutually follow each other
    func checkMutualFollow(currentUserId: UUID, otherUserId: UUID) async -> Bool {
        guard let supabase = supabase else { return false }
        
        do {
            let result: Bool = try await supabase
                .rpc("check_mutual_follow", params: ["user_a": currentUserId, "user_b": otherUserId])
                .execute()
                .value
            
            return result
        } catch {
            Logger.error("Failed to check mutual follow: \(error.localizedDescription)")
            return false
        }
    }
}
