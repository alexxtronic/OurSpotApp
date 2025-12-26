import Foundation
import Supabase

@MainActor
final class RatingService: ObservableObject {
    private let supabase: SupabaseClient? = Config.supabase
    
    @Published var myRating: Int?
    @Published var targetUserRatingAverage: Double = 0.0
    @Published var targetUserRatingCount: Int = 0
    
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
    
    /// Fetches the aggregate rating for a user
    func fetchAggregateRating(for userId: UUID) async {
        guard let supabase = supabase else { return }
        
        do {
            let response: [UserRatingDTO] = try await supabase
                .from("user_ratings")
                .select()
                .eq("rated_id", value: userId)
                .execute()
                .value
            
            let ratings = response.map { Double($0.rating) }
            self.targetUserRatingCount = ratings.count
            self.targetUserRatingAverage = ratings.isEmpty ? 0.0 : ratings.reduce(0, +) / Double(ratings.count)
            
            Logger.debug("Fetched aggregate rating for \(userId): \(self.targetUserRatingAverage) (\(self.targetUserRatingCount) reviews)")
        } catch {
            Logger.error("Error fetching aggregate rating: \(error.localizedDescription)")
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
            
            // Immediately refresh aggregate rating
            await fetchAggregateRating(for: userId)
            
            // Also update the profile in Supabase with new average
            await updateProfileRating(userId: userId)
            
            Logger.info("Successfully rated user \(userId) with \(rating) stars")
        } catch {
            Logger.error("Error rating user: \(error.localizedDescription)")
        }
    }
    
    /// Updates the user's profile with their new aggregate rating
    private func updateProfileRating(userId: UUID) async {
        guard let supabase = supabase else { return }
        
        let updateDTO = ProfileRatingUpdateDTO(
            rating_average: targetUserRatingAverage,
            rating_count: targetUserRatingCount
        )
        
        do {
            try await supabase
                .from("profiles")
                .update(updateDTO)
                .eq("id", value: userId)
                .execute()
            
            Logger.debug("Updated profile rating for \(userId)")
        } catch {
            Logger.error("Error updating profile rating: \(error.localizedDescription)")
        }
    }
}

struct ProfileRatingUpdateDTO: Encodable {
    let rating_average: Double
    let rating_count: Int
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
