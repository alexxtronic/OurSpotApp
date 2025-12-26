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
        // Safety limit to prevent unbounded queries at scale
        let response: [PlanDTO] = try await supabase
            .from("plans")
            .select("*, profiles:host_user_id(name, avatar_url)")
            .gte("starts_at", value: ISO8601DateFormatter().string(from: Date()))
            .order("starts_at", ascending: true)
            .limit(500)
            .execute()
            .value
        
        return response.map { dto in
            // Debug: log avatar URL for each plan
            Logger.debug("📸 Plan '\(dto.title)' ID: \(dto.id)")
            Logger.debug("   Host ID: \(dto.host_user_id)")
            Logger.debug("   Host Name (DTO): \(dto.profiles?.name ?? "NIL")")
            Logger.debug("   Host Avatar (DTO): \(dto.profiles?.avatar_url ?? "NIL")")
            
            return Plan(
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
    
    // MARK: - Fetch RSVPs for a User
    
    /// Fetches the current user's RSVP status for all plans
    func fetchMyRSVPs(userId: UUID) async throws -> [UUID: RSVPStatus] {
        guard let supabase = Config.supabase else { return [:] }
        
        let response: [RSVPDTO] = try await supabase
            .from("rsvps")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        var result: [UUID: RSVPStatus] = [:]
        for rsvp in response {
            let status: RSVPStatus
            switch rsvp.status {
            case "going": status = .going
            case "maybe": status = .maybe
            case "pending": status = .pending
            case "invited": status = .invited
            default: status = .none
            }
            result[rsvp.plan_id] = status
        }
        return result
    }
    
    /// Fetches all attendees (going status) for a list of plans
    func fetchAttendeesForPlans(planIds: [UUID]) async throws -> [UUID: Set<UUID>] {
        guard let supabase = Config.supabase, !planIds.isEmpty else { return [:] }
        
        // Fetch all "going" RSVPs for these plans
        let response: [RSVPDTO] = try await supabase
            .from("rsvps")
            .select()
            .in("plan_id", values: planIds.map { $0.uuidString })
            .eq("status", value: "going")
            .execute()
            .value
        
        var result: [UUID: Set<UUID>] = [:]
        for rsvp in response {
            if result[rsvp.plan_id] == nil {
                result[rsvp.plan_id] = []
            }
            result[rsvp.plan_id]?.insert(rsvp.user_id)
        }
        return result
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
        Logger.info("📝 updateRSVP called: planId=\(planId), userId=\(userId), status=\(status)")
        guard let supabase = Config.supabase else {
            Logger.error("❌ Supabase not configured, cannot update RSVP")
            return
        }
        
        let statusString: String
        switch status {
        case .going: statusString = "going"
        case .maybe: statusString = "maybe"
        case .none: statusString = "not_going"
        case .pending: statusString = "pending"
        case .invited: statusString = "invited"
        }
        
        Logger.info("📝 Upserting RSVP: plan_id=\(planId), user_id=\(userId), status=\(statusString)")
        try await supabase
            .from("rsvps")
            .upsert(RSVPInsertDTO(plan_id: planId, user_id: userId, status: statusString), onConflict: "plan_id, user_id")
            .execute()
        
        Logger.info("✅ RSVP upserted successfully: \(statusString) for user \(userId) on plan \(planId)")
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
    
    // MARK: - Update Plan
    
    func updatePlan(_ plan: Plan) async throws {
        guard let supabase = Config.supabase else { return }
        
        let updateDTO = PlanUpdateDTO(
            title: plan.title,
            description: plan.description,
            starts_at: plan.startsAt,
            latitude: plan.latitude,
            longitude: plan.longitude,
            emoji: plan.emoji,
            activity_type: plan.activityType.rawValue,
            address_text: plan.addressText,
            is_private: plan.isPrivate
        )
        
        try await supabase
            .from("plans")
            .update(updateDTO)
            .eq("id", value: plan.id.uuidString)
            .execute()
        
        Logger.info("Plan updated: \(plan.title)")
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

private struct RSVPDTO: Decodable {
    let plan_id: UUID
    let user_id: UUID
    let status: String
}

private struct RSVPInsertDTO: Encodable {
    let plan_id: UUID
    let user_id: UUID
    let status: String
}

private struct PlanUpdateDTO: Encodable {
    let title: String
    let description: String
    let starts_at: Date
    let latitude: Double
    let longitude: Double
    let emoji: String
    let activity_type: String
    let address_text: String?
    let is_private: Bool
}

private struct PlanBanInsertDTO: Encodable {
    let plan_id: UUID
    let banned_user_id: UUID
    let banned_by: UUID
    let reason: String?
}

private struct PlanBanDTO: Decodable {
    let id: UUID
    let plan_id: UUID
    let banned_user_id: UUID
}

// MARK: - Plan Service Extension for Kick/Ban

extension PlanService {
    
    /// Kicks a user from an event and permanently bans them from returning
    /// - Parameters:
    ///   - userId: The user to kick
    ///   - planId: The event to kick them from
    ///   - hostId: The host performing the kick (for verification)
    ///   - reason: Optional reason for the kick
    func kickUser(_ userId: UUID, from planId: UUID, by hostId: UUID, reason: String? = nil) async throws {
        guard let supabase = Config.supabase else { return }
        
        Logger.info("🚫 Kicking user \(userId) from plan \(planId)")
        
        // 1. Insert ban record
        try await supabase
            .from("plan_bans")
            .insert(PlanBanInsertDTO(
                plan_id: planId,
                banned_user_id: userId,
                banned_by: hostId,
                reason: reason
            ))
            .execute()
        
        Logger.info("✅ Ban record created")
        
        // 2. Remove their RSVP
        try await supabase
            .from("rsvps")
            .delete()
            .eq("plan_id", value: planId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
        
        Logger.info("✅ RSVP removed for kicked user")
    }
    
    /// Checks if a user is banned from an event
    func isUserBanned(_ userId: UUID, from planId: UUID) async -> Bool {
        guard let supabase = Config.supabase else { return false }
        
        do {
            let response: [PlanBanDTO] = try await supabase
                .from("plan_bans")
                .select("id, plan_id, banned_user_id")
                .eq("plan_id", value: planId.uuidString)
                .eq("banned_user_id", value: userId.uuidString)
                .execute()
                .value
            
            return !response.isEmpty
        } catch {
            Logger.error("Failed to check ban status: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Removes a ban (unbans a user) - host only
    func unbanUser(_ userId: UUID, from planId: UUID) async throws {
        guard let supabase = Config.supabase else { return }
        
        try await supabase
            .from("plan_bans")
            .delete()
            .eq("plan_id", value: planId.uuidString)
            .eq("banned_user_id", value: userId.uuidString)
            .execute()
        
        Logger.info("✅ User \(userId) unbanned from plan \(planId)")
    }
}
