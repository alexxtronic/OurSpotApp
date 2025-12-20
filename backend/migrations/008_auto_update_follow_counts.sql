-- OurSpot Database Migration 008
-- Automate follower/following counts via triggers
-- Created: 2025-12-19

-- 1. Create the function that runs on every follow/unfollow
CREATE OR REPLACE FUNCTION handle_follow_counts()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    -- Increment counts
    UPDATE profiles 
    SET following_count = following_count + 1 
    WHERE id = NEW.follower_id;

    UPDATE profiles 
    SET followers_count = followers_count + 1 
    WHERE id = NEW.following_id;
    
    RETURN NEW;
  ELSIF (TG_OP = 'DELETE') THEN
    -- Decrement counts (ensure we don't go below 0)
    UPDATE profiles 
    SET following_count = GREATEST(0, following_count - 1)
    WHERE id = OLD.follower_id;

    UPDATE profiles 
    SET followers_count = GREATEST(0, followers_count - 1)
    WHERE id = OLD.following_id;
    
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Attach the trigger to the follows table
DROP TRIGGER IF EXISTS on_follow_change ON follows;

CREATE TRIGGER on_follow_change
AFTER INSERT OR DELETE ON follows
FOR EACH ROW EXECUTE FUNCTION handle_follow_counts();
