-- Migration 029: fix avatar upload RLS -- case-sensitive LIKE never matches
-- 011's "Authenticated Users Upload Avatars" policy compares the object name
-- against `auth.uid() || '.jpg'` using a case-sensitive LIKE. Postgres's
-- auth.uid() renders as lowercase hex, but Swift's UUID().uuidString (used
-- by StorageService.swift to build the filename) renders uppercase hex --
-- so the comparison could never match, for any user, since the bucket was
-- created. Fold both sides to lowercase.

DROP POLICY IF EXISTS "Authenticated Users Upload Avatars" ON storage.objects;
CREATE POLICY "Authenticated Users Upload Avatars"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'avatars'
  AND auth.role() = 'authenticated'
  AND (
    lower(name) = lower(auth.uid()::text || '.jpg')
    OR lower(name) LIKE lower(auth.uid()::text) || '/%'
  )
);
