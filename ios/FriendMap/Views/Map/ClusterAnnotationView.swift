import SwiftUI

/// Map annotation view for a cluster of multiple plans
struct ClusterAnnotationView: View {
    let cluster: PlanCluster
    let scale: CGFloat
    
    private let baseSize: CGFloat = 52
    private var scaledSize: CGFloat { baseSize * scale }
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Simple Minimalist Gradient Bubble
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.9),  // Mostly white
                            Color(red: 1.0, green: 0.8, blue: 0.6).opacity(0.85) // Tinge of soft orange at bottom
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: scaledSize, height: scaledSize)
                .overlay(
                    // Shimmering orange/white/black app-themed gradient stroke
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color.orange,
                                    Color.white,
                                    Color.black,
                                    Color.orange
                                ],
                                center: .center
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
            
            // Pin emoji - clear and prominent
            Text("📍")
                .font(.system(size: 24 * scale))
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        }
        .offset(y: isAnimating ? -4 : 0) // Subtle bounce animation
        .onAppear {
            // Add random delay so they don't all bounce in perfect sync
            let delay = Double.random(in: 0...1.0)
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
                .delay(delay)
            ) {
                isAnimating = true
            }
        }
        // Count badge in upper-right corner
        .overlay(alignment: .topTrailing) {
            Text("\(cluster.count)")
                .font(.system(size: 11 * scale, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 5 * scale)
                .padding(.vertical, 2 * scale)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.5, blue: 0.15),
                                    Color(red: 0.95, green: 0.35, blue: 0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                )
                .offset(x: 6, y: -6)
        }
    }
}

#Preview {
    ClusterAnnotationView(
        cluster: PlanCluster(plans: []),
        scale: 1.0
    )
}
