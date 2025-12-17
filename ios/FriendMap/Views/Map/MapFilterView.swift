import SwiftUI

/// Filter view for map with date and activity type options
struct MapFilterView: View {
    @EnvironmentObject private var planStore: PlanStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Date filter
                Section("Date Range") {
                    ForEach(DateFilterRange.allCases) { range in
                        Button {
                            planStore.filterDateRange = range
                        } label: {
                            HStack {
                                Text(range.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                if planStore.filterDateRange == range {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(DesignSystem.Colors.primaryFallback)
                                }
                            }
                        }
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
                
                // Clear filters
                if !planStore.filterActivityTypes.isEmpty || planStore.filterDateRange != .all {
                    Section {
                        Button(role: .destructive) {
                            planStore.filterActivityTypes.removeAll()
                            planStore.filterDateRange = .all
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Clear All Filters")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    MapFilterView()
        .environmentObject(PlanStore())
}
