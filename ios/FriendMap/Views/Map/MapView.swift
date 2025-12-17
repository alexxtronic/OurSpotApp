import SwiftUI
import MapKit

/// Map view showing plan pins around Copenhagen
struct MapView: View {
    @EnvironmentObject private var planStore: PlanStore
    @State private var selectedPlan: Plan?
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: MockData.copenhagenCenter.latitude,
                longitude: MockData.copenhagenCenter.longitude
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )
    
    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $cameraPosition, selection: $selectedPlan) {
                    ForEach(planStore.upcomingPlans) { plan in
                        Annotation(plan.title, coordinate: CLLocationCoordinate2D(
                            latitude: plan.latitude,
                            longitude: plan.longitude
                        )) {
                            PlanAnnotationView(plan: plan)
                                .onTapGesture {
                                    selectedPlan = plan
                                }
                        }
                        .tag(plan)
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }
            }
            .navigationTitle("FriendMap")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedPlan) { plan in
                PlanDetailsView(plan: plan)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

/// Custom annotation view for plans on the map
struct PlanAnnotationView: View {
    let plan: Plan
    
    var body: some View {
        VStack(spacing: 2) {
            AvatarView(
                name: plan.hostName,
                size: 44,
                assetName: MockData.hostAvatars[plan.hostUserId]
            )
            
            Text(plan.title.prefix(15) + (plan.title.count > 15 ? "..." : ""))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial)
                .cornerRadius(4)
        }
    }
}

#Preview {
    MapView()
        .environmentObject(PlanStore())
        .environmentObject(SessionStore())
}
