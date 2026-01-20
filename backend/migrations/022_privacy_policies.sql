-- Tighten privacy, block enforcement, and RSVP visibility
-- Run in Supabase SQL Editor

-- Ensure blocks table exists (safety if earlier migration was skipped)
CREATE TABLE IF NOT EXISTS public.blocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(blocker_id, blocked_id),
    CHECK (blocker_id != blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_blocks_blocker ON blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_blocks_blocked ON blocks(blocked_id);

-- ============================================
-- PROFILES: block-aware select, authenticated only
-- ============================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "profiles_select" ON profiles;
CREATE POLICY "profiles_select_authenticated_not_blocked" ON profiles
FOR SELECT USING (
    auth.role() = 'authenticated'
    AND NOT EXISTS (
        SELECT 1 FROM blocks b
        WHERE (b.blocker_id = auth.uid() AND b.blocked_id = profiles.id)
           OR (b.blocker_id = profiles.id AND b.blocked_id = auth.uid())
    )
);

-- ============================================
-- RSVPS: host/attendee/public visibility, block-aware
-- ============================================
ALTER TABLE rsvps ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "rsvps_select" ON rsvps;
CREATE POLICY "rsvps_select_attendees_host_public" ON rsvps
FOR SELECT USING (
    auth.role() = 'authenticated'
    AND (
        -- Your own RSVPs
        rsvps.user_id = auth.uid()
        -- Hosts can see RSVPs for their events
        OR EXISTS (
            SELECT 1 FROM plans p
            WHERE p.id = rsvps.plan_id
              AND p.host_user_id = auth.uid()
        )
        -- Attendees can see who else is attending the same event
        OR EXISTS (
            SELECT 1 FROM rsvps r2
            WHERE r2.plan_id = rsvps.plan_id
              AND r2.user_id = auth.uid()
        )
        -- Public events expose RSVPs to authenticated users
        OR EXISTS (
            SELECT 1 FROM plans p
            WHERE p.id = rsvps.plan_id
              AND p.is_private = false
        )
    )
    AND NOT EXISTS (
        SELECT 1 FROM blocks b
        WHERE (b.blocker_id = auth.uid() AND b.blocked_id = rsvps.user_id)
           OR (b.blocker_id = rsvps.user_id AND b.blocked_id = auth.uid())
    )
);

-- ============================================
-- PLANS: respect blocks on visibility
-- ============================================
DROP POLICY IF EXISTS "plans_select" ON plans;
CREATE POLICY "plans_select_privacy_and_blocks" ON plans
FOR SELECT USING (
    -- Existing privacy rules
    (
        is_private = false
        OR host_user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM rsvps r
            WHERE r.plan_id = plans.id
              AND r.user_id = auth.uid()
        )
    )
    -- Block enforcement: either direction hides the plan
    AND NOT EXISTS (
        SELECT 1 FROM blocks b
        WHERE (b.blocker_id = auth.uid() AND b.blocked_id = plans.host_user_id)
           OR (b.blocker_id = plans.host_user_id AND b.blocked_id = auth.uid())
    )
);

-- ============================================
-- BLOCKS: allow users to manage their own blocks
-- ============================================
ALTER TABLE blocks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "blocks_select_own" ON blocks;
DROP POLICY IF EXISTS "blocks_insert" ON blocks;
DROP POLICY IF EXISTS "blocks_delete" ON blocks;

CREATE POLICY "blocks_select_related" ON blocks
FOR SELECT USING (auth.uid() = blocker_id OR auth.uid() = blocked_id);

CREATE POLICY "blocks_manage_own" ON blocks
FOR INSERT WITH CHECK (auth.uid() = blocker_id);

CREATE POLICY "blocks_delete_own" ON blocks
FOR DELETE USING (auth.uid() = blocker_id);
