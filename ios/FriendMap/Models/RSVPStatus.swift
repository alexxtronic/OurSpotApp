import Foundation

/// RSVP status for a plan
enum RSVPStatus: String, Codable, CaseIterable {
    case none
    case going
    case maybe
    case pending  // For private events awaiting host approval
    case invited  // User has been invited but hasn't responded
    
    var displayText: String {
        switch self {
        case .none: return "Not Going"
        case .going: return "Going"
        case .maybe: return "Maybe"
        case .pending: return "Pending"
        case .invited: return "Invited"
        }
    }
    
    var icon: String {
        switch self {
        case .none: return "xmark.circle"
        case .going: return "checkmark.circle.fill"
        case .maybe: return "questionmark.circle"
        case .pending: return "clock.circle"
        case .invited: return "envelope.circle"
        }
    }
}
