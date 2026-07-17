-- Migration: Fix infinite recursion in plans/rsvps RLS policies
-- 022_privacy_policies.sql made "plans_select" query rsvps, and "rsvps_select"
-- query plans. Each table's RLS policy triggers evaluation of the other's
-- RLS policy, which triggers the first again -> infinite recursion (42P17).
-- Fix: move the cross-table lookups into SECURITY DEFINER functions, which
-- bypass RLS internally and break the cycle.

CREATE OR REPLACE FUNCTION public.user_has_rsvp(p_plan_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.rsvps
    WHERE plan_id = p_plan_id AND user_id = p_user_id
  );
$$;

CREATE OR REPLACE FUNCTION public.is_plan_host(p_plan_id UUID, p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.plans
    WHERE id = p_plan_id AND host_user_id = p_user_id
  );
$$;

CREATE OR REPLACE FUNCTION public.is_plan_public(p_plan_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.plans
    WHERE id = p_plan_id AND is_private = false
  );
$$;

-- ============================================
-- PLANS: rebuilt without a direct rsvps subquery
-- ============================================
DROP POLICY IF EXISTS "plans_select_privacy_and_blocks" ON plans;
CREATE POLICY "plans_select_privacy_and_blocks" ON plans
FOR SELECT USING (
    (
        is_private = false
        OR host_user_id = auth.uid()
        OR public.user_has_rsvp(plans.id, auth.uid())
    )
    AND NOT EXISTS (
        SELECT 1 FROM blocks b
        WHERE (b.blocker_id = auth.uid() AND b.blocked_id = plans.host_user_id)
           OR (b.blocker_id = plans.host_user_id AND b.blocked_id = auth.uid())
    )
);

-- ============================================
-- RSVPS: rebuilt without a direct plans subquery
-- ============================================
DROP POLICY IF EXISTS "rsvps_select_attendees_host_public" ON rsvps;
CREATE POLICY "rsvps_select_attendees_host_public" ON rsvps
FOR SELECT USING (
    auth.role() = 'authenticated'
    AND (
        rsvps.user_id = auth.uid()
        OR public.is_plan_host(rsvps.plan_id, auth.uid())
        OR public.user_has_rsvp(rsvps.plan_id, auth.uid())
        OR public.is_plan_public(rsvps.plan_id)
    )
    AND NOT EXISTS (
        SELECT 1 FROM blocks b
        WHERE (b.blocker_id = auth.uid() AND b.blocked_id = rsvps.user_id)
           OR (b.blocker_id = rsvps.user_id AND b.blocked_id = auth.uid())
    )
);

NOTIFY pgrst, 'reload schema';
