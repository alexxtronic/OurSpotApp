import Foundation
import Supabase

@MainActor
final class ChatService: ObservableObject {
    private let supabase: SupabaseClient? = Config.supabase
    private var realtimeChannel: RealtimeChannelV2?
    
    @Published var messages: [ChatMessage] = []
    
    func fetchMessages(for planId: UUID) async {
        guard let supabase = supabase else { return }
        
        do {
            let response: [ChatMessageDTO] = try await supabase
                .from("event_messages")
                .select("""
                    id,
                    plan_id,
                    user_id,
                    content,
                    created_at,
                    profiles:user_id (
                        name,
                        avatar_url
                    )
                """)
                .eq("plan_id", value: planId.uuidString)
                .order("created_at", ascending: true)
                .limit(200) // Prevent unbounded message loading
                .execute()
                .value
            
            let fetchedMessages = response.map { dto in
                ChatMessage(
                    id: dto.id,
                    planId: dto.plan_id,
                    userId: dto.user_id,
                    userName: dto.profiles?.name ?? "User",
                    userAvatarUrl: dto.profiles?.avatar_url,
                    content: dto.content,
                    timestamp: dto.created_at,
                    status: .sent
                )
            }
            
            await MainActor.run {
                // Merge fetched messages with any local "sending/failed" messages
                let localMessages = self.messages.filter { $0.status != .sent }
                
                // Deduplicate: If a local "sending" message has now arrived in fetched, remove local
                // (Simple logic: just keep all fetched, and append local ones that aren't in fetched)
                // Since local IDs are random UUIDs, we can't match by ID. 
                // We'll just append pending ones at the end.
                
                self.messages = fetchedMessages + localMessages
            }
            
        } catch {
            Logger.error("Error fetching messages: \(error.localizedDescription)")
        }
    }
    
    func sendMessage(planId: UUID, userId: UUID, content: String, userName: String, userAvatarUrl: String?) async {
        guard let supabase = supabase else { return }
        
        // 1. Create Optimistic Message
        let tempId = UUID()
        let optimisticMessage = ChatMessage(
            id: tempId,
            planId: planId,
            userId: userId,
            userName: userName,
            userAvatarUrl: userAvatarUrl,
            content: content,
            timestamp: Date(),
            status: .sending
        )
        
        // 2. Insert locally immediately
        self.messages.append(optimisticMessage)
        
        let messageDTO = ChatMessageInsertDTO(
            plan_id: planId,
            user_id: userId,
            content: content
        )
        
        do {
            // 3. Send to backend
            try await supabase
                .from("event_messages")
                .insert(messageDTO)
                .execute()
            
            // 4. On success: Mark as sent (keep it visible!)
            // The optimistic message stays - we just update its status
            if let index = self.messages.firstIndex(where: { $0.id == tempId }) {
                self.messages[index].status = .sent
                HapticManager.lightTap()
            }
            
        } catch {
            Logger.error("Error sending message: \(error.localizedDescription)")
            
            // 5. On failure: Mark as failed so user can retry
            if let index = self.messages.firstIndex(where: { $0.id == tempId }) {
                self.messages[index].status = .failed
            }
        }
    }
    
    func retryMessage(_ message: ChatMessage) async {
        // Remove the failed message
        if let index = self.messages.firstIndex(where: { $0.id == message.id }) {
            self.messages.remove(at: index)
        }
        
        // Try sending again
        await sendMessage(
            planId: message.planId,
            userId: message.userId,
            content: message.content,
            userName: message.userName,
            userAvatarUrl: message.userAvatarUrl
        )
    }
    
    func subscribe(to planId: UUID) {
        guard let supabase = supabase else { return }
        
        let channel = supabase.channel("event_messages_\(planId)")
        let changes = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "event_messages",
            filter: "plan_id=eq.\(planId.uuidString)"
        )
        
        Task {
            await channel.subscribe()
            
            for await _ in changes {
                await self.fetchMessages(for: planId)
            }
        }
        
        self.realtimeChannel = channel
    }
    
    func unsubscribe() {
        Task {
            await realtimeChannel?.unsubscribe()
            realtimeChannel = nil
        }
    }
    func fetchChatSummaries(currentUserId: UUID) async throws -> [ChatSummaryDTO] {
        guard let supabase = supabase else { return [] }
        
        return try await supabase
            .database
            .rpc("get_user_chat_summaries", params: ["current_user_id": currentUserId.uuidString])
            .execute()
            .value
    }
    
    func markChatAsRead(planId: UUID, userId: UUID) {
        guard let supabase = supabase else { return }
        
        Task {
            // Upsert: last_read_at = NOW()
            struct ReadReceipt: Encodable {
                let user_id: UUID
                let plan_id: UUID
                let last_read_at: Date
            }
            
            try? await supabase
                .from("event_chat_reads")
                .upsert(ReadReceipt(
                    user_id: userId,
                    plan_id: planId,
                    last_read_at: Date()
                ))
                .execute()
        }
    }
}

// MARK: - DTOs

struct ChatMessageDTO: Decodable {
    let id: UUID
    let plan_id: UUID
    let user_id: UUID
    let content: String
    let created_at: Date
    let profiles: ProfileNameDTO?
}

struct ProfileNameDTO: Decodable {
    let name: String
    let avatar_url: String?
}

struct ChatMessageInsertDTO: Encodable {
    let plan_id: UUID
    let user_id: UUID
    let content: String
}

struct ChatSummaryDTO: Decodable {
    let plan_id: UUID
    let unread_count: Int
    let last_message_at: Date?
    let last_message_content: String?
}
