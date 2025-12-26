import SwiftUI

/// Primary button style for main actions
struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isDestructive: Bool = false
    var isDisabled: Bool = false
    var useGradient: Bool = true
    
    @State private var isPressed = false
    
    init(_ title: String, icon: String? = nil, isDestructive: Bool = false, isDisabled: Bool = false, useGradient: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isDestructive = isDestructive
        self.isDisabled = isDisabled
        self.useGradient = useGradient
        self.action = action
    }
    
    var body: some View {
        Button {
            HapticManager.mediumTap()
            action()
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(.body, design: .rounded).weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.sm + 2)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .background(backgroundView)
            .foregroundColor(.white)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(DesignSystem.Animation.quick, value: isPressed)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .shadowStyle(isDestructive ? DesignSystem.Shadows.small : DesignSystem.Shadows.medium)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        if isDestructive {
            Color.red
        } else if useGradient {
            DesignSystem.Gradients.primary
        } else {
            DesignSystem.Colors.primaryFallback
        }
    }
}

/// Secondary button style for less prominent actions
struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isDestructive: Bool = false
    
    init(_ title: String, icon: String? = nil, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .background(isDestructive ? Color.red.opacity(0.1) : DesignSystem.Colors.secondaryBackground)
            .foregroundColor(isDestructive ? .red : .primary)
            .cornerRadius(DesignSystem.CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .strokeBorder(isDestructive ? Color.red.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton("RSVP Going", icon: "checkmark.circle.fill") {}
        PrimaryButton("Block User", icon: "hand.raised.fill", isDestructive: true) {}
        SecondaryButton("Report", icon: "flag.fill", isDestructive: true) {}
        SecondaryButton("Share", icon: "square.and.arrow.up") {}
    }
    .padding()
}
