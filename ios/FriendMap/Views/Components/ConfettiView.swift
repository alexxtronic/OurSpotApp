import SwiftUI

/// Physics-based confetti cannon effect - bursts stars & sparkles from bottom with realistic gravity
struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    
    let particleCount = 50
    // Only stars and sparkles per user request
    let emojis = ["⭐", "🌟", "✨", "💫", "⭐", "🌟", "✨"]
    
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
        
        // Origin: bottom center (confetti cannon position)
        let originX = screenWidth / 2
        let originY = screenHeight - 60
        
        for i in 0..<particleCount {
            // Stagger creation for natural burst
            let creationDelay = Double(i) * 0.015
            
            DispatchQueue.main.asyncAfter(deadline: .now() + creationDelay) {
                // Wide spread angle: -80 to +80 degrees from vertical
                let spreadAngle = Double.random(in: -80...80) * .pi / 180
                
                // Fast upward launch velocity
                let launchSpeed = CGFloat.random(in: 600...1000)
                
                let velocityX = sin(spreadAngle) * launchSpeed
                let velocityY = -cos(spreadAngle) * launchSpeed // Negative = upward
                
                let particle = ConfettiParticle(
                    id: UUID(),
                    emoji: emojis.randomElement()!,
                    position: CGPoint(x: originX + CGFloat.random(in: -15...15), y: originY),
                    size: CGFloat.random(in: 18...28),
                    rotation: Double.random(in: 0...360),
                    opacity: 1.0,
                    scale: CGFloat.random(in: 0.9...1.3),
                    velocityX: velocityX,
                    velocityY: velocityY
                )
                particles.append(particle)
                
                // Phase 1: Burst upward (0.4s - fast arc up)
                let burstDuration = 0.4
                let peakHeight = velocityY * 0.35 // How high it goes
                let horizontalDrift = velocityX * 0.35
                let burstTargetX = originX + horizontalDrift
                let burstTargetY = originY + peakHeight
                
                withAnimation(.easeOut(duration: burstDuration)) {
                    if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                        particles[index].position = CGPoint(x: burstTargetX, y: burstTargetY)
                        particles[index].rotation += Double.random(in: 180...360)
                    }
                }
                
                // Phase 2: Fall with gravity and drift sideways (2-3s)
                DispatchQueue.main.asyncAfter(deadline: .now() + burstDuration) {
                    let fallDuration = Double.random(in: 2.0...3.0)
                    let finalDrift = horizontalDrift * 1.5 + CGFloat.random(in: -60...60)
                    
                    withAnimation(.easeIn(duration: fallDuration)) {
                        if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                            particles[index].position = CGPoint(
                                x: burstTargetX + finalDrift,
                                y: screenHeight + 80
                            )
                            particles[index].rotation += Double.random(in: 360...720)
                            particles[index].opacity = 0.2
                            particles[index].scale *= 0.7
                        }
                    }
                }
                
                // Cleanup after animation
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
    var scale: CGFloat
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
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
    Color.black
        .confetti(isShowing: .constant(true))
}
