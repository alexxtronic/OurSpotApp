import SwiftUI

/// Plans tab showing upcoming plans organized by sections
struct PlansView: View {
    @EnvironmentObject private var planStore: PlanStore
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var showCreatePlan = false
    @State private var selectedPlan: Plan?
    
    private var myPlans: [Plan] {
        planStore.myPlans(userId: sessionStore.currentUser.id)
    }
    
    private var hostedPlans: [Plan] {
        planStore.hostedPlans(userId: sessionStore.currentUser.id)
    }
    
    private var friendPlans: [Plan] {
        planStore.friendPlans(userId: sessionStore.currentUser.id)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // My Plans (Going/Maybe)
                    if !myPlans.isEmpty {
                        PlanSectionView(
                            title: "My Plans",
                            subtitle: "Going or Maybe",
                            icon: "📍",
                            plans: myPlans,
                            planStore: planStore
                        ) { plan in
                            selectedPlan = plan
                        }
                    }
                    
                    // Plans I'm Hosting
                    if !hostedPlans.isEmpty {
                        PlanSectionView(
                            title: "Hosting",
                            subtitle: "Plans you created",
                            icon: "🎯",
                            plans: hostedPlans,
                            planStore: planStore
                        ) { plan in
                            selectedPlan = plan
                        }
                    }
                    
                    // Friend Plans (Not RSVP'd)
                    if !friendPlans.isEmpty {
                        PlanSectionView(
                            title: "Friend Plans",
                            subtitle: "Not yet responded",
                            icon: "👀",
                            plans: friendPlans,
                            planStore: planStore
                        ) { plan in
                            selectedPlan = plan
                        }
                    }
                    
                    // Empty state
                    if myPlans.isEmpty && hostedPlans.isEmpty && friendPlans.isEmpty {
                        emptyState
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

/// Section view for a group of plans
struct PlanSectionView: View {
    let title: String
    let subtitle: String
    let icon: String
    let plans: [Plan]
    let planStore: PlanStore
    let onTapPlan: (Plan) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Section header
            HStack(spacing: DesignSystem.Spacing.xs) {
                Text(icon)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(plans.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
            }
            .padding(.horizontal, DesignSystem.Spacing.xs)
            
            // Plan cards
            ForEach(plans) { plan in
                PlanRowView(plan: plan, planStore: planStore)
                    .onTapGesture {
                        onTapPlan(plan)
                    }
            }
        }
    }
}

/// Row view for a single plan in the list
struct PlanRowView: View {
    let plan: Plan
    let planStore: PlanStore
    
    private var rsvpStatus: RSVPStatus {
        planStore.getRSVP(for: plan.id)
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Emoji icon
            Text(plan.emoji)
                .font(.title)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(Color.gray.opacity(0.1))
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
