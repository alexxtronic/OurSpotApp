import SwiftUI
import CoreLocation
import MapKit

/// View for editing an existing plan
struct EditPlanView: View {
    let plan: Plan
    @EnvironmentObject private var planStore: PlanStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String
    @State private var description: String
    @State private var startsAt: Date
    @State private var addressText: String
    @State private var selectedEmoji: String
    @State private var selectedActivityType: ActivityType
    @State private var isPrivate: Bool
    @State private var isSaving = false
    @State private var geocodedCoordinate: CLLocationCoordinate2D?
    
    private let geocoder = CLGeocoder()
    
    init(plan: Plan) {
        self.plan = plan
        _title = State(initialValue: plan.title)
        _description = State(initialValue: plan.description)
        _startsAt = State(initialValue: plan.startsAt)
        _addressText = State(initialValue: plan.addressText ?? "")
        _selectedEmoji = State(initialValue: plan.emoji)
        _selectedActivityType = State(initialValue: plan.activityType)
        _isPrivate = State(initialValue: plan.isPrivate)
        _geocodedCoordinate = State(initialValue: CLLocationCoordinate2D(
            latitude: plan.latitude,
            longitude: plan.longitude
        ))
    }
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty &&
        !addressText.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Shared form fields
                PlanFormFields(
                    title: $title,
                    description: $description,
                    selectedActivityType: $selectedActivityType,
                    selectedEmoji: $selectedEmoji,
                    startsAt: $startsAt,
                    addressText: $addressText,
                    isPrivate: $isPrivate,
                    geocodedCoordinate: $geocodedCoordinate
                )
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveChanges()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .bold()
                        }
                    }
                    .disabled(!isFormValid || isSaving)
                }
            }
        }
    }
    
    private func saveChanges() {
        isSaving = true
        
        Task {
            let updatedPlan = Plan(
                id: plan.id,
                hostUserId: plan.hostUserId,
                title: title.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces),
                startsAt: startsAt,
                latitude: geocodedCoordinate?.latitude ?? plan.latitude,
                longitude: geocodedCoordinate?.longitude ?? plan.longitude,
                emoji: selectedEmoji,
                activityType: selectedActivityType,
                addressText: addressText,
                isPrivate: isPrivate,
                hostName: plan.hostName,
                hostAvatar: plan.hostAvatar
            )
            
            do {
                try await planStore.updatePlan(updatedPlan)
                HapticManager.success()
                dismiss()
            } catch {
                Logger.error("Failed to update plan: \(error.localizedDescription)")
                HapticManager.error()
            }
            
            isSaving = false
        }
    }
}
