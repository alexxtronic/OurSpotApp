import Foundation
import PostgREST

/// Service for Plan CRUD operations with Supabase
@MainActor
final class PlanService: ObservableObject {
    
    // MARK: - Fetch Plans
    
    /// Fetch all visible plans (for now, all plans - later will filter by friends)
    func fetchPlans() async throws -> [Plan] {
        guard let supabase = Config.supabase else {
            Logger.warning("Supabase not configured - returning empty")
            return []
        }
        
        struct PlanDTO: Decodable {
            let id: UUID
            let host_user_id: UUID
            let title: String
            let description: String
            let starts_at: Date
            let latitude: Double
            let longitude: Double
            let emoji: String?
            let activity_type: String?
            let address_text: String?
            let is_private: Bool?
        }
        
        let response: [PlanDTO] = try await supabase
            .from("plans")
            .select()
            .gte("starts_at", value: ISO8601DateFormatter().string(from: Date()))
            .order("starts_at", ascending: true)
            .execute()
            .value
        
        // Map DTOs to Plan model
        return response.map { dto in
            Plan(
                id: dto.id,
                hostUserId: dto.host_user_id,
                title: dto.title,
                description: dto.description,
                startsAt: dto.starts_at,
                latitude: dto.latitude,
                longitude: dto.longitude,
                emoji: dto.emoji ?? "📍",
                activityType: ActivityType(rawValue: dto.activity_type ?? "social") ?? .social,
                addressText: dto.address_text ?? "",
                isPrivate: dto.is_private ?? false
            )
        }
    }
    
    // MARK: - Create Plan
    
    func createPlan(_ plan: Plan) async throws {
        guard let supabase = Config.supabase else {
            Logger.warning("Supabase not configured - plan not saved to cloud")
            return
        }
        
        try await supabase
            .from("plans")
            .insert([
                "id": plan.id.uuidString,
                "host_user_id": plan.hostUserId.uuidString,
                "title": plan.title,
                "description": plan.description,
                "starts_at": ISO8601DateFormatter().string(from: plan.startsAt),
                "latitude": plan.latitude,
                "longitude": plan.longitude,
                "emoji": plan.emoji,
                "activity_type": plan.activityType.rawValue,
                "address_text": plan.addressText,
                "is_private": plan.isPrivate
            ])
            .execute()
        
        Logger.info("Plan created in Supabase: \(plan.title)")
    }
    
    // MARK: - Update RSVP
    
    func updateRSVP(planId: UUID, userId: UUID, status: RSVPStatus) async throws {
        guard let supabase = Config.supabase else { return }
        
        let statusString: String
        switch status {
        case .going: statusString = "going"
        case .maybe: statusString = "maybe"
        case .none: statusString = "not_going"
        case .pending: statusString = "pending"
        }
        
        // Upsert RSVP
        try await supabase
            .from("rsvps")
            .upsert([
                "plan_id": planId.uuidString,
                "user_id": userId.uuidString,
                "status": statusString
            ])
            .execute()
        
        Logger.info("RSVP updated in Supabase: \(status.displayText)")
    }
    
    // MARK: - Fetch RSVPs for Plan
    
    func fetchRSVPs(for planId: UUID) async throws -> [UUID: RSVPStatus] {
        guard let supabase = Config.supabase else { return [:] }
        
        struct RSVPDTO: Decodable {
            let user_id: UUID
            let status: String
        }
        
        let response: [RSVPDTO] = try await supabase
            .from("rsvps")
            .select()
            .eq("plan_id", value: planId.uuidString)
            .execute()
            .value
        
        var result: [UUID: RSVPStatus] = [:]
        for rsvp in response {
            let status: RSVPStatus
            switch rsvp.status {
            case "going": status = .going
            case "maybe": status = .maybe
            case "pending": status = .pending
            default: status = RSVPStatus.none
            }
            result[rsvp.user_id] = status
        }
        
        return result
    }
    
    // MARK: - Delete Plan
    
    func deletePlan(_ planId: UUID) async throws {
        guard let supabase = Config.supabase else { return }
        
        try await supabase
            .from("plans")
            .delete()
            .eq("id", value: planId.uuidString)
            .execute()
        
        Logger.info("Plan deleted from Supabase: \(planId)")
    }
}
