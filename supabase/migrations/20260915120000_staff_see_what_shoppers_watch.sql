-- ============================================================
-- What a shopper looked at, gathered per customer and per product.
--
-- The events table has held this since 20260905132526 -- a row per view,
-- cart add, wishlist add and purchase -- and staff have been able to read
-- it since the same migration. Nothing reads it. The Sales & Customers
-- page groups people by what they *bought*, which is the end of the
-- story and the smallest part of it: 946 events so far, of which 86 are
-- purchases. The other 860 are the shop watching people decide.
--
-- This migration does not capture anything new. It shapes what is
-- already there into the one question worth asking of it -- which
-- customer is circling which product, and how hard -- and lets staff
-- see the wishlist, which until now only its owner could read.
--
-- Two things it is deliberately not:
--
--   Not anonymous rows. events.customer_id is NULL for a signed-out
--   browser, and those rows are left out entirely rather than shown
--   against an anon_id. A uuid in a table is not a person staff can act
--   on, and claim_anon_activity already stitches that history onto the
--   account when somebody signs in.
--
--   Not a profile. One row per customer per product, counts and dates
--   only. Nothing here scores or labels a person.
-- ============================================================

-- Staff can already read every event and every order. A wishlist is the
-- same kind of fact about the same customer, and the shop cannot answer
-- "who wanted this" without it. Read-only: the "own wishlist" policy
-- below it still governs every write, so staff can see a saved item and
-- cannot add, move or remove one.
CREATE POLICY "staff read wishlists" ON public.wishlist_items
  FOR SELECT TO authenticated
  USING ((SELECT public.is_admin()));


-- ============================================================
-- One row per customer per product they have touched.
--
-- security_invoker so the view carries no rights of its own: the
-- "staff read activity" policy on events and the policy above are what
-- decide who sees anything, exactly as with every other admin_ view.
-- ============================================================
CREATE VIEW public.admin_customer_activity
WITH (security_invoker = on) AS
WITH touched AS (
  SELECT
    e.customer_id,
    e.product_id,
    count(*) FILTER (WHERE e.event_type = 'view')         AS views,
    count(*) FILTER (WHERE e.event_type = 'cart_add')     AS cart_adds,
    count(*) FILTER (WHERE e.event_type = 'purchase')     AS purchases,
    min(e.created_at) FILTER (WHERE e.event_type = 'view') AS first_view,
    max(e.created_at)                                     AS last_seen,
    max(e.source) FILTER (WHERE e.event_type = 'view')    AS last_source
  FROM public.events e
  WHERE e.customer_id IS NOT NULL
  GROUP BY e.customer_id, e.product_id
)
SELECT
  t.customer_id,
  c.name                        AS customer_name,
  c.email                       AS customer_email,
  t.product_id,
  p.name                        AS product_name,
  cat.name                      AS category,
  p.price,
  t.views,
  t.cart_adds,
  t.purchases,
  t.first_view,
  t.last_seen,
  t.last_source,
  (w.customer_id IS NOT NULL)   AS in_wishlist,
  w.added_at                    AS wishlisted_at,
  -- The live deal price, if this product happens to be on offer right
  -- now. Lets the panel show at a glance who is watching something that
  -- is already discounted.
  (SELECT d.discount_price
     FROM public.deals d
    WHERE d.product_id = t.product_id
      AND d.is_active = 1
      AND d.start_time <= now()
      AND d.end_time   >  now()
    ORDER BY d.discount_price
    LIMIT 1)                    AS deal_price
FROM touched t
JOIN public.customers  c   ON c.customer_id = t.customer_id
JOIN public.products   p   ON p.product_id  = t.product_id
LEFT JOIN public.categories cat ON cat.category_id = p.category_id
LEFT JOIN public.wishlist_items w
       ON w.customer_id = t.customer_id AND w.product_id = t.product_id;

GRANT SELECT ON public.admin_customer_activity TO authenticated;

COMMENT ON VIEW public.admin_customer_activity IS
  'One row per customer per product they viewed, carted, wishlisted or bought. '
  'Signed-out activity is excluded. Staff-only, through the policies on the '
  'underlying tables.';
