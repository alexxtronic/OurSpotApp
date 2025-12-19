import Foundation
import SwiftUI

/// Manages plans and RSVP status
@MainActor
final class PlanStore: ObservableObject {
    @Published var plans: [Plan] = []
    @Published var rsvpStatus: [UUID: RSVPStatus] = [:]
    @Published var filterActivityTypes: Set<ActivityType> = []
    @Published var filterDateRange: DateFilterRange = .all
    @Published var filterSpecificDate: Date?
    
    /// Tracks attendees per plan: planId -> set of userIds
    @Published var attendees: [UUID: Set<UUID>] = [:]
    /// Tracks pending approval requests for private plans
    @Published var pendingApprovals: [UUID: Set<UUID>] = [:]
    
    private let planService = PlanService()
    
    init() {
        // Initialize with empty plans - loadPlans() should be called by the view
    }
    
    func loadPlans() async {
        do {
            let fetchedPlans = try await planService.fetchPlans()
            self.plans = fetchedPlans
            Logger.info("Loaded \(plans.count) plans from Supabase")
        } catch {
            Logger.error("Failed to fetch plans: \(error.localizedDescription)")
            // Fallback to mock data if offline or error
            if plans.isEmpty && Config.supabase == nil {
                self.plans = MockData.samplePlans
                Logger.info("Loaded mock plans (offline fallback)")
            }
        }
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
        hostUserId: UUID,
        hostName: String,
        hostAvatar: String?,
        isPrivate: Bool = false
    ) async {
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
            addressText: addressText,
            isPrivate: isPrivate,
            hostName: hostName,
            hostAvatar: hostAvatar
        )
        
        // Optimistic update
        plans.append(newPlan)
        rsvpStatus[newPlan.id] = .going
        attendees[newPlan.id] = [hostUserId] // Host is automatically attending
        
        do {
            try await planService.createPlan(newPlan)
            Logger.info("Created new plan: \(title)")
        } catch {
            Logger.error("Failed to create plan in Supabase: \(error.localizedDescription)")
            // Revert on failure? For now just log
        }
    }
    
    /// Toggles RSVP status for a plan
    func toggleRSVP(planId: UUID, userId: UUID) {
        let current = rsvpStatus[planId] ?? RSVPStatus.none
        let plan = plans.first { $0.id == planId }
        
        let next: RSVPStatus
        switch current {
        case .none:
            // For private plans, add to pending approvals instead of direct going
            if plan?.isPrivate == true && plan?.hostUserId != userId {
                addPendingApproval(planId: planId, userId: userId)
                next = .pending
            } else {
                next = .going
                addAttendee(planId: planId, userId: userId)
            }
        case .going:
            next = .maybe
            removeAttendee(planId: planId, userId: userId)
        case .maybe:
            next = RSVPStatus.none
        case .pending:
            next = RSVPStatus.none
            removePendingApproval(planId: planId, userId: userId)
        }
        rsvpStatus[planId] = next
        Logger.info("RSVP for plan \(planId): \(next.displayText)")
    }
    
    /// Approves a pending request for a private plan
    func approveAttendee(planId: UUID, userId: UUID) {
        removePendingApproval(planId: planId, userId: userId)
        addAttendee(planId: planId, userId: userId)
        // Update their RSVP status to going
        // Note: In a real app this would notify the user
        Logger.info("Approved user \(userId) for plan \(planId)")
    }
    
    /// Denies a pending request for a private plan
    func denyAttendee(planId: UUID, userId: UUID) {
        removePendingApproval(planId: planId, userId: userId)
        Logger.info("Denied user \(userId) for plan \(planId)")
    }
    
    private func addAttendee(planId: UUID, userId: UUID) {
        if attendees[planId] == nil {
            attendees[planId] = []
        }
        attendees[planId]?.insert(userId)
    }
    
    private func removeAttendee(planId: UUID, userId: UUID) {
        attendees[planId]?.remove(userId)
    }
    
    private func addPendingApproval(planId: UUID, userId: UUID) {
        if pendingApprovals[planId] == nil {
            pendingApprovals[planId] = []
        }
        pendingApprovals[planId]?.insert(userId)
    }
    
    private func removePendingApproval(planId: UUID, userId: UUID) {
        pendingApprovals[planId]?.remove(userId)
    }
    
    /// Gets attendees for a plan
    func getAttendees(for planId: UUID) -> [UUID] {
        Array(attendees[planId] ?? [])
    }
    
    /// Gets pending approvals for a plan
    func getPendingApprovals(for planId: UUID) -> [UUID] {
        Array(pendingApprovals[planId] ?? [])
    }
    
    /// Gets RSVP status for a specific plan
    func getRSVP(for planId: UUID) -> RSVPStatus {
        return rsvpStatus[planId] ?? RSVPStatus.none
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
        
        // Filter by specific date if set
        if let specificDate = filterSpecificDate {
            let calendar = Calendar.current
            result = result.filter { calendar.isDate($0.startsAt, inSameDayAs: specificDate) }
        } else {
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
            (rsvpStatus[plan.id] == nil || rsvpStatus[plan.id] == RSVPStatus.none)
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
