-- Migration 027: close the remaining anon grant left by Supabase's project
-- defaults. 026 revoked from PUBLIC (the classic Postgres default), but
-- Supabase separately auto-grants EXECUTE to anon/authenticated/service_role
-- explicitly on every new public-schema function via a project-level
-- ALTER DEFAULT PRIVILEGES rule. 025 already removed the `authenticated`
-- grant; this removes the leftover explicit `anon` grant, confirmed present
-- via: SELECT proname, proacl FROM pg_proc WHERE proname IN
-- ('get_chat_participants', 'get_notification_recipients');
-- -> {postgres=X/postgres, anon=X/postgres, service_role=X/postgres}

REVOKE ALL ON FUNCTION public.get_chat_participants(uuid) FROM anon;
REVOKE ALL ON FUNCTION public.get_notification_recipients(uuid, uuid) FROM anon;

NOTIFY pgrst, 'reload schema';
