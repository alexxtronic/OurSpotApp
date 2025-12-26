import Foundation

struct EventChat: Identifiable, Equatable, Hashable {
    let plan: Plan
    var unreadCount: Int
    var lastMessageAt: Date?
    var lastMessagePreview: String?
    
    var id: UUID { plan.id }
    
    // Sort comparator
    static func < (lhs: EventChat, rhs: EventChat) -> Bool {
        // Sort by last message time descending (newest first)
        // If neither has messages, fall back to start date or title
        guard let lhsTime = lhs.lastMessageAt else {
            return false // items without messages go to bottom? or check start date?
        }
        guard let rhsTime = rhs.lastMessageAt else {
            return true 
        }
        return lhsTime > rhsTime
    }
}


