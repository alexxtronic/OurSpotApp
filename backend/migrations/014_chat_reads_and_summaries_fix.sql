-- OurSpot Database Migration 014 FIX
-- Chat Reads and Summaries - Using correct rsvps table
-- Run this in Supabase SQL Editor

-- Drop the old function if it exists
DROP FUNCTION IF EXISTS get_user_chat_summaries(UUID);

-- Create the corrected function using rsvps table
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
        -- Plans user has RSVP'd as "going"
        SELECT r.plan_id FROM rsvps r WHERE r.user_id = current_user_id AND r.status = 'going'
    ),
    last_reads AS (
        SELECT ecr.plan_id, ecr.last_read_at 
        FROM event_chat_reads ecr
        WHERE ecr.user_id = current_user_id
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
        SELECT DISTINCT ON (em.plan_id) em.plan_id, em.content, em.created_at
        FROM event_messages em
        WHERE em.plan_id IN (SELECT id FROM user_plans)
        ORDER BY em.plan_id, em.created_at DESC
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

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
