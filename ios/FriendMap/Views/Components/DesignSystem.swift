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

        // Direct override for Rebranding
        static let primary = Color(hex: "cc990c") ?? .yellow // Dark Gold
        static let secondary = Color(hex: "e8be4a") ?? .orange // Light Gold
        
        // Fallback colors if assets not set up
        static let primaryFallback = Color(hex: "cc990c") ?? .yellow // Dark Gold
        static let secondaryFallback = Color(hex: "e8be4a") ?? .orange // Light Gold
        
        // MARK: - Adaptive Semantic Colors
        // These will automatically adapt to Light/Dark mode
        
        /// Main background color (Black in Dark Mode, White in Light Mode)
        static let screenBackground = Color("ScreenBackground") // Define in Assets or use code below
        
        /// Secondary background for cards/sheets (Dark Gray in Dark Mode, Light Gray/White in Light Mode)
        static let cardBackground = Color("CardBackground")
        
        /// Primary text color (White in Dark Mode, Black in Light Mode)
        static let textPrimary = Color.primary
        
        /// Secondary text color (Light Gray in Dark Mode, Dark Gray in Light Mode)
        static let textSecondary = Color.secondary
        
        /// Input field background
        static let inputBackground = Color.primary.opacity(0.1)
        
        // Legacy/Fixed colors (Use with caution in Light Mode)
        static let background = Color(hex: "000000") ?? .black
        
        // NOW ADAPTIVE: Dark Gray in Dark Mode, System Gray 6 (Light Gray) in Light Mode
        static let secondaryBackground = adaptive(
            dark: Color(hex: "1a1a1a") ?? .gray,
            light: Color(hex: "f2f2f7") ?? .white
        )
        
        static let tertiaryBackground = adaptive(
            dark: Color(hex: "2a2a2a") ?? .gray.opacity(0.5),
            light: Color(hex: "e5e5ea") ?? .gray.opacity(0.2) // Slightly darker for visibility in light mode
        )
        
        // Chat Colors
        static let chatUserBubble = Color.blue.opacity(0.8)
        static let chatOtherBubble = adaptive(
            dark: Color(hex: "2a2a2a") ?? .gray.opacity(0.5),
            light: Color(hex: "e5e5ea") ?? .gray.opacity(0.2)
        )
        
        // Helper to get adaptive color directly from code if Asset catalog updates are delayed
        static func adaptive(dark: Color, light: Color) -> Color {
            Color(UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
            })
        }
        
        // Pre-defined adaptive colors if not using Assets yet
        static let adaptiveBackground = adaptive(dark: .black, light: .white)
        static let adaptiveCard = adaptive(dark: Color(hex: "1a1a1a") ?? .gray, light: Color(hex: "f2f2f7") ?? .white)
        static let adaptiveText = adaptive(dark: .white, light: .black)
        static let adaptiveSecondaryText = adaptive(dark: .gray, light: .gray)
    }
    
    // MARK: - Premium Gradients
    enum Gradients {
        /// Primary brand gradient (Dark Gold to Light Gold)
        static let primary = LinearGradient(
            colors: [Color(hex: "cc990c") ?? .yellow, Color(hex: "e8be4a") ?? .orange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        /// Accent gradient (Light Gold to Black)
        static let accent = LinearGradient(
            colors: [Color(hex: "e8be4a") ?? .orange, Color(hex: "000000") ?? .black],
            startPoint: .leading,
            endPoint: .trailing
        )
        
        /// Success gradient (teal to green) - Keeping as is for now, or could be Gold to Green
        static let success = LinearGradient(
            colors: [Color(hex: "14B8A6") ?? .teal, Color(hex: "22C55E") ?? .green],
            startPoint: .leading,
            endPoint: .trailing
        )
        
        /// Dark card gradient
        static let darkCard = LinearGradient(
            colors: [Color(hex: "1F2937") ?? .black, Color(hex: "111827") ?? .black],
            startPoint: .top,
            endPoint: .bottom
        )
        
        /// Shimmer gradient for loading
        static let shimmer = LinearGradient(
            colors: [
                Color.white.opacity(0.0),
                Color.white.opacity(0.3),
                Color.white.opacity(0.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // MARK: - Fonts
    enum Fonts {
        static let largeTitle = Font.system(.largeTitle, design: .rounded).bold()
        static let title = Font.system(.title, design: .rounded).bold()
        static let title2 = Font.system(.title2, design: .rounded).weight(.semibold)
        static let headline = Font.system(.headline, design: .rounded)
        static let body = Font.system(.body, design: .default)
        static let caption = Font.system(.caption, design: .default)
    }
    
    // MARK: - Shadows
    enum Shadows {
        static let small = ShadowStyle(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        static let medium = ShadowStyle(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        static let large = ShadowStyle(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
        static let glow = ShadowStyle(color: Color(hex: "e8be4a")?.opacity(0.5) ?? .yellow.opacity(0.5), radius: 20, x: 0, y: 0)
    }
    
    // MARK: - Animation
    enum Animation {
        static let springy = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.7)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let quick = SwiftUI.Animation.easeOut(duration: 0.15)
        static let bouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
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
    
    /// Adds a premium press effect with scale and haptic feedback
    func pressEffect() -> some View {
        self.modifier(PressEffectModifier())
    }
    
    /// Adds a shimmer loading effect
    func shimmer(isActive: Bool = true) -> some View {
        self.modifier(ShimmerModifier(isActive: isActive))
    }
    
    /// Adds glassmorphism background
    func glassBackground(cornerRadius: CGFloat = DesignSystem.CornerRadius.lg) -> some View {
        self
            .background(.ultraThinMaterial)
            .cornerRadius(cornerRadius)
    }
    
    /// Premium card styling with shadow and corner radius
    func premiumCard() -> some View {
        self
            .background(DesignSystem.Colors.secondaryBackground)
            .cornerRadius(DesignSystem.CornerRadius.lg)
            .shadowStyle(DesignSystem.Shadows.medium)
    }
    
    /// Gradient border effect
    func gradientBorder(lineWidth: CGFloat = 2) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .stroke(DesignSystem.Gradients.primary, lineWidth: lineWidth)
        )
    }
}

// MARK: - Press Effect Modifier
struct PressEffectModifier: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .opacity(isPressed ? 0.9 : 1.0)
            .animation(DesignSystem.Animation.quick, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in 
                        isPressed = false
                        HapticManager.lightTap()
                    }
            )
    }
}

// MARK: - Shimmer Effect Modifier
struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    if isActive {
                        DesignSystem.Gradients.shimmer
                            .frame(width: geometry.size.width * 2)
                            .offset(x: phase * geometry.size.width * 2 - geometry.size.width)
                            .onAppear {
                                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                    phase = 1
                                }
                            }
                    }
                }
            )
            .mask(content)
    }
}

// MARK: - Skeleton Loading View
struct SkeletonView: View {
    let width: CGFloat?
    let height: CGFloat
    
    init(width: CGFloat? = nil, height: CGFloat = 20) {
        self.width = width
        self.height = height
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
            .fill(Color.gray.opacity(0.3))
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - Animated Counter View
struct AnimatedCounter: View {
    let value: Int
    @State private var animatedValue: Int = 0
    
    var body: some View {
        Text("\(animatedValue)")
            .contentTransition(.numericText(value: Double(animatedValue)))
            .onAppear {
                withAnimation(DesignSystem.Animation.springy) {
                    animatedValue = value
                }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(DesignSystem.Animation.springy) {
                    animatedValue = newValue
                }
            }
    }
}

// MARK: - Pulsing Dot View
struct PulsingDot: View {
    let color: Color
    @State private var isPulsing = false
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(color, lineWidth: 2)
                    .scaleEffect(isPulsing ? 2 : 1)
                    .opacity(isPulsing ? 0 : 0.8)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
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
