-- OurSpot Database Migration 014
-- Chaat Reads and Summaries
-- Created: 2025-12-22

-- ============================================
-- 1. EVENT CHAT READS (Track last read time)
-- ============================================
CREATE TABLE IF NOT EXISTS event_chat_reads (
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    plan_id UUID REFERENCES plans(id) ON DELETE CASCADE,
    last_read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, plan_id)
);

-- RLS
ALTER TABLE event_chat_reads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own read receipts" 
ON event_chat_reads 
USING (auth.uid() = user_id) 
WITH CHECK (auth.uid() = user_id);


-- ============================================
-- 2. FETCH CHAT SUMMARIES RPC
-- ============================================
-- Returns: plan_id, unread_count, last_message_at, last_message_content
CREATE OR REPLACE FUNCTION get_user_chat_summaries(current_user_id UUID)
RETURNS TABLE (
    plan_id UUID,
    unread_count BIGINT,
    last_message_at TIMESTAMP WITH TIME ZONE,
    last_message_content TEXT
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    WITH user_plans AS (
        -- Plans user is hosting
        SELECT id FROM plans WHERE host_user_id = current_user_id
        UNION
        -- Plans user is attending
        SELECT plan_id FROM plan_attendees WHERE user_id = current_user_id
    ),
    last_reads AS (
        SELECT plan_id, last_read_at 
        FROM event_chat_reads 
        WHERE user_id = current_user_id
    ),
    message_stats AS (
        SELECT 
            m.plan_id,
            COUNT(*) FILTER (WHERE m.created_at > COALESCE(lr.last_read_at, '1970-01-01')) AS unread,
            MAX(m.created_at) AS last_msg_time
        FROM event_messages m
        LEFT JOIN last_reads lr ON m.plan_id = lr.plan_id
        WHERE m.plan_id IN (SELECT id FROM user_plans)
        GROUP BY m.plan_id
    ),
    latest_content AS (
        SELECT DISTINCT ON (plan_id) plan_id, content, created_at
        FROM event_messages
        WHERE plan_id IN (SELECT id FROM user_plans)
        ORDER BY plan_id, created_at DESC
    )
    SELECT 
        up.id AS plan_id,
        COALESCE(ms.unread, 0) AS unread_count,
        ms.last_msg_time AS last_message_at,
        lc.content AS last_message_content
    FROM user_plans up
    LEFT JOIN message_stats ms ON up.id = ms.plan_id
    LEFT JOIN latest_content lc ON up.id = lc.plan_id
    WHERE ms.last_msg_time IS NOT NULL; -- Only return chats with messages? Or all? Let's return only those with messages for now to keep list clean, or maybe all.
    -- Actually, if we want to show all events even without chats, we should remove the WHERE clause. 
    -- But the requirements say "Event Chats", implying active chats. 
    -- However, usually you want to see the event group even if no one spoke yet?
    -- Creating a new event should likely show up. 
    -- Let's remove the WHERE clause so even empty chats show up (with 0 unread and null last message).
    
END;
$$;

-- Fix the WHERE clause mentioned above
CREATE OR REPLACE FUNCTION get_user_chat_summaries(current_user_id UUID)
RETURNS TABLE (
    plan_id UUID,
    unread_count BIGINT,
    last_message_at TIMESTAMP WITH TIME ZONE,
    last_message_content TEXT
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    WITH user_plans AS (
        SELECT id FROM plans WHERE host_user_id = current_user_id
        UNION
        SELECT plan_id FROM plan_attendees WHERE user_id = current_user_id
    ),
    last_reads AS (
        SELECT plan_id, last_read_at 
        FROM event_chat_reads 
        WHERE user_id = current_user_id
    ),
    message_stats AS (
        SELECT 
            m.plan_id,
            COUNT(*) FILTER (WHERE m.created_at > COALESCE(lr.last_read_at, '1970-01-01')) AS unread,
            MAX(m.created_at) AS last_msg_time
        FROM event_messages m
        LEFT JOIN last_reads lr ON m.plan_id = lr.plan_id
        WHERE m.plan_id IN (SELECT id FROM user_plans)
        GROUP BY m.plan_id
    ),
    latest_content AS (
        SELECT DISTINCT ON (plan_id) plan_id, content, created_at
        FROM event_messages
        WHERE plan_id IN (SELECT id FROM user_plans)
        ORDER BY plan_id, created_at DESC
    )
    SELECT 
        up.id AS plan_id,
        COALESCE(ms.unread, 0) AS unread_count,
        ms.last_msg_time AS last_message_at,
        lc.content AS last_message_content
    FROM user_plans up
    LEFT JOIN message_stats ms ON up.id = ms.plan_id
    LEFT JOIN latest_content lc ON up.id = lc.plan_id;
END;
$$;

NOTIFY pgrst, 'reload schema';
