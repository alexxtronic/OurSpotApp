# Session Log — Backend Recovery, Security Hardening & Bug Fixes

> Written for whoever (human or LLM) picks this up next. Read `DEV_NOTES.md` first for
> general project context; this file is a chronological account of one long session that
> took the app from "completely broken, can't launch" to "working, with a real security
> pass done." Dates below are relative to when this was written (late July 2026).

## Current State (read this first)

- **Live Supabase project**: `ammeeipxspudkbsrtkyn` (region: Paris). This is a **replacement**
  project — the original (`vbzuxdmvqkycuevvwxgk`, "OurSpot App") is permanently dead (paused
  >90 days, past the point Supabase allows dashboard restore). `Config.plist` points at the
  new project. Its DB password and other secrets are **not** in git; ask the project owner.
- **Migrations**: `backend/migrations/001` through `031` are the full history, already
  applied to the live project **up through 029**. **Migrations 030 and 031 are written
  but need to be confirmed applied** — check by running the verification queries in their
  own file comments, or just re-run them (both are idempotent / safe to re-run).
- **iOS app**: builds 1.0.1 (6), (7), and (8) have been archived and uploaded to TestFlight
  over the course of this session, each carrying fixes that the previous build didn't have.
  Check `ios/project.yml`'s `CURRENT_PROJECT_VERSION` for the latest before assuming any
  given TestFlight build has a particular fix.
- **Edge function**: `supabase/functions/send-chat-notification` is deployed to the new
  project (it wasn't, at all, until this session) with a shared-secret check and its own
  set of secrets (`APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY`, `APNS_BUNDLE_ID`,
  `APNS_ENVIRONMENT`, `CHAT_WEBHOOK_SECRET`). It's wired to fire via a **Database Webhook**
  (Dashboard → Database → Webhooks) on `event_messages` insert, **not** the old pg_net
  trigger from migration `013` (that trigger relied on Postgres custom settings that only
  ever existed on the dead project and has been dropped — see migration `028`).
- **Not yet end-to-end confirmed**: an actual push notification arriving on a real device
  from a real chat message. The pipeline (webhook → function → APNs) is fully wired and the
  function's own logic has been verified, but nobody has watched a push actually land yet.
- **This sandbox/session has no route to raw Postgres ports** (5432/6543) — confirmed
  repeatedly. Every SQL migration in this session was authored here, copied to the user's
  Desktop, and run manually via the Supabase SQL Editor. Don't assume you can `psql` in
  directly; you probably can't either.

## Why there was a crisis at all

The app's original Supabase project got paused (free-tier inactivity) and, by the time
anyone came back to it, had been paused long enough that Supabase's dashboard no longer
offers a one-click restore — only "download a backup" or "restore to a new project." The
user had a `db_cluster-27-01-2026@....backup.gz` cluster dump on hand, but ultimately the
simplest path (confirmed by explicit user preference) was: **skip restoring old data**,
create a fresh Supabase project, and apply the full migration history to get a clean,
working schema. No user data was migrated from the old project.

## Migration history cleanup (before any of this session's new migrations)

`backend/migrations/004`, `014`, and `021` each had **two different files sharing the same
numeric prefix** — real, divergent SQL, not just a naming collision. This is exactly the
kind of thing that breaks a clean `supabase db push` or confuses anyone reading the
migration history in order. Fixed by renaming:
- `004_social_features.sql` → `004_social_features.sql.superseded` (confirmed via file
  timestamps to be an earlier, abandoned draft that got split into 004/005/006/008; not a
  real migration, kept only for history)
- `014_chat_reads_and_summaries_fix.sql` → `014a_...` (a genuine same-day fix to `014`)
- `021_user_reports.sql` → `023_user_reports.sql` (unrelated content that just happened to
  reuse a number; moved to the next free slot)

A GitHub Action (`.github/workflows/migration-lint.yml`) now fails a PR if
`backend/migrations/*.sql` ever has duplicate numeric prefixes again.

## Applying the schema to the new project

Migrations `001`–`024` were concatenated and pasted into the SQL Editor as one script.
Three real bugs surfaced only once run against a genuinely fresh project (i.e. bugs that
were latent in the migration history all along, not things this session introduced):

1. **`001_init.sql` needed the `postgis` extension** for its `ST_MakePoint`-based location
   index — added inline (`CREATE EXTENSION IF NOT EXISTS "postgis";`).
2. **`011_storage_setup.sql` tried to `ALTER TABLE storage.objects ENABLE ROW LEVEL
   SECURITY`** — Supabase already enables this by default and owns the table via
   `supabase_storage_admin`; even the `postgres` role can't re-alter it. Removed the
   redundant line (the actual bucket policies below it are what matter and were fine).
3. **`021_add_max_attendees.sql`** tried to add a column that `001_init.sql` *also* already
   declares directly (schema drift from history) — added `IF NOT EXISTS`.

### The big one: RLS infinite recursion (migration `024`)

`022_privacy_policies.sql`'s `plans` SELECT policy queried `rsvps`, and its `rsvps` SELECT
policy queried `plans` right back — Postgres detects this as `42P17: infinite recursion
detected in policy`. The `rsvps` policy *also* self-referenced `rsvps` from within its own
policy, which independently triggers the same error class. Both reads had worked as
individual migrations at the time they were written, but nobody had ever actually
`SELECT`ed from a fresh project with the full policy set active until this session.

**Fix**: three `SECURITY DEFINER` helper functions (`is_plan_host`, `is_plan_public`,
`user_has_rsvp`) that internally bypass RLS, referenced from both policies instead of
inline cross-table subqueries. This is the standard, documented pattern for exactly this
Postgres RLS limitation.

## Security hardening pass (migrations `025`–`027`)

After getting the app functionally working again, three parallel audits (iOS architecture,
backend/RLS, cross-cutting repo hygiene) were run. Full findings are not reproduced here —
what actually got fixed and verified live:

- **All `SECURITY DEFINER` functions now pin `search_path`** (hijacking hardening) —
  including the three from `024` above.
- **`get_chat_participants` / `get_notification_recipients` locked to `service_role`
  only.** This was a real, exploitable bug: any authenticated user (or even the anon key
  alone) could call `get_notification_recipients` directly via PostgREST RPC and receive
  back **other users' raw APNs device tokens** for any plan. Took two follow-up migrations
  to fully close (`026` revoked the classic Postgres `PUBLIC` grant; `027` was needed
  because Supabase *separately* auto-grants `EXECUTE` to `anon`/`authenticated` on every
  new function via a project-level default-privileges rule — revoking from `PUBLIC` alone
  didn't touch that. Verified via `pg_proc.proacl` before/after, not just assumed.)
- **`plan_bans` now actually enforced** in the `rsvps` INSERT policy — previously a banned
  user could just re-insert their own RSVP; the ban was cosmetic.
- **`user_reports` foreign keys** changed to `ON DELETE SET NULL` — previously
  `delete_current_user()` would hard-fail with a `23503` if the deleted user ever filed or
  was the subject of a report, which is a realistic scenario on a live app with moderation.
- **`app_notifications` INSERT policy tightened** — previously any authenticated user could
  insert a notification row targeting *any* other user with fully spoofed title/content
  (phishing vector). Verified the only legitimate cross-user insert path
  (`PlanStore.inviteUsers()`, a host inviting someone to their own plan) still works under
  the new policy by tracing the exact field mapping before shipping the fix.

**Deliberately deferred** (flagged, not fixed, with reasons):
- `direct_messages` allows DMing anyone despite a documented (unenforced) mutual-follow
  design — needs a product decision, not just a policy flip.
- `is_plan_host`/`is_plan_public`/`user_has_rsvp` (the `024` helpers) are *also*
  directly callable via RPC by any authenticated user, since they need to stay callable by
  their own RLS policies. This leaks a narrower thing (host/RSVP relationship for a given
  plan/user pair) than the device-token leak above. The correct fix is moving them to a
  Postgres schema PostgREST doesn't expose — bigger change, not done this pass.
- No test suite exists anywhere in this repo (`ios/OurSpot.xcodeproj` has no XCTest
  target). This is the root enabler of basically every bug in this log — nothing catches
  regressions before a human does.

## Repo hygiene (same pass)

- `ios/node_modules` (backing an unrelated standalone `jsonwebtoken` script) and
  `website/node_modules` were tracked in git; both untracked and gitignored.
- `ios/build_log*.txt` (5 files) were tracked; untracked and gitignored.
- `README.md` told a fresh clone to `open FriendMap.xcodeproj` — that project is stale
  (6+ months, wrong bundle ID). The real, actively-built project is `OurSpot.xcodeproj`
  (generated by `xcodegen` from `ios/project.yml`). README fixed.
- **`ios/FriendMap/Views/Profile/` (5 files, including `ProfileView.swift`) had never been
  tracked in git at all.** Root cause: the generic Xcode `.gitignore` template has a bare
  `profile` rule (meant for an Instruments trace-output file), which on macOS's default
  case-insensitive filesystem also matched the *directory* `Profile`. Removed the offending
  gitignore line and force-added the directory. If you're reading this in a fresh clone and
  profile-related Swift files seem to be missing, this is why — check they're actually
  there now.

## iOS-side fixes

- **`ios/project.yml` had an empty `DEVELOPMENT_TEAM`**, which made archiving fail outright
  (`xcodebuild archive` → "Signing for OurSpot requires a development team"). Set to
  `HFC498ZVXN` (the team ID already present on the existing distribution certificate).
  This is why builds 6→7→8 all needed this fixed first before any of them could ship.
- **Instagram profile link crash**: `PublicProfileView.swift` did
  `URL(string: "https://instagram.com/\(handle)")!` on unsanitized free-text user input —
  any space/emoji/`#` in the handle force-unwrapped a `nil` and crashed. Fixed with
  percent-encoding + safe optional handling.
- Removed a dead `testInvite()` debug helper in `PlanStore.swift` (explicitly marked
  "REMOVE IN PROD" in its own comment, zero call sites).
- **Plan creation silently vanishing**: `PlanStore.createPlanWithId()` added the new plan
  to local UI state *before* the Supabase insert was confirmed, and on failure just logged
  it ("Revert on failure? For now just log" — a literal comment admitting the gap). The
  plan looked completely real — viewable, chattable — until the next data refresh, when it
  silently disappeared because it never existed server-side. **Reproduced live**: a plan
  created this way had zero trace in the database despite behaving normally in the app for
  a while. Fixed by reordering (server call first, local state only on confirmed success)
  and surfacing a real error via `PlanStore.error` + an alert in `CreatePlanView`. The exact
  same bug shape existed in `deletePlan()` (inverted: event vanishes from UI on a failed
  delete, still exists server-side, reappears confusingly later) and `updatePlan()`
  (local edits shown even if the save failed) — both fixed the same way.
- **Avatar upload always failed** (`new row violates row-level security policy`) even
  after the `avatars` storage bucket was created (that itself was a prerequisite step
  nobody had done yet, since Storage buckets aren't created by SQL migrations). Root cause:
  `011_storage_setup.sql`'s upload policy compared the filename against `auth.uid()` using
  a **case-sensitive** `LIKE`. Postgres renders `auth.uid()` as lowercase hex; Swift's
  `UUID().uuidString` (used to build the filename) renders **uppercase**. The comparison
  could never match, for any user, ever — this bug existed since `011` was written and
  simply never got exercised until the bucket existed. Fixed in migration `029` by folding
  both sides to lowercase.

## The `alexdamore2@gmail.com` orphaned-profile saga

Worth understanding in full since it's a good example of how confusing these bugs can look
from the outside. Symptoms over several messages: profile/onboarding never saved (silently
— no error), chat messages failed to send (visibly — FK violation), and this only affected
one specific account.

Root cause: `profiles.email` has a `UNIQUE` constraint, and `profiles.id` has **no foreign
key to `auth.users` at all**. At some point this account's `auth.users` row got deleted and
recreated (partly at this session's own suggestion, trying to fix an unrelated email-
confirmation redirect issue), which issues a **new** `auth.uid()` on every fresh sign-in —
but the *old* profile row (same email) was left behind as an orphan. Every subsequent
sign-in tried to insert a new profile row for the new user id, silently collided with the
orphan on the `email` unique constraint, and failed — so no profile ever existed for the
new id. Updates against a nonexistent row silently no-op (0 rows affected, no error).
Message inserts hard-failed because `event_messages.user_id` has a real FK to `profiles.id`.

Fixed in the moment by deleting the orphaned row. **Structurally fixed** in migration `030`
by finally adding `profiles.id REFERENCES auth.users(id) ON DELETE CASCADE`, so this class
of bug can't recur for any account going forward.

## Auth provider config (not a code bug, but cost real time)

- **Anonymous sign-in** ("Continue as Guest") was disabled by default on the new project
  (Supabase default for fresh projects). Dashboard → Authentication → Sign In / Providers →
  Anonymous → enabled.
- **Sign in with Apple** failed with `Unacceptable audience in id_token: [com.ourspot.world]`.
  The app's native flow produces a token whose `aud` claim is the bundle ID
  (`com.ourspot.world`), but Supabase's Apple provider "Client IDs" field wasn't configured
  to accept that audience (likely only had a Services ID from a web-flow setup). Fixed by
  adding `com.ourspot.world` to that field. The existing SIWA key (`AuthKey_D75VS7M3F9.p8`,
  Key ID `D75VS7M3F9`, Team ID `HFC498ZVXN`) also has APNs enabled and was reused for the
  edge function's push credentials — found on disk at
  `~/Desktop/Vibe Code Assets/AuthKey_D75VS7M3F9.p8` (Apple only lets you download a
  private key once, at creation; if this file is ever lost, the key has to be revoked and
  recreated, which also means updating the Supabase Apple provider's Key ID and the app's
  Sign In with Apple config to match).

## Notification bell (migration `031`)

The bell was only ever half-built: `newFollower` and `rsvpUpdate` notification types have
full UI support (icon, color in `NotificationBellView.swift`) but **no code anywhere ever
creates one** — those are just unused enum cases. Only `eventInvite` had a real creation
path (`PlanStore.inviteUsers()`), and there was a separate, redundant *local-only* fake
invite notification (`PlanStore.checkForNewInvites()`) that never touched the database at
all — a second, conflicting source of truth for the same event type.

Migration `031` adds a trigger-based notification for **new chat messages**
(`type = 'chatMessage'`, already fully supported by the client — icon, color, and deep-link
routing all pre-existed, just never received real data). Deliberately implemented as a
Postgres trigger (not another client-side call site) so it fires reliably regardless of
which client version sends the message, mirroring the existing `handle_follow_counts()`
pattern. Respects `notifications_enabled`, `chat_notifications_enabled`, and `muted_chats`.

**Not done**: `newFollower` and `rsvpUpdate` notifications still don't fire (still dead
enum cases). If asked to build those, the same trigger-based pattern is the right template
to follow — a trigger on `follows` insert, and on `rsvps` insert/update respectively.

## Edge function: `send-chat-notification`

This function existed in the repo but **was not deployed to the new project at all**, and
had zero secrets configured — the entire push pipeline was inert until this session.
Also hardened while rebuilding it: previously it trusted `payload.record` completely, with
no check that the request actually came from Supabase's own webhook. Since Edge Functions
accept any valid Supabase API key by default and the app's public key is baked into every
install, anyone holding that key could have POSTed a fabricated payload directly to the
function's URL and triggered a real push, spoofed as any user, with arbitrary content. Now
requires a `x-webhook-secret` header (configured as a custom header on the Database Webhook
in the Dashboard) and re-fetches the message from `event_messages` by id instead of
trusting the payload's content/plan_id/user_id verbatim.

## Reference

- Supabase project ref: `ammeeipxspudkbsrtkyn` (org: same one that owned the dead
  `vbzuxdmvqkycuevvwxgk` project; a redundant CLI-created third project,
  `ourspot-app-restored` / `ufrhtnnikmcwuixknxau`, was created and deleted earlier in this
  session — if you see a reference to it anywhere, it no longer exists).
- Apple Team ID: `HFC498ZVXN`. SIWA/APNs Key ID: `D75VS7M3F9`.
- All 31 migrations are the source of truth for current schema state; there is no
  `supabase/migrations` folder wired to `supabase db push` — migrations in
  `backend/migrations/` are applied manually via the SQL Editor. Keep numbering
  sequential and unique (the CI check in `.github/workflows/migration-lint.yml` will
  catch duplicates on a PR, but not a same-number collision within an uncommitted batch).
