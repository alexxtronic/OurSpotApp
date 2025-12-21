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
    @State private var isPrivate = false
    
    // Invite friends state
    @State private var friendSearchText = ""
    @State private var friendSearchResults: [FriendSearchResult] = []
    @State private var invitedFriends: [FriendSearchResult] = []
    
    @StateObject private var followService = FollowService()
    
    private let geocoder = CLGeocoder()
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !description.trimmingCharacters(in: .whitespaces).isEmpty &&
        !addressText.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Shared form fields (title, category, when, where, privacy)
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
                
                // Invite Friends section (Create-only)
                Section {
                    TextField("Search friends...", text: $friendSearchText)
                        .textContentType(.name)
                        .onChange(of: friendSearchText) { _, newValue in
                            searchFriends(query: newValue)
                        }
                    
                    // Search results
                    if !friendSearchResults.isEmpty && !friendSearchText.isEmpty {
                        ForEach(friendSearchResults, id: \.id) { user in
                            Button {
                                addInvite(user)
                            } label: {
                                HStack {
                                    AvatarView(
                                        name: user.name,
                                        size: 32,
                                        url: URL(string: user.avatarUrl ?? "")
                                    )
                                    Text(user.name)
                                    Spacer()
                                    if invitedFriends.contains(where: { $0.id == user.id }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    } else {
                                        Image(systemName: "plus.circle")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Invited friends chips
                    if !invitedFriends.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(invitedFriends, id: \.id) { friend in
                                HStack(spacing: 4) {
                                    Text(friend.name)
                                        .font(.subheadline)
                                    Button {
                                        removeInvite(friend)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.15))
                                .cornerRadius(16)
                            }
                        }
                    }
                } header: {
                    Text("Invite Friends (Optional)")
                } footer: {
                    Text("Invited friends will receive a notification.")
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
        Task {
            await planStore.createPlan(
                title: title,
                description: description,
                startsAt: startsAt,
                latitude: latitude,
                longitude: longitude,
                emoji: selectedEmoji,
                activityType: selectedActivityType,
                addressText: addressText,
                hostUserId: sessionStore.currentUser.id,
                hostName: sessionStore.currentUser.name,
                hostAvatar: sessionStore.currentUser.avatarUrl,
                isPrivate: isPrivate
            )
            
            // Send invite notifications to selected friends
            if !invitedFriends.isEmpty {
                // Get the newly created plan ID (it's the last one added)
                if let newPlan = planStore.plans.last {
                    sendInviteNotifications(planId: newPlan.id, planTitle: title)
                }
            }
            
            dismiss()
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

// MARK: - Friend Search Model

struct FriendSearchResult: Identifiable, Equatable {
    let id: UUID
    let name: String
    let avatarUrl: String?
}

// MARK: - Flow Layout for Chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0
        
        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var maxHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > width && x > 0 {
                    x = 0
                    y += maxHeight + spacing
                    maxHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                maxHeight = max(maxHeight, size.height)
                x += size.width + spacing
            }
            height = y + maxHeight
        }
    }
}

// MARK: - CreatePlanView Extension

extension CreatePlanView {
    func searchFriends(query: String) {
        guard !query.isEmpty else {
            friendSearchResults = []
            return
        }
        
        Task {
            // Search from followers/following
            let results = await followService.searchFriends(query: query)
            friendSearchResults = results.map { FriendSearchResult(id: $0.id, name: $0.name, avatarUrl: $0.avatarUrl) }
        }
    }
    
    func addInvite(_ friend: FriendSearchResult) {
        if !invitedFriends.contains(where: { $0.id == friend.id }) {
            invitedFriends.append(friend)
            HapticManager.lightTap()
        }
        friendSearchText = ""
        friendSearchResults = []
    }
    
    func removeInvite(_ friend: FriendSearchResult) {
        invitedFriends.removeAll { $0.id == friend.id }
    }
    
    func sendInviteNotifications(planId: UUID, planTitle: String) {
        for friend in invitedFriends {
            let notification = AppNotification.eventInvite(
                from: sessionStore.currentUser.name,
                eventName: planTitle,
                planId: planId,
                userId: sessionStore.currentUser.id
            )
            // This sends local notification - push would require backend
            NotificationCenter.shared.addNotification(notification)
        }
    }
}

#Preview {
    CreatePlanView()
        .environmentObject(PlanStore())
        .environmentObject(SessionStore())
}
