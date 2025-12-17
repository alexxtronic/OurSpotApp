import Foundation
import SwiftUI

/// Manages plans and RSVP status
@MainActor
final class PlanStore: ObservableObject {
    @Published var plans: [Plan] = []
    @Published var rsvpStatus: [UUID: RSVPStatus] = [:]
    
    init() {
        // Load mock plans
        self.plans = MockData.samplePlans
        Logger.info("Loaded \(plans.count) mock plans")
    }
    
    /// Creates a new plan and adds it to the store
    func createPlan(title: String, description: String, startsAt: Date, location: LocationPreset, hostUserId: UUID) {
        let newPlan = Plan(
            id: UUID(),
            hostUserId: hostUserId,
            title: title,
            description: description,
            startsAt: startsAt,
            latitude: location.latitude,
            longitude: location.longitude
        )
        plans.append(newPlan)
        rsvpStatus[newPlan.id] = .going // Auto-RSVP to your own plan
        Logger.info("Created new plan: \(title)")
    }
    
    /// Toggles RSVP status for a plan
    func toggleRSVP(planId: UUID) {
        let current = rsvpStatus[planId] ?? .none
        let next: RSVPStatus
        switch current {
        case .none:
            next = .going
        case .going:
            next = .maybe
        case .maybe:
            next = .none
        }
        rsvpStatus[planId] = next
        Logger.info("RSVP for plan \(planId): \(next.displayText)")
    }
    
    /// Gets RSVP status for a specific plan
    func getRSVP(for planId: UUID) -> RSVPStatus {
        return rsvpStatus[planId] ?? .none
    }
    
    /// Returns plans sorted by start date
    var upcomingPlans: [Plan] {
        plans
            .filter { $0.startsAt > Date() }
            .sorted { $0.startsAt < $1.startsAt }
    }
    
    /// Returns plans the user is going to
    func plansIAmGoing(userId: UUID) -> [Plan] {
        upcomingPlans.filter { rsvpStatus[$0.id] == .going || $0.hostUserId == userId }
    }
}
