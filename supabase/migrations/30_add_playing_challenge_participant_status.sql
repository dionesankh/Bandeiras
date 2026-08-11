-- 30. Add the in-progress status used by challenge session RPCs.
-- The RPCs already transition challenge participants from accepted to playing
-- before a result is submitted as completed.

ALTER TYPE public.challenge_participant_status
ADD VALUE IF NOT EXISTS 'playing' AFTER 'accepted';
