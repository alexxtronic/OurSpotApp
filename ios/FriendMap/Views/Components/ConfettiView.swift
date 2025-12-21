import SwiftUI

/// Confetti celebration view overlay
struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var isAnimating = false
    
    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .cyan, .mint]
    let particleCount = 50
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Text(particle.emoji)
                        .font(.system(size: particle.size))
                        .position(particle.position)
                        .opacity(particle.opacity)
                        .rotationEffect(.degrees(particle.rotation))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            HapticManager.celebrationRamp()
            startConfetti()
        }
    }
    
    private func startConfetti() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let emojis = ["🎉", "🎊", "✨", "⭐", "🌟", "💫", "🎈", "🥳", "🎆"]
        
        for i in 0..<particleCount {
            let delay = Double.random(in: 0...0.3)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // Start from bottom center area
                let startX = CGFloat.random(in: (screenWidth * 0.3)...(screenWidth * 0.7))
                let particle = ConfettiParticle(
                    id: UUID(),
                    emoji: emojis.randomElement()!,
                    position: CGPoint(
                        x: startX,
                        y: screenHeight + 20
                    ),
                    size: CGFloat.random(in: 20...36),
                    rotation: Double.random(in: 0...360),
                    opacity: 1.0
                )
                particles.append(particle)
                
                // Animate bursting upward and outward
                let targetX = CGFloat.random(in: 0...screenWidth)
                let targetY = CGFloat.random(in: screenHeight * 0.1...screenHeight * 0.5)
                
                withAnimation(.easeOut(duration: Double.random(in: 1.5...2.5))) {
                    if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                        particles[index].position = CGPoint(x: targetX, y: targetY)
                        particles[index].rotation += Double.random(in: 360...720)
                    }
                }
                
                // Then fade out and fall
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeIn(duration: 1.5)) {
                        if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                            particles[index].position.y = screenHeight + 50
                            particles[index].opacity = 0
                        }
                    }
                }
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id: UUID
    let emoji: String
    var position: CGPoint
    let size: CGFloat
    var rotation: Double
    var opacity: Double
}

/// View modifier to easily add confetti
struct ConfettiModifier: ViewModifier {
    @Binding var isShowing: Bool
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isShowing {
                ConfettiView()
                    .ignoresSafeArea()
                    .onAppear {
                        // Auto-hide after animation completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            isShowing = false
                        }
                    }
            }
        }
    }
}

extension View {
    func confetti(isShowing: Binding<Bool>) -> some View {
        modifier(ConfettiModifier(isShowing: isShowing))
    }
}

#Preview {
    Color.white
        .confetti(isShowing: .constant(true))
}
