import SwiftUI
import MapKit

/// Detailed view for a single plan
struct PlanDetailsView: View {
    let plan: Plan
    @EnvironmentObject private var planStore: PlanStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var showBlockAlert = false
    @State private var showReportAlert = false
    
    private var rsvpStatus: RSVPStatus {
        planStore.getRSVP(for: plan.id)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // Host info
                    hostSection
                    
                    // Plan details
                    detailsSection
                    
                    // Map preview
                    mapPreviewSection
                    
                    // RSVP section
                    rsvpSection
                    
                    // Safety buttons
                    safetySection
                }
                .padding(DesignSystem.Spacing.md)
            }
            .navigationTitle("Plan Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
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
    
    private var hostSection: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            AvatarView(
                name: plan.hostName,
                size: 56,
                assetName: MockData.hostAvatars[plan.hostUserId]
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Hosted by")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(plan.hostName)
                    .font(.headline)
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.secondaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
    
    private var detailsSection: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(plan.title)
                    .font(.title2.bold())
                
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
                ForEach(RSVPStatus.allCases, id: \.self) { status in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            // Toggle through statuses
                            planStore.rsvpStatus[plan.id] = status
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
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.secondaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
    
    private func statusColor(_ status: RSVPStatus) -> Color {
        switch status {
        case .going: return .green
        case .maybe: return .orange
        case .none: return .gray
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
}
