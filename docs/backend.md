# FriendMap Backend Architecture

## Overview

FriendMap uses **Supabase** as the backend, providing:
- PostgreSQL database
- Row Level Security (RLS)
- Real-time subscriptions
- Authentication
- Edge Functions for custom logic

## Database Schema

See `migrations/001_init.sql` for the complete schema.

### Tables

| Table | Purpose |
|-------|---------|
| `profiles` | User profile data |
| `friendships` | Friend connections (bidirectional) |
| `plans` | Events/hangouts |
| `rsvps` | User responses to plans |
| `invites` | Invite codes for new users |
| `blocks` | User blocks (safety) |
| `reports` | Content reports (safety) |

## Row Level Security (RLS) Policies

### Profiles

```sql
-- Users can read profiles of accepted friends
CREATE POLICY "profiles_select_friends" ON profiles
    FOR SELECT USING (
        auth.uid() = id
        OR EXISTS (
            SELECT 1 FROM friendships
            WHERE status = 'accepted'
            AND (
                (user_id = auth.uid() AND friend_id = profiles.id)
                OR (friend_id = auth.uid() AND user_id = profiles.id)
            )
        )
    );

-- Users can only update their own profile
CREATE POLICY "profiles_update_self" ON profiles
    FOR UPDATE USING (auth.uid() = id);

-- Users can insert their own profile on signup
CREATE POLICY "profiles_insert_self" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);
```

### Friendships

```sql
-- Users can see their own friendships
CREATE POLICY "friendships_select_own" ON friendships
    FOR SELECT USING (
        auth.uid() = user_id OR auth.uid() = friend_id
    );

-- Users can create friend requests
CREATE POLICY "friendships_insert" ON friendships
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update friendships where they are the recipient
CREATE POLICY "friendships_update" ON friendships
    FOR UPDATE USING (auth.uid() = friend_id);
```

### Plans

```sql
-- Friends can see each other's plans (unless blocked)
CREATE POLICY "plans_select_friends" ON plans
    FOR SELECT USING (
        auth.uid() = host_user_id
        OR (
            EXISTS (
                SELECT 1 FROM friendships
                WHERE status = 'accepted'
                AND (
                    (user_id = auth.uid() AND friend_id = plans.host_user_id)
                    OR (friend_id = auth.uid() AND user_id = plans.host_user_id)
                )
            )
            AND NOT EXISTS (
                SELECT 1 FROM blocks
                WHERE (blocker_id = auth.uid() AND blocked_id = plans.host_user_id)
                OR (blocker_id = plans.host_user_id AND blocked_id = auth.uid())
            )
        )
    );

-- Only host can update their plan
CREATE POLICY "plans_update_host" ON plans
    FOR UPDATE USING (auth.uid() = host_user_id);

-- Only host can delete their plan
CREATE POLICY "plans_delete_host" ON plans
    FOR DELETE USING (auth.uid() = host_user_id);

-- Auth users can create plans
CREATE POLICY "plans_insert_auth" ON plans
    FOR INSERT WITH CHECK (auth.uid() = host_user_id);
```

### Invites

```sql
-- Users can see invites they created
CREATE POLICY "invites_select_own" ON invites
    FOR SELECT USING (auth.uid() = created_by);

-- Users can create invites
CREATE POLICY "invites_insert_auth" ON invites
    FOR INSERT WITH CHECK (auth.uid() = created_by);

-- Invite redemption handled by server-side function
-- to prevent race conditions
```

### Blocks

```sql
-- Users can see their own blocks
CREATE POLICY "blocks_select_own" ON blocks
    FOR SELECT USING (auth.uid() = blocker_id);

-- Users can create blocks
CREATE POLICY "blocks_insert" ON blocks
    FOR INSERT WITH CHECK (auth.uid() = blocker_id);

-- Users can delete their own blocks
CREATE POLICY "blocks_delete" ON blocks
    FOR DELETE USING (auth.uid() = blocker_id);
```

### Reports

```sql
-- Users can see their own reports
CREATE POLICY "reports_select_own" ON reports
    FOR SELECT USING (auth.uid() = reporter_id);

-- Users can create reports
CREATE POLICY "reports_insert" ON reports
    FOR INSERT WITH CHECK (auth.uid() = reporter_id);
```

## Edge Functions (Future)

### `redeem-invite`
Server-side function to redeem invite codes atomically:
1. Check invite exists and is not used
2. Check invite is not expired
3. Mark invite as used
4. Link to new user profile

### `get-friends-plans`
Optimized query to get all visible plans:
1. Get accepted friends
2. Filter by blocks
3. Return plans with RSVP counts

## Security Notes

1. **Blocks override all visibility** - If user A blocks user B, neither can see each other's content
2. **Invite-only signup** - New users must have a valid invite code
3. **No live location sharing** - Plans have static locations only
4. **Copenhagen-only MVP** - Geofencing to ~50km radius of Copenhagen center

## Setup Instructions

1. Create Supabase project at https://supabase.com
2. Run `migrations/001_init.sql` in SQL editor
3. Enable RLS on all tables
4. Apply RLS policies (see above)
5. Copy project URL and anon key to iOS app Config.plist
