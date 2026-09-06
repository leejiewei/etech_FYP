-- ============================================================
-- Making the events table fit to be beta-tested against.
--
-- Objective 1's dataset is not generated; it is collected, once, from
-- real people using the real shop during the beta. There is no second
-- run and no way to backfill a signal that was never written down. So
-- everything the recommender will need has to be recorded before the
-- first tester arrives, not after.
--
-- Three things were missing. Each is a hole in the data rather than a
-- fault in the code, which is why none of them has ever shown up as a
-- bug:
--
--   1. An anonymous visitor left no trace of being one person. 260 of
--      the 742 views collected so far carry customer_id NULL and
--      nothing else, so they are 260 unrelated rows. Two views a minute
--      apart from the same browser cannot be told from two views by two
--      strangers. During a beta, where testers browse before they sign
--      up, this is most of the interesting data.
--
--   2. Because of 1, sessions could not be derived. "People who looked
--      at X also looked at Y" is the recommendation that this amount of
--      data can actually support, and it is a statement about one
--      sitting. The 30-minute-gap rule that carves a stream of views
--      into sittings needs to know whose stream it is first.
--
--   3. Search was not recorded at all. Someone typing "rtx 4070" has
--      told us more about what they want than three idle clicks will,
--      and the shop has had a search box the whole time.
--
-- What this migration does NOT do is change how a view is counted, or
-- touch the Inventory Velocity score. admin_product_scores and
-- v_product_velocity read the same rows they always did.
-- ============================================================


-- ------------------------------------------------------------
-- 1. anon_id: who an anonymous visitor is, for as long as they stay one
--
-- A UUID the client makes up once and keeps -- localStorage in the
-- browser, SharedPreferences on the phone. It is not an identity and
-- proves nothing: anyone can send any value, and the INSERT policy is
-- deliberately left alone rather than made to check it. That is
-- acceptable because these rows are insert-only and unreadable from the
-- client's side, so the worst a forged anon_id can do is put two
-- strangers' views in one basket. Set against that, requiring proof
-- would mean no anonymous tracking at all.
--
-- Nullable, and null for every row that already exists. Those stay
-- exactly as unusable as they are now; nothing can fix them after the
-- fact.
--
-- No GRANT is needed. INSERT on both tables is held at table level by
-- anon and authenticated, so a new column is insertable the moment it
-- exists. (A column-level grant, as products and customers have, would
-- have had to be added to by hand.)
-- ------------------------------------------------------------
ALTER TABLE public.events       ADD COLUMN IF NOT EXISTS anon_id uuid;
ALTER TABLE public.chatbot_logs ADD COLUMN IF NOT EXISTS anon_id uuid;

COMMENT ON COLUMN public.events.anon_id IS
  'Client-generated id for a browser or phone that is not signed in. Groups a stranger''s activity into one stream so sessions can be derived from created_at. Unverified by design; null on rows recorded before 2026-09-01.';

COMMENT ON COLUMN public.chatbot_logs.anon_id IS
  'As events.anon_id. A question asked signed out is still an intent signal.';

-- Reading these is analysis, not shop traffic: a partial index, because
-- every signed-in row is null here and there is no query that wants them.
CREATE INDEX IF NOT EXISTS events_anon_id_idx
  ON public.events (anon_id, created_at) WHERE anon_id IS NOT NULL;

-- Carving a stream into sittings walks it in time order, per person.
CREATE INDEX IF NOT EXISTS events_customer_time_idx
  ON public.events (customer_id, created_at) WHERE customer_id IS NOT NULL;


-- ------------------------------------------------------------
-- 2. search_logs
--
-- A search has no product, and events.product_id is NOT NULL -- rightly,
-- since every consumer of that table counts per-product activity. Making
-- it nullable to fit searches in would put a row in events that
-- v_product_velocity and admin_product_scores would both then have to
-- learn to skip.
--
-- So searches get their own table, built the same way chatbot_logs
-- already is, for the same reason: a signal about intent that is not
-- about one product.
--
-- result_count is stored because a search returning nothing is the most
-- useful row in the table. It says the shop was asked for something it
-- does not sell, or does not name the way the shopper does.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.search_logs (
  search_id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id  integer REFERENCES public.customers (customer_id) ON DELETE SET NULL,
  anon_id      uuid,
  query        text NOT NULL,
  result_count integer,
  created_at   timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.search_logs IS
  'What shoppers typed into the search box, and how many products came back. Insert-only from the clients, staff-readable, same shape as chatbot_logs.';

CREATE INDEX IF NOT EXISTS search_logs_created_at_idx ON public.search_logs (created_at);

ALTER TABLE public.search_logs ENABLE ROW LEVEL SECURITY;

-- Word for word the policy pair on events and chatbot_logs: anyone may
-- write a row, signed in or not, but a signed-in caller may only stamp
-- their own customer id on it. Reading is staff.
CREATE POLICY "anyone may record a search" ON public.search_logs
  FOR INSERT TO anon, authenticated
  WITH CHECK (customer_id IS NULL OR customer_id = (SELECT public.current_customer_id()));

CREATE POLICY "staff read searches" ON public.search_logs
  FOR SELECT TO authenticated
  USING ((SELECT public.is_admin()));

-- Supabase's default grants hand anon and authenticated everything on a
-- new table. Take it back, and give out only what the two policies above
-- describe.
REVOKE ALL ON public.search_logs FROM anon, authenticated;
GRANT INSERT ON public.search_logs TO anon, authenticated;
GRANT SELECT ON public.search_logs TO authenticated;


-- ------------------------------------------------------------
-- 3. claim_anon_activity()
--
-- The join that makes anonymous data worth collecting. A tester browses
-- signed out, decides to buy, signs up, and buys. Without this their
-- browsing and their purchase are two unconnected people, and the
-- purchase -- the one row a recommender most wants to explain -- has
-- nothing leading up to it.
--
-- Called by both clients straight after a successful sign-in or
-- sign-up, with the anon_id that browser or phone has been using.
--
-- SECURITY DEFINER because the clients hold no UPDATE on any of these
-- three tables and must not: this is the single, narrow exception, and
-- it can only ever move a row from "nobody" to "the caller". It cannot
-- take a row that already belongs to someone (customer_id IS NULL is in
-- every WHERE), and it cannot assign a row to anyone but whoever is
-- calling (current_customer_id(), never an argument).
--
-- Returns the number of rows claimed, which is a useful thing to watch
-- in the network tab while testing and harmless to expose.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.claim_anon_activity(p_anon_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_customer integer := public.current_customer_id();
  v_claimed  integer := 0;
  v_rows     integer;
BEGIN
  IF v_customer IS NULL OR p_anon_id IS NULL THEN
    RETURN 0;
  END IF;

  UPDATE public.events SET customer_id = v_customer
  WHERE anon_id = p_anon_id AND customer_id IS NULL;
  GET DIAGNOSTICS v_rows = ROW_COUNT;  v_claimed := v_claimed + v_rows;

  UPDATE public.chatbot_logs SET customer_id = v_customer
  WHERE anon_id = p_anon_id AND customer_id IS NULL;
  GET DIAGNOSTICS v_rows = ROW_COUNT;  v_claimed := v_claimed + v_rows;

  UPDATE public.search_logs SET customer_id = v_customer
  WHERE anon_id = p_anon_id AND customer_id IS NULL;
  GET DIAGNOSTICS v_rows = ROW_COUNT;  v_claimed := v_claimed + v_rows;

  RETURN v_claimed;
END;
$$;

-- The same two-layer lock as every other function here: the body checks
-- the caller, and the grant means a signed-out caller cannot reach the
-- body at all. REVOKE FROM anon by name, not just PUBLIC -- see
-- 20260828005426_revoke_anon_defaults.sql for why that distinction
-- matters on Supabase.
REVOKE EXECUTE ON FUNCTION public.claim_anon_activity(uuid) FROM public, anon;
GRANT  EXECUTE ON FUNCTION public.claim_anon_activity(uuid) TO authenticated;
