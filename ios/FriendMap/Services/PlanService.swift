import Foundation
import Supabase

/// Service for Plan CRUD operations with Supabase
@MainActor
final class PlanService: ObservableObject {
    
    // MARK: - Fetch Plans
    
    // MARK: - Fetch Plans
    
    func fetchPlans() async throws -> [Plan] {
        guard let supabase = Config.supabase else {
            Logger.warning("Supabase not configured - returning empty")
            return []
        }
        
        // Select all plan fields plus host profile name and avatar
        let response: [PlanDTO] = try await supabase
            .from("plans")
            .select("*, profiles:host_user_id(name, avatar_url)")
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
                isPrivate: dto.is_private ?? false,
                hostName: dto.profiles?.name ?? "Unknown Host",
                hostAvatar: dto.profiles?.avatar_url
            )
        }
    }
    
    // MARK: - Create Plan
    
    func createPlan(_ plan: Plan) async throws {
        guard let supabase = Config.supabase else {
            Logger.warning("Supabase not configured")
            return
        }
        
        try await supabase
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
        guard let supabase = Config.supabase else { return }
        
        let statusString: String
        switch status {
        case .going: statusString = "going"
        case .maybe: statusString = "maybe"
        case .none: statusString = "not_going"
        case .pending: statusString = "pending"
        }
        
        try await supabase
            .from("rsvps")
            .upsert(RSVPInsertDTO(plan_id: planId, user_id: userId, status: statusString))
            .execute()
        
        Logger.info("RSVP updated: \(statusString)")
    }
    
    // MARK: - Delete Plan
    
    func deletePlan(_ planId: UUID) async throws {
        guard let supabase = Config.supabase else { return }
        
        try await supabase
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
    let profiles: ProfileDTO?
}

private struct ProfileDTO: Decodable {
    let name: String
    let avatar_url: String?
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
