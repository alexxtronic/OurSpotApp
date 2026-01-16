import Foundation

/// Represents a plan/event created by a user
struct Plan: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let hostUserId: UUID
    var title: String
    var description: String
    var startsAt: Date
    var latitude: Double
    var longitude: Double
    var emoji: String
    var activityType: ActivityType
    var addressText: String
    var isPrivate: Bool
    var maxAttendees: Int? // nil = unlimited
    
    // Host details
    var hostName: String
    var hostAvatar: String? // Optional since we might not fetch it initially
    
    var locationName: String {
        if !addressText.isEmpty {
            return addressText
        }
        return MockData.copenhagenSpots.first { spot in
            abs(spot.latitude - latitude) < 0.001 && abs(spot.longitude - longitude) < 0.001
        }?.name ?? "Copenhagen"
    }
}
