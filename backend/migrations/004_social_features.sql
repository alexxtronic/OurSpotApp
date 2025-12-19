-- OurSpot Social Features Migration
-- Run in Supabase SQL Editor

-- ============================================
-- EVENT MESSAGES TABLE (for group chat)
-- ============================================
CREATE TABLE IF NOT EXISTS event_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plan_id UUID NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_event_messages_plan ON event_messages(plan_id);
CREATE INDEX IF NOT EXISTS idx_event_messages_created ON event_messages(created_at);

-- RLS for event messages
ALTER TABLE event_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "event_messages_select" ON event_messages FOR SELECT USING (true);
CREATE POLICY "event_messages_insert" ON event_messages FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================
-- FOLLOWS TABLE (social feature)
-- ============================================
CREATE TABLE IF NOT EXISTS follows (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    follower_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    following_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(follower_id, following_id),
    CHECK(follower_id != following_id)
);

CREATE INDEX IF NOT EXISTS idx_follows_follower ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following ON follows(following_id);

-- RLS for follows
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
CREATE POLICY "follows_select" ON follows FOR SELECT USING (true);
CREATE POLICY "follows_insert" ON follows FOR INSERT WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "follows_delete" ON follows FOR DELETE USING (auth.uid() = follower_id);

-- ============================================
-- ENHANCED PROFILE FIELDS
-- ============================================
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS country_of_birth TEXT,
ADD COLUMN IF NOT EXISTS favorite_song TEXT,
ADD COLUMN IF NOT EXISTS fun_fact TEXT,
ADD COLUMN IF NOT EXISTS profile_color TEXT DEFAULT '#6366F1',
ADD COLUMN IF NOT EXISTS followers_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS following_count INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS referral_source TEXT;

-- ============================================
-- TRIGGER: Update follower counts
-- ============================================
CREATE OR REPLACE FUNCTION update_follow_counts()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE profiles SET following_count = following_count + 1 WHERE id = NEW.follower_id;
        UPDATE profiles SET followers_count = followers_count + 1 WHERE id = NEW.following_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE profiles SET following_count = following_count - 1 WHERE id = OLD.follower_id;
        UPDATE profiles SET followers_count = followers_count - 1 WHERE id = OLD.following_id;
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_follow_change ON follows;
CREATE TRIGGER on_follow_change
    AFTER INSERT OR DELETE ON follows
    FOR EACH ROW EXECUTE FUNCTION update_follow_counts();
