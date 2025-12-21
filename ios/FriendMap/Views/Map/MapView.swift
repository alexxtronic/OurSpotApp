import SwiftUI
import MapKit

/// Map view showing plan pins around Copenhagen
struct MapView: View {
    @EnvironmentObject private var planStore: PlanStore
    @StateObject private var locationManager = LocationManager()
    @State private var selectedPlan: Plan?
    @State private var showFilters = false
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: MockData.copenhagenCenter.latitude,
                longitude: MockData.copenhagenCenter.longitude
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    ))
    
    private var hasActiveFilters: Bool {
        !planStore.filterActivityTypes.isEmpty || planStore.filterDateRange != .all
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $cameraPosition) {
                    UserAnnotation()
                    
                    ForEach(planStore.filteredPlans) { plan in
                        Annotation("", coordinate: CLLocationCoordinate2D(
                            latitude: plan.latitude,
                            longitude: plan.longitude
                        )) {
                            PlanAnnotationView(plan: plan)
                                .onTapGesture {
                                    selectedPlan = plan
                                }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
            }
            .onChange(of: locationManager.mapUpdateTrigger) {
                withAnimation {
                    cameraPosition = .region(locationManager.region)
                }
            }
            .navigationTitle("OurSpot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NotificationBellView()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.title3)
                            .foregroundColor(hasActiveFilters ? DesignSystem.Colors.primaryFallback : .primary)
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                MapFilterView()
                    .presentationDetents([.medium])
                    .environmentObject(locationManager)
            }
            .sheet(item: $selectedPlan) { plan in
                PlanDetailsView(plan: plan)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

/// Custom annotation view for plans on the map - shows emoji icon
struct PlanAnnotationView: View {
    let plan: Plan
    
    var body: some View {
        VStack(spacing: 2) {
            // Emoji circle
            Text(plan.emoji)
                .font(.title)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                )
            
            // Title label
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
