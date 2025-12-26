import SwiftUI

/// Search bar with activity and date filters for the map view
struct MapSearchBar: View {
    @Binding var searchText: String
    @Binding var selectedActivityFilter: ActivityType?
    @Binding var selectedDateFilter: DateFilter
    @Binding var isExpanded: Bool
    
    let onSearch: () -> Void
    
    @State private var showDatePicker = false
    @State private var tempDate = Date()
    
    var body: some View {
        VStack(spacing: 10) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16, weight: .medium))
                
                TextField("Search events...", text: $searchText)
                    .font(.system(size: 16))
                    .submitLabel(.search)
                    .onSubmit(onSearch)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        onSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Expand/collapse button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "slider.horizontal.3")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
            
            // Filters (when expanded)
            if isExpanded {
                VStack(spacing: 8) {
                    // Activity filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // "All" chip
                            FilterChip(
                                label: "All",
                                emoji: nil,
                                isSelected: selectedActivityFilter == nil
                            ) {
                                selectedActivityFilter = nil
                                onSearch()
                            }
                            
                            // Activity type chips
                            ForEach(ActivityType.allCases, id: \.self) { activity in
                                FilterChip(
                                    label: activity.displayName,
                                    emoji: activity.defaultEmoji,
                                    isSelected: selectedActivityFilter == activity
                                ) {
                                    selectedActivityFilter = activity
                                    onSearch()
                                }
                            }
                        }
                        .padding(.horizontal, 4)
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
                        .padding(.horizontal, 4)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
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
    
    // Helper to check if current selection is custom
    private var isCustomDateSelected: Bool {
        if case .custom = selectedDateFilter { return true }
        return false
    }
}

/// Date filter options
enum DateFilter: Hashable, Equatable {
    case all
    case today
    case thisWeek
    case thisMonth
    case custom(Date)
    
    // Standard options to show in the scroll view initially
    static var standardOptions: [DateFilter] {
        [.all, .today, .thisWeek, .thisMonth]
    }
    
    var displayName: String {
        switch self {
        case .all: return "All Dates"
        case .today: return "Today"
        case .thisWeek: return "This Week"
        case .thisMonth: return "This Month"
        case .custom(let date):
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
    
    func matches(date: Date) -> Bool {
        let calendar = Calendar.current
        switch self {
        case .all:
            return true
        case .today:
            return calendar.isDateInToday(date)
        case .thisWeek:
            return calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
        case .thisMonth:
            return calendar.isDate(date, equalTo: Date(), toGranularity: .month)
        case .custom(let customDate):
            return calendar.isDate(date, inSameDayAs: customDate)
        }
    }
}

/// Activity filter chip with glass effect
struct FilterChip: View {
    let label: String
    let emoji: String?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let emoji = emoji {
                    Text(emoji)
                        .font(.system(size: 14))
                }
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.3) : Color.clear)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.blue.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Date filter chip
struct DateFilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.green.opacity(0.3) : Color.clear)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.green.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            MapSearchBar(
                searchText: .constant(""),
                selectedActivityFilter: .constant(nil),
                selectedDateFilter: .constant(.all),
                isExpanded: .constant(true),
                onSearch: {}
            )
            .padding()
            
            Spacer()
        }
    }
}
