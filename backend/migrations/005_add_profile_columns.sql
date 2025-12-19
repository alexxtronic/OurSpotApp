-- OurSpot Database Migration 005
-- Add missing profile columns for extended bio and stats
-- Created: 2025-12-19

-- Add columns if they don't exist
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS country_of_birth TEXT,
ADD COLUMN IF NOT EXISTS favorite_song TEXT,
ADD COLUMN IF NOT EXISTS fun_fact TEXT,
ADD COLUMN IF NOT EXISTS profile_color TEXT,
ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS referral_source TEXT,
ADD COLUMN IF NOT EXISTS followers_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS following_count INTEGER DEFAULT 0;

-- Refresh the schema cache hint (optional, but good practice)
NOTIFY pgrst, 'reload schema';
