import Foundation
import SwiftUI

/// Manages plans and RSVP status
@MainActor
final class PlanStore: ObservableObject {
    @Published var plans: [Plan] = []
    @Published var rsvpStatus: [UUID: RSVPStatus] = [:]
    
    // New Filtering Logic
    @Published var dateFilter: DateFilterOption = .allFuture
    @Published var customDate: Date? // For when dateFilter is .custom
    @Published var activityFilter: ActivityType? // Single selection or nil for all
    
    /// Tracks attendees per plan: planId -> set of userIds
    @Published var attendees: [UUID: Set<UUID>] = [:]
    /// Tracks pending approval requests for private plans
    @Published var pendingApprovals: [UUID: Set<UUID>] = [:]
    /// Plan to navigate to on Map tab (cross-tab navigation)
    @Published var planToShowOnMap: Plan?
    
    @Published var profiles: [UUID: UserProfile] = [:]
    
    private let planService = PlanService()
    private let userService = UserService()
    
    init() {
        // Initialize with empty plans - loadPlans() should be called by the view
    }
    
    func loadPlans(currentUserId: UUID) async {
        do {
            let fetchedPlans = try await planService.fetchPlans()
            self.plans = fetchedPlans
            
            // Fetch RSVPs and attendees from backend
            let planIds = fetchedPlans.map { $0.id }
            
            // 1. Fetch current user's RSVP status for all plans
            let myRSVPs = try await planService.fetchMyRSVPs(userId: currentUserId)
            
            // 2. Fetch all attendees (going users) for all plans
            let allAttendees = try await planService.fetchAttendeesForPlans(planIds: planIds)
            
            // 3. Apply the fetched data
            self.rsvpStatus = myRSVPs
            self.attendees = allAttendees
            
            // Debug: log invited RSVPs
            let invitedCount = myRSVPs.values.filter { $0 == .invited }.count
            Logger.info("📋 RSVPs loaded: \(myRSVPs.count) total, \(invitedCount) invited")
            
            // Ensure hosts are marked as going for their own events
            for plan in fetchedPlans {
                if plan.hostUserId == currentUserId {
                    rsvpStatus[plan.id] = .going
                    attendees[plan.id] = (attendees[plan.id] ?? []).union([currentUserId])
                }
            }
            
            Logger.info("Loaded \(plans.count) plans with \(myRSVPs.count) RSVPs from Supabase")
            
            // Trigger notifications for invites
            checkForNewInvites()
            
        } catch {
            Logger.error("Failed to fetch plans: \(error.localizedDescription)")
            // Fallback to mock data if offline or error
            if plans.isEmpty && Config.supabase == nil {
                self.plans = MockData.samplePlans
                Logger.info("Loaded mock plans (offline fallback)")
            }
        }
    }
    
    private func checkForNewInvites() {
        let invites = invitedPlans
        for plan in invites {
            // Check if notification already exists for this plan
            let hasNotification = NotificationCenter.shared.notifications.contains {
                $0.type == .eventInvite && $0.relatedPlanId == plan.id
            }
            
            if !hasNotification {
                let notification = AppNotification.eventInvite(
                    from: plan.hostName,
                    eventName: plan.title,
                    planId: plan.id,
                    userId: plan.hostUserId
                )
                NotificationCenter.shared.addNotification(notification)
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
        await createPlanWithId(
            id: UUID(),
            title: title,
            description: description,
            startsAt: startsAt,
            latitude: latitude,
            longitude: longitude,
            emoji: emoji,
            activityType: activityType,
            addressText: addressText,
            hostUserId: hostUserId,
            hostName: hostName,
            hostAvatar: hostAvatar,
            isPrivate: isPrivate
        )
    }
    
    /// Creates a new plan with a specific ID (useful when you need to reference the plan ID immediately)
    func createPlanWithId(
        id: UUID,
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
            id: id,
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
    
    /// Deletes a plan from local storage and Supabase
    func deletePlan(_ plan: Plan) async throws {
        // Optimistic removal
        plans.removeAll { $0.id == plan.id }
        rsvpStatus.removeValue(forKey: plan.id)
        attendees.removeValue(forKey: plan.id)
        pendingApprovals.removeValue(forKey: plan.id)
        
        // Delete from Supabase
        try await planService.deletePlan(plan.id)
        Logger.info("Deleted plan: \(plan.title)")
    }
    
    /// Updates an existing plan
    func updatePlan(_ updatedPlan: Plan) async throws {
        // Update local state
        if let index = plans.firstIndex(where: { $0.id == updatedPlan.id }) {
            plans[index] = updatedPlan
        }
        
        // Update in Supabase
        try await planService.updatePlan(updatedPlan)
    }
    
    /// Kicks a user from an event and permanently bans them
    func kickUser(_ userId: UUID, from planId: UUID, by hostId: UUID, reason: String? = nil) async throws {
        // Call service to create ban and remove RSVP
        try await planService.kickUser(userId, from: planId, by: hostId, reason: reason)
        
        // Update local state immediately
        removeAttendee(planId: planId, userId: userId)
        rsvpStatus[planId] = nil
        
        Logger.info("✅ User \(userId) kicked from plan \(planId)")
    }
    
    /// Invites users to a plan (creates RSVP records and sends notifications)
    func inviteUsers(to plan: Plan, users: [FriendSearchResult], currentUser: UserProfile) async {
        Logger.info("🔔 inviteUsers called for plan '\(plan.title)' with \(users.count) users")
        
        for user in users {
            Logger.info("🔔 Processing invite for user: \(user.name) (id: \(user.id))")
            do {
                // 1. Create RSVP record with .invited status
                Logger.info("🔔 Inserting RSVP for user \(user.id) with status .invited")
                try await planService.updateRSVP(planId: plan.id, userId: user.id, status: .invited)
                Logger.info("✅ RSVP inserted successfully for user \(user.id)")
                
                // 2. Send notification
                let notification = AppNotification.eventInvite(
                    from: currentUser.name,
                    eventName: plan.title,
                    planId: plan.id,
                    userId: currentUser.id
                )
                
                Logger.info("🔔 Sending notification to user \(user.id)")
                await NotificationCenter.shared.sendNotificationToUser(
                    userId: user.id,
                    notification: notification
                )
                Logger.info("✅ Notification sent to user \(user.id)")
                
                Logger.info("✅ Invited user \(user.name) to plan \(plan.title)")
            } catch {
                Logger.error("❌ Failed to invite user \(user.name): \(error.localizedDescription)")
            }
        }
        Logger.info("🔔 inviteUsers completed for plan '\(plan.title)'")
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
        case .invited:
            // Treat invited like "none" but with a prompt to go
            // If they toggle it, they are accepting the invite
            next = .going
            addAttendee(planId: planId, userId: userId)
        }
        rsvpStatus[planId] = next
        Logger.info("RSVP for plan \(planId): \(next.displayText)")
    }
    
    /// Sets a specific RSVP status for a plan
    func setRSVP(planId: UUID, userId: UUID, status: RSVPStatus, isPrivate: Bool, isHost: Bool) {
        let currentStatus = rsvpStatus[planId] ?? RSVPStatus.none
        
        // Handle the transition based on what was selected
        switch status {
        case .going:
            // For private plans, non-hosts go to pending
            if isPrivate && !isHost {
                addPendingApproval(planId: planId, userId: userId)
                rsvpStatus[planId] = .pending
            } else {
                // Remove from pending if was pending
                if currentStatus == .pending {
                    removePendingApproval(planId: planId, userId: userId)
                }
                addAttendee(planId: planId, userId: userId)
                rsvpStatus[planId] = .going
            }
        case .maybe:
            // Remove from attendees if was going
            if currentStatus == .going {
                removeAttendee(planId: planId, userId: userId)
            }
            if currentStatus == .pending {
                removePendingApproval(planId: planId, userId: userId)
            }
            rsvpStatus[planId] = .maybe
        case .none:
            // Remove from everything
            if currentStatus == .going {
                removeAttendee(planId: planId, userId: userId)
            }
            if currentStatus == .pending {
                removePendingApproval(planId: planId, userId: userId)
            }
            rsvpStatus[planId] = .none
        case .pending:
            // Handled in going case
            break
        case .invited:
            // Reset to invited? Rare but handle it safely
            // Remove from attendees if was going
            if currentStatus == .going {
                removeAttendee(planId: planId, userId: userId)
            }
            if currentStatus == .pending {
                removePendingApproval(planId: planId, userId: userId)
            }
            rsvpStatus[planId] = .invited
        }
        
        // Sync to backend
        Task {
            do {
                try await planService.updateRSVP(planId: planId, userId: userId, status: rsvpStatus[planId] ?? .none)
            } catch {
                Logger.error("Failed to sync RSVP to backend: \(error.localizedDescription)")
            }
        }
        
        Logger.info("RSVP set for plan \(planId): \(status.displayText)")
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
        if let activity = activityFilter {
            result = result.filter { $0.activityType == activity }
        }
        
        // Filter by date
        let calendar = Calendar.current
        let now = Date()
        
        switch dateFilter {
        case .allFuture:
            // Show all future events (already filtered by upcomingPlans)
            break
        case .today:
            result = result.filter { calendar.isDateInToday($0.startsAt) }
        case .tomorrow:
            result = result.filter { calendar.isDateInTomorrow($0.startsAt) }
        case .nextWeek:
            // Next 7 days from now
            if let weekEnd = calendar.date(byAdding: .day, value: 7, to: now) {
                result = result.filter { $0.startsAt <= weekEnd }
            }
        case .nextMonth:
            // Next 30 days from now
            if let monthEnd = calendar.date(byAdding: .day, value: 30, to: now) {
                result = result.filter { $0.startsAt <= monthEnd }
            }
        case .custom:
            if let targetDate = customDate {
                result = result.filter { calendar.isDate($0.startsAt, inSameDayAs: targetDate) }
            }
        }
        
        return result
    }
    
    /// Plans the user has been invited to (status == .invited)
    var invitedPlans: [Plan] {
        plans.filter { plan in
            getRSVP(for: plan.id) == .invited && plan.startsAt > Date()
        }
        .sorted { $0.startsAt < $1.startsAt }
    }
    
    /// Count of pending invitations for badge
    var invitationCount: Int {
        invitedPlans.count
    }

    /// Helper to test invitations (REMOVE IN PROD)
    func testInvite() {
        if let firstPlan = plans.first {
            rsvpStatus[firstPlan.id] = .invited
            checkForNewInvites()
        }
    }
    
    // MARK: - Plan Sections
    
    /// Plans I'm going to or maybe attending (not hosting)
    func myPlans(userId: UUID) -> [Plan] {
        upcomingPlans.filter { plan in
            plan.hostUserId != userId &&
            (rsvpStatus[plan.id] == .going || rsvpStatus[plan.id] == .maybe)
        }
    }
    
    // MARK: - Event Chats
    
    @Published var eventChats: [EventChat] = []
    private var chatService = ChatService()
    
    func loadEventChats(currentUserId: UUID) async {
        // Ensure plans are loaded first? Or just use what we have?
        // Ideally we should have plans loaded. But let's assume views call loadPlans first or independently.
        
        do {
            let summaries = try await chatService.fetchChatSummaries(currentUserId: currentUserId)
            
            // Map summaries to EventChat objects
            // We need to match summaries with Plans. 
            // If plans are not loaded, we might miss some info.
            // But we can filter by plans we have in memory.
            
            var newChats: [EventChat] = []
            
            for summary in summaries {
                if let plan = plans.first(where: { $0.id == summary.plan_id }) {
                    let chat = EventChat(
                        plan: plan,
                        unreadCount: summary.unread_count,
                        lastMessageAt: summary.last_message_at,
                        lastMessagePreview: summary.last_message_content
                    )
                    newChats.append(chat)
                }
            }
            
            // Sort them
            newChats.sort(by: <)
            
            self.eventChats = newChats
            
        } catch {
            Logger.error("Failed to load event chats: \(error.localizedDescription)")
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
    // MARK: - Profile Management
    
    func fetchProfiles(for userIds: [UUID]) async {
        // Filter out IDs we already have
        let missingIds = userIds.filter { profiles[$0] == nil }
        guard !missingIds.isEmpty else { return }
        
        do {
            let fetchedProfiles = try await userService.fetchProfiles(userIds: missingIds)
            for profile in fetchedProfiles {
                profiles[profile.id] = profile
            }
        } catch {
            Logger.error("Failed to batch fetch profiles: \(error.localizedDescription)")
        }
    }
    
    func getProfile(id: UUID) -> UserProfile? {
        profiles[id]
    }
}

/// Date filter options for map
enum DateFilterOption: String, CaseIterable, Identifiable {
    case allFuture = "All Future"
    case today = "Today"
    case tomorrow = "Tomorrow"
    case nextWeek = "Next Week"
    case nextMonth = "Next Month"
    case custom = "Custom Date"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .allFuture: return "calendar"
        case .today: return "sun.max.fill"
        case .tomorrow: return "sunrise.fill"
        case .nextWeek: return "calendar.badge.clock"
        case .nextMonth: return "calendar"
        case .custom: return "calendar.badge.plus"
        }
    }
}

// EventChat is defined in Models/EventChat.swift
