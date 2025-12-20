-- OurSpot Database Migration 009
-- Complete Chat System Setup & Auto-Cleanup
-- Created: 2025-12-19

-- 1. Ensure Table Exists
CREATE TABLE IF NOT EXISTS event_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plan_id UUID NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Performance Indexes
CREATE INDEX IF NOT EXISTS idx_event_messages_plan ON event_messages(plan_id);
CREATE INDEX IF NOT EXISTS idx_event_messages_created ON event_messages(created_at);

-- 3. Row Level Security
ALTER TABLE event_messages ENABLE ROW LEVEL SECURITY;

-- Allow reading messages for any plan (could be restricted to attendees, but open for MVP social nature)
DROP POLICY IF EXISTS "event_messages_select" ON event_messages;
CREATE POLICY "event_messages_select" ON event_messages FOR SELECT USING (true);

-- Allow inserting messages only as yourself
DROP POLICY IF EXISTS "event_messages_insert" ON event_messages;
CREATE POLICY "event_messages_insert" ON event_messages FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 4. Auto-Deletion of old messages
-- Function to delete messages from plans that ended more than 24 hours ago
CREATE OR REPLACE FUNCTION delete_expired_chat_messages()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Delete messages where the associated plan's start time + 24 hours is in the past
  DELETE FROM event_messages
  WHERE plan_id IN (
    SELECT id FROM plans 
    WHERE starts_at < NOW() - INTERVAL '48 hours'
  );
END;
$$;
