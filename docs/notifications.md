# Push Notifications

Production-ready push notification system for real-time chat messages.

## Architecture

```
User A sends message → Supabase INSERT → Database Webhook → Edge Function
    → Fetch participants (host + going RSVPs) 
    → Filter (exclude sender, muted, disabled)
    → Get APNs tokens → Send via HTTP/2 → User B receives push
```

## iOS Setup

### 1. Xcode Configuration

1. **Enable Push Notifications Capability**
   - Select project → Signing & Capabilities → + Capability → Push Notifications

2. **Enable Background Modes**
   - Add "Remote notifications" background mode

3. **Add new files to Xcode project:**
   - `App/AppDelegate.swift`
   - `Services/DeviceTokenService.swift`
   - `Services/NotificationRouter.swift`
   - `Views/Profile/NotificationPreferencesView.swift`

### 2. Apple Developer Setup

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Certificates, Identifiers & Profiles → Keys
3. Create new key:
   - Name: "OurSpot APNs Key"
   - Enable: Apple Push Notifications service (APNs)
4. Download `.p8` file (save securely!)
5. Note the **Key ID** (10 characters)
6. Note your **Team ID** (Account → Membership)

### 3. Supabase Configuration

1. **Run database migrations:**
   ```sql
   -- Run migrations/012_push_notifications.sql
   -- Run migrations/013_chat_notification_trigger.sql
   ```

2. **Deploy Edge Function:**
   ```bash
   supabase functions deploy send-chat-notification
   ```

3. **Configure secrets:**
   ```bash
   supabase secrets set APNS_KEY_ID="YOUR_KEY_ID"
   supabase secrets set APNS_TEAM_ID="YOUR_TEAM_ID"
   supabase secrets set APNS_BUNDLE_ID="com.yourapp.bundleid"
   supabase secrets set APNS_ENVIRONMENT="development"  # or "production"
   supabase secrets set APNS_PRIVATE_KEY="$(cat ~/path/to/AuthKey_XXXXXXXX.p8)"
   ```

4. **Create database webhook:**
   - Supabase Dashboard → Database → Webhooks
   - Name: `send_chat_notification`
   - Table: `event_messages`
   - Events: `INSERT`
   - Type: Supabase Edge Function
   - Function: `send-chat-notification`

## Testing

### Simulator (limited)
- Permission prompts work
- Deep linking can be tested via CLI
- Actual push delivery requires real device

### Real Device

1. Build to physical device
2. Grant notification permission when prompted
3. Check logs for "APNs device token: ..."
4. Send message from another user
5. Verify notification received

### Debug Commands

```bash
# Check Edge Function logs
supabase functions logs send-chat-notification

# Test webhook manually
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/send-chat-notification \
  -H "Authorization: Bearer YOUR_SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"record": {"id": "test", "plan_id": "...", "user_id": "...", "content": "Test"}}'
```

## Failure Modes

| Issue | Cause | Solution |
|-------|-------|----------|
| No notification received | Invalid APNs token | Check device registration logs |
| 403 from APNs | Wrong Team ID or Key | Verify Supabase secrets |
| 410 from APNs | Expired token | Auto-cleaned by Edge Function |
| Edge Function timeout | Too many recipients | Batch notifications (future) |

## Extending Notifications

To add new notification types (e.g., RSVP updates):

1. Create trigger on relevant table
2. Add case to Edge Function
3. Add case to `NotificationDeepLink.NotificationType`
4. Handle in `NotificationRouter.handleNotificationTap()`
