import SwiftUI

/// Custom animated tab bar with premium styling
struct AnimatedTabBar: View {
    @Binding var selectedTab: Int
    let items: [TabBarItem]
    
    @State private var tabPositions: [CGFloat] = []
    @Namespace private var tabNamespace
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                tabButton(for: item, at: index)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 15, y: 5)
        )
        .padding(.horizontal, 20)
    }
    
    private func tabButton(for item: TabBarItem, at index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index
            }
            HapticManager.lightTap()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if selectedTab == index {
                        Circle()
                            .fill(DesignSystem.Gradients.primary)
                            .frame(width: 48, height: 48)
                            .matchedGeometryEffect(id: "tabBackground", in: tabNamespace)
                    }
                    
                    Image(systemName: selectedTab == index ? item.selectedIcon : item.icon)
                        .font(.system(size: 20, weight: selectedTab == index ? .semibold : .regular))
                        .foregroundColor(selectedTab == index ? .white : .gray)
                        .scaleEffect(selectedTab == index ? 1.1 : 1.0)
                }
                .frame(width: 48, height: 48)
                
                Text(item.title)
                    .font(.caption2)
                    .fontWeight(selectedTab == index ? .semibold : .regular)
                    .foregroundColor(selectedTab == index ? DesignSystem.Colors.primaryFallback : .gray)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

struct TabBarItem {
    let title: String
    let icon: String
    let selectedIcon: String
    
    init(title: String, icon: String, selectedIcon: String? = nil) {
        self.title = title
        self.icon = icon
        self.selectedIcon = selectedIcon ?? icon
    }
}

// MARK: - Pull to Refresh with Premium Animation

struct PremiumRefreshControl: View {
    @Binding var isRefreshing: Bool
    let onRefresh: () async -> Void
    
    @State private var pullProgress: CGFloat = 0
    @State private var rotation: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Rotating gradient ring
                Circle()
                    .trim(from: 0, to: isRefreshing ? 0.8 : pullProgress * 0.8)
                    .stroke(
                        DesignSystem.Gradients.primary,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(rotation))
                
                // Center dot
                Circle()
                    .fill(DesignSystem.Gradients.primary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isRefreshing ? 1.0 : pullProgress)
            }
            .frame(maxWidth: .infinity)
            .offset(y: geometry.frame(in: .global).minY > 0 ? geometry.frame(in: .global).minY : 0)
        }
        .frame(height: 60)
        .onChange(of: isRefreshing) { _, newValue in
            if newValue {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            } else {
                rotation = 0
            }
        }
    }
}

// MARK: - Page Transition Modifiers

extension AnyTransition {
    static var slideUp: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }
    
    static var slideFromTrailing: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
    
    static var scaleAndFade: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 1.1).combined(with: .opacity)
        )
    }
    
    static var heroReveal: AnyTransition {
        .modifier(
            active: HeroModifier(scale: 0.8, opacity: 0),
            identity: HeroModifier(scale: 1.0, opacity: 1)
        )
    }
}

struct HeroModifier: ViewModifier {
    let scale: CGFloat
    let opacity: Double
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
    }
}

// MARK: - Bounce Animation on Appear

struct BounceOnAppear: ViewModifier {
    @State private var isVisible = false
    let delay: Double
    
    init(delay: Double = 0) {
        self.delay = delay
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isVisible ? 1.0 : 0.5)
            .opacity(isVisible ? 1.0 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func bounceOnAppear(delay: Double = 0) -> some View {
        modifier(BounceOnAppear(delay: delay))
    }
}

// MARK: - Staggered List Animation

struct StaggeredList<Content: View, Item: Identifiable>: View {
    let items: [Item]
    let spacing: CGFloat
    let content: (Item) -> Content
    
    @State private var visibleItems: Set<Item.ID> = []
    
    init(
        items: [Item],
        spacing: CGFloat = DesignSystem.Spacing.md,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        LazyVStack(spacing: spacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                content(item)
                    .scaleEffect(visibleItems.contains(item.id) ? 1.0 : 0.8)
                    .opacity(visibleItems.contains(item.id) ? 1.0 : 0)
                    .onAppear {
                        let delay = Double(index) * 0.05
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(delay)) {
                            visibleItems.insert(item.id)
                        }
                    }
            }
        }
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isPulsing = false
    
    var body: some View {
        Button(action: {
            HapticManager.mediumTap()
            action()
        }) {
            ZStack {
                // Pulse ring
                Circle()
                    .stroke(DesignSystem.Gradients.primary, lineWidth: 2)
                    .frame(width: 70, height: 70)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .opacity(isPulsing ? 0 : 0.5)
                
                // Main button
                Circle()
                    .fill(DesignSystem.Gradients.primary)
                    .frame(width: 60, height: 60)
                    .shadow(color: DesignSystem.Colors.primaryFallback.opacity(0.4), radius: 10, y: 5)
                
                Image(systemName: icon)
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Success Checkmark Animation

struct SuccessCheckmark: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(DesignSystem.Gradients.success)
                .frame(width: 80, height: 80)
                .scaleEffect(isAnimating ? 1.0 : 0)
            
            Image(systemName: "checkmark")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
                .scaleEffect(isAnimating ? 1.0 : 0)
                .rotationEffect(.degrees(isAnimating ? 0 : -90))
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                isAnimating = true
            }
            HapticManager.success()
        }
    }
}

#Preview("Tab Bar") {
    VStack {
        Spacer()
        AnimatedTabBar(
            selectedTab: .constant(0),
            items: [
                TabBarItem(title: "Map", icon: "map", selectedIcon: "map.fill"),
                TabBarItem(title: "Groups", icon: "person.2", selectedIcon: "person.2.fill"),
                TabBarItem(title: "Plans", icon: "calendar", selectedIcon: "calendar.circle.fill"),
                TabBarItem(title: "Profile", icon: "person", selectedIcon: "person.fill")
            ]
        )
    }
    .background(Color.gray.opacity(0.1))
}
