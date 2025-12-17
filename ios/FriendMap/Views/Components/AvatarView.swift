import SwiftUI

/// Circular avatar view with placeholder support
struct AvatarView: View {
    let name: String
    let size: CGFloat
    let assetName: String?
    
    init(name: String, size: CGFloat = 44, assetName: String? = nil) {
        self.name = name
        self.size = size
        self.assetName = assetName
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(gradientForName)
            
            if let assetName = assetName, UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .strokeBorder(Color.white, lineWidth: size > 40 ? 3 : 2)
        )
        .shadowStyle(DesignSystem.Shadows.small)
    }
    
    private var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
    
    private var gradientForName: LinearGradient {
        let colors = avatarColors
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var avatarColors: [Color] {
        let hash = name.hashValue
        let colorSets: [[Color]] = [
            [Color(red: 0.25, green: 0.47, blue: 0.85), Color(red: 0.4, green: 0.6, blue: 0.9)],
            [Color(red: 0.94, green: 0.36, blue: 0.45), Color(red: 0.98, green: 0.5, blue: 0.55)],
            [Color(red: 0.55, green: 0.35, blue: 0.85), Color(red: 0.7, green: 0.5, blue: 0.9)],
            [Color(red: 0.2, green: 0.7, blue: 0.6), Color(red: 0.35, green: 0.8, blue: 0.7)],
            [Color(red: 0.95, green: 0.5, blue: 0.2), Color(red: 0.98, green: 0.65, blue: 0.35)],
            [Color(red: 0.85, green: 0.25, blue: 0.6), Color(red: 0.9, green: 0.4, blue: 0.7)]
        ]
        let index = abs(hash) % colorSets.count
        return colorSets[index]
    }
}

#Preview {
    HStack(spacing: 16) {
        AvatarView(name: "Emma Hansen", size: 60)
        AvatarView(name: "Oliver Nielsen", size: 60)
        AvatarView(name: "Sofia Andersen", size: 60)
    }
    .padding()
}
