-- OurSpot Database Migration 004
-- Add follows table for social features
-- Created: 2025-12-19

-- ============================================
-- FOLLOWS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS follows (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    follower_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    following_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(follower_id, following_id),
    CHECK (follower_id != following_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_follows_follower ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following ON follows(following_id);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

ALTER TABLE follows ENABLE ROW LEVEL SECURITY;

-- Anyone can read follows (to see counts and lists)
CREATE POLICY "follows_select" ON follows FOR SELECT USING (true);

-- Authenticated users can follow others (insert)
CREATE POLICY "follows_insert" ON follows FOR INSERT WITH CHECK (auth.uid() = follower_id);

-- Authenticated users can unfollow (delete their own follows)
CREATE POLICY "follows_delete" ON follows FOR DELETE USING (auth.uid() = follower_id);
