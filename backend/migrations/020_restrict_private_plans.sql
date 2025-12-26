-- OurSpot Database Migration 020
-- Restrict visibility of private plans
-- Created: 2024-12-26

-- Drop the overly permissive select policy
DROP POLICY IF EXISTS "plans_select" ON plans;

-- Create new policy that handles privacy
CREATE POLICY "plans_select" ON plans FOR SELECT USING (
    -- 1. Public plans are visible to everyone
    (is_private = false) 
    OR 
    -- 2. Host can always see their own plans
    (host_user_id = auth.uid()) 
    OR 
    -- 3. Invited/Attending users can see the plan
    (EXISTS (
        SELECT 1 FROM rsvps 
        WHERE rsvps.plan_id = plans.id 
        AND rsvps.user_id = auth.uid()
    ))
    -- Note: We rely on the fact that only hosts can create 'invited' RSVPs
    -- and users can create 'going'/'maybe' RSVPs via invites or public events.
);

-- Ensure RLS is enabled (it should be, but just in case)
ALTER TABLE plans ENABLE ROW LEVEL SECURITY;
