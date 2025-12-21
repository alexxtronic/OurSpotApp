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
    @State private var attendeeProfiles: [UUID: UserProfile] = [:]
    
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
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // Private badge if applicable
                    if plan.isPrivate {
                        privateEventBadge
                    }
                    
                    // Host info
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
                    
                    // Attendees section (for hosts)
                    if isHost {
                        attendeesSection
                        
                        if !pendingApprovals.isEmpty {
                            pendingApprovalsSection
                        }
                    }
                    
                    // Safety buttons
                    safetySection
                    
                    // Delete button (host only)
                    if isHost {
                        deleteEventSection
                    }
                }
                .padding(DesignSystem.Spacing.md)
            }
            .navigationTitle("Plan Details")
            .navigationBarTitleDisplayMode(.inline)
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
                }
            }
            .sheet(item: $selectedAttendee) { selection in
                PublicProfileView(userId: selection.id)
            }
            .sheet(isPresented: $showEditSheet) {
                EditPlanView(plan: plan)
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
                    size: 56,
                    url: URL(string: plan.hostAvatar ?? "")
                )
                
                VStack(alignment: .leading, spacing: 4) {
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
            .padding()
            .background(DesignSystem.Colors.secondaryBackground)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .shadowStyle(DesignSystem.Shadows.small)
        }
        .sheet(isPresented: $showHostProfile) {
            PublicProfileView(userId: plan.hostUserId)
        }
    }
    
    private var detailsSection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Text(plan.emoji)
                        .font(.title)
                    Text(plan.title)
                        .font(.title2.bold())
                }
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(DesignSystem.Colors.primaryFallback)
                    Text(plan.startsAt.formatted(date: .abbreviated, time: .shortened))
                }
                .font(.subheadline)
                
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
        .frame(height: 150)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .disabled(true)
    }
    
    private var rsvpSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("Your Response")
                .font(.headline)
            
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Only show Going/Maybe/None, not Pending in the picker
                ForEach([RSVPStatus.none, RSVPStatus.going, RSVPStatus.maybe], id: \.self) { status in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            // Set the specific status that was tapped
                            planStore.setRSVP(planId: plan.id, userId: sessionStore.currentUser.id, status: status, isPrivate: plan.isPrivate, isHost: isHost)
                            HapticManager.lightTap()
                        }
                    } label: {
                        HStack {
                            Image(systemName: status.icon)
                            Text(status.displayText)
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(rsvpStatus == status ? statusColor(status) : Color.gray.opacity(0.1))
                        .foregroundColor(rsvpStatus == status ? .white : .primary)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                    }
                }
            }
            
            if rsvpStatus == .pending {
                Text("⏳ Waiting for host approval")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(DesignSystem.Colors.secondaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
    
    @State private var selectedAttendee: SelectedAttendee?
    
    struct SelectedAttendee: Identifiable {
        let id: UUID
    }
    
    private var attendeesSection: some View {
        SectionCard(title: "Attendees (\(attendees.count))") {
            if attendees.isEmpty {
                Text("No attendees yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(attendees, id: \.self) { userId in
                        let profile = attendeeProfiles[userId]
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
                }
            }
        }
        .task {
            await loadAttendeeProfiles()
        }
    }
    
    private func loadAttendeeProfiles() async {
        guard let supabase = Config.supabase else { return }
        
        for userId in attendees {
            // Skip if already loaded or is current user
            if attendeeProfiles[userId] != nil { continue }
            if userId == sessionStore.currentUser.id {
                attendeeProfiles[userId] = sessionStore.currentUser
                continue
            }
            
            do {
                let response: ProfileDTO = try await supabase
                    .from("profiles")
                    .select("id, name, avatar_url")
                    .eq("id", value: userId.uuidString)
                    .single()
                    .execute()
                    .value
                
                attendeeProfiles[userId] = UserProfile(
                    id: response.id,
                    name: response.name,
                    age: 0,
                    bio: "",
                    avatarUrl: response.avatar_url
                )
            } catch {
                Logger.error("Failed to load attendee profile: \(error.localizedDescription)")
            }
        }
    }
    
    private struct ProfileDTO: Decodable {
        let id: UUID
        let name: String
        let avatar_url: String?
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
