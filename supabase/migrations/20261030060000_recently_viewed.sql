-- ============================================================
-- Recently viewed, kept on the customer's account.
--
-- Until now the home page's "Recently viewed" row was read from the
-- browser's localStorage, so it belonged to the browser, not the person:
-- two customers signing in on the same laptop saw each other's history,
-- and one customer on a phone and a laptop had two different lists.
--
-- Signed-in views now land here, one row per customer and product.
-- Viewing the same product again moves its viewed_at forward instead of
-- adding a row, and only the newest 20 are kept per customer. Guests
-- still keep their list in localStorage (web/js/tracking.js); when they
-- sign in, merge_recent_views() folds that list into this table.
--
-- Clients may read their own rows and nothing else. They cannot write
-- the table at all: both writes go through the two SECURITY DEFINER
-- functions below, which take the customer from the session
-- (current_customer_id()), never from an argument, so no request can
-- file a view under somebody else's account.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.recently_viewed (
  customer_id integer     NOT NULL REFERENCES public.customers (customer_id) ON DELETE CASCADE,
  product_id  integer     NOT NULL REFERENCES public.products (product_id) ON DELETE CASCADE,
  viewed_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (customer_id, product_id)
);

CREATE INDEX IF NOT EXISTS recently_viewed_newest
  ON public.recently_viewed (customer_id, viewed_at DESC);

ALTER TABLE public.recently_viewed ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "own recently viewed" ON public.recently_viewed;
CREATE POLICY "own recently viewed" ON public.recently_viewed
  FOR SELECT TO authenticated
  USING (customer_id = (SELECT public.current_customer_id()));

REVOKE ALL ON public.recently_viewed FROM anon, authenticated;
GRANT SELECT ON public.recently_viewed TO authenticated;

-- How many views each customer keeps.
CREATE OR REPLACE FUNCTION public.recent_views_trim(p_customer integer)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO ''
AS $$
  DELETE FROM public.recently_viewed r
  WHERE r.customer_id = p_customer
    AND r.product_id NOT IN (
      SELECT k.product_id FROM public.recently_viewed k
      WHERE k.customer_id = p_customer
      ORDER BY k.viewed_at DESC
      LIMIT 20);
$$;

REVOKE ALL ON FUNCTION public.recent_views_trim(integer) FROM PUBLIC, anon, authenticated;

-- One view by the signed-in customer. A guest's call does nothing.
CREATE OR REPLACE FUNCTION public.record_recent_view(p_product_id integer)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_customer integer := public.current_customer_id();
BEGIN
  IF v_customer IS NULL THEN RETURN; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.products WHERE product_id = p_product_id) THEN RETURN; END IF;

  INSERT INTO public.recently_viewed (customer_id, product_id, viewed_at)
  VALUES (v_customer, p_product_id, now())
  ON CONFLICT (customer_id, product_id) DO UPDATE SET viewed_at = now();

  PERFORM public.recent_views_trim(v_customer);
END;
$$;

-- A guest's list from this browser, handed over at sign-in:
-- [{"product_id": 12, "viewed_at": "2026-10-30T05:00:00Z"}, ...].
-- Only the first 20 entries are read; a time in the future is taken as
-- now; a product already on the account keeps the later of the two
-- times. Returns how many entries were taken.
CREATE OR REPLACE FUNCTION public.merge_recent_views(p_items jsonb)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_customer integer := public.current_customer_id();
  v_taken    integer;
BEGIN
  IF v_customer IS NULL OR jsonb_typeof(p_items) IS DISTINCT FROM 'array' THEN RETURN 0; END IF;

  WITH given AS (
    SELECT (e->>'product_id')::integer AS product_id,
           least(coalesce((e->>'viewed_at')::timestamptz, now()), now()) AS viewed_at
    FROM jsonb_array_elements(p_items) WITH ORDINALITY AS t(e, n)
    WHERE n <= 20 AND jsonb_typeof(e->'product_id') = 'number'
  ), latest AS (
    SELECT g.product_id, max(g.viewed_at) AS viewed_at
    FROM given g JOIN public.products p ON p.product_id = g.product_id
    GROUP BY g.product_id
  )
  INSERT INTO public.recently_viewed (customer_id, product_id, viewed_at)
  SELECT v_customer, product_id, viewed_at FROM latest
  ON CONFLICT (customer_id, product_id)
    DO UPDATE SET viewed_at = greatest(public.recently_viewed.viewed_at, excluded.viewed_at);
  GET DIAGNOSTICS v_taken = ROW_COUNT;

  PERFORM public.recent_views_trim(v_customer);
  RETURN v_taken;
END;
$$;

REVOKE ALL ON FUNCTION public.record_recent_view(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.merge_recent_views(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_recent_view(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.merge_recent_views(jsonb) TO authenticated;
