import Foundation
import PostgREST

/// Service for Plan CRUD operations with Supabase
@MainActor
final class PlanService: ObservableObject {
    
    // MARK: - Fetch Plans
    
    func fetchPlans() async throws -> [Plan] {
        guard let postgrest = Config.postgrest else {
            Logger.warning("PostgREST not configured - returning empty")
            return []
        }
        
        let response: [PlanDTO] = try await postgrest
            .from("plans")
            .select()
            .gte("starts_at", value: ISO8601DateFormatter().string(from: Date()))
            .order("starts_at", ascending: true)
            .execute()
            .value
        
        return response.map { dto in
            Plan(
                id: dto.id,
                hostUserId: dto.host_user_id,
                title: dto.title,
                description: dto.description ?? "",
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
        guard let postgrest = Config.postgrest else {
            Logger.warning("PostgREST not configured")
            return
        }
        
        try await postgrest
            .from("plans")
            .insert(PlanInsertDTO(
                id: plan.id,
                host_user_id: plan.hostUserId,
                title: plan.title,
                description: plan.description,
                starts_at: plan.startsAt,
                latitude: plan.latitude,
                longitude: plan.longitude,
                emoji: plan.emoji,
                activity_type: plan.activityType.rawValue,
                address_text: plan.addressText,
                is_private: plan.isPrivate
            ))
            .execute()
        
        Logger.info("Plan created: \(plan.title)")
    }
    
    // MARK: - Update RSVP
    
    func updateRSVP(planId: UUID, userId: UUID, status: RSVPStatus) async throws {
        guard let postgrest = Config.postgrest else { return }
        
        let statusString: String
        switch status {
        case .going: statusString = "going"
        case .maybe: statusString = "maybe"
        case .none: statusString = "not_going"
        case .pending: statusString = "pending"
        }
        
        try await postgrest
            .from("rsvps")
            .upsert(RSVPInsertDTO(plan_id: planId, user_id: userId, status: statusString))
            .execute()
        
        Logger.info("RSVP updated: \(statusString)")
    }
    
    // MARK: - Delete Plan
    
    func deletePlan(_ planId: UUID) async throws {
        guard let postgrest = Config.postgrest else { return }
        
        try await postgrest
            .from("plans")
            .delete()
            .eq("id", value: planId.uuidString)
            .execute()
        
        Logger.info("Plan deleted")
    }
}

// MARK: - DTOs

private struct PlanDTO: Decodable {
    let id: UUID
    let host_user_id: UUID
    let title: String
    let description: String?
    let starts_at: Date
    let latitude: Double
    let longitude: Double
    let emoji: String?
    let activity_type: String?
    let address_text: String?
    let is_private: Bool?
}

private struct PlanInsertDTO: Encodable {
    let id: UUID
    let host_user_id: UUID
    let title: String
    let description: String
    let starts_at: Date
    let latitude: Double
    let longitude: Double
    let emoji: String
    let activity_type: String
    let address_text: String
    let is_private: Bool
}

private struct RSVPInsertDTO: Encodable {
    let plan_id: UUID
    let user_id: UUID
    let status: String
}
