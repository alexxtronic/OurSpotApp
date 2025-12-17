import Foundation

/// RSVP status for a plan
enum RSVPStatus: String, Codable, CaseIterable {
    case none
    case going
    case maybe
    
    var displayText: String {
        switch self {
        case .none: return "Not Going"
        case .going: return "Going"
        case .maybe: return "Maybe"
        }
    }
    
    var icon: String {
        switch self {
        case .none: return "xmark.circle"
        case .going: return "checkmark.circle.fill"
        case .maybe: return "questionmark.circle"
        }
    }
}
