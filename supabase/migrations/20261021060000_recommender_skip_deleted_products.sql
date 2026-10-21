-- ------------------------------------------------------------
-- The recommender skips history for products that no longer exist.
--
-- Found while testing for Chapter 5 (21 Oct 2026): four products named
-- in events_archive_20260916 have since been deleted. When one of them
-- was the "because_of" product, the reason came out NULL
-- ('Shoppers who liked ' || NULL), and the weekly push builds its body
-- from that reason. A deleted product is also no evidence of what the
-- customer wants today, so its events are dropped from every signal.
--
-- Only change from 20261001032630: the EXISTS check in signals.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recommend_products(
  p_customer integer,
  p_limit    integer DEFAULT 8
)
RETURNS TABLE (product_id integer, score numeric, reason text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  WITH
  -- Every interaction anyone has had with a product, live and archived.
  -- UNION, not UNION ALL: should a row ever be poured back from the
  -- archive into events it must not be counted twice.
  raw_events AS (
    SELECT e.event_id, e.customer_id, e.product_id, e.event_type, e.created_at
    FROM public.events e
    UNION
    SELECT a.event_id, a.customer_id, a.product_id, a.event_type, a.created_at
    FROM public.events_archive_20260916 a
  ),
  signals AS (
    SELECT r.customer_id, r.product_id, r.created_at,
           r.event_type::text AS kind,
           CASE r.event_type WHEN 'view' THEN 1 WHEN 'cart_add' THEN 3 ELSE 5 END::numeric AS w
    FROM raw_events r
    WHERE r.customer_id IS NOT NULL
      AND r.product_id  IS NOT NULL
      AND r.event_type IN ('view', 'cart_add', 'purchase')
      AND EXISTS (SELECT 1 FROM public.products p WHERE p.product_id = r.product_id)
    UNION ALL
    SELECT wi.customer_id, wi.product_id, wi.added_at, 'wishlist', 4::numeric
    FROM public.wishlist_items wi
  ),

  -- ---- this customer ----
  -- Decayed, so last week's browsing outweighs February's.
  mine AS (
    SELECT s.product_id,
           sum(s.w * exp(-GREATEST(extract(epoch FROM now() - s.created_at), 0) / 86400.0 / 45.0)) AS w,
           -- The strongest thing they did with it, for the reason line.
           (array_agg(s.kind ORDER BY s.w DESC))[1] AS top_kind,
           bool_or(s.kind = 'purchase') AS bought,
           bool_or(s.kind = 'wishlist') AS saved
    FROM signals s
    WHERE s.customer_id = p_customer
    GROUP BY s.product_id
  ),

  -- ---- everybody else: the customer-item matrix ----
  -- Undecayed. Two products bought by the same people in February are
  -- still alike in October.
  ratings AS (
    SELECT s.customer_id, s.product_id, sum(s.w) AS r
    FROM signals s
    WHERE s.customer_id <> p_customer
    GROUP BY s.customer_id, s.product_id
  ),
  norms AS (
    SELECT rt.product_id, sqrt(sum(rt.r * rt.r)) AS n
    FROM ratings rt
    GROUP BY rt.product_id
  ),
  -- Cosine similarity between each product the customer touched and
  -- every product the same other customers touched.
  item_sim AS (
    SELECT a.product_id AS src, b.product_id AS dst,
           sum(a.r * b.r) / (na.n * nb.n) AS cos
    FROM mine m
    JOIN ratings a ON a.product_id = m.product_id
    JOIN ratings b ON b.customer_id = a.customer_id AND b.product_id <> a.product_id
    JOIN norms na  ON na.product_id = a.product_id
    JOIN norms nb  ON nb.product_id = b.product_id
    GROUP BY a.product_id, b.product_id, na.n, nb.n
  ),
  cf AS (
    SELECT sm.dst AS product_id,
           sum(m.w * sm.cos) AS v,
           (array_agg(sm.src ORDER BY m.w * sm.cos DESC))[1] AS because_of
    FROM item_sim sm
    JOIN mine m ON m.product_id = sm.src
    GROUP BY sm.dst
  ),

  -- ---- category interest ----
  interest AS (
    SELECT p.category_id,
           sum(m.w) AS v,
           (array_agg(m.top_kind ORDER BY m.w DESC))[1] AS top_kind
    FROM mine m
    JOIN public.products p ON p.product_id = m.product_id
    GROUP BY p.category_id
  ),

  -- ---- role ----
  my_role AS (
    SELECT c.shopper_role FROM public.customers c WHERE c.customer_id = p_customer
  ),

  -- ---- popularity ----
  popular AS (
    SELECT s.product_id, sum(s.w) AS v
    FROM signals s
    GROUP BY s.product_id
  ),

  -- ---- what may be recommended ----
  candidates AS (
    SELECT p.product_id, p.category_id, p.name, p.price,
           CASE WHEN p.stock_status = 'out' THEN 0.9 ELSE 1 END AS stock_factor
    FROM public.products p
    WHERE p.is_active = 1
      AND NOT EXISTS (SELECT 1 FROM mine m
                      WHERE m.product_id = p.product_id AND (m.bought OR m.saved))
  ),
  raw_scores AS (
    SELECT cd.product_id, cd.category_id, cd.stock_factor,
           COALESCE(cf.v, 0)  AS cf_v,
           cf.because_of,
           COALESCE(it.v, 0)  AS int_v,
           it.top_kind,
           COALESCE(rw.weight, 0) *
             CASE WHEN (SELECT shopper_role FROM my_role) = 'student'
                  -- Cheapest in its category keeps the full weight,
                  -- dearest keeps 60% of it.
                  THEN 1 - 0.4 * (percent_rank() OVER (PARTITION BY cd.category_id ORDER BY cd.price))::numeric
                  ELSE 1 END AS role_v,
           COALESCE(pp.v, 0)  AS pop_v
    FROM candidates cd
    LEFT JOIN cf                  ON cf.product_id  = cd.product_id
    LEFT JOIN interest it         ON it.category_id = cd.category_id
    LEFT JOIN public.role_category_weights rw
           ON rw.category_id = cd.category_id
          AND rw.shopper_role = (SELECT shopper_role FROM my_role)
    LEFT JOIN popular pp          ON pp.product_id  = cd.product_id
  ),
  -- Each signal scaled to 0..1 so the weights mean what they say.
  scaled AS (
    SELECT rs.*,
           rs.cf_v   / NULLIF(max(rs.cf_v)   OVER (), 0) AS cf_n,
           rs.int_v  / NULLIF(max(rs.int_v)  OVER (), 0) AS int_n,
           rs.role_v / NULLIF(max(rs.role_v) OVER (), 0) AS role_n,
           rs.pop_v  / NULLIF(max(rs.pop_v)  OVER (), 0) AS pop_n
    FROM raw_scores rs
  ),
  scored AS (
    SELECT sc.*,
           sc.stock_factor * 0.30 * COALESCE(sc.cf_n, 0)   AS cf_part,
           sc.stock_factor * 0.40 * COALESCE(sc.int_n, 0)  AS int_part,
           sc.stock_factor * 0.20 * COALESCE(sc.role_n, 0) AS role_part,
           sc.stock_factor * 0.10 * COALESCE(sc.pop_n, 0)  AS pop_part
    FROM scaled sc
  ),
  ranked AS (
    SELECT s.*,
           s.cf_part + s.int_part + s.role_part + s.pop_part AS total,
           row_number() OVER (PARTITION BY s.category_id
                              ORDER BY s.cf_part + s.int_part + s.role_part + s.pop_part DESC,
                                       s.product_id) AS in_category
    FROM scored s
  )
  SELECT r.product_id,
         round(r.total, 4) AS score,
         -- The biggest of the four parts explains the pick.
         CASE GREATEST(r.cf_part, r.int_part, r.role_part, r.pop_part)
           WHEN 0 THEN 'Popular right now'
           WHEN r.cf_part THEN
             'Shoppers who liked ' || (SELECT p.name FROM public.products p WHERE p.product_id = r.because_of) ||
             ' also chose this'
           WHEN r.int_part THEN
             'Based on your ' || (SELECT cat.name FROM public.categories cat WHERE cat.category_id = r.category_id) ||
             CASE r.top_kind WHEN 'purchase' THEN ' purchases'
                             WHEN 'wishlist' THEN ' wishlist'
                             WHEN 'cart_add' THEN ' cart'
                             ELSE ' views' END
           WHEN r.role_part THEN
             CASE (SELECT shopper_role FROM my_role)
               WHEN 'gamer'      THEN 'Picked for gamers'
               WHEN 'student'    THEN 'Picked for students'
               ELSE                   'Picked for business' END
           ELSE 'Popular right now'
         END AS reason
  FROM ranked r
  WHERE r.in_category <= ceil(GREATEST(p_limit, 1) * 0.6)
  ORDER BY r.total DESC, r.product_id
  LIMIT GREATEST(p_limit, 1);
$$;

REVOKE EXECUTE ON FUNCTION public.recommend_products(integer, integer) FROM public, anon, authenticated;
