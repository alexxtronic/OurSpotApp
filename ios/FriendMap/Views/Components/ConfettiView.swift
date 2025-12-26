import SwiftUI

/// Confetti celebration view overlay - bursts from center like a confetti cannon
struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    
    let particleCount = 60
    let emojis = ["🎉", "🎊", "✨", "⭐", "🌟", "💫", "🎈", "🥳", "🎆", "🎀", "💜", "💙", "💚", "💛"]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Text(particle.emoji)
                        .font(.system(size: particle.size))
                        .position(particle.position)
                        .opacity(particle.opacity)
                        .rotationEffect(.degrees(particle.rotation))
                        .scaleEffect(particle.scale)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            HapticManager.celebrationRamp()
            burstConfetti()
        }
    }
    
    private func burstConfetti() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        // Origin point: center bottom (where plus button is)
        let originX = screenWidth / 2
        let originY = screenHeight - 80 // Just above tab bar
        
        for i in 0..<particleCount {
            // Stagger creation slightly for more natural burst
            let creationDelay = Double(i) * 0.008
            
            DispatchQueue.main.asyncAfter(deadline: .now() + creationDelay) {
                // Random angle for burst spread (-60 to 60 degrees from vertical)
                let spreadAngle = Double.random(in: -70...70) * .pi / 180
                
                // Random initial velocity
                let velocity = CGFloat.random(in: 400...700)
                
                // Calculate initial trajectory
                let velocityX = sin(spreadAngle) * velocity
                let velocityY = -cos(spreadAngle) * velocity // Negative = upward
                
                let particle = ConfettiParticle(
                    id: UUID(),
                    emoji: emojis.randomElement()!,
                    position: CGPoint(x: originX, y: originY),
                    size: CGFloat.random(in: 16...28),
                    rotation: Double.random(in: 0...360),
                    opacity: 1.0,
                    scale: CGFloat.random(in: 0.8...1.2),
                    velocityX: velocityX,
                    velocityY: velocityY
                )
                particles.append(particle)
                
                // Phase 1: Burst upward (fast, easeOut)
                let burstDuration = 0.5
                let burstTargetX = originX + velocityX * 0.5
                let burstTargetY = originY + velocityY * 0.5
                
                withAnimation(.easeOut(duration: burstDuration)) {
                    if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                        particles[index].position = CGPoint(x: burstTargetX, y: burstTargetY)
                        particles[index].rotation += Double.random(in: 180...360)
                    }
                }
                
                // Phase 2: Fall with gravity (slower, easeIn)
                DispatchQueue.main.asyncAfter(deadline: .now() + burstDuration) {
                    let fallDuration = Double.random(in: 2.0...3.5)
                    let drift = CGFloat.random(in: -100...100) // Horizontal drift while falling
                    
                    withAnimation(.easeIn(duration: fallDuration)) {
                        if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                            particles[index].position = CGPoint(
                                x: burstTargetX + drift,
                                y: screenHeight + 100 // Fall off screen
                            )
                            particles[index].rotation += Double.random(in: 360...720)
                            particles[index].opacity = 0.3
                        }
                    }
                }
                
                // Phase 3: Cleanup
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    particles.removeAll { $0.id == particle.id }
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
    var scale: CGFloat = 1.0
    let velocityX: CGFloat
    let velocityY: CGFloat
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
