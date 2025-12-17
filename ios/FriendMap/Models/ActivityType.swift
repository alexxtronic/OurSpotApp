import Foundation

/// Activity type for plans
enum ActivityType: String, Codable, CaseIterable, Identifiable {
    case food
    case drinks
    case sports
    case culture
    case outdoors
    case nightlife
    case social
    case other
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .food: return "Food"
        case .drinks: return "Drinks"
        case .sports: return "Sports"
        case .culture: return "Culture"
        case .outdoors: return "Outdoors"
        case .nightlife: return "Nightlife"
        case .social: return "Social"
        case .other: return "Other"
        }
    }
    
    var defaultEmoji: String {
        switch self {
        case .food: return "🍕"
        case .drinks: return "☕"
        case .sports: return "🏃"
        case .culture: return "🎨"
        case .outdoors: return "🌳"
        case .nightlife: return "🎉"
        case .social: return "👋"
        case .other: return "📍"
        }
    }
    
    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .drinks: return "cup.and.saucer.fill"
        case .sports: return "figure.run"
        case .culture: return "theatermasks.fill"
        case .outdoors: return "leaf.fill"
        case .nightlife: return "party.popper.fill"
        case .social: return "person.2.fill"
        case .other: return "mappin"
        }
    }
}

/// Common emojis for plan selection
enum PlanEmoji {
    static let all: [String] = [
        "🍕", "🍔", "🍣", "🍜", "🍳", "🥗",  // Food
        "☕", "🍺", "🍷", "🧋", "🍹",         // Drinks
        "🏃", "⚽", "🏀", "🎾", "🚴", "🏊",   // Sports
        "🎨", "🎭", "🎬", "📚", "🎵", "🖼️",   // Culture
        "🌳", "🏖️", "⛰️", "🚶", "🧘", "🌅",   // Outdoors
        "🎉", "💃", "🎤", "🎪", "🪩",         // Nightlife
        "👋", "🤝", "💬", "🎮", "🎲",         // Social
        "📍", "⭐", "❤️", "🔥", "✨"          // Other
    ]
}
