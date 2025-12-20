-- OurSpot Database Migration 011
-- Storage Setup
-- Created: 2025-12-21

-- IMPORTANT: You must manually create a bucket named 'avatars' in the Supabase Dashboard > Storage
-- This script sets up the policies for that bucket.

-- Enable RLS for storage.objects if not already
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 1. Allow Public Access to Avatars (Read)
CREATE POLICY "Public Access to Avatars"
ON storage.objects FOR SELECT
USING ( bucket_id = 'avatars' );

-- 2. Allow Authenticated Users to Upload Avatars (Insert)
-- Checks if the file name starts with their user ID to prevent overwriting others
-- Format: {user_id}.jpg or {user_id}/...
CREATE POLICY "Authenticated Users Upload Avatars"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'avatars' 
  AND auth.role() = 'authenticated'
  AND (name like auth.uid() || '.jpg' OR name like auth.uid() || '/%')
);

-- 3. Allow Owners to Update/Overwrite their Avatars
CREATE POLICY "Users Update Own Avatars"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'avatars' 
  AND auth.uid() = owner
);

-- 4. Allow Owners to Delete their Avatars
CREATE POLICY "Users Delete Own Avatars"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'avatars' 
  AND auth.uid() = owner
);
