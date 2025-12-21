import Foundation

/// Activity type for plans
enum ActivityType: String, Codable, CaseIterable, Identifiable {
    case social
    case drinks
    case coffee
    case food
    case gaming
    case movies
    case sports
    case culture
    case outdoors
    case nightlife
    case other
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .social: return "Casual hang"
        case .drinks: return "Grab drinks"
        case .coffee: return "Grab a coffee"
        case .food: return "Get food"
        case .gaming: return "Play games"
        case .movies: return "Watch something"
        case .sports: return "Get active"
        case .culture: return "Art & culture"
        case .outdoors: return "Go outside"
        case .nightlife: return "Party time"
        case .other: return "Something else"
        }
    }
    
    var defaultEmoji: String {
        switch self {
        case .social: return "👋"
        case .drinks: return "🍺"
        case .coffee: return "☕"
        case .food: return "🍕"
        case .gaming: return "🎮"
        case .movies: return "🍿"
        case .sports: return "🏃"
        case .culture: return "🎨"
        case .outdoors: return "🌳"
        case .nightlife: return "🎉"
        case .other: return "📍"
        }
    }
    
    var icon: String {
        switch self {
        case .social: return "person.2.fill"
        case .drinks: return "wineglass.fill"
        case .coffee: return "cup.and.saucer.fill"
        case .food: return "fork.knife"
        case .gaming: return "gamecontroller.fill"
        case .movies: return "film.fill"
        case .sports: return "figure.run"
        case .culture: return "theatermasks.fill"
        case .outdoors: return "leaf.fill"
        case .nightlife: return "party.popper.fill"
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
