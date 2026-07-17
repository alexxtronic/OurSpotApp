-- OurSpot Database Migration 011
-- Storage Setup
-- Created: 2025-12-21

-- IMPORTANT: You must manually create a bucket named 'avatars' in the Supabase Dashboard > Storage
-- This script sets up the policies for that bucket.

-- Note: RLS is already enabled on storage.objects by default in Supabase,
-- and it's owned by supabase_storage_admin, so we don't (and can't) re-enable it here.

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
