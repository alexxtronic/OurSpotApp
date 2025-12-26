import SwiftUI

/// Map annotation view for a cluster of multiple plans
struct ClusterAnnotationView: View {
    let cluster: PlanCluster
    let scale: CGFloat
    
    private let baseSize: CGFloat = 52
    private var scaledSize: CGFloat { baseSize * scale }
    
    var body: some View {
        ZStack {
            // Main glass bubble (similar to regular pin)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.85),
                            Color.white.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: scaledSize, height: scaledSize)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.9),
                                    Color.white.opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
            
            // Pin emoji - clear and prominent
            Text("📍")
                .font(.system(size: 26 * scale))
        }
        // Orange badge in upper-right corner with count
        .overlay(alignment: .topTrailing) {
            Text("\(cluster.count)")
                .font(.system(size: 11 * scale, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 5 * scale)
                .padding(.vertical, 2 * scale)
                .background(
                    Capsule()
                        .fill(Color.orange)
                        .shadow(color: .orange.opacity(0.4), radius: 3, x: 0, y: 1)
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
