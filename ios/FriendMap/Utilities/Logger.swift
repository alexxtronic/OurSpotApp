import Foundation
import os

/// Lightweight logging utility
enum Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.friendmap"
    private static let logger = os.Logger(subsystem: subsystem, category: "FriendMap")
    
    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }
    
    static func warning(_ message: String) {
        logger.warning("⚠️ \(message, privacy: .public)")
    }
    
    static func error(_ message: String) {
        logger.error("❌ \(message, privacy: .public)")
    }
    
    static func debug(_ message: String) {
        #if DEBUG
        logger.debug("🔍 \(message, privacy: .public)")
        #endif
    }
}
