import Foundation

/// Service for Plan CRUD operations (stub for now)
@MainActor
final class PlanService: ObservableObject {
    
    // MARK: - Fetch Plans (placeholder)
    
    func fetchPlans() async throws -> [Plan] {
        // TODO: Implement Supabase fetch
        Logger.info("PlanService.fetchPlans called - using local data")
        return []
    }
    
    // MARK: - Create Plan (placeholder)
    
    func createPlan(_ plan: Plan) async throws {
        // TODO: Implement Supabase insert
        Logger.info("PlanService.createPlan called - plan: \(plan.title)")
    }
    
    // MARK: - Update RSVP (placeholder)
    
    func updateRSVP(planId: UUID, userId: UUID, status: RSVPStatus) async throws {
        // TODO: Implement Supabase upsert
        Logger.info("PlanService.updateRSVP called")
    }
    
    // MARK: - Delete Plan (placeholder)
    
    func deletePlan(_ planId: UUID) async throws {
        // TODO: Implement Supabase delete
        Logger.info("PlanService.deletePlan called")
    }
}
