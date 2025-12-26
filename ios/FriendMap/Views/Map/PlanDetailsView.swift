import SwiftUI
import MapKit

/// Detailed view for a single plan
struct PlanDetailsView: View {
    let plan: Plan
    @EnvironmentObject private var planStore: PlanStore
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var showBlockAlert = false
    @State private var showReportAlert = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var showEditSheet = false
    @State private var showGroupChat = false
    @State private var showAttendeesSheet = false
    
    // Kick/Ban state
    @State private var showKickConfirmation = false
    @State private var userToKick: UUID? = nil
    @State private var isKicking = false
    
    private var rsvpStatus: RSVPStatus {
        planStore.getRSVP(for: plan.id)
    }
    
    private var isHost: Bool {
        plan.hostUserId == sessionStore.currentUser.id
    }
    
    private var attendees: [UUID] {
        planStore.getAttendees(for: plan.id)
    }
    
    private var pendingApprovals: [UUID] {
        planStore.getPendingApprovals(for: plan.id)
    }
    
    private var canSeeDetails: Bool {
        // Host can always see, or if not private, or if approved (going)
        isHost || !plan.isPrivate || rsvpStatus == .going
    }
    
    private var shareURL: URL {
        // Deep link format: ourspot://plan/{id}
        URL(string: "https://ourspot.app/plan/\(plan.id.uuidString)")!
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    // Premium header with gradient
                    premiumHeader
                    
                    // Private badge if applicable
                    if plan.isPrivate {
                        privateEventBadge
                    }
                    
                    // Host info - moved up for trust signal
                    hostSection
                    
                    // Plan details (hidden for private if not approved)
                    if canSeeDetails {
                        detailsSection
                        mapPreviewSection
                    } else {
                        pendingApprovalSection
                    }
                    
                    // RSVP section
                    rsvpSection
                    
                    // Join Chat button (visible to attendees)
                    if rsvpStatus == .going || isHost {
                        joinChatButton
                    }
                    
                    // Attendees section - visible to everyone
                    attendeesSection
                    
                    // Pending approvals section (for hosts only)
                    if isHost && !pendingApprovals.isEmpty {
                        pendingApprovalsSection
                    }
                    
                    // Safety buttons
                    safetySection
                    
                    // Delete button (host only)
                    if isHost {
                        deleteEventSection
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
            .scrollIndicators(.hidden)
            .background(DesignSystem.Colors.background)
            .navigationTitle("Plan Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignSystem.Colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar) // Ensure text is visible if BG is dark

            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    ShareLink(
                        item: shareURL,
                        subject: Text(plan.title),
                        message: Text("Join me at \(plan.title)!")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(item: $selectedAttendee) { selection in
                NavigationStack {
                    PublicProfileView(userId: selection.id)
                }
            }
            .sheet(isPresented: $showEditSheet) {
                EditPlanView(plan: plan)
            }
            .sheet(isPresented: $showGroupChat) {
                NavigationStack {
                    GroupChatView(plan: plan)
                }
            }
            .sheet(isPresented: $showAttendeesSheet) {
                attendeesListSheet
            }
            .alert("Block User", isPresented: $showBlockAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Block", role: .destructive) {
                    Logger.info("Block action triggered for \(plan.hostName)")
                }
            } message: {
                Text("Are you sure you want to block \(plan.hostName)? You won't see their plans anymore.")
            }
            .alert("Report Plan", isPresented: $showReportAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Report", role: .destructive) {
                    Logger.info("Report action triggered for plan \(plan.id)")
                }
            } message: {
                Text("Report this plan for inappropriate content? Our team will review it.")
            }
        }
        .task {
            await loadAttendeeProfiles()
        }
    }
    
    private var premiumHeader: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Activity icon with gradient ring and glow
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#667eea")?.opacity(0.3) ?? .purple.opacity(0.3),
                                .clear
                            ],
                            center: .center,
                            startRadius: 35,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                
                // Gradient ring
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                Color(hex: "#667eea") ?? .purple,
                                Color(hex: "#764ba2") ?? .purple,
                                Color(hex: "#66d3e4") ?? .cyan,
                                Color(hex: "#667eea") ?? .purple
                            ],
                            center: .center
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 80, height: 80)
                
                // Icon background
                Circle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: 70, height: 70)
                
                Text(plan.emoji)
                    .font(.system(size: 36))
            }
            
            // Title with LIVE badge
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text(plan.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                if plan.isHappeningNow {
                    HStack(spacing: 4) {
                        PulsingDot(color: .green)
                        Text("LIVE")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                }
            }
            
            // Location + Time on one line
            HStack(spacing: 8) {
                // Location
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(truncatedLocationName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Text("·")
                    .foregroundColor(.secondary)
                
                // Time
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text(relativeTimeString())
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.green)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(plan.startsAt.formatted(date: .omitted, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // People going section with avatars
            peopleGoingSection
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.md)
    }
    
    /// Truncates location to just venue name + street (no city/country/zip)
    private var truncatedLocationName: String {
        let components = plan.locationName.components(separatedBy: ",")
        if components.count >= 2 {
            // Take first two parts (venue, street)
            let venuePart = components[0].trimmingCharacters(in: .whitespaces)
            let streetPart = components[1].trimmingCharacters(in: .whitespaces)
            return "\(venuePart), \(streetPart)"
        }
        return plan.locationName
    }
    
    private var peopleGoingSection: some View {
        VStack(spacing: 8) {
            // Overlapping avatars
            HStack(spacing: -12) {
                let displayedAttendees = Array(attendees.prefix(4))
                
                ForEach(Array(displayedAttendees.enumerated()), id: \.element) { index, userId in
                    let profile = planStore.getProfile(id: userId)
                    let name = profile?.name ?? (userId == sessionStore.currentUser.id ? sessionStore.currentUser.name : "User")
                    let avatarUrl = profile?.avatarUrl ?? (userId == sessionStore.currentUser.id ? sessionStore.currentUser.avatarUrl : nil)
                    
                    AvatarView(
                        name: name,
                        size: 40,
                        url: URL(string: avatarUrl ?? "")
                    )
                    .overlay(
                        Circle()
                            .stroke(Color(UIColor.systemBackground), lineWidth: 2)
                    )
                    .zIndex(Double(4 - index))
                }
                
                // Overflow indicator
                if attendees.count > 4 {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 40)
                        Text("+\(attendees.count - 4)")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                    .overlay(
                        Circle()
                            .stroke(Color(UIColor.systemBackground), lineWidth: 2)
                    )
                }
            }
            
            // Social proof text
            if attendees.isEmpty {
                Text("Be the first to join \(plan.hostName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if attendees.count == 1 {
                let userId = attendees.first!
                let name = getAttendeeName(for: userId)
                Text("\(name) is going")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                let userId = attendees.first!
                let name = getAttendeeName(for: userId)
                let othersCount = attendees.count - 1
                Text("\(name) and \(othersCount) \(othersCount == 1 ? "other" : "others") are going")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 8)
    }
    
    /// Resolves attendee name - checks current user first, then profile cache
    private func getAttendeeName(for userId: UUID) -> String {
        if userId == sessionStore.currentUser.id {
            return sessionStore.currentUser.name
        }
        return planStore.getProfile(id: userId)?.name ?? "Someone"
    }
    
    private func relativeTimeString() -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(plan.startsAt) {
            return "Today"
        } else if calendar.isDateInTomorrow(plan.startsAt) {
            return "Tomorrow"
        } else {
            return plan.startsAt.formatted(.dateTime.month(.wide).day())
        }
    }
    
    private func calculateDistance() -> String? {
        // Placeholder - could integrate with LocationManager for actual distance
        return nil
    }
    
    private var privateEventBadge: some View {
        HStack {
            Image(systemName: "lock.fill")
            Text("Private Event")
            Spacer()
            if !isHost && rsvpStatus == .pending {
                Text("Awaiting Approval")
                    .font(.caption)
            }
        }
        .font(.caption.weight(.medium))
        .foregroundColor(.orange)
        .padding(DesignSystem.Spacing.sm)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
    
    private var pendingApprovalSection: some View {
        SectionCard {
            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                
                Text("Details Hidden")
                    .font(.headline)
                
                Text("RSVP to request access. The host will approve your request before you can see the exact location and details.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
    
    @State private var showHostProfile = false

    private var hostSection: some View {
        Button {
            showHostProfile = true
        } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                AvatarView(
                    name: plan.hostName,
                    size: 50,
                    url: URL(string: plan.hostAvatar ?? "")
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hosted by")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(plan.hostName)
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .sheet(isPresented: $showHostProfile) {
            NavigationStack {
                PublicProfileView(userId: plan.hostUserId)
            }
        }
    }
    
    private var detailsSection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Event title row
                HStack {
                    Text(plan.emoji)
                        .font(.title)
                    Text(plan.title)
                        .font(.title2.bold())
                }
                
                // Calendar/time
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(DesignSystem.Colors.primaryFallback)
                    Text(plan.startsAt.formatted(date: .abbreviated, time: .shortened))
                }
                .font(.subheadline)
                
                // Location
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(DesignSystem.Colors.secondaryFallback)
                    Text(plan.locationName)
                }
                .font(.subheadline)
                
                Divider()
                    .padding(.vertical, DesignSystem.Spacing.xs)
                
                Text(plan.description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var mapPreviewSection: some View {
        Map {
            Marker(plan.locationName, coordinate: CLLocationCoordinate2D(
                latitude: plan.latitude,
                longitude: plan.longitude
            ))
        }
        .frame(height: 120)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .disabled(true)
    }
    
    private var rsvpSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Private event - not yet approved
            if plan.isPrivate && !isHost && rsvpStatus != .going {
                if rsvpStatus == .pending {
                    // Pending approval state
                    VStack(spacing: 12) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.title)
                            .foregroundColor(.orange)
                        
                        Text("Request Sent!")
                            .font(.headline)
                        
                        Text("The event host will review your request and get back to you soon.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                planStore.setRSVP(planId: plan.id, userId: sessionStore.currentUser.id, status: .none, isPrivate: plan.isPrivate, isHost: isHost)
                                HapticManager.lightTap()
                            }
                        } label: {
                            Text("Cancel Request")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                } else {
                    // Not requested yet - show Request to Join button
                    VStack(spacing: 12) {
                        Text("🔒 Private Event")
                            .font(.headline)
                        
                        Text("This event requires approval from the host to join.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                planStore.setRSVP(planId: plan.id, userId: sessionStore.currentUser.id, status: .pending, isPrivate: plan.isPrivate, isHost: isHost)
                                HapticManager.success()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("Request to Join")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(DesignSystem.CornerRadius.md)
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                }
            } else {
                // Public event OR host OR already approved - show normal RSVP buttons
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach([RSVPStatus.going, RSVPStatus.maybe, RSVPStatus.none], id: \.self) { status in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                planStore.setRSVP(planId: plan.id, userId: sessionStore.currentUser.id, status: status, isPrivate: plan.isPrivate, isHost: isHost)
                                HapticManager.lightTap()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: status.icon)
                                Text(status == .none ? "Can't Go" : status.displayText)
                            }
                            .font(.subheadline.weight(.medium))
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                    .fill(rsvpStatus == status ? statusColor(status) : Color.white.opacity(0.1))
                            )
                            .foregroundColor(rsvpStatus == status ? .white : .primary)
                        }
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    @State private var selectedAttendee: SelectedAttendee?
    
    struct SelectedAttendee: Identifiable {
        let id: UUID
    }
    
    // MARK: - Join Chat Button
    private var joinChatButton: some View {
        Button {
            HapticManager.mediumTap()
            showGroupChat = true
        } label: {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.title3)
                Text("Join The Chat")
                    .font(.headline.weight(.semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "#FF6B35") ?? .orange,
                        Color(hex: "#FFB347") ?? .yellow
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(DesignSystem.CornerRadius.lg)
            .shadow(color: Color.orange.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
    
    // MARK: - Attendees Section (Max 5, clickable)
    private var attendeesSection: some View {
        SectionCard(title: "Attendees (\(attendees.count))") {
            if attendees.isEmpty {
                Text("No attendees yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    // Show max 5 attendees
                    let displayedAttendees = Array(attendees.prefix(5))
                    
                    ForEach(displayedAttendees, id: \.self) { userId in
                        let profile = planStore.getProfile(id: userId)
                        let name = profile?.name ?? sessionStore.currentUser.name
                        let avatarUrl = profile?.avatarUrl ?? sessionStore.currentUser.avatarUrl
                        
                        Button {
                            selectedAttendee = SelectedAttendee(id: userId)
                        } label: {
                            HStack {
                                AvatarView(
                                    name: name,
                                    size: 36,
                                    url: URL(string: avatarUrl ?? "")
                                )
                                Text(name)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("Going")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    // View All button if more than 5 attendees
                    if attendees.count > 5 {
                        Button {
                            showAttendeesSheet = true
                        } label: {
                            HStack {
                                Text("View All \(attendees.count) Attendees")
                                    .font(.subheadline.weight(.medium))
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .foregroundColor(DesignSystem.Colors.primaryFallback)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                        }
                    }
                }
            }
        }
        .onTapGesture {
            if !attendees.isEmpty {
                showAttendeesSheet = true
            }
        }
        .task {
            await loadAttendeeProfiles()
        }
    }
    
    // MARK: - Attendees List Sheet
    private var attendeesListSheet: some View {
        NavigationStack {
            List {
                ForEach(attendees, id: \.self) { userId in
                    let profile = planStore.getProfile(id: userId)
                    let name = profile?.name ?? "User"
                    let avatarUrl = profile?.avatarUrl
                    let isCurrentUser = userId == sessionStore.currentUser.id
                    let isHostUser = userId == plan.hostUserId
                    
                    HStack(spacing: DesignSystem.Spacing.md) {
                        // Tap area for profile navigation
                        Button {
                            showAttendeesSheet = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                selectedAttendee = SelectedAttendee(id: userId)
                            }
                        } label: {
                            HStack(spacing: DesignSystem.Spacing.md) {
                                AvatarView(
                                    name: name,
                                    size: 44,
                                    url: URL(string: avatarUrl ?? "")
                                )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    if isHostUser {
                                        Text("Host")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    } else {
                                        Text("Attending")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Kick Out button (host only, not for self or other host)
                        if isHost && !isCurrentUser && !isHostUser {
                            Button {
                                userToKick = userId
                                showKickConfirmation = true
                            } label: {
                                Text("Kick Out")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.red)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Attendees")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showAttendeesSheet = false
                    }
                }
            }
            .alert("Remove from Event?", isPresented: $showKickConfirmation) {
                Button("Cancel", role: .cancel) {
                    userToKick = nil
                }
                Button("Kick Out", role: .destructive) {
                    Task {
                        await kickSelectedUser()
                    }
                }
            } message: {
                if let userId = userToKick, let profile = planStore.getProfile(id: userId) {
                    Text("\(profile.name) will be permanently removed from this event and cannot rejoin.")
                } else {
                    Text("This user will be permanently removed from this event and cannot rejoin.")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func kickSelectedUser() async {
        guard let userId = userToKick else { return }
        isKicking = true
        
        do {
            try await planStore.kickUser(
                userId,
                from: plan.id,
                by: sessionStore.currentUser.id,
                reason: nil
            )
            
            HapticManager.success()
            Logger.info("✅ User kicked successfully")
        } catch {
            Logger.error("Failed to kick user: \(error.localizedDescription)")
            HapticManager.error()
        }
        
        isKicking = false
        userToKick = nil
    }
    
    private func loadAttendeeProfiles() async {
        // Collect all IDs needed: attendees + host
        var userIds = attendees
        if !userIds.contains(plan.hostUserId) {
            userIds.append(plan.hostUserId)
        }
        
        await planStore.fetchProfiles(for: userIds)
    }
    
    private var pendingApprovalsSection: some View {
        SectionCard(title: "Pending Approvals (\(pendingApprovals.count))") {
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(pendingApprovals, id: \.self) { userId in
                    HStack {
                        AvatarView(
                            name: MockData.hostNames[userId] ?? "User",
                            size: 36,
                            assetName: MockData.hostAvatars[userId]
                        )
                        Text(MockData.hostNames[userId] ?? "User")
                            .font(.subheadline)
                        Spacer()
                        
                        Button {
                            planStore.approveAttendee(planId: plan.id, userId: userId)
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                        }
                        
                        Button {
                            planStore.denyAttendee(planId: plan.id, userId: userId)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.title2)
                        }
                    }
                }
            }
        }
    }
    
    private func statusColor(_ status: RSVPStatus) -> Color {
        switch status {
        case .going: return .green
        case .maybe: return .orange
        case .none: return .gray
        case .pending: return .orange
        case .invited: return .purple
        }
    }
    
    private var safetySection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("Safety")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: DesignSystem.Spacing.sm) {
                SecondaryButton("Block", icon: "hand.raised.fill", isDestructive: true) {
                    showBlockAlert = true
                }
                
                SecondaryButton("Report", icon: "flag.fill", isDestructive: true) {
                    showReportAlert = true
                }
            }
        }
    }
    
    private var deleteEventSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Divider()
                .padding(.top, DesignSystem.Spacing.md)
            
            // Edit button (blue)
            Button {
                showEditSheet = true
            } label: {
                HStack {
                    Image(systemName: "pencil")
                    Text("Edit Event")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(DesignSystem.CornerRadius.md)
            }
            
            // Delete button (red)
            Button {
                showDeleteAlert = true
            } label: {
                HStack {
                    if isDeleting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "trash.fill")
                    }
                    Text("Delete Event")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(DesignSystem.CornerRadius.md)
            }
            .disabled(isDeleting)
            
            Text("This will permanently delete the event for everyone.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .alert("Delete Event?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteEvent()
            }
        } message: {
            Text("This action cannot be undone. All RSVPs and messages will also be deleted.")
        }
    }
    
    private func deleteEvent() {
        isDeleting = true
        Task {
            do {
                try await planStore.deletePlan(plan)
                HapticManager.success()
                dismiss()
            } catch {
                Logger.error("Failed to delete event: \(error.localizedDescription)")
                HapticManager.error()
            }
            isDeleting = false
        }
    }
}

#Preview {
    PlanDetailsView(plan: MockData.samplePlans[0])
        .environmentObject(PlanStore())
        .environmentObject(SessionStore())
}
