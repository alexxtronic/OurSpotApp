-- Migration: 015_app_notifications.sql
-- Purpose: Store in-app notifications (invites, follows, etc.) in Supabase

-- Create the app_notifications table
CREATE TABLE IF NOT EXISTS public.app_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('eventInvite', 'chatMessage', 'rsvpUpdate', 'newFollower')),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    related_plan_id UUID REFERENCES public.plans(id) ON DELETE CASCADE,
    related_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create index for efficient user notification queries
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.app_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON public.app_notifications(user_id) WHERE is_read = false;

-- Enable RLS
ALTER TABLE public.app_notifications ENABLE ROW LEVEL SECURITY;

-- RLS policies: users can only see/manage their own notifications
CREATE POLICY "Users can view their own notifications"
ON public.app_notifications FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own notifications"
ON public.app_notifications FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own notifications"  
ON public.app_notifications FOR DELETE
USING (auth.uid() = user_id);

-- Any authenticated user can insert notifications for any user
-- This allows User A to send a notification TO User B
CREATE POLICY "Authenticated users can create notifications"
ON public.app_notifications FOR INSERT
WITH CHECK (auth.uid() IS NOT NULL);

-- Grant access
GRANT ALL ON public.app_notifications TO authenticated;
GRANT ALL ON public.app_notifications TO service_role;

