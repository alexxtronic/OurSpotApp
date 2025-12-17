import Foundation
import SwiftUI

/// Manages plans and RSVP status
@MainActor
final class PlanStore: ObservableObject {
    @Published var plans: [Plan] = []
    @Published var rsvpStatus: [UUID: RSVPStatus] = [:]
    @Published var filterActivityTypes: Set<ActivityType> = []
    @Published var filterDateRange: DateFilterRange = .all
    
    init() {
        // Load mock plans
        self.plans = MockData.samplePlans
        Logger.info("Loaded \(plans.count) mock plans")
    }
    
    /// Creates a new plan and adds it to the store
    func createPlan(
        title: String,
        description: String,
        startsAt: Date,
        latitude: Double,
        longitude: Double,
        emoji: String,
        activityType: ActivityType,
        addressText: String,
        hostUserId: UUID
    ) {
        let newPlan = Plan(
            id: UUID(),
            hostUserId: hostUserId,
            title: title,
            description: description,
            startsAt: startsAt,
            latitude: latitude,
            longitude: longitude,
            emoji: emoji,
            activityType: activityType,
            addressText: addressText
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
    
    /// Returns filtered plans for map display
    var filteredPlans: [Plan] {
        var result = upcomingPlans
        
        // Filter by activity type if any selected
        if !filterActivityTypes.isEmpty {
            result = result.filter { filterActivityTypes.contains($0.activityType) }
        }
        
        // Filter by date range
        let calendar = Calendar.current
        let now = Date()
        switch filterDateRange {
        case .today:
            result = result.filter { calendar.isDateInToday($0.startsAt) }
        case .thisWeek:
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: now)!
            result = result.filter { $0.startsAt <= weekEnd }
        case .thisMonth:
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: now)!
            result = result.filter { $0.startsAt <= monthEnd }
        case .all:
            break
        }
        
        return result
    }
    
    // MARK: - Plan Sections
    
    /// Plans I'm going to or maybe attending (not hosting)
    func myPlans(userId: UUID) -> [Plan] {
        upcomingPlans.filter { plan in
            plan.hostUserId != userId &&
            (rsvpStatus[plan.id] == .going || rsvpStatus[plan.id] == .maybe)
        }
    }
    
    /// Plans I'm hosting
    func hostedPlans(userId: UUID) -> [Plan] {
        upcomingPlans.filter { $0.hostUserId == userId }
    }
    
    /// Friend plans I haven't RSVP'd to
    func friendPlans(userId: UUID) -> [Plan] {
        upcomingPlans.filter { plan in
            plan.hostUserId != userId &&
            (rsvpStatus[plan.id] == nil || rsvpStatus[plan.id] == .none)
        }
    }
}

/// Date filter options for map
enum DateFilterRange: String, CaseIterable, Identifiable {
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case all = "All"
    
    var id: String { rawValue }
}
