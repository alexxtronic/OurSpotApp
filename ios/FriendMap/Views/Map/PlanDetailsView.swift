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
                            planStore.toggleRSVP(planId: plan.id, userId: sessionStore.currentUser.id)
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
                        Button {
                            selectedAttendee = SelectedAttendee(id: userId)
                        } label: {
                            HStack {
                                AvatarView(
                                    name: MockData.hostNames[userId] ?? "User",
                                    size: 36,
                                    assetName: MockData.hostAvatars[userId]
                                )
                                Text(MockData.hostNames[userId] ?? "User")
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
}

#Preview {
    PlanDetailsView(plan: MockData.samplePlans[0])
        .environmentObject(PlanStore())
        .environmentObject(SessionStore())
}
