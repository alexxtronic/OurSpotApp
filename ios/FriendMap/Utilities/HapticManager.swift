import UIKit

/// Centralized haptic feedback manager
enum HapticManager {
    
    // MARK: - Simple Haptics
    
    /// Light tap - for small actions like navigation
    static func lightTap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    /// Medium tap - for confirmations
    static func mediumTap() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// Success feedback
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    /// Error feedback
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    // MARK: - Complex Haptics
    
    /// Celebratory ramp-up haptic pattern for confetti
    /// Starts soft and builds to a satisfying finale
    static func celebrationRamp() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
        let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
        
        // Prepare generators
        generator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        
        // Ramping pattern: light -> medium -> heavy
        DispatchQueue.main.async {
            generator.impactOccurred(intensity: 0.3)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            generator.impactOccurred(intensity: 0.5)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            mediumGenerator.impactOccurred(intensity: 0.7)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            mediumGenerator.impactOccurred(intensity: 0.9)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            heavyGenerator.impactOccurred(intensity: 1.0)
        }
        // Final success notification
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let notificationGenerator = UINotificationFeedbackGenerator()
            notificationGenerator.notificationOccurred(.success)
        }
    }
}
