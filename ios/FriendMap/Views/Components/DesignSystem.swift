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

    // MARK: - Vibe Colors
    enum VibeColors {
        static let neonPink = Color(hex: "FF10F0") ?? .pink
        static let electricBlue = Color(hex: "00FFFF") ?? .blue
        static let slimeGreen = Color(hex: "39FF14") ?? .green
        static let hotOrange = Color(hex: "FF5E00") ?? .orange
        static let cyberPurple = Color(hex: "BF00FF") ?? .purple
        static let brightYellow = Color(hex: "FFFF00") ?? .yellow
        static let coolMint = Color(hex: "98FF98") ?? .green.opacity(0.8)
        static let radicalRed = Color(hex: "FF355E") ?? .red
        
        static let all: [Color] = [
            neonPink, electricBlue, slimeGreen, hotOrange,
            cyberPurple, brightYellow, coolMint, radicalRed
        ]
        
        static let allHex: [String] = [
            "FF10F0", "00FFFF", "39FF14", "FF5E00",
            "BF00FF", "FFFF00", "98FF98", "FF355E"
        ]
    }
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Country Helpers
struct CountryInfo: Identifiable, Hashable {
    let id: String // ISO Code
    let name: String
    let flag: String
    
    static let all: [CountryInfo] = {
        Locale.Region.isoRegions
            .filter { $0.subRegions.isEmpty } // Only countries, not continents
            .compactMap { region -> CountryInfo? in
                guard let name = Locale.current.localizedString(forRegionCode: region.identifier) else { return nil }
                return CountryInfo(id: region.identifier, name: name, flag: region.identifier.flagEmoji)
            }
            .sorted { $0.name < $1.name }
    }()
}

extension String {
    var flagEmoji: String {
        let base: UInt32 = 127397
        var s = ""
        for v in self.unicodeScalars {
            s.unicodeScalars.append(UnicodeScalar(base + v.value)!)
        }
        return String(s)
    }
}

extension View {
    func shadowStyle(_ style: ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0

        let length = hexSanitized.count

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0

        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0

        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }
}
