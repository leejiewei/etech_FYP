-- ============================================================
-- A second copy of the behaviour capture, before anything empties it.
--
-- The owner wants events cleared so the next browsing session can be
-- watched arriving from nothing -- "later i will test have got record or
-- not". The 947 rows currently in there are the Objective 1 beta capture
-- going back to 14 February, collected under the ethics approval of
-- 7 September, and there is no other copy of them.
--
-- This migration only makes the copy. The DELETE is deliberately not in
-- here: emptying the table is a separate, deliberate act and should read
-- as one in the migration history.
--
-- Pouring it back, if it is ever wanted:
--
--   INSERT INTO public.events
--   SELECT * FROM public.events_archive_20260916;
--
-- The identity sequence on events is not touched by any of this, so an
-- event_id never comes to mean two different things.
--
-- ------------------------------------------------------------
-- Sealed in the same breath as it is created.
--
-- A hand-made table in the public schema is reachable by anon unless
-- something says otherwise -- which is exactly how the zz_backup order
-- tables ended up world-writable, found on 15 September. This one has RLS
-- on and every grant revoked before it holds a single row, so there is no
-- window where it is readable and no policy anybody could get wrong.
-- Only the owner and the service role can see it, which is what a backup
-- wants.
-- ------------------------------------------------------------
-- ============================================================

CREATE TABLE IF NOT EXISTS public.events_archive_20260916
  (LIKE public.events INCLUDING ALL);

ALTER TABLE public.events_archive_20260916 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.events_archive_20260916 FROM anon, authenticated, public;

INSERT INTO public.events_archive_20260916
SELECT * FROM public.events
WHERE NOT EXISTS (SELECT 1 FROM public.events_archive_20260916);
