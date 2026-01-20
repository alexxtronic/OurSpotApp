import SwiftUI
import MapKit

/// Map view showing plan pins around Copenhagen
struct MapView: View {
    @EnvironmentObject private var planStore: PlanStore
    @EnvironmentObject private var blockService: BlockService
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
            // Block filter
            if blockService.isBlocked(userId: plan.hostUserId.uuidString) {
                return false
            }
            
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
    
    // Check if any filter is currently active
    private var hasActiveFilters: Bool {
        selectedActivityFilter != nil || selectedDateFilter != .all || !searchText.isEmpty
    }
    
    var body: some View {
        // Compute clusters based on current zoom level - performed outside Map builder to help compiler
        let clusters = MapClusterHelper.clusterPlans(searchFilteredPlans, span: mapSpan)
        
        NavigationStack {
            ZStack {
                MapReader { proxy in
                    ZStack {
                        Map(position: $cameraPosition) {
                            UserAnnotation()
                            
                            ForEach(clusters) { cluster in
                                annotationContent(for: cluster)
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
                                performLocationSearch()
                            }
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    

                    
                    // Filters & Quick Actions
                    if isSearchExpanded {
                        // Full-width filters when expanded
                        MapFiltersView(
                            selectedActivityFilter: $selectedActivityFilter,
                            selectedDateFilter: $selectedDateFilter,
                            onSearch: {
                                HapticManager.lightTap()
                                performLocationSearch()
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    } else {

    // Quick Action Bubbles (only visible when search is NOT expanded)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                // 1. Plans Today
                                QuickActionBubble(
                                    text: "Plans Today",
                                    icon: "calendar",
                                    isSystemImage: true,
                                    isActive: selectedDateFilter == .today && selectedActivityFilter == nil && searchText.isEmpty
                                ) {
                                    selectedDateFilter = .today
                                    selectedActivityFilter = nil
                                    searchText = ""
                                    HapticManager.lightTap()
                                }
                                
                                // 2. Yoga with new friends
                                QuickActionBubble(
                                    text: "Yoga with new friends",
                                    icon: "figure.yoga",
                                    isSystemImage: true,
                                    isActive: searchText.lowercased() == "yoga" && selectedActivityFilter == nil && selectedDateFilter == .all
                                ) {
                                    searchText = "yoga"
                                    selectedActivityFilter = nil
                                    selectedDateFilter = .all
                                    HapticManager.lightTap()
                                }
                                
                                // 3. Grab a coffee
                                QuickActionBubble(
                                    text: "Grab a coffee",
                                    icon: ActivityType.coffee.icon,
                                    isSystemImage: false,
                                    isActive: selectedActivityFilter == .coffee && searchText.isEmpty
                                ) {
                                    selectedActivityFilter = .coffee
                                    selectedDateFilter = .all
                                    searchText = ""
                                    HapticManager.lightTap()
                                }
                                
                                // 4. Nightlife this weekend
                                QuickActionBubble(
                                    text: "Nightlife this weekend",
                                    icon: ActivityType.nightlife.icon, // "nightlife"
                                    isSystemImage: false,
                                    isActive: selectedActivityFilter == .nightlife && selectedDateFilter == .thisWeekend && searchText.isEmpty
                                ) {
                                    selectedActivityFilter = .nightlife
                                    selectedDateFilter = .thisWeekend
                                    searchText = ""
                                    HapticManager.lightTap()
                                }
                                
                                // 5. Go for beers tonight
                                QuickActionBubble(
                                    text: "Go for beers tonight",
                                    icon: ActivityType.drinks.icon, // "drinks"
                                    isSystemImage: false,
                                    isActive: selectedActivityFilter == .drinks && selectedDateFilter == .today && searchText.isEmpty
                                ) {
                                    selectedActivityFilter = .drinks
                                    selectedDateFilter = .today
                                    searchText = ""
                                    HapticManager.lightTap()
                                }
                                
                                // 6. See live music this week
                                QuickActionBubble(
                                    text: "See live music this week",
                                    icon: ActivityType.liveMusic.icon, // "livemusic"
                                    isSystemImage: false,
                                    isActive: selectedActivityFilter == .liveMusic && selectedDateFilter == .thisWeek && searchText.isEmpty
                                ) {
                                    selectedActivityFilter = .liveMusic
                                    selectedDateFilter = .thisWeek
                                    searchText = ""
                                    HapticManager.lightTap()
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }

                        .transition(.move(edge: .top).combined(with: .opacity))
                        
                        // Reset Filters button - appears when any filter is active
                        if hasActiveFilters {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedActivityFilter = nil
                                    selectedDateFilter = .all
                                    searchText = ""
                                }
                                HapticManager.mediumTap()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Reset Filters")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.red.opacity(0.85))
                                )
                                .shadow(color: .red.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    
                    Spacer()
                        .allowsHitTesting(false) // Allow taps to pass through to map annotations
                    
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
                        .padding(.bottom, 30) // Positioned closer to center console
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
                .padding(.bottom, 70) // Position well above tab bar
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
    
    // Helper to reduce complexity in Map content builder
    @MapContentBuilder
    private func annotationContent(for cluster: PlanCluster) -> some MapContent {
        if cluster.isSingle, let plan = cluster.singlePlan {
            // Single plan - show normal annotation
            Annotation("", coordinate: CLLocationCoordinate2D(
                latitude: plan.latitude,
                longitude: plan.longitude
            )) {

                PlanAnnotationView(plan: plan, scale: zoomScale, isSelected: selectedPlan?.id == plan.id)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            planStore.planToShowOnMap = plan
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
    
    private func performLocationSearch() {
        guard !searchText.isEmpty else { return }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        
        let search = MKLocalSearch(request: request)
        
        search.start { response, error in
            guard let mapItem = response?.mapItems.first, let location = mapItem.placemark.location else {
                Logger.warning("Location search failed or no results")
                return 
            }
            
            // Move map to location
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                cameraPosition = .region(MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1) // City level
                ))
            }
            
            // Clear search text so users can see events in that city
            searchText = ""
            
            Logger.info("Map moved to location search result: \(mapItem.name ?? "Unknown")")
        }
    }
}

/// Map annotation - liquid glass bubble with emoji and title
struct PlanAnnotationView: View {
    let plan: Plan
    let scale: CGFloat
    var isSelected: Bool = false
    
    // Base dimensions - larger for visibility
    // Base dimensions - larger for visibility
    private let baseSize: CGFloat = 62 // increased ~11% from 56
    private let baseEmojiSize: CGFloat = 31 // increased ~11% from 28
    
    @State private var isAnimating = false
    
    private var scaledSize: CGFloat { baseSize * scale }
    private var scaledEmojiSize: CGFloat { baseEmojiSize * scale }
    
    /// Whether event is "live" (started within last 10 hours)
    private var isLive: Bool {
        let hoursSinceStart = Date().timeIntervalSince(plan.startsAt) / 3600
        return hoursSinceStart >= 0 && hoursSinceStart < 10
    }
    
    var body: some View {
        VStack(spacing: 3 * scale) {
            // LIVE badge - shown above the bubble for live events
            if isLive {
                Text("LIVE")
                    .font(.system(size: 9 * scale, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6 * scale)
                    .padding(.vertical, 2 * scale)
                    .background(Color.red)
                    .cornerRadius(4 * scale)
            }
            
            // Simple Minimalist Gradient Bubble container
            ZStack {
                // Background Circle (Black for high contrast with 3D icons, or keep eggshell logic?)
                // Since the 3D icons have their own black background, we can just clip them.
                // But we need a border/stroke for branding/Live status
                
                Circle()
                    .fill(Color(hex: "E6DFCD") ?? .white) // Slightly darker eggshell/beige
                    .frame(width: scaledSize, height: scaledSize)
                    .overlay(
                        // Rainbow stroke for live events, otherwise branded orange
                        Circle()
                            .stroke(
                                isLive 
                                    ? AnyShapeStyle(AngularGradient(
                                        colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                                        center: .center
                                    ))
                                    : AnyShapeStyle(DesignSystem.Colors.primary),
                                lineWidth: isLive ? 3 : 2
                            )
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 5, x: 0, y: 3)
                
                // 3D Icon Image
                let iconScale: CGFloat = plan.activityType == .culture ? 1.25 : 1.0
                Image(plan.activityType.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: (scaledSize - 4) * iconScale, height: (scaledSize - 4) * iconScale)
                    .clipShape(Circle())
            }
            .offset(y: isAnimating ? -4 : 0) // Subtle bounce animation
            .onAppear {
                // Add random delay so they don't all bounce in perfect sync
                let delay = Double.random(in: 0...1.0)
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    isAnimating = true
                }
            }
            // Host avatar - small circle overlapping bottom-right of the bubble
            .overlay(alignment: .bottomTrailing) {
                AvatarView(
                    name: plan.hostName,
                    size: 24.5 * scale, // Increased ~11% from 22
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
        .contentShape(Rectangle()) // Ensure entire area is tappable
    }

}


#Preview {
    MapView()
        .environmentObject(PlanStore())
        .environmentObject(SessionStore())
}

/// Quick action bubble for one-tap filtering
struct QuickActionBubble: View {
    let text: String
    let icon: String // Asset name or System Name
    var isSystemImage: Bool = true // Default to true
    var isActive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSystemImage {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: isActive ? .semibold : .regular))
                        .foregroundColor(isActive ? .orange : .primary)
                } else {
                    Image(icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .clipShape(Circle())
                }
                
                Text(text)
                    .font(.system(size: 14, weight: isActive ? .semibold : .medium))
                    .foregroundColor(isActive ? .orange : .primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isActive {
                        // Orange gradient glow background when active
                        LinearGradient(
                            colors: [
                                Color.orange.opacity(0.2),
                                Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color.clear
                    }
                }
            )
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        isActive
                            ? LinearGradient(
                                colors: [Color.orange, Color(red: 1.0, green: 0.65, blue: 0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.white.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              ),
                        lineWidth: isActive ? 1.5 : 1
                    )
            )
            .shadow(
                color: isActive ? Color.orange.opacity(0.3) : Color.black.opacity(0.1),
                radius: isActive ? 8 : 4,
                y: 2
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isActive ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
    }
}

// MARK: - Filter Views

/// Horizontal scrolling filters for Activity and Date
struct MapFiltersView: View {
    @Binding var selectedActivityFilter: ActivityType?
    @Binding var selectedDateFilter: DateFilter
    let onSearch: () -> Void
    
    @State private var showDatePicker = false
    @State private var tempDate = Date()
    
    var body: some View {
        VStack(spacing: 12) {
            // Activity filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // "All" chip
                    FilterChip(
                        label: "All",
                        iconName: nil,
                        isSelected: selectedActivityFilter == nil
                    ) {
                        selectedActivityFilter = nil
                        onSearch()
                    }
                    
                    // Activity type chips
                    ForEach(ActivityType.allCases, id: \.self) { activity in
                        let scale: CGFloat = {
                            switch activity {
                            case .culture: return 1.25
                            case .sports, .exploreTheCity: return 1.20
                            default: return 1.0
                            }
                        }()
                        
                        FilterChip(
                            label: activity.displayName,
                            iconName: activity.icon,
                            iconScale: scale,
                            isSelected: selectedActivityFilter == activity
                        ) {
                            selectedActivityFilter = activity
                            onSearch()
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            
            // Date filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DateFilter.standardOptions, id: \.self) { filter in
                        DateFilterChip(
                            label: filter.displayName,
                            isSelected: selectedDateFilter == filter
                        ) {
                            selectedDateFilter = filter
                            onSearch()
                        }
                    }
                    
                    // Custom Date Chip
                    let isCustomSelected = isCustomDateSelected
                    DateFilterChip(
                        label: isCustomSelected ? selectedDateFilter.displayName : "Select Date",
                        isSelected: isCustomSelected
                    ) {
                        showDatePicker = true
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                VStack {
                    DatePicker(
                        "Select Date",
                        selection: $tempDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    
                    Spacer()
                }
                .navigationTitle("Filter by Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showDatePicker = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Apply") {
                            selectedDateFilter = .custom(tempDate)
                            showDatePicker = false
                            onSearch()
                        }
                        .fontWeight(.bold)
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
    
    private var isCustomDateSelected: Bool {
        if case .custom = selectedDateFilter { return true }
        return false
    }
}

/// Activity filter chip with glass effect - Updated to match QuickActionBubble style
struct FilterChip: View {
    let label: String
    let iconName: String?
    var iconScale: CGFloat = 1.0
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = iconName {
                    Image(icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20 * iconScale, height: 20 * iconScale)
                        .clipShape(Circle())
                }
                Text(label)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10) // Slightly taller to match QuickActionBubble feel
            .background(isSelected ? Color.blue.opacity(0.3) : Color.clear)
            .background(.ultraThinMaterial)
            .clipShape(Capsule()) // Capsule shape
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.blue.opacity(0.5) : Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

/// Date filter chip - Updated to match QuickActionBubble style
struct DateFilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.green.opacity(0.3) : Color.clear)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.green.opacity(0.5) : Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}
