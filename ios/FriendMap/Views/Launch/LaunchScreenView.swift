import SwiftUI

/// Animated launch screen with logo reveal and gradient animation
struct LaunchScreenView: View {
    @State private var isAnimating = false
    @State private var showTitle = false
    @State private var showTagline = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var gradientRotation: Double = 0
    
    var body: some View {
        ZStack {
            // Animated gradient background
            animatedGradientBackground
            
            VStack(spacing: 24) {
                // Animated logo
                logoView
                
                // App title with typewriter effect
                if showTitle {
                    Text("OurSpot")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .transition(.scale.combined(with: .opacity))
                }
                
                // Tagline
                if showTagline {
                    Text("Plan. Meet. Vibe.")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Animated Gradient Background
    
    private var animatedGradientBackground: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(hex: "#667eea") ?? .purple,
                    Color(hex: "#764ba2") ?? .purple,
                    Color(hex: "#6B8DD6") ?? .blue
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated overlay circles
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.15), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
                .frame(width: 600, height: 600)
                .offset(x: -100, y: -200)
                .rotationEffect(.degrees(gradientRotation))
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.cyan.opacity(0.2), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 250
                    )
                )
                .frame(width: 500, height: 500)
                .offset(x: 150, y: 300)
                .rotationEffect(.degrees(-gradientRotation))
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                gradientRotation = 360
            }
        }
    }
    
    // MARK: - Logo View
    
    private var logoView: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .cyan.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 140, height: 140)
                .scaleEffect(pulseScale)
                .opacity(2 - pulseScale)
            
            // Glass morphism circle
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 120, height: 120)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.6), .white.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            
            // Inner content - Map pin icon
            ZStack {
                // Pin shape
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0)
            }
        }
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        // Logo reveal
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
            isAnimating = true
        }
        
        // Pulse animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
            pulseScale = 1.5
        }
        
        // Title reveal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showTitle = true
            }
        }
        
        // Tagline reveal
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                showTagline = true
            }
        }
    }
}

/// Launch screen coordinator that handles transition to main app
struct LaunchScreenCoordinator: View {
    @State private var isFinished = false
    let onFinished: () -> Void
    
    var body: some View {
        ZStack {
            if !isFinished {
                LaunchScreenView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            // Complete after 2.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isFinished = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onFinished()
                }
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
