import SwiftUI
import CoreLocation

/// Form for creating a new plan with emoji picker and address geocoding
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
                        // Auto-update emoji to match activity type default
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
                
                // Location
                Section("Where?") {
                    TextField("Enter address", text: $addressText)
                        .textContentType(.fullStreetAddress)
                        .autocapitalization(.words)
                    
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
                            Text("Location found")
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
    
    private func geocodeAndCreatePlan() {
        isGeocoding = true
        geocodeError = nil
        
        // Append Copenhagen if not already mentioned for better geocoding
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
                
                geocodedCoordinate = location.coordinate
                
                // Create the plan
                planStore.createPlan(
                    title: title,
                    description: description,
                    startsAt: startsAt,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    emoji: selectedEmoji,
                    activityType: selectedActivityType,
                    addressText: addressText,
                    hostUserId: sessionStore.currentUser.id
                )
                
                dismiss()
            }
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
