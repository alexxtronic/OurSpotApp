import Foundation

/// Activity type for plans
enum ActivityType: String, Codable, CaseIterable, Identifiable {
    case social     // Casual hang - Default
    case exploreTheCity
    case sports     // Get active
    case coffee
    case drinks     // Grab drinks
    case food
    case partyTime
    case nightlife
    case culture    // Art & culture
    case liveMusic
    case outdoors   // Nature
    case movies     // Watch something
    case other
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .sports: return "Get active"
        case .social: return "Casual hang"
        case .drinks: return "Grab drinks"
        case .coffee: return "Grab a coffee"
        case .food: return "Get food"
        case .movies: return "Watch something"
        case .culture: return "Art & culture"
        case .outdoors: return "Go outside"
        case .nightlife: return "Nightlife"
        case .exploreTheCity: return "Explore the City"
        case .partyTime: return "Party Time"
        case .liveMusic: return "Live music"
        case .other: return "Something else"
        }
    }
    
    var defaultEmoji: String {
        switch self {
        case .sports: return "🏃"
        case .social: return "👋"
        case .drinks: return "🍺"
        case .coffee: return "☕"
        case .food: return "🍽️"
        case .movies: return "🍿"
        case .culture: return "🎨"
        case .outdoors: return "🌳"
        case .nightlife: return "🪩"
        case .exploreTheCity: return "🗺️"
        case .partyTime: return "🎉"
        case .liveMusic: return "🎸"
        case .other: return "📍"
        }
    }
    
    /// Asset name for the 3D icon
    var icon: String {
        switch self {
        case .sports: return "sports"
        case .social: return "social"
        case .drinks: return "drinks"
        case .coffee: return "coffee"
        case .food: return "food"
        case .movies: return "movies"
        case .culture: return "culture"
        case .outdoors: return "nature" // Mapped to nature icon
        case .nightlife: return "nightlife"
        case .exploreTheCity: return "explorethecity"
        case .partyTime: return "partytime"
        case .liveMusic: return "livemusic"
        case .other: return "other"
        }
    }
    
    /// Curated emojis for this activity type - shown in custom emoji picker
    var availableEmojis: [String] {
        switch self {
        case .sports:
            return ["🏃", "⚽", "🏀", "🎾", "🏓", "🏐", "🏈", "⚾", "🏒", "🏸",
                    "🚴", "🏊", "🧘", "🏋️", "🤸", "⛷️", "🏂", "🛹", "🥊", "🤾",
                    "🧗", "🏌️", "🎿", "🛼", "🚣", "🎳", "💪", "🏆"]
        case .social:
            return ["👋", "🤝", "💬", "🎲", "♟️", "🃏", "🧩", "📺", "🛋️", "🏠",
                    "☕", "🍵", "🧁", "🎂", "🎈", "🤗", "😊", "👯", "🙌", "✨"]
        case .drinks:
            return ["🍺", "🍻", "🥂", "🍷", "🍸", "🍹", "🥃", "🍾", "🧉", "🍶",
                    "🥤", "🧃", "🫗", "🪩", "🌃", "🍊", "🍋", "🫒", "🧊", "🔥"]
        case .coffee:
            return ["☕", "🧋", "🍵", "🫖", "🥐", "🥯", "🍩", "🧁", "🍪", "🥧",
                    "📖", "💻", "📝", "🎧", "☀️", "🌤️", "🪴", "💭", "✨", "🤎"]
        case .food:
            return ["🍽️", "🍕", "🍔", "🍣", "🍜", "🍝", "🌮", "🌯", "🥗", "🍱",
                    "🍛", "🥘", "🍲", "🥙", "🧆", "🍳", "🥞", "🧇", "🍖", "🍗",
                    "🍤", "🦐", "🦞", "🦑", "🍰", "🎂", "🍨", "🍦"]
        case .movies:
            return ["🍿", "🎬", "🎥", "📽️", "🎞️", "📺", "🛋️", "🎭", "👀", "🎧",
                    "🥤", "🍫", "🍭", "🍬", "😱", "😂", "😭", "🤔", "⭐", "🌟"]
        case .culture:
            return ["🎨", "🖼️", "🎭", "🎪", "📚", "📖", "🏛️", "🗽", "🏰", "⛩️",
                    "🕌", "🎻", "🎼", "✍️", "🖌️", "📷", "🔭", "🔬", "🧬", "💡"]
        case .outdoors:
            return ["🌳", "🏕️", "⛰️", "🏔️", "🌲", "🌴", "🏖️", "🌊", "🚶", "🥾",
                    "🧗", "🏄", "🛶", "🚣", "🎣", "🌅", "🌄", "🦋", "🐿️", "🌸",
                    "🌺", "🌻", "🍂", "❄️", "☀️", "🌈", "⛺", "🔦"]
        case .nightlife:
            return ["🌙", "🌃", "🏙️", "🍸", "🍹", "🌚", "🎆", "🎇", "🌠", "🕯️",
                    "🔥", "💫", "✨", "😈", "🕺", "💃", "🕶️", "🪩", "🎰", "🎲"]
        case .exploreTheCity:
            return ["🗺️", "🏙️", "🚶", "📸", "🚲", "🛴", "🚕", "🚌", "🚇", "🌉",
                    "🏰", "🏛️", "🏢", "🏬", "🏪", "🏫", "🏩", "💒", "🎡", "⛲"]
        case .partyTime:
            return ["🎉", "🎊", "🪩", "🥳", "👯", "👯‍♂️", "👯‍♀️", "🍻", "🥂", "🍾",
                    "🥤", "🎈", "🎁", "🎂", "🍰", "🧁", "🍭", "🍬", "🍫", "🍿"]
        case .liveMusic:
            return ["🎸", "🎹", "🎷", "🎺", "🥁", "🎻", "🎤", "🎵", "🎶", "🎼",
                    "🎧", "🔊", "🎪", "🎫", "🤘", "🙌", "👏", "🔥", "⭐", "✨"]
        case .other:
            return ["📍", "⭐", "❤️", "🔥", "✨", "🎯", "💡", "🚀", "🌟", "💫",
                    "🎁", "🎀", "💝", "🦄", "🌈", "☀️", "🌙", "⚡", "💎", "🏅"]
        }
    }
}



