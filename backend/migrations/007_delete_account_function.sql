-- OurSpot Database Migration 007
-- Add RPC function to allow users to delete their own account
-- Created: 2025-12-19

CREATE OR REPLACE FUNCTION delete_current_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 1. Delete the public profile 
  -- (This filters by auth.uid() matching the profile id, which is our convention)
  -- Because plans, rsvps, blocks, etc. reference profiles(id) ON DELETE CASCADE,
  -- this single deletion will wipe all user data in the public schema.
  DELETE FROM public.profiles WHERE id = auth.uid();

  -- 2. Delete the auth user
  -- This requires SECURITY DEFINER to run with privileges to modify auth.users
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;
