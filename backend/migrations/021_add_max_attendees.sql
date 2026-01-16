-- Migration: Add max_attendees column to plans table
-- This allows hosts to set a limit on how many people can RSVP "going"

ALTER TABLE public.plans
ADD COLUMN max_attendees INTEGER DEFAULT NULL;

-- NULL means unlimited attendees
-- Any positive integer sets the cap

COMMENT ON COLUMN public.plans.max_attendees IS 'Maximum number of attendees allowed. NULL = unlimited.';
