import SwiftUI

/// Form for creating a new plan
struct CreatePlanView: View {
    @EnvironmentObject private var planStore: PlanStore
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var startsAt = Date().addingTimeInterval(3600) // 1 hour from now
    @State private var selectedLocation: LocationPreset?
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedLocation != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("What's the plan?") {
                    TextField("Title", text: $title)
                        .textContentType(.none)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("When?") {
                    DatePicker(
                        "Date & Time",
                        selection: $startsAt,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                
                Section("Where in Copenhagen?") {
                    ForEach(MockData.copenhagenSpots) { spot in
                        Button {
                            selectedLocation = spot
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(spot.name)
                                        .foregroundColor(.primary)
                                }
                                
                                Spacer()
                                
                                if selectedLocation?.id == spot.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(DesignSystem.Colors.primaryFallback)
                                }
                            }
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
                        createPlan()
                    }
                    .font(.headline)
                    .disabled(!isFormValid)
                }
            }
        }
    }
    
    private func createPlan() {
        guard let location = selectedLocation else { return }
        
        planStore.createPlan(
            title: title,
            description: description,
            startsAt: startsAt,
            location: location,
            hostUserId: sessionStore.currentUser.id
        )
        
        dismiss()
    }
}

#Preview {
    CreatePlanView()
        .environmentObject(PlanStore())
        .environmentObject(SessionStore())
}
