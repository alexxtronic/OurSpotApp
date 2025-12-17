import SwiftUI

/// Design system constants for FriendMap
enum DesignSystem {
    // MARK: - Spacing
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    enum CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let full: CGFloat = 9999
    }
    
    // MARK: - Colors
    enum Colors {
        static let primary = Color("Primary", bundle: nil)
        static let secondary = Color("Secondary", bundle: nil)
        
        // Fallback colors if assets not set up
        static let primaryFallback = Color(red: 0.25, green: 0.47, blue: 0.85) // Copenhagen blue
        static let secondaryFallback = Color(red: 0.94, green: 0.36, blue: 0.45) // Coral accent
        static let background = Color(UIColor.systemBackground)
        static let secondaryBackground = Color(UIColor.secondarySystemBackground)
        static let tertiaryBackground = Color(UIColor.tertiarySystemBackground)
    }
    
    // MARK: - Fonts
    enum Fonts {
        static let title = Font.system(.title, design: .rounded).bold()
        static let headline = Font.system(.headline, design: .rounded)
        static let body = Font.system(.body, design: .default)
        static let caption = Font.system(.caption, design: .default)
    }
    
    // MARK: - Shadows
    enum Shadows {
        static let small = ShadowStyle(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        static let medium = ShadowStyle(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    func shadowStyle(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
