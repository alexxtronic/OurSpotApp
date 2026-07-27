-- Migration 030: link profiles to auth.users so deleted accounts can't
-- leave orphaned profile rows behind.
--
-- profiles.id has never had a foreign key to auth.users -- it's just a
-- UUID primary key that the app *convention* keeps in sync with the
-- authenticated user's id. When an auth.users row gets deleted (e.g. via
-- delete_current_user(), or manually during this session's debugging) and
-- the same email signs up again, Supabase issues a brand-new auth.users id,
-- but the old profiles row (same email, orphaned id) is left behind. Since
-- profiles.email is UNIQUE, the new signup's profile insert then silently
-- fails with a uniqueness violation, and the account is stuck: profile
-- never saves, and any INSERT referencing profiles.id (e.g. event_messages)
-- fails on the foreign key. This is exactly what happened to
-- alexdamore2@gmail.com's account earlier this session -- fixed there by
-- manually deleting the orphaned row, but nothing stopped it from
-- recurring for any account until now.
--
-- ON DELETE CASCADE makes profile cleanup automatic going forward.

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_id_fkey
  FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
