import SwiftUI
import MapKit

/// Shared form fields for creating and editing plans
/// Used by both CreatePlanView and EditPlanView for consistency
struct PlanFormFields: View {
    @Binding var title: String
    @Binding var description: String
    @Binding var selectedActivityType: ActivityType
    @Binding var selectedEmoji: String
    @Binding var startsAt: Date
    @Binding var addressText: String
    @Binding var isPrivate: Bool
    @Binding var geocodedCoordinate: CLLocationCoordinate2D?
    
    @StateObject private var addressCompleter = AddressCompleter()
    
    var body: some View {
        // What's the plan?
        Section("What's the plan?") {
            TextField("Title", text: $title)
            TextField("Description", text: $description, axis: .vertical)
                .lineLimit(3...6)
        }
        
        // Category - simple dropdown with emoji + text
        Section("Category") {
            Picker("Activity Type", selection: $selectedActivityType) {
                ForEach(ActivityType.allCases) { type in
                    Text("\(type.defaultEmoji) \(type.displayName)")
                        .tag(type)
                }
            }
            .onChange(of: selectedActivityType) { _, newValue in
                selectedEmoji = newValue.defaultEmoji
            }
        }
        
        // When?
        Section("When?") {
            DatePicker(
                "Date & Time",
                selection: $startsAt,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
        }
        
        // Where?
        Section("Where?") {
            TextField("Address", text: $addressText)
                .textContentType(.fullStreetAddress)
                .onChange(of: addressText) { _, newValue in
                    addressCompleter.search(query: newValue)
                }
            
            if !addressCompleter.suggestions.isEmpty {
                ForEach(addressCompleter.suggestions, id: \.self) { suggestion in
                    Button {
                        selectSuggestion(suggestion)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(suggestion.title)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Text(suggestion.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            if geocodedCoordinate != nil {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Location confirmed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        
        // Privacy setting
        Section {
            Toggle(isOn: $isPrivate) {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading) {
                        Text("Make Private")
                            .font(.body)
                        Text("You'll approve each attendee")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("Privacy")
        } footer: {
            if isPrivate {
                Text("Guests won't see exact location until you approve them.")
            }
        }
    }
    
    private func selectSuggestion(_ suggestion: MKLocalSearchCompletion) {
        addressText = "\(suggestion.title), \(suggestion.subtitle)"
        addressCompleter.suggestions = []
        
        // Use MKLocalSearch instead of CLGeocoder - more reliable for MapKit suggestions
        let searchRequest = MKLocalSearch.Request(completion: suggestion)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            if let coordinate = response?.mapItems.first?.placemark.coordinate {
                geocodedCoordinate = coordinate
                Logger.info("Address geocoded via MKLocalSearch: \(coordinate.latitude), \(coordinate.longitude)")
            } else if let error = error {
                Logger.error("MKLocalSearch error: \(error.localizedDescription)")
            }
        }
    }
}
