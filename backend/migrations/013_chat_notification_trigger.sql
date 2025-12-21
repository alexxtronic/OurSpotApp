-- Webhook trigger for chat notifications
-- Run this AFTER deploying the Edge Function

-- Create a trigger to call the Edge Function on new chat messages
-- Note: This uses Supabase's built-in pg_net extension for HTTP calls

-- Option 1: Database Webhook (recommended)
-- Configure this in Supabase Dashboard:
-- 1. Go to Database → Webhooks
-- 2. Create new webhook:
--    - Name: send_chat_notification
--    - Table: event_messages
--    - Events: INSERT
--    - Type: Supabase Edge Function
--    - Function: send-chat-notification

-- Option 2: pg_net trigger (if you want it in SQL)
-- Requires pg_net extension to be enabled

CREATE OR REPLACE FUNCTION trigger_chat_notification()
RETURNS TRIGGER AS $$
DECLARE
    edge_function_url TEXT;
    service_key TEXT;
BEGIN
    -- Get the Edge Function URL from environment
    edge_function_url := current_setting('app.settings.edge_function_base_url', true) 
        || '/send-chat-notification';
    service_key := current_setting('app.settings.service_role_key', true);
    
    -- Only proceed if we have the URL configured
    IF edge_function_url IS NOT NULL AND service_key IS NOT NULL THEN
        -- Call Edge Function asynchronously via pg_net
        PERFORM net.http_post(
            url := edge_function_url,
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || service_key
            ),
            body := jsonb_build_object(
                'type', 'INSERT',
                'table', 'event_messages',
                'record', jsonb_build_object(
                    'id', NEW.id::text,
                    'plan_id', NEW.plan_id::text,
                    'user_id', NEW.user_id::text,
                    'content', NEW.content,
                    'created_at', NEW.created_at::text
                )
            )::text
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Note: Uncomment below if using pg_net trigger approach
-- CREATE TRIGGER on_new_chat_message
-- AFTER INSERT ON event_messages
-- FOR EACH ROW
-- EXECUTE FUNCTION trigger_chat_notification();
