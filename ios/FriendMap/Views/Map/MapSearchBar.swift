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
            
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
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
    case thisWeekend  // Friday, Saturday, Sunday
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
        case .thisWeekend: return "This Weekend"
        case .thisMonth: return "This Month"
        case .custom(let date):
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
    
    func matches(date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .all:
            return true
        case .today:
            return calendar.isDateInToday(date)
        case .thisWeek:
            // Use 7-day rolling window from today (not calendar week)
            let startOfToday = calendar.startOfDay(for: now)
            guard let sevenDaysLater = calendar.date(byAdding: .day, value: 7, to: startOfToday) else {
                return false
            }
            return date >= startOfToday && date < sevenDaysLater
        case .thisWeekend:
            // Find the next Friday, Saturday, Sunday (or current day if already weekend)
            let startOfToday = calendar.startOfDay(for: now)
            let weekday = calendar.component(.weekday, from: now) // 1=Sun, 7=Sat
            
            // Calculate days until Friday (6)
            var daysUntilFriday = (6 - weekday + 7) % 7
            if daysUntilFriday == 0 && weekday != 6 {
                daysUntilFriday = 7 // If today is not Friday, go to next Friday
            }
            if weekday == 1 { // Sunday - we're already in weekend, start from today
                daysUntilFriday = 0
            } else if weekday == 7 { // Saturday - we're already in weekend, start from yesterday actually means today
                daysUntilFriday = 0
            } else if weekday == 6 { // Friday
                daysUntilFriday = 0
            }
            
            // Simpler approach: just check if date falls on Fri/Sat/Sun within the next 7 days
            let dateWeekday = calendar.component(.weekday, from: date)
            let isFridaySaturdaySunday = dateWeekday == 6 || dateWeekday == 7 || dateWeekday == 1
            
            guard let sevenDaysLater = calendar.date(byAdding: .day, value: 7, to: startOfToday) else {
                return false
            }
            
            return date >= startOfToday && date < sevenDaysLater && isFridaySaturdaySunday
        case .thisMonth:
            // Use 30-day rolling window from today (not calendar month)
            let startOfToday = calendar.startOfDay(for: now)
            guard let thirtyDaysLater = calendar.date(byAdding: .day, value: 30, to: startOfToday) else {
                return false
            }
            return date >= startOfToday && date < thirtyDaysLater
        case .custom(let customDate):
            return calendar.isDate(date, inSameDayAs: customDate)
        }
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
