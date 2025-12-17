import SwiftUI

/// Reusable section card container
struct SectionCard<Content: View>: View {
    let title: String?
    let content: Content
    
    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if let title = title {
                Text(title)
                    .font(DesignSystem.Fonts.headline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                content
            }
            .padding(DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.Colors.secondaryBackground)
            .cornerRadius(DesignSystem.CornerRadius.lg)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SectionCard(title: "About") {
            Text("This is some content inside the card.")
            Text("Multiple lines work great!")
        }
        
        SectionCard {
            Text("Card without title")
        }
    }
    .padding()
}
