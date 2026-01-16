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
    @State private var showEmojiPicker = false
    
    var body: some View {
        // What's the plan?
        Section {
            TextField("Title", text: $title)
                .onChange(of: title) { _, newValue in
                    if newValue.count > 70 {
                        title = String(newValue.prefix(70))
                    }
                }
            
            TextField("Description", text: $description, axis: .vertical)
                .lineLimit(3...6)
        } header: {
            Text("What's the plan?")
        } footer: {
            Text("\(title.count)/70 characters")
                .foregroundColor(title.count >= 70 ? .orange : .secondary)
        }
        
        // Category - simple dropdown with emoji + text
        Section("Category") {
            Menu {
                ForEach(ActivityType.allCases) { type in
                    Button {
                        selectedActivityType = type
                        HapticManager.lightTap()
                    } label: {
                        Label(type.displayName, image: type.icon)
                    }
                }
            } label: {
                HStack {
                    Text("Activity Type")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(selectedActivityType.displayName)
                        .foregroundColor(.secondary)
                    Image(selectedActivityType.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48) // Increased size for visibility
                }
            }
            .onChange(of: selectedActivityType) { _, newValue in
                selectedEmoji = newValue.defaultEmoji
            }
            
            // Custom emoji picker button
            Button {
                showEmojiPicker = true
                HapticManager.lightTap()
            } label: {
                HStack {
                    Text("Custom Emoji")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(selectedEmoji)
                        .font(.system(size: 28))
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .sheet(isPresented: $showEmojiPicker) {
                EmojiPickerView(
                    activityType: selectedActivityType,
                    selectedEmoji: $selectedEmoji
                )
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
                        Text("Only people you invite can see this event")
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

// MARK: - Emoji Picker View

/// Emoji picker sheet that shows emojis based on the selected activity type
struct EmojiPickerView: View {
    let activityType: ActivityType
    @Binding var selectedEmoji: String
    @Environment(\.dismiss) private var dismiss
    
    private let columns = [
        GridItem(.adaptive(minimum: 44, maximum: 60), spacing: 8)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header showing which category
                    HStack {
                        Text(activityType.defaultEmoji)
                            .font(.system(size: 24))
                        Text(activityType.displayName)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Emoji grid
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(activityType.availableEmojis, id: \.self) { emoji in
                            EmojiButton(
                                emoji: emoji,
                                isSelected: selectedEmoji == emoji,
                                action: {
                                    selectedEmoji = emoji
                                    HapticManager.lightTap()
                                    dismiss()
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Pick an Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

/// Individual emoji button with selection state
private struct EmojiButton: View {
    let emoji: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(emoji)
                .font(.system(size: 32))
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.orange.opacity(0.3) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isSelected)
    }
}
