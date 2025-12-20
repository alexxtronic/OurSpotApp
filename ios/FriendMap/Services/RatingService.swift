import Foundation
import Supabase

@MainActor
final class RatingService: ObservableObject {
    private let supabase: SupabaseClient? = Config.supabase
    
    @Published var myRating: Int?
    
    func fetchMyRating(for userId: UUID) async {
        guard let supabase = supabase,
              let currentUserId = supabase.auth.currentUser?.id else { return }
        
        do {
            let response: [UserRatingDTO] = try await supabase
                .from("user_ratings")
                .select()
                .eq("rater_id", value: currentUserId)
                .eq("rated_id", value: userId)
                .execute()
                .value
            
            self.myRating = response.first?.rating
        } catch {
            Logger.error("Error fetching rating: \(error.localizedDescription)")
        }
    }
    
    func rateUser(userId: UUID, rating: Int) async {
        guard let supabase = supabase,
              let currentUserId = supabase.auth.currentUser?.id else { return }
        
        let ratingEntry = UserRatingInsertDTO(
            rater_id: currentUserId,
            rated_id: userId,
            rating: rating
        )
        
        do {
            try await supabase
                .from("user_ratings")
                .upsert(ratingEntry, onConflict: "rater_id, rated_id")
                .execute()
            
            self.myRating = rating
        } catch {
            Logger.error("Error rating user: \(error.localizedDescription)")
        }
    }
}

struct UserRatingDTO: Decodable {
    let id: UUID
    let rater_id: UUID
    let rated_id: UUID
    let rating: Int
    let created_at: Date
}

struct UserRatingInsertDTO: Encodable {
    let rater_id: UUID
    let rated_id: UUID
    let rating: Int
}
