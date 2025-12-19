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
                        name
                    )
                """)
                .eq("plan_id", value: planId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            self.messages = response.map { dto in
                ChatMessage(
                    id: dto.id,
                    planId: dto.plan_id,
                    userId: dto.user_id,
                    userName: dto.profiles?.name ?? "User",
                    content: dto.content,
                    timestamp: dto.created_at
                )
            }
            
        } catch {
            Logger.error("Error fetching messages: \(error.localizedDescription)")
        }
    }
    
    func sendMessage(planId: UUID, userId: UUID, content: String) async {
        guard let supabase = supabase else { return }
        
        let message = ChatMessageInsertDTO(
            plan_id: planId,
            user_id: userId,
            content: content
        )
        
        do {
            try await supabase
                .from("event_messages")
                .insert(message)
                .execute()
        } catch {
            Logger.error("Error sending message: \(error.localizedDescription)")
        }
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
}

struct ChatMessageInsertDTO: Encodable {
    let plan_id: UUID
    let user_id: UUID
    let content: String
}
