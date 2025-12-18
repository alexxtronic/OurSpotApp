-- OurSpot Database Migration 002
-- Add new plan fields for emoji, activity type, address, and privacy
-- Created: 2024-12-18

-- Add new columns to plans table
ALTER TABLE plans
ADD COLUMN IF NOT EXISTS emoji TEXT DEFAULT '📍',
ADD COLUMN IF NOT EXISTS activity_type TEXT DEFAULT 'social' 
    CHECK (activity_type IN ('food', 'drinks', 'sports', 'culture', 'outdoors', 'nightlife', 'social')),
ADD COLUMN IF NOT EXISTS address_text TEXT DEFAULT '',
ADD COLUMN IF NOT EXISTS is_private BOOLEAN DEFAULT FALSE;

-- Add pending status to rsvps
ALTER TABLE rsvps 
DROP CONSTRAINT IF EXISTS rsvps_status_check;

ALTER TABLE rsvps
ADD CONSTRAINT rsvps_status_check 
CHECK (status IN ('going', 'maybe', 'not_going', 'pending'));

-- Index for private plans (for approval queries)
CREATE INDEX IF NOT EXISTS idx_plans_is_private ON plans(is_private) WHERE is_private = TRUE;

-- Comment on new columns
COMMENT ON COLUMN plans.emoji IS 'Emoji icon for the plan';
COMMENT ON COLUMN plans.activity_type IS 'Category of activity';
COMMENT ON COLUMN plans.address_text IS 'Human-readable address';
COMMENT ON COLUMN plans.is_private IS 'If true, host must approve attendees';
