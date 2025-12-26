import SwiftUI
import MapKit

/// Map view showing plan pins around Copenhagen
struct MapView: View {
    @EnvironmentObject private var planStore: PlanStore
    @StateObject private var locationManager = LocationManager()
    @State private var selectedPlan: Plan?
    @State private var showPlanDetails = false  // For hero animation
    @State private var showCreatePlan = false
    @State private var tappedLocation: CLLocationCoordinate2D?
    @State private var tappedAddress: String?
    @State private var currentTapLocation: CGPoint = .zero // Track precise tap location
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: MockData.copenhagenCenter.latitude,
                longitude: MockData.copenhagenCenter.longitude
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    ))
    
    // Track zoom level for pin scaling
    @State private var zoomScale: CGFloat = 1.0
    @State private var mapSpan: Double = 0.05  // Track span for clustering
    
    // Hero animation namespace
    @Namespace private var heroAnimation
    
    // Coach mark for first-time users
    @AppStorage("hasSeenMapCoachMark") private var hasSeenMapCoachMark = false
    @State private var showCoachMark = false
    @State private var coachMarkBounce = false
    
    // Search and filter state
    @State private var searchText: String = ""
    @State private var selectedActivityFilter: ActivityType? = nil
    @State private var selectedDateFilter: DateFilter = .all
    @State private var isSearchExpanded: Bool = false
    
    // Filtered plans based on search and filters
    private var searchFilteredPlans: [Plan] {
        planStore.filteredPlans.filter { plan in
            // Search text filter
            let matchesSearch = searchText.isEmpty || 
                plan.title.localizedCaseInsensitiveContains(searchText) ||
                plan.hostName.localizedCaseInsensitiveContains(searchText) ||
                plan.locationName.localizedCaseInsensitiveContains(searchText)
            
            // Activity filter
            let matchesActivity = selectedActivityFilter == nil || plan.activityType == selectedActivityFilter
            
            // Date filter
            let matchesDate = selectedDateFilter.matches(date: plan.startsAt)
            
            return matchesSearch && matchesActivity && matchesDate
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                MapReader { proxy in
                    ZStack {
                        Map(position: $cameraPosition) {
                            UserAnnotation()
                            
                            // Compute clusters based on current zoom level
                            let clusters = MapClusterHelper.clusterPlans(searchFilteredPlans, span: mapSpan)
                            
                            ForEach(clusters) { cluster in
                                if cluster.isSingle, let plan = cluster.singlePlan {
                                    // Single plan - show normal annotation
                                    Annotation("", coordinate: CLLocationCoordinate2D(
                                        latitude: plan.latitude,
                                        longitude: plan.longitude
                                    )) {

                                        PlanAnnotationView(plan: plan, scale: zoomScale, isSelected: selectedPlan?.id == plan.id)
                                            .onTapGesture {
                                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                    selectedPlan = plan
                                                    showPlanDetails = true
                                                }
                                                HapticManager.mediumTap()
                                            }
                                    }
                                } else {
                                    // Cluster - show cluster annotation
                                    Annotation("", coordinate: cluster.center) {
                                        ClusterAnnotationView(cluster: cluster, scale: zoomScale)
                                            .onTapGesture {
                                                // Zoom into the cluster
                                                withAnimation {
                                                    cameraPosition = .region(MKCoordinateRegion(
                                                        center: cluster.center,
                                                        span: MKCoordinateSpan(
                                                            latitudeDelta: mapSpan * 0.3,
                                                            longitudeDelta: mapSpan * 0.3
                                                        )
                                                    ))
                                                }
                                                HapticManager.lightTap()
                                            }
                                    }
                                }
                            }
                        }
                        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
                        // We use custom controls now, so removing standard ones or keeping minimal if needed
                        .mapControls {
                            // MapUserLocationButton() - replaced by our custom one
                            MapCompass()
                            MapScaleView()
                        }
                        .onAppear {
                            locationManager.checkAuthorization()
                        }
                        .onMapCameraChange { context in
                            // Calculate scale based on zoom level
                            // Smaller span = more zoomed in = larger pins
                            let span = context.region.span.latitudeDelta
                            mapSpan = span  // Track for clustering
                            // span of 0.01 = zoomed in, span of 0.5 = zoomed out
                            // Map to scale: 1.0 at close, 0.7 at far (never too small)
                            let scale = max(0.7, min(1.0, 0.015 / span))
                            zoomScale = scale
                        }
                    }
                }
                
                // Floating Controls - positioned at top with bell on left, search center, controls on right
                VStack(spacing: 0) {
                    // Top row: Bell, Search Bar, Controls
                    HStack(alignment: .top, spacing: 12) {
                        // Left side - Notification Bell only
                        NotificationBellView()
                        
                        // Center - Search Bar (expands to fill)
                        MapSearchBar(
                            searchText: $searchText,
                            selectedActivityFilter: $selectedActivityFilter,
                            selectedDateFilter: $selectedDateFilter,
                            isExpanded: $isSearchExpanded,
                            onSearch: {
                                HapticManager.lightTap()
                            }
                        )
                        
                        // Right side - Location Button removed to allow search bar expansion

                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    Spacer()
                    
                    // Bottom Controls layer
                    HStack {
                        Spacer()
                        
                        // Location Button (moved to bottom right)
                        Button {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                cameraPosition = .userLocation(fallback: .region(
                                    MKCoordinateRegion(
                                        center: CLLocationCoordinate2D(
                                            latitude: MockData.copenhagenCenter.latitude,
                                            longitude: MockData.copenhagenCenter.longitude
                                        ),
                                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                                    )
                                ))
                            }
                            HapticManager.lightTap()
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 20, weight: .bold)) // Slightly larger icon
                                .foregroundColor(.blue)
                                .frame(width: 50, height: 50) // Slightly larger button for bottom reachability
                                .background(.thickMaterial) // Thicker material for bottom overlay
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 20) // Positioned above Tab Bar (approx 50-80pt usually needed, but inside safe area usually handles it. Will add padding to be safe).
                    }
                }
            }
            .onChange(of: locationManager.mapUpdateTrigger) {
                withAnimation {
                    cameraPosition = .region(locationManager.region)
                }
            }
            .navigationTitle("OurSpot")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPlanDetails, onDismiss: {
                withAnimation(.spring(response: 0.3)) {
                    selectedPlan = nil
                }
            }) {
                if let plan = selectedPlan {
                    PlanDetailsView(plan: plan)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showCreatePlan, onDismiss: {
                // Dismiss coach mark when returning from create plan
                // (whether plan was created or not, user understands the flow)
                if showCoachMark {
                    dismissCoachMark()
                }
            }) {
                CreatePlanView(initialCoordinate: tappedLocation, initialAddress: tappedAddress)
                    .presentationDetents([.large])
            }
            .onChange(of: planStore.planToShowOnMap) { plan in
                if let plan = plan {
                    // Dismiss coach mark when a new plan is created
                    if showCoachMark {
                        dismissCoachMark()
                    }
                    
                    withAnimation {
                        cameraPosition = .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: plan.latitude, longitude: plan.longitude),
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))
                    }
                    selectedPlan = plan
                    planStore.planToShowOnMap = nil
                }
            }
            .overlay {
                // Coach mark overlay for first-time users
                if showCoachMark {
                    coachMarkOverlay
                }
            }
            .onAppear {
                // Show coach mark for first-time users
                if !hasSeenMapCoachMark {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showCoachMark = true
                        }
                        // Start bounce animation
                        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                            coachMarkBounce = true
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Coach Mark Overlay
    
    private var coachMarkOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissCoachMark()
                }
            
            VStack {
                Spacer()
                
                // Coach mark positioned just above the tab bar
                VStack(spacing: 8) {
                    // Coach mark card
                    VStack(spacing: 8) {
                        Text("Tap here to make your first plan!")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                        
                        Text("Click the + button below to get started")
                            .font(.subheadline)
                            .foregroundColor(.black.opacity(0.7))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: .orange.opacity(0.4), radius: 12, y: 4)
                    
                    // Animated arrow pointing down at + button
                    Image(systemName: "arrow.down")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.orange)
                        .offset(y: coachMarkBounce ? 10 : 0)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20) // Position just above tab bar
            }
        }
        .transition(.opacity)
    }
    
    private func dismissCoachMark() {
        hasSeenMapCoachMark = true
        withAnimation(.easeOut(duration: 0.3)) {
            showCoachMark = false
        }
    }


    private func handleLongPress(at coordinate: CLLocationCoordinate2D) {
        // Haptic feedback
        HapticManager.mediumTap()
        
        tappedLocation = coordinate
        tappedAddress = nil // Reset
        
        // Reverse geocode
        Task {
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            
            if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
                // Construct address string
                var parts: [String] = []
                if let name = placemark.name { parts.append(name) }
                if let street = placemark.thoroughfare { 
                    if !parts.contains(street) { parts.append(street) }
                }
                
                tappedAddress = parts.joined(separator: ", ")
            }
            
            // Present sheet on main thread
            await MainActor.run {
                showCreatePlan = true
            }
        }
    }
}

/// Map annotation - liquid glass bubble with emoji and title
struct PlanAnnotationView: View {
    let plan: Plan
    let scale: CGFloat
    var isSelected: Bool = false
    
    // Base dimensions - larger for visibility
    private let baseSize: CGFloat = 56
    private let baseEmojiSize: CGFloat = 28
    
    private var scaledSize: CGFloat { baseSize * scale }
    private var scaledEmojiSize: CGFloat { baseEmojiSize * scale }
    
    var body: some View {
        VStack(spacing: 3 * scale) {
            // Glass bubble with glow
            ZStack {
                // Outer glow - subtle light effect
                 Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: scaledSize * 0.8
                        )
                    )
                    .frame(width: scaledSize + 8, height: scaledSize + 8)
                
                // Main glass bubble - more opaque
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.85),
                                Color.white.opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: scaledSize, height: scaledSize)
                    .overlay(
                        // Strong border with gradient for liquid glass effect
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.9),
                                        Color.white.opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    // Prism/Rainbow Effect
                    .overlay(
                        Circle()
                            .stroke(
                                AngularGradient(
                                    colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                                    center: .center
                                ),
                                lineWidth: 1.5
                            )
                            .opacity(0.5)
                            .blur(radius: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
                
                // Emoji
                Text(plan.emoji)
                    .font(.system(size: scaledEmojiSize))
            }
            // Host avatar - small circle overlapping bottom-right of the bubble
            .overlay(alignment: .bottomTrailing) {
                AvatarView(
                    name: plan.hostName,
                    size: 22 * scale,
                    url: URL(string: plan.hostAvatar ?? ""),
                    showBorder: false  // Clean circle, no white border
                )
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                .offset(x: 4, y: -2)  // Moved up to overlap bubble, not get blocked by text
            }
            .scaleEffect(isSelected ? 1.4 : 1.0)
            .shadow(color: isSelected ? .black.opacity(0.4) : .clear, radius: isSelected ? 12 : 0, x: 0, y: 6)
            .animation(.spring(response: 0.35, dampingFraction: 0.5, blendDuration: 0), value: isSelected)
            
            // Event title with glass background - always visible
            Text(plan.title.prefix(12) + (plan.title.count > 12 ? "…" : ""))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                )
                .lineLimit(1)
        }
    }
}

#Preview {
    MapView()
        .environmentObject(PlanStore())
        .environmentObject(SessionStore())
}
