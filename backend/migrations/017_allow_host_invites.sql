-- Migration: 017_allow_host_invites.sql
-- Purpose: Allow plan hosts to create 'invited' RSVPs for other users

-- First, update the status CHECK constraint to include 'invited'
ALTER TABLE rsvps DROP CONSTRAINT IF EXISTS rsvps_status_check;
ALTER TABLE rsvps ADD CONSTRAINT rsvps_status_check 
    CHECK (status IN ('going', 'maybe', 'not_going', 'pending', 'invited'));

-- Drop the old insert policy
DROP POLICY IF EXISTS "rsvps_insert" ON rsvps;

-- Create new insert policy that allows:
-- 1. Users to create their own RSVPs (for any status)
-- 2. Plan hosts to create 'invited' RSVPs for other users
CREATE POLICY "rsvps_insert" ON rsvps FOR INSERT
WITH CHECK (
    auth.uid() = user_id  -- User can create their own RSVP
    OR 
    (
        status = 'invited' AND  -- Only for invitations
        EXISTS (
            SELECT 1 FROM plans 
            WHERE plans.id = plan_id 
            AND plans.host_user_id = auth.uid()  -- Current user is the plan host
        )
    )
);

-- Grant to authenticated users
GRANT ALL ON rsvps TO authenticated;
