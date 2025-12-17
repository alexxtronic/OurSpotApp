import SwiftUI
import CoreLocation
import MapKit

/// Form for creating a new plan with emoji picker and address autocomplete
struct CreatePlanView: View {
    @EnvironmentObject private var planStore: PlanStore
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var startsAt = Date().addingTimeInterval(3600) // 1 hour from now
    @State private var addressText = ""
    @State private var selectedEmoji = "📍"
    @State private var selectedActivityType: ActivityType = .social
    @State private var showEmojiPicker = false
    @State private var isGeocoding = false
    @State private var geocodedCoordinate: CLLocationCoordinate2D?
    @State private var geocodeError: String?
    
    @StateObject private var addressCompleter = AddressCompleter()
    
    private let geocoder = CLGeocoder()
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty &&
        !addressText.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Title and Description
                Section("What's the plan?") {
                    TextField("Title", text: $title)
                        .textContentType(.none)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // Emoji and Activity Type
                Section("Category") {
                    HStack {
                        Text("Icon")
                        Spacer()
                        Button {
                            showEmojiPicker = true
                        } label: {
                            Text(selectedEmoji)
                                .font(.title)
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    Picker("Activity Type", selection: $selectedActivityType) {
                        ForEach(ActivityType.allCases) { type in
                            HStack {
                                Text(type.defaultEmoji)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    .onChange(of: selectedActivityType) { _, newValue in
                        selectedEmoji = newValue.defaultEmoji
                    }
                }
                
                // Date and Time
                Section("When?") {
                    DatePicker(
                        "Date & Time",
                        selection: $startsAt,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                
                // Location with autocomplete
                Section("Where?") {
                    TextField("Start typing an address...", text: $addressText)
                        .textContentType(.fullStreetAddress)
                        .autocapitalization(.words)
                        .onChange(of: addressText) { _, newValue in
                            addressCompleter.search(query: newValue)
                            geocodedCoordinate = nil
                            geocodeError = nil
                        }
                    
                    // Address suggestions
                    if !addressCompleter.suggestions.isEmpty && geocodedCoordinate == nil {
                        ForEach(addressCompleter.suggestions, id: \.self) { suggestion in
                            Button {
                                selectSuggestion(suggestion)
                            } label: {
                                HStack {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(DesignSystem.Colors.primaryFallback)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(suggestion.title)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        if !suggestion.subtitle.isEmpty {
                                            Text(suggestion.subtitle)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    if isGeocoding {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Finding location...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let error = geocodeError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
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
            }
            .navigationTitle("Create Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        geocodeAndCreatePlan()
                    }
                    .font(.headline)
                    .disabled(!isFormValid || isGeocoding)
                }
            }
            .sheet(isPresented: $showEmojiPicker) {
                EmojiPickerView(selectedEmoji: $selectedEmoji)
                    .presentationDetents([.medium])
            }
        }
    }
    
    private func selectSuggestion(_ suggestion: MKLocalSearchCompletion) {
        // Set address text from suggestion
        let fullAddress = suggestion.subtitle.isEmpty 
            ? suggestion.title 
            : "\(suggestion.title), \(suggestion.subtitle)"
        addressText = fullAddress
        addressCompleter.suggestions.removeAll()
        
        // Geocode the selected suggestion
        isGeocoding = true
        let searchRequest = MKLocalSearch.Request(completion: suggestion)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            DispatchQueue.main.async {
                isGeocoding = false
                
                if let item = response?.mapItems.first {
                    geocodedCoordinate = item.placemark.coordinate
                    Logger.info("Selected location: \(item.name ?? "Unknown")")
                } else {
                    geocodeError = "Couldn't find exact location"
                }
            }
        }
    }
    
    private func geocodeAndCreatePlan() {
        // If we already have coordinates from suggestion selection, use them
        if let coordinate = geocodedCoordinate {
            createPlan(latitude: coordinate.latitude, longitude: coordinate.longitude)
            return
        }
        
        isGeocoding = true
        geocodeError = nil
        
        // Append Copenhagen if not already mentioned
        let searchAddress = addressText.lowercased().contains("copenhagen") || addressText.lowercased().contains("københavn")
            ? addressText
            : "\(addressText), Copenhagen, Denmark"
        
        geocoder.geocodeAddressString(searchAddress) { placemarks, error in
            DispatchQueue.main.async {
                isGeocoding = false
                
                if let error = error {
                    geocodeError = "Couldn't find location. Try a more specific address."
                    Logger.error("Geocoding error: \(error.localizedDescription)")
                    return
                }
                
                guard let placemark = placemarks?.first,
                      let location = placemark.location else {
                    geocodeError = "Location not found"
                    return
                }
                
                createPlan(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            }
        }
    }
    
    private func createPlan(latitude: Double, longitude: Double) {
        planStore.createPlan(
            title: title,
            description: description,
            startsAt: startsAt,
            latitude: latitude,
            longitude: longitude,
            emoji: selectedEmoji,
            activityType: selectedActivityType,
            addressText: addressText,
            hostUserId: sessionStore.currentUser.id
        )
        dismiss()
    }
}

/// Observable class that handles address autocomplete using MKLocalSearchCompleter
@MainActor
class AddressCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [MKLocalSearchCompletion] = []
    
    private let completer: MKLocalSearchCompleter
    
    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        
        // Focus search on Copenhagen area
        let copenhagenRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 55.6761, longitude: 12.5683),
            span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
        )
        completer.region = copenhagenRegion
    }
    
    func search(query: String) {
        guard query.count >= 2 else {
            suggestions = []
            return
        }
        completer.queryFragment = query
    }
    
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            // Limit to 5 suggestions for cleaner UI
            self.suggestions = Array(completer.results.prefix(5))
        }
    }
    
    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            Logger.error("Address completer error: \(error.localizedDescription)")
            self.suggestions = []
        }
    }
}

/// Emoji picker grid view
struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    @Environment(\.dismiss) private var dismiss
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(PlanEmoji.all, id: \.self) { emoji in
                        Button {
                            selectedEmoji = emoji
                            dismiss()
                        } label: {
                            Text(emoji)
                                .font(.largeTitle)
                                .frame(width: 50, height: 50)
                                .background(selectedEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CreatePlanView()
        .environmentObject(PlanStore())
        .environmentObject(SessionStore())
}
