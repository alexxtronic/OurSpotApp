import SwiftUI

/// Animated map marker for events with pulsing effect
struct AnimatedMapMarker: View {
    let emoji: String
    let color: Color
    var isSelected: Bool = false
    var isLive: Bool = false
    
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // Pulsing ring for live events
            if isLive {
                Circle()
                    .stroke(color.opacity(0.5), lineWidth: 2)
                    .frame(width: 60, height: 60)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0 : 0.8)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                            isPulsing = true
                        }
                    }
            }
            
            // Selection ring
            if isSelected {
                Circle()
                    .stroke(color, lineWidth: 3)
                    .frame(width: 52, height: 52)
            }
            
            // Main marker body
            ZStack {
                // Shadow circle
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .offset(y: 2)
                    .blur(radius: 4)
                
                // Main circle with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                
                // Emoji
                Text(emoji)
                    .font(.system(size: 22))
            }
            .scaleEffect(isSelected ? 1.15 : 1.0)
            .animation(DesignSystem.Animation.springy, value: isSelected)
        }
    }
}

/// Floating card that appears above map with event preview
struct FloatingEventCard: View {
    let plan: Plan
    let onTap: () -> Void
    
    @State private var isAppearing = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Emoji with gradient background
                ZStack {
                    Circle()
                        .fill(DesignSystem.Gradients.primary)
                        .frame(width: 48, height: 48)
                    Text(plan.emoji)
                        .font(.title2)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(plan.startsAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(DesignSystem.Spacing.sm)
            .background(.ultraThinMaterial)
            .cornerRadius(DesignSystem.CornerRadius.lg)
            .shadowStyle(DesignSystem.Shadows.large)
        }
        .buttonStyle(.plain)
        .scaleEffect(isAppearing ? 1.0 : 0.8)
        .opacity(isAppearing ? 1.0 : 0)
        .onAppear {
            withAnimation(DesignSystem.Animation.springy) {
                isAppearing = true
            }
        }
    }
}

/// Event card for lists with premium styling
struct PremiumEventCard: View {
    let plan: Plan
    let attendeeCount: Int
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Header with emoji and time
                HStack {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Gradients.primary)
                            .frame(width: 44, height: 44)
                        Text(plan.emoji)
                            .font(.title3)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(plan.activityType.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Live badge if event is happening now
                    if plan.isHappeningNow {
                        HStack(spacing: 4) {
                            PulsingDot(color: .green)
                            Text("LIVE")
                                .font(.caption2.bold())
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                    }
                }
                
                // Location
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(DesignSystem.Colors.primaryFallback)
                    Text(plan.addressText ?? "Location TBD")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Divider()
                
                // Footer with time and attendees
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundColor(.orange)
                        Text(plan.startsAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.purple)
                        AnimatedCounter(value: attendeeCount)
                            .font(.subheadline.bold())
                        Text("going")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.secondaryBackground)
            .cornerRadius(DesignSystem.CornerRadius.lg)
            .shadowStyle(DesignSystem.Shadows.medium)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(DesignSystem.Animation.quick, value: isPressed)
        }
        .buttonStyle(.plain)
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

// Extension to check if event is live
extension Plan {
    var isHappeningNow: Bool {
        let now = Date()
        let eventEnd = startsAt.addingTimeInterval(3 * 60 * 60) // Assume 3 hour duration
        return now >= startsAt && now <= eventEnd
    }
}

#Preview {
    VStack(spacing: 20) {
        AnimatedMapMarker(emoji: "🎉", color: .purple, isLive: true)
        AnimatedMapMarker(emoji: "🍻", color: .orange, isSelected: true)
        AnimatedMapMarker(emoji: "🎵", color: .blue)
    }
    .padding()
}
