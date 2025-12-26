-- Migration: 019_fix_rsvp_update_policy.sql
-- Purpose: Ensure users can update their own RSVP status (e.g. accepting an invite)
-- Previous policies might have been restrictive or missing for the UPDATE case on invited rows.

-- 1. Ensure the status check constraint includes all valid statuses
ALTER TABLE rsvps DROP CONSTRAINT IF EXISTS rsvps_status_check;
ALTER TABLE rsvps ADD CONSTRAINT rsvps_status_check 
    CHECK (status IN ('going', 'maybe', 'not_going', 'pending', 'invited'));

-- 2. Drop existing update policy to start fresh
DROP POLICY IF EXISTS "rsvps_update" ON rsvps;

-- 3. Create permissive update policy
-- Users can update any RSVP row where they are the user_id
CREATE POLICY "rsvps_update" ON rsvps FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 4. Ensure select policy is open (just in case)
DROP POLICY IF EXISTS "rsvps_select" ON rsvps;
CREATE POLICY "rsvps_select" ON rsvps FOR SELECT USING (true);

-- 5. Grant permissions
GRANT ALL ON rsvps TO authenticated;
