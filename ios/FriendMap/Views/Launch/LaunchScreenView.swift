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
                    Text("Plan. Meet. Connect.")
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
    
    // MARK: - Animated Gradient Background
    
    private var animatedGradientBackground: some View {
        ZStack {
            // Base background - Deep Black to Dark Orange
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.2, green: 0.1, blue: 0.05) // Very dark orange/brown at bottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Upper Right Bulb - Vibrant Orange
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.orange.opacity(0.6), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 400
                    )
                )
                .frame(width: 600, height: 600)
                .position(x: UIScreen.main.bounds.width, y: 0) // Top Right corner
                .blur(radius: 50)
            
            // Bottom Left Bulb - Vibrant Orange
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 1.0, green: 0.5, blue: 0.0).opacity(0.5), .clear], // Red-Orange
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
                .frame(width: 500, height: 500)
                .position(x: 0, y: UIScreen.main.bounds.height) // Bottom Left corner
                .blur(radius: 40)
        }
    }
    
    // MARK: - Logo View
    
    private var logoView: some View {
        ZStack {
            // Outer pulse ring - Warm colors
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .orange.opacity(0.3)],
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
            
            // Inner content - High Five Hands Logo
            ZStack {
                Image("AppLogo") // Uses the new uploaded asset
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
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
