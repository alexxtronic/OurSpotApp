import Foundation

/// Copenhagen location preset for plan creation
struct LocationPreset: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let latitude: Double
    let longitude: Double
}

/// Mock data for the app
enum MockData {
    // Copenhagen center coordinates
    static let copenhagenCenter = (latitude: 55.6761, longitude: 12.5683)
    
    // Preset Copenhagen spots
    static let copenhagenSpots: [LocationPreset] = [
        LocationPreset(name: "Nyhavn", latitude: 55.6796, longitude: 12.5891),
        LocationPreset(name: "Tivoli Gardens", latitude: 55.6737, longitude: 12.5681),
        LocationPreset(name: "The Little Mermaid", latitude: 55.6929, longitude: 12.5996),
        LocationPreset(name: "Strøget", latitude: 55.6771, longitude: 12.5729),
        LocationPreset(name: "Freetown Christiania", latitude: 55.6714, longitude: 12.5967),
        LocationPreset(name: "Rosenborg Castle", latitude: 55.6859, longitude: 12.5773),
        LocationPreset(name: "Copenhagen Street Food", latitude: 55.6803, longitude: 12.5910),
        LocationPreset(name: "Assistens Cemetery", latitude: 55.6912, longitude: 12.5498),
        LocationPreset(name: "Superkilen", latitude: 55.7012, longitude: 12.5389),
        LocationPreset(name: "Amager Strandpark", latitude: 55.6549, longitude: 12.6496)
    ]
    
    // Mock user IDs and names
    static let mockUsers: [(id: UUID, name: String, avatar: String)] = [
        (UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, "Emma Hansen", "avatar1"),
        (UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, "Oliver Nielsen", "avatar2"),
        (UUID(uuidString: "33333333-3333-3333-3333-333333333333")!, "Sofia Andersen", "avatar3"),
        (UUID(uuidString: "44444444-4444-4444-4444-444444444444")!, "William Larsen", "avatar4"),
        (UUID(uuidString: "55555555-5555-5555-5555-555555555555")!, "Freja Petersen", "avatar5"),
        (UUID(uuidString: "66666666-6666-6666-6666-666666666666")!, "Noah Jensen", "avatar6")
    ]
    
    static var hostNames: [UUID: String] {
        Dictionary(uniqueKeysWithValues: mockUsers.map { ($0.id, $0.name) })
    }
    
    static var hostAvatars: [UUID: String] {
        Dictionary(uniqueKeysWithValues: mockUsers.map { ($0.id, $0.avatar) })
    }
    
    // Mock plans around Copenhagen
    static var samplePlans: [Plan] {
        let calendar = Calendar.current
        let now = Date()
        
        return [
            Plan(
                id: UUID(),
                hostUserId: mockUsers[0].id,
                title: "Coffee at Nyhavn",
                description: "Let's grab coffee and watch the boats! I know a great spot with outdoor seating.",
                startsAt: calendar.date(byAdding: .hour, value: 2, to: now)!,
                latitude: copenhagenSpots[0].latitude,
                longitude: copenhagenSpots[0].longitude,
                emoji: "☕",
                activityType: .drinks,
                addressText: "Nyhavn 17, Copenhagen"
            ),
            Plan(
                id: UUID(),
                hostUserId: mockUsers[1].id,
                title: "Tivoli Evening",
                description: "Friday night at Tivoli! Meeting at the main entrance. Bring your adventurous spirit!",
                startsAt: calendar.date(byAdding: .day, value: 1, to: now)!,
                latitude: copenhagenSpots[1].latitude,
                longitude: copenhagenSpots[1].longitude,
                emoji: "🎢",
                activityType: .nightlife,
                addressText: "Vesterbrogade 3, Copenhagen"
            ),
            Plan(
                id: UUID(),
                hostUserId: mockUsers[2].id,
                title: "Running Group",
                description: "Morning run around the lakes. All paces welcome! We'll do 5-7km depending on the group.",
                startsAt: calendar.date(byAdding: .day, value: 2, to: now)!,
                latitude: copenhagenSpots[5].latitude,
                longitude: copenhagenSpots[5].longitude,
                emoji: "🏃",
                activityType: .sports,
                addressText: "Rosenborg Castle Gardens"
            ),
            Plan(
                id: UUID(),
                hostUserId: mockUsers[3].id,
                title: "Street Food Dinner",
                description: "Exploring Copenhagen Street Food market. So many cuisines to try!",
                startsAt: calendar.date(byAdding: .hour, value: 28, to: now)!,
                latitude: copenhagenSpots[6].latitude,
                longitude: copenhagenSpots[6].longitude,
                emoji: "🍜",
                activityType: .food,
                addressText: "Reffen, Refshalevej 167"
            ),
            Plan(
                id: UUID(),
                hostUserId: mockUsers[4].id,
                title: "Sunset at Strøget",
                description: "Shopping and sunset walk through the pedestrian street. Maybe ice cream after?",
                startsAt: calendar.date(byAdding: .hour, value: 6, to: now)!,
                latitude: copenhagenSpots[3].latitude,
                longitude: copenhagenSpots[3].longitude,
                emoji: "🌅",
                activityType: .social,
                addressText: "Strøget, Copenhagen"
            ),
            Plan(
                id: UUID(),
                hostUserId: mockUsers[5].id,
                title: "Beach Day at Amager",
                description: "Beach hangout! Bring sunscreen, snacks, and good vibes. We have a volleyball.",
                startsAt: calendar.date(byAdding: .day, value: 3, to: now)!,
                latitude: copenhagenSpots[9].latitude,
                longitude: copenhagenSpots[9].longitude,
                emoji: "🏖️",
                activityType: .outdoors,
                addressText: "Amager Strandpark"
            ),
            Plan(
                id: UUID(),
                hostUserId: mockUsers[0].id,
                title: "Art Walk at Superkilen",
                description: "Exploring the colorful urban park. Great for photos and a casual stroll.",
                startsAt: calendar.date(byAdding: .hour, value: 48, to: now)!,
                latitude: copenhagenSpots[8].latitude,
                longitude: copenhagenSpots[8].longitude,
                emoji: "🎨",
                activityType: .culture,
                addressText: "Superkilen, Nørrebro"
            ),
            Plan(
                id: UUID(),
                hostUserId: mockUsers[2].id,
                title: "Christiania Tour",
                description: "First-timer friendly walk through Freetown. Cameras away in certain areas!",
                startsAt: calendar.date(byAdding: .day, value: 4, to: now)!,
                latitude: copenhagenSpots[4].latitude,
                longitude: copenhagenSpots[4].longitude,
                emoji: "🌿",
                activityType: .culture,
                addressText: "Freetown Christiania"
            )
        ]
    }
}
