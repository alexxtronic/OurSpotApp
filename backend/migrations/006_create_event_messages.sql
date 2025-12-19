-- OurSpot Database Migration 006
-- Add event_messages table for group chat
-- Created: 2025-12-19

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

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
