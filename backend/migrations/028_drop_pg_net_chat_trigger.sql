-- Migration 028: drop the pg_net-based chat notification trigger from 013
-- It depended on current_setting('app.settings.edge_function_base_url') and
-- current_setting('app.settings.service_role_key'), which were only ever set
-- manually on the old (now-dead) project via ALTER DATABASE -- not captured
-- in any migration, so they don't exist on this project either, and the
-- trigger has been silently doing nothing (its IF check fails and it no-ops).
--
-- 013's own comment already recommended the alternative: a Dashboard-
-- configured Database Webhook, which supports custom headers (needed for
-- our new shared-secret check) without relying on custom Postgres settings.
-- Switching to that instead of trying to reconstruct the old GUC values.

DROP TRIGGER IF EXISTS on_new_chat_message ON event_messages;
DROP FUNCTION IF EXISTS trigger_chat_notification();
