-- Migration 025: Security hardening
-- Bundles five independent fixes found during a structural audit:
--  1. Pin search_path on all SECURITY DEFINER functions (search_path hijacking hardening)
--  2. Lock get_chat_participants/get_notification_recipients to service_role only
--     (previously any authenticated user could read other users' raw APNs device tokens
--     for any plan by calling get_notification_recipients directly via PostgREST RPC)
--  3. Enforce plan_bans in the rsvps INSERT policy (bans were purely cosmetic before this)
--  4. Fix user_reports FKs so delete_current_user() doesn't hard-fail with a 23503 when
--     the deleted user ever filed or was the subject of a report
--  5. Tighten app_notifications INSERT policy so only self-notifications or a plan host
--     inviting to their own plan are allowed (previously any authenticated user could
--     insert a spoofed notification targeting any other user)

-- ============================================
-- 1. Pin search_path on all SECURITY DEFINER functions
-- ============================================
ALTER FUNCTION public.delete_current_user() SET search_path = public, pg_temp;
ALTER FUNCTION public.handle_follow_counts() SET search_path = public, pg_temp;
ALTER FUNCTION public.delete_expired_chat_messages() SET search_path = public, pg_temp;
ALTER FUNCTION public.update_user_rating_stats() SET search_path = public, pg_temp;
ALTER FUNCTION public.get_chat_participants(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.get_notification_recipients(uuid, uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.trigger_chat_notification() SET search_path = public, pg_temp;
ALTER FUNCTION public.get_user_chat_summaries(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.check_mutual_follow(uuid, uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.get_dm_conversations(uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.user_has_rsvp(uuid, uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.is_plan_host(uuid, uuid) SET search_path = public, pg_temp;
ALTER FUNCTION public.is_plan_public(uuid) SET search_path = public, pg_temp;

-- ============================================
-- 2. Lock down device-token-returning RPCs to service_role only
-- ============================================
REVOKE EXECUTE ON FUNCTION public.get_chat_participants(uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_notification_recipients(uuid, uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.get_chat_participants(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_notification_recipients(uuid, uuid) TO service_role;

-- ============================================
-- 3. Enforce plan_bans on rsvps INSERT
-- ============================================
DROP POLICY IF EXISTS "rsvps_insert" ON rsvps;
CREATE POLICY "rsvps_insert" ON rsvps FOR INSERT
WITH CHECK (
    (
        auth.uid() = user_id
        OR (
            status = 'invited' AND
            EXISTS (SELECT 1 FROM plans WHERE plans.id = plan_id AND plans.host_user_id = auth.uid())
        )
    )
    AND NOT EXISTS (
        SELECT 1 FROM plan_bans
        WHERE plan_bans.plan_id = plan_id
        AND plan_bans.banned_user_id = user_id
    )
);

-- ============================================
-- 4. Fix user_reports FKs so account deletion doesn't hard-fail
-- ============================================
DO $$
DECLARE
  reporter_fk text;
  reported_fk text;
BEGIN
  SELECT conname INTO reporter_fk FROM pg_constraint
    WHERE conrelid = 'public.user_reports'::regclass
      AND pg_get_constraintdef(oid) LIKE '%(reporter_id)%REFERENCES auth.users%';
  SELECT conname INTO reported_fk FROM pg_constraint
    WHERE conrelid = 'public.user_reports'::regclass
      AND pg_get_constraintdef(oid) LIKE '%(reported_id)%REFERENCES auth.users%';
  EXECUTE format('ALTER TABLE public.user_reports DROP CONSTRAINT %I', reporter_fk);
  EXECUTE format('ALTER TABLE public.user_reports DROP CONSTRAINT %I', reported_fk);
END $$;

ALTER TABLE public.user_reports ALTER COLUMN reporter_id DROP NOT NULL;
ALTER TABLE public.user_reports ALTER COLUMN reported_id DROP NOT NULL;

ALTER TABLE public.user_reports
  ADD CONSTRAINT user_reports_reporter_id_fkey
  FOREIGN KEY (reporter_id) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.user_reports
  ADD CONSTRAINT user_reports_reported_id_fkey
  FOREIGN KEY (reported_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- ============================================
-- 5. Tighten app_notifications INSERT policy
-- ============================================
DROP POLICY IF EXISTS "Authenticated users can create notifications" ON public.app_notifications;
CREATE POLICY "Users can create verified notifications"
ON public.app_notifications FOR INSERT
WITH CHECK (
  auth.uid() = user_id
  OR (
    type = 'eventInvite'
    AND related_user_id = auth.uid()
    AND related_plan_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.plans
      WHERE plans.id = related_plan_id AND plans.host_user_id = auth.uid()
    )
  )
);

NOTIFY pgrst, 'reload schema';
