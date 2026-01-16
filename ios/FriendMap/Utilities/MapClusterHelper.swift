import Foundation
import CoreLocation

/// Represents a cluster of plans on the map
struct PlanCluster: Identifiable {
    let id: String
    let plans: [Plan]
    
    init(plans: [Plan]) {
        self.plans = plans
        if plans.count == 1, let first = plans.first {
             self.id = first.id.uuidString
        } else {
             // Generate a stable sorted ID for the cluster to prevent flickering
             self.id = plans.map { $0.id.uuidString }.sorted().joined(separator: "-")
        }
    }
    
    /// Center coordinate of the cluster (average of all plan coordinates)
    var center: CLLocationCoordinate2D {
        guard !plans.isEmpty else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        
        let avgLat = plans.reduce(0.0) { $0 + $1.latitude } / Double(plans.count)
        let avgLon = plans.reduce(0.0) { $0 + $1.longitude } / Double(plans.count)
        return CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
    }
    
    /// Number of plans in the cluster
    var count: Int { plans.count }
    
    /// Whether this cluster represents a single plan (no clustering)
    var isSingle: Bool { plans.count == 1 }
    
    /// The single plan if isSingle, otherwise nil
    var singlePlan: Plan? { isSingle ? plans.first : nil }
    
    /// Representative emoji for the cluster (uses first plan's emoji)
    var emoji: String { plans.first?.emoji ?? "📍" }
}

/// Helper for computing map annotation clusters
struct MapClusterHelper {
    
    /// Clusters plans based on their proximity at the current zoom level
    /// - Parameters:
    ///   - plans: Array of plans to cluster
    ///   - span: Current map span (latitude delta) - larger span = more zoomed out
    ///   - clusterThreshold: Distance threshold for clustering (in degrees, relative to span)
    /// - Returns: Array of clusters (single plans are returned as clusters of 1)
    static func clusterPlans(
        _ plans: [Plan],
        span: Double,
        clusterThreshold: Double = 0.05 // Reduced from 0.08 for less aggressive clustering
    ) -> [PlanCluster] {
        guard !plans.isEmpty else { return [] }
        
        // At very close zoom levels (span < 0.01), don't cluster at all
        if span < 0.01 {
            return plans.map { PlanCluster(plans: [$0]) }
        }
        
        // Distance threshold scales with zoom level
        let threshold = span * clusterThreshold
        
        var remainingPlans = plans
        var clusters: [PlanCluster] = []
        
        while !remainingPlans.isEmpty {
            let basePlan = remainingPlans.removeFirst()
            var clusterPlans = [basePlan]
            
            // Find all plans within threshold distance
            var i = 0
            while i < remainingPlans.count {
                let candidate = remainingPlans[i]
                let distance = sqrt(
                    pow(basePlan.latitude - candidate.latitude, 2) +
                    pow(basePlan.longitude - candidate.longitude, 2)
                )
                
                if distance < threshold {
                    clusterPlans.append(candidate)
                    remainingPlans.remove(at: i)
                } else {
                    i += 1
                }
            }
            
            clusters.append(PlanCluster(plans: clusterPlans))
        }
        
        return clusters
    }
}
