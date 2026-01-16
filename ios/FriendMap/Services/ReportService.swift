import Foundation
import Supabase

struct UserReportInsertDTO: Encodable {
    let reporter_id: UUID
    let reported_id: UUID
    let reason: String
}

@MainActor
final class ReportService: ObservableObject {
    static let shared = ReportService()
    
    private init() {}
    
    func reportUser(reportingUserId: UUID, reportedUserId: UUID, reason: String) async throws {
        guard let supabase = Config.supabase else {
            throw NSError(domain: "ReportService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Supabase not configured"])
        }
        
        let report = UserReportInsertDTO(
            reporter_id: reportingUserId,
            reported_id: reportedUserId,
            reason: reason
        )
        
        try await supabase
            .from("user_reports")
            .insert(report)
            .execute()
            
        Logger.info("✅ Report submitted successfully for user: \(reportedUserId)")
    }
}
