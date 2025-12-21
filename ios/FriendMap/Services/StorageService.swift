import Foundation
import Supabase
import SwiftUI

@MainActor
final class StorageService: ObservableObject {
    private let supabase: SupabaseClient? = Config.supabase
    private let bucketName = "avatars"
    
    /// Uploads a profile photo and returns the public URL
    /// - Parameters:
    ///   - data: The image data (JPEG/PNG)
    ///   - userId: The user's ID to name the file consistently
    func uploadAvatar(data: Data, userId: UUID) async throws -> URL? {
        guard let supabase = supabase else { return nil }
        
        // File path: {userId}/avatar.jpg (overwrites previous)
        // Or just {userId}.jpg to keep it simple at root of bucket
        let fileName = "\(userId.uuidString).jpg"
        let fileOptions = FileOptions(upsert: true)
        
        do {
            // 1. Upload (new API)
            try await supabase.storage
                .from(bucketName)
                .upload(fileName, data: data, options: fileOptions)
            
            // 2. Get Public URL (new API)
            let baseUrl = try supabase.storage
                .from(bucketName)
                .getPublicURL(path: fileName)
            
            // 3. Add cache-busting timestamp to force refresh
            let cacheBustedUrl = URL(string: "\(baseUrl.absoluteString)?t=\(Int(Date().timeIntervalSince1970))")
            
            return cacheBustedUrl ?? baseUrl
        } catch {
            Logger.error("Storage upload error: \(error.localizedDescription)")
            throw error
        }
    }
}
