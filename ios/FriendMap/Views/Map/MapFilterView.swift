import SwiftUI
import CoreLocation

// NOTE: This file now contains MapOverlayControls to maintain compatibility with the existing Xcode project file structure.
// The file MapFilterView.swift is included in the project, so we define MapOverlayControls here.

/// Floating map controls (Calendar, Activity, Location)
struct MapOverlayControls: View {
    @EnvironmentObject private var planStore: PlanStore
    @EnvironmentObject private var locationManager: LocationManager
    
    // Callback to center map on user location
    var onCenterOnUser: (() -> Void)?
    
    @State private var showDatePicker = false
    
    // Check if we are checking authorization status to show appropriate location button state
    var isAuthorized: Bool {
        locationManager.permissionStatus == .authorizedWhenInUse || 
        locationManager.permissionStatus == .authorizedAlways
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 1. Activity Filter
            Menu {
                Button {
                    planStore.activityFilter = nil
                    HapticManager.lightTap()
                } label: {
                    if planStore.activityFilter == nil {
                        Label("All Activities", systemImage: "checkmark")
                    } else {
                        Text("All Activities")
                    }
                }
                
                Divider()
                
                ForEach(ActivityType.allCases, id: \.self) { type in
                    Button {
                        planStore.activityFilter = type
                        HapticManager.lightTap()
                    } label: {
                        if planStore.activityFilter == type {
                            Label(type.displayName, systemImage: "checkmark")
                        } else {
                            Label {
                                Text(type.displayName)
                            } icon: {
                                Image(type.icon)
                            }
                        }
                    }
                }
            } label: {
                ZStack {
                    GlassBubble(size: 50)
                    if let filter = planStore.activityFilter {
                        Image(filter.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    } else {
                        Text("👋")
                            .font(.title2)
                    }
                }
            }
            
            // 2. Date Filter
            Menu {
                ForEach(DateFilterOption.allCases) { option in
                    Button {
                        if option == .custom {
                            showDatePicker = true
                        } else {
                            planStore.dateFilter = option
                            planStore.customDate = nil
                        }
                        HapticManager.lightTap()
                    } label: {
                        if planStore.dateFilter == option {
                            Label(option.rawValue, systemImage: "checkmark")
                        } else {
                            Label(option.rawValue, systemImage: option.icon)
                        }
                    }
                }
            } label: {
                ZStack {
                    GlassBubble(size: 50)
                    Image(systemName: planStore.dateFilter.icon)
                        .font(.title3)
                        .foregroundColor(.primary)
                }
            }
            
            // 3. Location Button - always visible
            Button {
                if isAuthorized {
                    // Prefer callback if provided, otherwise use locationManager
                    if let centerOnUser = onCenterOnUser {
                        centerOnUser()
                    } else {
                        locationManager.centerMapOnUser()
                    }
                } else {
                    locationManager.checkAuthorization()
                }
                HapticManager.mediumTap()
            } label: {
                ZStack {
                    GlassBubble(size: 50)
                    Image(systemName: isAuthorized ? "location.fill" : "location")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(selectedDate: $planStore.customDate) {
                // On clear - reset to all future
                planStore.dateFilter = .allFuture
                planStore.customDate = nil
            }
            .presentationDetents([.medium])
            .onDisappear {
                if planStore.customDate != nil {
                    planStore.dateFilter = .custom
                }
            }
        }
    }
}

/// Reusable Glass Bubble Background
struct GlassBubble: View {
    let size: CGFloat
    
    var body: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}
