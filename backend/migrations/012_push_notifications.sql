-- Push Notifications Infrastructure
-- Migration: 012_push_notifications.sql

-- Device tokens table for APNs
CREATE TABLE IF NOT EXISTS device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    apns_token TEXT NOT NULL,
    platform TEXT DEFAULT 'ios' CHECK (platform IN ('ios', 'android')),
    created_at TIMESTAMPTZ DEFAULT now(),
    last_seen_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, apns_token)
);

-- Index for fast token lookups
CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON device_tokens(user_id);

-- User notification preferences (add to profiles if not exists)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notifications_enabled BOOLEAN DEFAULT true;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS chat_notifications_enabled BOOLEAN DEFAULT true;

-- Muted chats per user
CREATE TABLE IF NOT EXISTS muted_chats (
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
    muted_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, plan_id)
);

-- RLS for device_tokens: Users can only manage their own tokens
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own tokens" ON device_tokens;
CREATE POLICY "Users manage own tokens" ON device_tokens
    FOR ALL USING (auth.uid() = user_id);

-- RLS for muted_chats: Users can only manage their own mutes
ALTER TABLE muted_chats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own mutes" ON muted_chats;
CREATE POLICY "Users manage own mutes" ON muted_chats
    FOR ALL USING (auth.uid() = user_id);

-- Function to get chat participants (host + going RSVPs)
CREATE OR REPLACE FUNCTION get_chat_participants(p_plan_id UUID)
RETURNS TABLE(user_id UUID) AS $$
BEGIN
    RETURN QUERY
    -- Plan host
    SELECT plans.host_user_id AS user_id
    FROM plans
    WHERE plans.id = p_plan_id
    
    UNION
    
    -- Users who RSVP'd "going"
    SELECT rsvps.user_id
    FROM rsvps
    WHERE rsvps.plan_id = p_plan_id
    AND rsvps.status = 'going';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get notification recipients (participants minus sender, muted, disabled)
CREATE OR REPLACE FUNCTION get_notification_recipients(
    p_plan_id UUID,
    p_sender_id UUID
)
RETURNS TABLE(
    user_id UUID,
    apns_token TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT dt.user_id, dt.apns_token
    FROM device_tokens dt
    INNER JOIN profiles p ON p.id = dt.user_id
    WHERE dt.user_id IN (SELECT get_chat_participants(p_plan_id))
    AND dt.user_id != p_sender_id  -- Exclude sender
    AND p.notifications_enabled = true  -- User has notifications enabled
    AND p.chat_notifications_enabled = true  -- Chat notifications enabled
    AND dt.user_id NOT IN (
        SELECT mc.user_id FROM muted_chats mc 
        WHERE mc.plan_id = p_plan_id
    );  -- Not muted this chat
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_chat_participants(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_notification_recipients(UUID, UUID) TO authenticated;
