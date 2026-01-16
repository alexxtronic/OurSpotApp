import Foundation
import Supabase
import SwiftUI

@MainActor
final class StorageService: ObservableObject {
    private let supabase: SupabaseClient? = Config.supabase
    private let bucketName = "avatars"
    
    /// Uploads a profile photo and returns the public URL
    /// Deletes any existing avatar first to ensure only one photo per user
    /// - Parameters:
    ///   - data: The image data (JPEG/PNG)
    ///   - userId: The user's ID to name the file consistently
    func uploadAvatar(data: Data, userId: UUID) async throws -> URL? {
        guard let supabase = supabase else { return nil }
        
        // File path: {userId}.jpg (overwrites previous)
        let fileName = "\(userId.uuidString).jpg"
        let fileOptions = FileOptions(upsert: true)
        
        do {
            // 1. Delete existing avatar first (ensures clean storage)
            do {
                try await supabase.storage
                    .from(bucketName)
                    .remove(paths: [fileName])
                Logger.debug("🗑️ Deleted old avatar for user \(userId)")
            } catch {
                // Ignore errors if file doesn't exist
                Logger.debug("No existing avatar to delete for user \(userId)")
            }
            
            // 2. Upload new avatar
            try await supabase.storage
                .from(bucketName)
                .upload(fileName, data: data, options: fileOptions)
            
            // 3. Get Public URL
            let baseUrl = try supabase.storage
                .from(bucketName)
                .getPublicURL(path: fileName)
            
            // 4. Add cache-busting timestamp to force refresh
            let cacheBustedUrl = URL(string: "\(baseUrl.absoluteString)?t=\(Int(Date().timeIntervalSince1970))")
            
            Logger.info("✅ Uploaded avatar for user \(userId): \(cacheBustedUrl?.absoluteString ?? "nil")")
            
            return cacheBustedUrl ?? baseUrl
        } catch {
            Logger.error("Storage upload error: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Clear cached avatar for a specific URL
    static func clearCachedAvatar(for url: URL?) {
        guard let url = url else { return }
        // Clear from ImageCache
        ImageCache.shared.remove(for: url)
    }
}
