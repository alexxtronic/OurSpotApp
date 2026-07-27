-- Migration 031: notify chat participants when a new message is sent
--
-- The notification bell was only ever half-built: app_notifications has a
-- 'chatMessage' type, and the iOS client already fully supports displaying
-- and deep-linking it (NotificationBellView, NotificationRouter), but
-- nothing anywhere ever inserted one. Every other notification-creation
-- path this session has been client-driven and easy to miss; this one is
-- a trigger instead, so it fires reliably regardless of which client sent
-- the message.
--
-- SECURITY DEFINER lets this bypass the app_notifications RLS policy (025)
-- safely -- the same pattern already used by handle_follow_counts() etc.
-- Recipients are host + "going" attendees (same set as push notifications),
-- excluding the sender, anyone who muted this chat, and anyone with chat
-- notifications turned off in their profile.

CREATE OR REPLACE FUNCTION public.notify_chat_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  sender_name TEXT;
BEGIN
  SELECT name INTO sender_name FROM profiles WHERE id = NEW.user_id;

  INSERT INTO app_notifications (user_id, type, title, message, related_plan_id, related_user_id)
  SELECT
    p.user_id,
    'chatMessage',
    COALESCE(sender_name, 'Someone'),
    left(NEW.content, 100),
    NEW.plan_id,
    NEW.user_id
  FROM get_chat_participants(NEW.plan_id) p
  JOIN profiles pr ON pr.id = p.user_id
  WHERE p.user_id != NEW.user_id
    AND pr.notifications_enabled = true
    AND pr.chat_notifications_enabled = true
    AND p.user_id NOT IN (
      SELECT mc.user_id FROM muted_chats mc WHERE mc.plan_id = NEW.plan_id
    );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_chat_message_notify ON event_messages;
CREATE TRIGGER on_chat_message_notify
AFTER INSERT ON event_messages
FOR EACH ROW EXECUTE FUNCTION notify_chat_message();
