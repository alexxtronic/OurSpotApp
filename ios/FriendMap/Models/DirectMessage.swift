import Foundation

/// Represents a direct message between two users
struct DirectMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let senderId: UUID
    let recipientId: UUID
    let content: String
    let timestamp: Date
    var isRead: Bool
    
    /// Returns which user is the "other" user in this conversation
    func otherUserId(relativeTo currentUserId: UUID) -> UUID {
        return senderId == currentUserId ? recipientId : senderId
    }
}

/// Represents a DM conversation summary for the inbox list
struct DMConversation: Identifiable, Equatable {
    let id: UUID // other user's ID
    let otherUserId: UUID
    let otherUserName: String
    let otherUserAvatar: String?
    let lastMessageContent: String?
    let lastMessageAt: Date?
    let lastMessageSenderId: UUID?
    let unreadCount: Int
    
    /// Whether the last message was sent by the current user
    func lastMessageIsFromMe(currentUserId: UUID) -> Bool {
        return lastMessageSenderId == currentUserId
    }
}

// MARK: - Supabase DTOs

struct DirectMessageDTO: Codable {
    let id: UUID
    let sender_id: UUID
    let recipient_id: UUID
    let content: String
    let is_read: Bool
    let created_at: Date
    
    func toDirectMessage() -> DirectMessage {
        DirectMessage(
            id: id,
            senderId: sender_id,
            recipientId: recipient_id,
            content: content,
            timestamp: created_at,
            isRead: is_read
        )
    }
}

struct DirectMessageInsertDTO: Codable {
    let sender_id: UUID
    let recipient_id: UUID
    let content: String
}

struct DMConversationDTO: Codable {
    let other_user_id: UUID
    let other_user_name: String
    let other_user_avatar: String?
    let last_message_content: String?
    let last_message_at: Date?
    let last_message_sender_id: UUID?
    let unread_count: Int
    
    func toDMConversation() -> DMConversation {
        DMConversation(
            id: other_user_id,
            otherUserId: other_user_id,
            otherUserName: other_user_name,
            otherUserAvatar: other_user_avatar,
            lastMessageContent: last_message_content,
            lastMessageAt: last_message_at,
            lastMessageSenderId: last_message_sender_id,
            unreadCount: unread_count
        )
    }
}
