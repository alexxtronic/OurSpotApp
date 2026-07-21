-- Migration 026: fix incomplete RPC lockdown from 025
-- 025 revoked EXECUTE on get_chat_participants/get_notification_recipients
-- from `authenticated`, but Postgres grants EXECUTE to PUBLIC by default on
-- function creation and neither 012 nor 025 ever revoked that. Every role,
-- including `anon`, inherits PUBLIC's grants -- confirmed live: calling
-- get_notification_recipients with only the anon key still returned 200
-- after 025 was applied. This revokes from PUBLIC explicitly.

REVOKE ALL ON FUNCTION public.get_chat_participants(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_notification_recipients(uuid, uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_chat_participants(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_notification_recipients(uuid, uuid) TO service_role;

NOTIFY pgrst, 'reload schema';
