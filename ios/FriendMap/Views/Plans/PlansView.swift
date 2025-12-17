import SwiftUI

/// Plans tab showing upcoming plans with ability to create new ones
struct PlansView: View {
    @EnvironmentObject private var planStore: PlanStore
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var showCreatePlan = false
    @State private var selectedPlan: Plan?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.md) {
                    if planStore.upcomingPlans.isEmpty {
                        emptyState
                    } else {
                        ForEach(planStore.upcomingPlans) { plan in
                            PlanRowView(plan: plan)
                                .onTapGesture {
                                    selectedPlan = plan
                                }
                        }
                    }
                }
                .padding(DesignSystem.Spacing.md)
            }
            .navigationTitle("Plans")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreatePlan = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(DesignSystem.Colors.primaryFallback)
                    }
                }
            }
            .sheet(isPresented: $showCreatePlan) {
                CreatePlanView()
            }
            .sheet(item: $selectedPlan) { plan in
                PlanDetailsView(plan: plan)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Upcoming Plans")
                .font(.title3.bold())
            
            Text("Create a plan to hang out with friends!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            PrimaryButton("Create Plan", icon: "plus") {
                showCreatePlan = true
            }
            .frame(maxWidth: 200)
        }
        .padding(.top, DesignSystem.Spacing.xxl)
    }
}

/// Row view for a single plan in the list
struct PlanRowView: View {
    let plan: Plan
    @EnvironmentObject private var planStore: PlanStore
    
    private var rsvpStatus: RSVPStatus {
        planStore.getRSVP(for: plan.id)
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            AvatarView(
                name: plan.hostName,
                size: 50,
                assetName: MockData.hostAvatars[plan.hostUserId]
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(plan.hostName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Label(plan.startsAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    
                    if rsvpStatus != .none {
                        Text("• \(rsvpStatus.displayText)")
                            .foregroundColor(rsvpStatus == .going ? .green : .orange)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.secondaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
}

#Preview {
    PlansView()
        .environmentObject(PlanStore())
        .environmentObject(SessionStore())
}
