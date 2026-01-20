import SwiftUI
import CoreLocation
import MapKit
import UserNotifications

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
    @State private var isCreating = false
    @State private var maxAttendeesText = ""
    @State private var isKeyboardVisible = false
    
    private var maxAttendees: Int? {
        guard !maxAttendeesText.isEmpty else { return nil }
        return Int(maxAttendeesText)
    }
    
    // Invite friends state
    @State private var friendSearchText = ""
    @State private var friendSearchResults: [FriendSearchResult] = []
    @State private var invitedFriends: [FriendSearchResult] = []
    
    @StateObject private var followService = FollowService()
    
    private let geocoder = CLGeocoder()
    
    init(initialCoordinate: CLLocationCoordinate2D? = nil, initialAddress: String? = nil) {
        if let coordinate = initialCoordinate {
            _geocodedCoordinate = State(initialValue: coordinate)
            _isGeocoding = State(initialValue: false)
        }
        if let address = initialAddress {
            _addressText = State(initialValue: address)
        }
    }
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !addressText.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        ZStack {
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
                
                // Max Attendees section
                Section {
                    HStack {
                        Text("Max Attendees")
                        Spacer()
                        TextField("Unlimited", text: $maxAttendeesText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .onChange(of: maxAttendeesText) { _, newValue in
                                // Only allow numbers
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered != newValue {
                                    maxAttendeesText = filtered
                                }
                            }
                    }
                } header: {
                    Text("Attendee Limit")
                } footer: {
                    if let max = maxAttendees {
                        Text("Only \(max) people can RSVP as going.")
                    } else {
                        Text("Leave blank for unlimited attendees.")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
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
                    .disabled(!isFormValid || isGeocoding || isCreating)
                }
            }
            } // closes NavigationStack
            
            // Floating keyboard dismiss button - hovers above keyboard
            if isKeyboardVisible {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            HapticManager.lightTap()
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.7))
                                )
                                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 12)
                    }
                }
                .transition(.opacity)
            }
        } // closes ZStack
        .onReceive(Foundation.NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(Foundation.NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
    }
    
    private func geocodeAndCreatePlan() {
        Logger.info("Create button tapped - starting geocodeAndCreatePlan")
        
        // If we already have coordinates from suggestion selection, use them
        if let coordinate = geocodedCoordinate {
            Logger.info("Using existing coordinates: \(coordinate.latitude), \(coordinate.longitude)")
            createPlan(latitude: coordinate.latitude, longitude: coordinate.longitude)
            return
        }
        
        Logger.info("No coordinates - starting geocoding for: \(addressText)")
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
                    Logger.error("No placemark found")
                    return
                }
                
                Logger.info("Geocoded successfully: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                createPlan(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            }
        }
    }
    
    private func createPlan(latitude: Double, longitude: Double) {
        // Prevent double-submission
        guard !isCreating else {
            Logger.warning("createPlan called while already creating - ignoring duplicate")
            return
        }
        isCreating = true
        
        Task {
            defer { isCreating = false }
            
            // Create a plan ID upfront so we can track it
            let newPlanId = UUID()
            
            await planStore.createPlanWithId(
                id: newPlanId,
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
                isPrivate: isPrivate,
                maxAttendees: maxAttendees
            )
            
            // Send invite notifications to selected friends (await to ensure they're sent)
            Logger.info("🎯 CreatePlanView: Plan created, invitedFriends.count = \(invitedFriends.count)")
            if !invitedFriends.isEmpty {
                Logger.info("🎯 CreatePlanView: About to call inviteUsers for \(invitedFriends.map { $0.name })")
                // Create a temporary Plan object for the invite
                let newPlan = Plan(
                    id: newPlanId,
                    hostUserId: sessionStore.currentUser.id,
                    title: title,
                    description: description,
                    startsAt: startsAt,
                    latitude: latitude,
                    longitude: longitude,
                    emoji: selectedEmoji,
                    activityType: selectedActivityType,
                    addressText: addressText,
                    isPrivate: isPrivate,
                    hostName: sessionStore.currentUser.name,
                    hostAvatar: sessionStore.currentUser.avatarUrl
                )
                
                await planStore.inviteUsers(to: newPlan, users: invitedFriends, currentUser: sessionStore.currentUser)
                Logger.info("🎯 CreatePlanView: inviteUsers call completed")
            } else {
                Logger.info("🎯 CreatePlanView: No invited friends, skipping inviteUsers")
            }
            
            // Auto-zoom to the newly created event on the map
            if let newPlan = planStore.plans.first(where: { $0.id == newPlanId }) {
                planStore.planToShowOnMap = newPlan
            }
            
            // Request push notification permission if not yet determined (e.g. first event created)
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                Logger.info("Requesting push notification permission after creating first event")
                let _ = await PushNotificationManager.requestPermission()
            }
            
            dismiss()
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
        Logger.info("🔍 searchFriends called with query: '\(query)'")
        guard !query.isEmpty else {
            friendSearchResults = []
            return
        }
        
        Task {
            // Search from followers/following
            let results = await followService.searchFriends(query: query)
            Logger.info("🔍 searchFriends got \(results.count) results for query '\(query)'")
            friendSearchResults = results.map { FriendSearchResult(id: $0.id, name: $0.name, avatarUrl: $0.avatarUrl) }
        }
    }
    
    func addInvite(_ friend: FriendSearchResult) {
        Logger.info("➕ addInvite called for \(friend.name) (id: \(friend.id))")
        if !invitedFriends.contains(where: { $0.id == friend.id }) {
            invitedFriends.append(friend)
            Logger.info("➕ Added \(friend.name) to invitedFriends, count is now: \(invitedFriends.count)")
            HapticManager.lightTap()
        } else {
            Logger.info("➕ \(friend.name) already in invitedFriends, skipping")
        }
        friendSearchText = ""
        friendSearchResults = []
    }
    
    func removeInvite(_ friend: FriendSearchResult) {
        invitedFriends.removeAll { $0.id == friend.id }
        Logger.info("➖ Removed \(friend.name) from invitedFriends, count is now: \(invitedFriends.count)")
    }
}

#Preview {
    CreatePlanView()
        .environmentObject(PlanStore())
        .environmentObject(SessionStore())
}
