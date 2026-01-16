import SwiftUI

/// Plans tab showing plans organized by Hosting/Attending with date filter
struct PlansView: View {
    @EnvironmentObject private var planStore: PlanStore
    @EnvironmentObject private var sessionStore: SessionStore
    @Binding var selectedTab: ContentView.Tab
    
    @State private var showCreatePlan = false
    @State private var selectedPlan: Plan?
    @State private var showDatePicker = false
    @State private var filterDate: Date? = nil
    
    // Section collapse state - all expanded by default
    @State private var expandedSections: Set<PlanSection> = Set(PlanSection.allCases)
    
    enum PlanSection: String, CaseIterable {
        case hosting = "Hosting"
        case attending = "Attending"
        case nearby = "Events Nearby"
        
        var icon: String {
            switch self {
            case .hosting: return "star.fill"
            case .attending: return "calendar.badge.checkmark"
            case .nearby: return "mappin.and.ellipse"
            }
        }
        
        var iconColor: Color {
            switch self {
            case .hosting: return .orange
            case .attending: return .green
            case .nearby: return .blue
            }
        }
    }
    
    // MARK: - Plan Groupings
    
    private var hostingPlans: [Plan] {
        let tenHoursAgo = Date().addingTimeInterval(-10 * 60 * 60)
        var plans = planStore.plans
            .filter { $0.hostUserId == sessionStore.currentUser.id && $0.startsAt > tenHoursAgo }
        
        // Apply date filter if set
        if let filterDate = filterDate {
            let calendar = Calendar.current
            plans = plans.filter { calendar.isDate($0.startsAt, inSameDayAs: filterDate) }
        }
        
        return plans.sorted { $0.startsAt < $1.startsAt }
    }
    
    private var attendingPlans: [Plan] {
        let tenHoursAgo = Date().addingTimeInterval(-10 * 60 * 60)
        var plans = planStore.plans
            .filter { plan in
                plan.hostUserId != sessionStore.currentUser.id &&
                plan.startsAt > tenHoursAgo &&
                (planStore.getRSVP(for: plan.id) == .going || planStore.getRSVP(for: plan.id) == .maybe)
            }
        
        // Apply date filter if set
        if let filterDate = filterDate {
            let calendar = Calendar.current
            plans = plans.filter { calendar.isDate($0.startsAt, inSameDayAs: filterDate) }
        }
        
        return plans.sorted { $0.startsAt < $1.startsAt }
    }
    
    private var nearbyPlans: [Plan] {
        // Use filteredPlans from store which already applies active filters
        var plans = planStore.filteredPlans
            .filter { plan in
                // Exclude plans I'm hosting or attending
                plan.hostUserId != sessionStore.currentUser.id &&
                planStore.getRSVP(for: plan.id) == .none
            }
        
        return plans.sorted { $0.startsAt < $1.startsAt }
    }
    
    private var hasAnyPlans: Bool {
        !hostingPlans.isEmpty || !attendingPlans.isEmpty || !nearbyPlans.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.sm, pinnedViews: []) {
                    // 0. Invitations (Highest Priority)
                    if !planStore.invitedPlans.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("INVITATIONS (\(planStore.invitedPlans.count))")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                            
                            ForEach(planStore.invitedPlans) { plan in
                                InvitationRow(plan: plan, planStore: planStore)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    
                    // Hosting - tap navigates to Map with plan details
                    if !hostingPlans.isEmpty {
                        CollapsiblePlanSection(
                            section: .hosting,
                            plans: hostingPlans,
                            isExpanded: expandedSections.contains(.hosting),
                            planStore: planStore,
                            onToggle: { toggleSection(.hosting) },
                            onTapPlan: { plan in
                                navigateToMapWithPlan(plan)
                            }
                        )
                    }
                    

                    
                    // Attending - tap shows details sheet
                    if !attendingPlans.isEmpty {
                        CollapsiblePlanSection(
                            section: .attending,
                            plans: attendingPlans,
                            isExpanded: expandedSections.contains(.attending),
                            planStore: planStore,
                            onToggle: { toggleSection(.attending) },
                            onTapPlan: { plan in
                                navigateToMapWithPlan(plan)
                            }
                        )
                    }
                    
                    // Events Nearby - tap navigates to Map
                    if !nearbyPlans.isEmpty {
                        CollapsiblePlanSection(
                            section: .nearby,
                            plans: nearbyPlans,
                            isExpanded: expandedSections.contains(.nearby),
                            planStore: planStore,
                            onToggle: { toggleSection(.nearby) },
                            onTapPlan: { plan in
                                navigateToMapWithPlan(plan)
                            }
                        )
                    }
                    
                    // Empty state
                    if !hasAnyPlans && planStore.invitedPlans.isEmpty {
                        EmptyStateView(
                            icon: "calendar.badge.plus",
                            title: filterDate != nil ? "No Plans on This Day" : "No Upcoming Plans",
                            message: filterDate != nil ? "Try selecting a different date" : "Create a plan to hang out with friends!",
                            actionTitle: filterDate != nil ? "Clear Filter" : "Create Plan"
                        ) {
                            if filterDate != nil {
                                filterDate = nil
                            } else {
                                showCreatePlan = true
                            }
                        }
                        .padding(.top, DesignSystem.Spacing.xxl)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.top, DesignSystem.Spacing.sm)
                .padding(.bottom, DesignSystem.Spacing.xxl)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.top, DesignSystem.Spacing.sm)
                .padding(.bottom, DesignSystem.Spacing.xxl)
            }
            .refreshable {
                await planStore.loadPlans(currentUserId: sessionStore.currentUser.id)
            }
            .navigationTitle("Plans")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        // Date filter button
                        Button {
                            showDatePicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: filterDate != nil ? "calendar.badge.checkmark" : "calendar")
                                    .font(.body)
                                if let date = filterDate {
                                    Text(date.formatted(.dateTime.month(.abbreviated).day()))
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(filterDate != nil ? DesignSystem.Colors.primaryFallback : .primary)
                        }
                        
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.mediumTap()
                        showCreatePlan = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(DesignSystem.Gradients.primary)
                    }
                }
            }
            .sheet(isPresented: $showCreatePlan) {
                CreatePlanView()
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(selectedDate: $filterDate, onClear: { filterDate = nil })
                    .presentationDetents([.medium])
            }
        }
    }
    
    private func toggleSection(_ section: PlanSection) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if expandedSections.contains(section) {
                expandedSections.remove(section)
            } else {
                expandedSections.insert(section)
            }
        }
    }
    
    /// Navigate to Map tab and show plan details
    private func navigateToMapWithPlan(_ plan: Plan) {
        planStore.planToShowOnMap = plan
        selectedTab = .map
    }
}

// MARK: - Invitation Row

struct InvitationRow: View {
    let plan: Plan
    @ObservedObject var planStore: PlanStore
    @EnvironmentObject var sessionStore: SessionStore
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Text(plan.emoji)
                    .font(.title2)
            }
            
            // Text Info
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(plan.startsAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 12) {
                // Decline (X)
                Button {
                    planStore.setRSVP(
                        planId: plan.id,
                        userId: sessionStore.currentUser.id,
                        status: .none,
                        isPrivate: plan.isPrivate,
                        isHost: false
                    )
                    HapticManager.lightTap()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
                
                // Accept (Check)
                Button {
                    planStore.setRSVP(
                        planId: plan.id,
                        userId: sessionStore.currentUser.id,
                        status: .going,
                        isPrivate: plan.isPrivate,
                        isHost: false
                    )
                    HapticManager.success()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(color: .blue.opacity(0.3), radius: 4, y: 2)
                }
            }
        }
        .padding(12)
        // Darker background for better visibility in dark mode
        .background(Color(.systemGray6))
        .cornerRadius(16)
        // Subtle shadow
        .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    @Binding var selectedDate: Date?
    let onClear: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var pickerDate = Date()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                DatePicker(
                    "Select Date",
                    selection: $pickerDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                
                Spacer()
            }
            .navigationTitle("Filter by Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        onClear()
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        selectedDate = pickerDate
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            pickerDate = selectedDate ?? Date()
        }
    }
}

// MARK: - Collapsible Section

struct CollapsiblePlanSection: View {
    let section: PlansView.PlanSection
    let plans: [Plan]
    let isExpanded: Bool
    let planStore: PlanStore
    let onToggle: () -> Void
    let onTapPlan: (Plan) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: onToggle) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: section.icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(section.iconColor)
                        .frame(width: 24)
                    
                    Text(section.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(plans.count)")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(10)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.vertical, DesignSystem.Spacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Content
            if isExpanded {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(plans) { plan in
                        Button {
                            HapticManager.lightTap()
                            onTapPlan(plan)
                        } label: {
                            CompactPlanRow(plan: plan, planStore: planStore)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Compact Plan Row

struct CompactPlanRow: View {
    let plan: Plan
    @ObservedObject var planStore: PlanStore
    @EnvironmentObject private var sessionStore: SessionStore
    
    @State private var isPressed = false
    
    private var rsvpStatus: RSVPStatus {
        planStore.getRSVP(for: plan.id)
    }
    
    private var attendees: [UUID] {
        planStore.getAttendees(for: plan.id)
    }
    
    private var attendeeCount: Int {
        attendees.count
    }
    
    private var isHost: Bool {
        plan.hostUserId == sessionStore.currentUser.id
    }
    
    /// Truncates location to just venue + street
    private var shortLocation: String {
        let components = plan.locationName.components(separatedBy: ",")
        return components.first?.trimmingCharacters(in: .whitespaces) ?? plan.locationName
    }
    
    /// Formats date compactly
    private var dateString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(plan.startsAt) {
            return "Today"
        } else if calendar.isDateInTomorrow(plan.startsAt) {
            return "Tomorrow"
        } else {
            return plan.startsAt.formatted(.dateTime.month(.abbreviated).day())
        }
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Emoji
            ZStack {
                Circle()
                    .fill(DesignSystem.Gradients.primary.opacity(0.12))
                    .frame(width: 40, height: 40)
                Text(plan.emoji)
                    .font(.title3)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(plan.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    
                    if plan.isHappeningNow {
                        HStack(spacing: 3) {
                            PulsingDot(color: .green)
                            Text("LIVE")
                                .font(.caption2.bold())
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(4)
                    }
                }
                
                // Compact info row
                HStack(spacing: 8) {
                    // Date
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(dateString)
                    }
                    .foregroundColor(.secondary)
                    
                    Text("·")
                        .foregroundColor(.secondary)
                    
                    // Time
                    HStack(spacing: 3) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                            Text(plan.startsAt.formatted(date: .omitted, time: .shortened))
                    }
                    .foregroundColor(.secondary)
                }
                .font(.caption)
                
                // Attendees (Moved to new line for better visibility)
                if !attendees.isEmpty {
                    HStack(spacing: -8) {
                        ForEach(Array(attendees.prefix(3).enumerated()), id: \.element) { index, userId in
                            let profile = planStore.getProfile(id: userId)
                            let avatarUrl = profile?.avatarUrl ?? (userId == sessionStore.currentUser.id ? sessionStore.currentUser.avatarUrl : nil)
                            
                            AvatarView(
                                name: "User",
                                size: 24,
                                url: URL(string: avatarUrl ?? "")
                            )
                            .overlay(
                                Circle()
                                    .stroke(DesignSystem.Colors.secondaryBackground, lineWidth: 2)
                            )
                            .zIndex(Double(3 - index))
                        }
                        
                        if attendees.count > 3 {
                            Text("+\(attendees.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.leading, 12)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // RSVP indicator
            if rsvpStatus != .none && !isHost {
                Text(rsvpStatus.displayText)
                    .font(.caption.weight(.medium))
                    .foregroundColor(rsvpStatus == .going ? .green : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (rsvpStatus == .going ? Color.green : Color.orange).opacity(0.12)
                    )
                    .cornerRadius(6)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.secondaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.md)
        .contentShape(Rectangle())
        .task {
            // Load profiles for visible attendees
            if !attendees.isEmpty {
                await planStore.fetchProfiles(for: Array(attendees.prefix(3)))
            }
        }
    }
}

#Preview {
    PlansView(selectedTab: .constant(.plans))
        .environmentObject(PlanStore())
        .environmentObject(SessionStore())
}
