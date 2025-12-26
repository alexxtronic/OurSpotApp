-- Migration: Add plan_bans table for admin kick/ban functionality
-- This allows event hosts to permanently remove users from their events

-- Create plan_bans table
CREATE TABLE IF NOT EXISTS public.plan_bans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_id UUID NOT NULL REFERENCES public.plans(id) ON DELETE CASCADE,
    banned_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    banned_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    
    -- Ensure a user can only be banned once per plan
    UNIQUE(plan_id, banned_user_id)
);

-- Create index for fast lookups
CREATE INDEX IF NOT EXISTS idx_plan_bans_plan_id ON public.plan_bans(plan_id);
CREATE INDEX IF NOT EXISTS idx_plan_bans_banned_user_id ON public.plan_bans(banned_user_id);

-- Enable RLS
ALTER TABLE public.plan_bans ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Anyone can view bans (needed to check if user is banned)
CREATE POLICY plan_bans_select ON public.plan_bans
    FOR SELECT
    USING (true);

-- RLS Policy: Only the plan host can create bans
CREATE POLICY plan_bans_insert ON public.plan_bans
    FOR INSERT
    WITH CHECK (
        -- Must be the host of the plan
        EXISTS (
            SELECT 1 FROM public.plans
            WHERE plans.id = plan_id
            AND plans.host_user_id = auth.uid()
        )
        -- And banning on behalf of themselves
        AND banned_by = auth.uid()
    );

-- RLS Policy: Only the plan host can delete bans (unban)
CREATE POLICY plan_bans_delete ON public.plan_bans
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.plans
            WHERE plans.id = plan_bans.plan_id
            AND plans.host_user_id = auth.uid()
        )
    );

-- Update RLS policy for rsvps to allow hosts to delete any RSVP on their event
-- First drop the existing delete policy if it exists
DROP POLICY IF EXISTS rsvps_delete ON public.rsvps;

-- Create new delete policy that allows:
-- 1. Users to delete their own RSVP
-- 2. Plan hosts to delete any RSVP on their plan
CREATE POLICY rsvps_delete ON public.rsvps
    FOR DELETE
    USING (
        -- User can delete their own RSVP
        auth.uid() = user_id
        OR
        -- Host can delete any RSVP on their plan
        EXISTS (
            SELECT 1 FROM public.plans
            WHERE plans.id = rsvps.plan_id
            AND plans.host_user_id = auth.uid()
        )
    );

-- Add comment for documentation
COMMENT ON TABLE public.plan_bans IS 'Stores permanent bans for users kicked from events by hosts';
