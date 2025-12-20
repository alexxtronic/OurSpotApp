-- OurSpot Database Migration 010
-- User Ratings System
-- Created: 2025-12-20

-- 1. Create ratings table
CREATE TABLE IF NOT EXISTS user_ratings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rater_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    rated_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(rater_id, rated_id) -- One rating per pair
);

-- 2. Add stats to profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS rating_average DECIMAL(3, 2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS rating_count INTEGER DEFAULT 0;

-- 3. RLS Policies
ALTER TABLE user_ratings ENABLE ROW LEVEL SECURITY;

-- Everyone can read ratings
CREATE POLICY "user_ratings_select" ON user_ratings FOR SELECT USING (true);

-- Authenticated users can rate others (but not themselves)
CREATE POLICY "user_ratings_insert" ON user_ratings FOR INSERT 
WITH CHECK (auth.uid() = rater_id AND rater_id != rated_id);

CREATE POLICY "user_ratings_update" ON user_ratings FOR UPDATE
USING (auth.uid() = rater_id)
WITH CHECK (auth.uid() = rater_id AND rater_id != rated_id);

CREATE POLICY "user_ratings_delete" ON user_ratings FOR DELETE
USING (auth.uid() = rater_id);


-- 4. Trigger to auto-update profile stats
CREATE OR REPLACE FUNCTION update_user_rating_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- Determine which user's stats to update
    DECLARE
        target_user_id UUID;
    BEGIN
        IF (TG_OP = 'DELETE') THEN
            target_user_id := OLD.rated_id;
        ELSE
            target_user_id := NEW.rated_id;
        END IF;

        -- Calculate and update
        UPDATE profiles
        SET 
            rating_average = (
                SELECT COALESCE(AVG(rating), 0) 
                FROM user_ratings 
                WHERE rated_id = target_user_id
            ),
            rating_count = (
                SELECT COUNT(*) 
                FROM user_ratings 
                WHERE rated_id = target_user_id
            )
        WHERE id = target_user_id;

        RETURN NULL;
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_rating_change
AFTER INSERT OR UPDATE OR DELETE ON user_ratings
FOR EACH ROW EXECUTE FUNCTION update_user_rating_stats();
