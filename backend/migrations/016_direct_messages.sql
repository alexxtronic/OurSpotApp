-- Migration: 016_direct_messages.sql
-- Purpose: Enable 1:1 direct messaging between users who mutually follow each other

-- Create direct_messages table
CREATE TABLE IF NOT EXISTS public.direct_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    recipient_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    
    -- Prevent self-messaging
    CONSTRAINT no_self_message CHECK (sender_id != recipient_id)
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_dm_sender ON public.direct_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_dm_recipient ON public.direct_messages(recipient_id);
CREATE INDEX IF NOT EXISTS idx_dm_conversation ON public.direct_messages(
    LEAST(sender_id, recipient_id), 
    GREATEST(sender_id, recipient_id), 
    created_at DESC
);
CREATE INDEX IF NOT EXISTS idx_dm_unread ON public.direct_messages(recipient_id) WHERE is_read = false;

-- Enable RLS
ALTER TABLE public.direct_messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Users can only see messages they sent or received
CREATE POLICY "Users can view their own messages"
ON public.direct_messages FOR SELECT
USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

CREATE POLICY "Users can send messages"
ON public.direct_messages FOR INSERT
WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Recipients can mark messages as read"
ON public.direct_messages FOR UPDATE
USING (auth.uid() = recipient_id)
WITH CHECK (auth.uid() = recipient_id);

CREATE POLICY "Senders can delete their messages"
ON public.direct_messages FOR DELETE
USING (auth.uid() = sender_id);

-- Grant access
GRANT ALL ON public.direct_messages TO authenticated;
GRANT ALL ON public.direct_messages TO service_role;

-- Function to check if two users mutually follow each other
CREATE OR REPLACE FUNCTION public.check_mutual_follow(user_a UUID, user_b UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.follows f1
        JOIN public.follows f2 ON f1.follower_id = f2.following_id AND f1.following_id = f2.follower_id
        WHERE f1.follower_id = user_a AND f1.following_id = user_b
    );
END;
$$;

-- Function to get conversation summaries for a user
CREATE OR REPLACE FUNCTION public.get_dm_conversations(current_user_id UUID)
RETURNS TABLE (
    other_user_id UUID,
    other_user_name TEXT,
    other_user_avatar TEXT,
    last_message_content TEXT,
    last_message_at TIMESTAMPTZ,
    last_message_sender_id UUID,
    unread_count BIGINT
)
LANGUAGE sql
SECURITY DEFINER
AS $$
    WITH conversations AS (
        SELECT DISTINCT
            CASE 
                WHEN sender_id = current_user_id THEN recipient_id 
                ELSE sender_id 
            END as other_user
        FROM public.direct_messages
        WHERE sender_id = current_user_id OR recipient_id = current_user_id
    ),
    last_messages AS (
        SELECT DISTINCT ON (
            LEAST(sender_id, recipient_id), 
            GREATEST(sender_id, recipient_id)
        )
            id,
            sender_id,
            recipient_id,
            content,
            created_at,
            CASE 
                WHEN sender_id = current_user_id THEN recipient_id 
                ELSE sender_id 
            END as other_user
        FROM public.direct_messages
        WHERE sender_id = current_user_id OR recipient_id = current_user_id
        ORDER BY 
            LEAST(sender_id, recipient_id), 
            GREATEST(sender_id, recipient_id),
            created_at DESC
    ),
    unread_counts AS (
        SELECT 
            sender_id as other_user,
            COUNT(*) as unread
        FROM public.direct_messages
        WHERE recipient_id = current_user_id AND is_read = false
        GROUP BY sender_id
    )
    SELECT 
        c.other_user as other_user_id,
        p.name as other_user_name,
        p.avatar_url as other_user_avatar,
        lm.content as last_message_content,
        lm.created_at as last_message_at,
        lm.sender_id as last_message_sender_id,
        COALESCE(uc.unread, 0) as unread_count
    FROM conversations c
    JOIN public.profiles p ON p.id = c.other_user
    LEFT JOIN last_messages lm ON lm.other_user = c.other_user
    LEFT JOIN unread_counts uc ON uc.other_user = c.other_user
    ORDER BY lm.created_at DESC NULLS LAST;
$$;
