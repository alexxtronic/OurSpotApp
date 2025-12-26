import SwiftUI

/// Skeleton loading views for premium loading states
struct EventCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                SkeletonView(width: 44, height: 44)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonView(width: 120, height: 16)
                    SkeletonView(width: 80, height: 12)
                }
                
                Spacer()
            }
            
            SkeletonView(width: 180, height: 14)
            
            Divider()
            
            HStack {
                SkeletonView(width: 100, height: 14)
                Spacer()
                SkeletonView(width: 60, height: 14)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.secondaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
}

/// Skeleton for profile view
struct ProfileSkeleton: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Avatar
            SkeletonView(width: 100, height: 100)
                .clipShape(Circle())
            
            // Name
            SkeletonView(width: 150, height: 24)
            
            // Bio
            VStack(spacing: 8) {
                SkeletonView(height: 14)
                SkeletonView(width: 200, height: 14)
            }
            
            // Stats row
            HStack(spacing: DesignSystem.Spacing.xl) {
                StatSkeleton()
                StatSkeleton()
                StatSkeleton()
            }
        }
        .padding()
    }
}

struct StatSkeleton: View {
    var body: some View {
        VStack(spacing: 4) {
            SkeletonView(width: 40, height: 20)
            SkeletonView(width: 50, height: 12)
        }
    }
}

/// Skeleton for chat messages
struct ChatMessageSkeleton: View {
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer() }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                SkeletonView(width: CGFloat.random(in: 100...200), height: 16)
                SkeletonView(width: CGFloat.random(in: 80...150), height: 16)
            }
            .padding(DesignSystem.Spacing.sm)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(DesignSystem.CornerRadius.md)
            
            if !isFromCurrentUser { Spacer() }
        }
    }
}

/// Full list skeleton with multiple cards
struct EventListSkeleton: View {
    let count: Int
    
    init(count: Int = 3) {
        self.count = count
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ForEach(0..<count, id: \.self) { _ in
                EventCardSkeleton()
            }
        }
        .padding(.horizontal)
    }
}

/// Loading overlay with blur background
struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: DesignSystem.Spacing.md) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(DesignSystem.Spacing.xl)
            .glassBackground()
        }
    }
}

/// Empty state view with illustration and CTA
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    @State private var isAnimating = false
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(DesignSystem.Gradients.primary.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(DesignSystem.Gradients.primary)
            }
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear { isAnimating = true }
            
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Fonts.title2)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                PrimaryButton(actionTitle, icon: "plus.circle.fill", action: action)
                    .frame(maxWidth: 200)
            }
        }
        .padding(DesignSystem.Spacing.xl)
    }
}

#Preview("Skeletons") {
    ScrollView {
        VStack(spacing: 20) {
            EventCardSkeleton()
            EventCardSkeleton()
            
            Divider()
            
            EmptyStateView(
                icon: "calendar.badge.plus",
                title: "No Events Yet",
                message: "Create your first event and invite friends!",
                actionTitle: "Create Event"
            ) {
                // Create action
            }
        }
        .padding()
    }
}
