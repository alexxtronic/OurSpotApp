import SwiftUI

/// Filter view for map with calendar, activity types, and reset button
struct MapFilterView: View {
    @EnvironmentObject private var planStore: PlanStore
    @Environment(\.dismiss) private var dismiss
    @State private var showCalendar = false
    
    private var hasActiveFilters: Bool {
        !planStore.filterActivityTypes.isEmpty || 
        planStore.filterDateRange != .all ||
        planStore.filterSpecificDate != nil
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Date filter section
                Section("Date") {
                    // Quick date ranges
                    ForEach(DateFilterRange.allCases) { range in
                        Button {
                            planStore.filterDateRange = range
                            planStore.filterSpecificDate = nil
                        } label: {
                            HStack {
                                Text(range.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                if planStore.filterDateRange == range && planStore.filterSpecificDate == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(DesignSystem.Colors.primaryFallback)
                                }
                            }
                        }
                    }
                    
                    // Specific date picker
                    Button {
                        showCalendar.toggle()
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                            Text("Pick a Date")
                                .foregroundColor(.primary)
                            Spacer()
                            if let date = planStore.filterSpecificDate {
                                Text(date.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundColor(DesignSystem.Colors.primaryFallback)
                            }
                        }
                    }
                    
                    if showCalendar {
                        DatePicker(
                            "Select Date",
                            selection: Binding(
                                get: { planStore.filterSpecificDate ?? Date() },
                                set: { newDate in
                                    planStore.filterSpecificDate = newDate
                                    planStore.filterDateRange = .all
                                }
                            ),
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                    }
                }
                
                // Activity type filter
                Section("Activity Type") {
                    ForEach(ActivityType.allCases) { type in
                        Button {
                            if planStore.filterActivityTypes.contains(type) {
                                planStore.filterActivityTypes.remove(type)
                            } else {
                                planStore.filterActivityTypes.insert(type)
                            }
                        } label: {
                            HStack {
                                Text(type.defaultEmoji)
                                Text(type.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if planStore.filterActivityTypes.contains(type) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(DesignSystem.Colors.primaryFallback)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if hasActiveFilters {
                        Button {
                            resetAllFilters()
                        } label: {
                            Text("Reset")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func resetAllFilters() {
        planStore.filterActivityTypes.removeAll()
        planStore.filterDateRange = .all
        planStore.filterSpecificDate = nil
    }
}

#Preview {
    MapFilterView()
        .environmentObject(PlanStore())
}
