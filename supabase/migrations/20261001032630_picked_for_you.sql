-- ============================================================
-- Personalised recommendations: "Picked for you".
--
-- The FYP aim, in the owner's words: analyse customer behaviour and give
-- each signed-in customer personalised product recommendations using
-- machine learning. This migration is the engine; the home page on the
-- web and in the app, and a push to the phone, are its three windows.
--
-- WHO GETS THEM
--
-- Signed-in customers only. A recommendation is about a person, and the
-- only person this database can name is one with an account. Signed-out
-- browsing still counts -- claim_anon_activity() hands it to the account
-- the moment they sign in -- but nothing is recommended to nobody.
--
-- WHAT IT LEARNS FROM, AND HOW
--
-- Four signals, each scaled to 0..1 across the candidates, then blended:
--
--   0.40  category interest         The customer's own history, summed
--                                   per category. Keep opening laptops and
--                                   laptops climb. Recent behaviour counts
--                                   more: a 45-day exponential decay.
--                                   Weighted highest because it is the one
--                                   the customer can see working.
--   0.30  collaborative filtering   Item-to-item cosine similarity over
--                                   every OTHER customer's interactions.
--                                   "Customers who bought/saved/viewed
--                                   the things you did also went for
--                                   this." This is the machine-learning
--                                   part in the textbook sense: a
--                                   neighbourhood model learned from the
--                                   customer-item matrix, not a rule
--                                   anybody wrote.
--   0.20  shopper role              Student, Enterprise or Gamer, picked
--                                   at sign-up. It is what makes a brand
--                                   new account's home page already lean
--                                   the right way (the cold-start problem),
--                                   and it fades in importance as real
--                                   behaviour piles up beside it. Students
--                                   are nudged toward the cheaper end of
--                                   each category.
--   0.10  popularity                What everybody interacts with. Mostly
--                                   a tie-breaker.
--
-- One interaction, four strengths:
--
--   view 1   cart add 3   wishlist 4   purchase 5
--
-- the same order as the velocity score staff already know, with the
-- wishlist slotted in as "wanted, not yet bought". Wishlist strength is
-- read from wishlist_items rather than wishlist_add events, so a product
-- taken back off the wishlist stops counting.
--
-- The September beta capture in events_archive_20260916 is read too. It
-- is 946 real interactions from 14 customers and it is the only
-- cross-customer history the shop has: without it the collaborative
-- filter would have nobody to compare anyone with.
--
-- WHAT IT WILL NOT RECOMMEND
--
-- Something the customer already bought, something already on their
-- wishlist (it is saved; telling them about it is the deal alert's job),
-- and inactive products. Out of stock is NOT excluded: every one of the
-- 37 laptops is 'out' because the shop orders them in, and laptops are
-- the owner's own example of what a student should be shown. Out of
-- stock keeps 90% of its score instead, so an in-stock product wins a
-- tie. And no more than 60% of
-- the list from one category, so a laptop shopper sees mostly laptops,
-- which is the point, but not only laptops.
-- ============================================================


-- ------------------------------------------------------------
-- 1. The customer says who they are.
--
-- Nullable: the 15 accounts made before today have no answer, and
-- inventing one for them would be worse than asking. The home page asks.
-- ------------------------------------------------------------
ALTER TABLE public.customers
  ADD COLUMN IF NOT EXISTS shopper_role text
  CHECK (shopper_role IN ('student', 'enterprise', 'gamer'));

COMMENT ON COLUMN public.customers.shopper_role IS
  'Student, enterprise or gamer, chosen by the customer. Seeds their recommendations before they have any history.';

-- The customer reads and changes their own answer. Column-level, like
-- the rest of this table: UPDATE was exactly (name, phone, address) and
-- is now those three and this one.
GRANT SELECT (shopper_role), UPDATE (shopper_role) ON public.customers TO authenticated;


-- ------------------------------------------------------------
-- 2. What each role leans toward.
--
-- A table rather than a CASE inside the function so the leaning can be
-- tuned without a new function, and so the thesis can print it. Weights
-- are 0..1; a category not listed is 0 for that role, not excluded.
-- Read only by the SECURITY DEFINER function below, so no client grant.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.role_category_weights (
  shopper_role text    NOT NULL CHECK (shopper_role IN ('student', 'enterprise', 'gamer')),
  category_id  integer NOT NULL REFERENCES public.categories(category_id) ON DELETE CASCADE,
  weight       numeric NOT NULL CHECK (weight > 0 AND weight <= 1),
  PRIMARY KEY (shopper_role, category_id)
);

COMMENT ON TABLE public.role_category_weights IS
  'How strongly each shopper role leans toward each category. The cold-start prior for recommend_products().';

ALTER TABLE public.role_category_weights ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.role_category_weights FROM anon, authenticated, public;

INSERT INTO public.role_category_weights (shopper_role, category_id, weight) VALUES
  -- Gamer: the parts of a gaming rig, the rig itself, and what sits on the desk.
  ('gamer', 20, 1.0),  -- GPU
  ('gamer', 37, 1.0),  -- Prebuilt Gaming PCs
  ('gamer', 40, 0.9),  -- Keyboard
  ('gamer', 41, 0.9),  -- Mouse
  ('gamer', 43, 0.9),  -- Headset
  ('gamer', 18, 0.8),  -- CPU
  ('gamer',  7, 0.8),  -- Monitors
  ('gamer', 42, 0.7),  -- Mouse Pad
  ('gamer', 19, 0.6),  -- Motherboard
  ('gamer', 21, 0.6),  -- RAM
  ('gamer', 17, 0.6),  -- Case
  ('gamer', 10, 0.6),  -- Cooler
  ('gamer',  2, 0.5),  -- Laptops (gaming laptops)
  ('gamer', 23, 0.5),  -- Storage
  ('gamer', 24, 0.5),  -- PSU
  ('gamer', 25, 0.5),  -- Case Fans
  ('gamer', 29, 0.5),  -- ARGB Lighting
  ('gamer', 45, 0.5),  -- Microphone
  ('gamer', 46, 0.4),  -- Speaker
  -- Student: a laptop and what goes with it, on a budget.
  ('student',  2, 1.0),  -- Laptops
  ('student', 41, 0.8),  -- Mouse
  ('student', 44, 0.8),  -- Earbuds
  ('student', 22, 0.7),  -- Laptop Memory
  ('student', 43, 0.7),  -- Headset
  ('student', 47, 0.6),  -- Webcams
  ('student', 40, 0.6),  -- Keyboard
  ('student', 23, 0.6),  -- Storage
  ('student', 42, 0.5),  -- Mouse Pad
  ('student',  7, 0.5),  -- Monitors
  ('student', 11, 0.5),  -- Inkjet
  ('student', 13, 0.5),  -- Ink Tank
  ('student', 28, 0.4),  -- Power Adapters
  ('student', 46, 0.4),  -- Speaker
  ('student', 31, 0.3),  -- Router
  -- Enterprise: office machines, printing, networking, meeting rooms.
  ('enterprise', 35, 1.0),  -- Branded PC
  ('enterprise', 36, 1.0),  -- All-in-One PC
  ('enterprise', 38, 1.0),  -- Office PC Series
  ('enterprise', 39, 0.9),  -- Custom Office CO1
  ('enterprise', 12, 0.9),  -- Laser
  ('enterprise',  2, 0.8),  -- Laptops
  ('enterprise',  7, 0.8),  -- Monitors
  ('enterprise', 13, 0.8),  -- Ink Tank
  ('enterprise', 31, 0.8),  -- Router
  ('enterprise', 14, 0.8),  -- Projector
  ('enterprise',  9, 0.7),  -- Monitor Arms
  ('enterprise', 32, 0.7),  -- Mesh WiFi
  ('enterprise', 47, 0.7),  -- Webcams
  ('enterprise', 33, 0.6),  -- Cellular Router
  ('enterprise',  6, 0.6),  -- Consumables
  ('enterprise', 16, 0.5),  -- Screen
  ('enterprise', 15, 0.4),  -- Projector accessory
  ('enterprise', 40, 0.4),  -- Keyboard
  ('enterprise', 41, 0.4),  -- Mouse
  ('enterprise', 23, 0.4)   -- Storage
ON CONFLICT (shopper_role, category_id) DO UPDATE SET weight = EXCLUDED.weight;


-- ------------------------------------------------------------
-- 3. New sign-ups bring their role with them.
--
-- The web and the app send it as sign-up metadata beside the name, the
-- same way the name already travels. Anything that is not one of the
-- three is dropped rather than refused: a sign-up must never fail over
-- a preference, and the home page will ask again.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_role text := lower(btrim(COALESCE(NEW.raw_user_meta_data ->> 'role', '')));
BEGIN
  IF (NEW.raw_app_meta_data ->> 'etech_role') = 'admin' THEN
    RETURN NEW;
  END IF;

  IF v_role NOT IN ('student', 'enterprise', 'gamer') THEN
    v_role := NULL;
  END IF;

  INSERT INTO public.customers AS c (name, email, auth_user_id, shopper_role)
  VALUES (
    COALESCE(NULLIF(btrim(NEW.raw_user_meta_data ->> 'name'), ''), split_part(NEW.email, '@', 1)),
    lower(NEW.email),
    NEW.id,
    v_role
  )
  ON CONFLICT (email) DO UPDATE
    SET auth_user_id = EXCLUDED.auth_user_id
    WHERE c.auth_user_id IS NULL;

  RETURN NEW;
END;
$$;


-- ------------------------------------------------------------
-- 4. The recommender.
--
-- Takes a customer id, so it is never granted to a client: anyone could
-- pass someone else's. recommend_for_me() below is the door customers
-- use, and send_recommendation_alerts() is the one the push uses.
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

COMMENT ON FUNCTION public.recommend_products(integer, integer) IS
  'Hybrid recommender: 0.4 own category interest + 0.3 item-item cosine CF + 0.2 shopper role + 0.1 popularity. Not client-callable; see recommend_for_me().';


-- ------------------------------------------------------------
-- 5. The customer's own door.
--
-- Answers for whoever is signed in and nobody else. Signed out, it
-- returns nothing rather than an error: the home page simply has no
-- "Picked for you" row.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recommend_for_me(p_limit integer DEFAULT 8)
RETURNS TABLE (product_id integer, score numeric, reason text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_customer integer := public.current_customer_id();
BEGIN
  IF v_customer IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT r.product_id, r.score, r.reason
  FROM public.recommend_products(v_customer, LEAST(GREATEST(COALESCE(p_limit, 8), 1), 24)) r;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recommend_for_me(integer) FROM public, anon;
GRANT  EXECUTE ON FUNCTION public.recommend_for_me(integer) TO authenticated;


-- ------------------------------------------------------------
-- 6. The same picks, sent to the phone.
--
-- A notification row is all it takes: trg_notify_push already turns
-- every new row into a push (20260916190000), and the bell on the web
-- and in the app already shows it and opens the product it names.
--
-- One message, about the customer's single best pick that they have not
-- been told about in the last 30 days, and no more than one message per
-- customer per p_cooldown_days. Only customers the recommender knows
-- something about -- a role or some history. Telling a blank account
-- what is popular is an advert, not a recommendation.
--
-- Staff may run it from the console; with no signed-in user it can also
-- run from a schedule. anon cannot reach it at all.
-- ------------------------------------------------------------
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_kind_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_kind_check
  CHECK (kind IN ('payment_approved', 'payment_rejected', 'order_ready', 'deal_started', 'recommendation'));

CREATE OR REPLACE FUNCTION public.send_recommendation_alerts(
  p_customer      integer DEFAULT NULL,
  p_cooldown_days integer DEFAULT 7
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_told integer := 0;
BEGIN
  -- A signed-in caller must be staff. No caller at all is a schedule.
  IF auth.uid() IS NOT NULL AND NOT (SELECT public.is_admin()) THEN
    RAISE EXCEPTION 'Staff access only.' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.notifications (customer_id, product_id, kind, title, body)
  SELECT c.customer_id,
         pick.product_id,
         'recommendation',
         'Picked for you',
         p.name || ' is RM ' || to_char(p.price, 'FM999G999D00') || '. ' ||
         pick.reason || '. Tap to take a look.'
  FROM public.customers c
  CROSS JOIN LATERAL (
    SELECT r.product_id, r.reason
    FROM public.recommend_products(c.customer_id, 12) r
    WHERE NOT EXISTS (
      SELECT 1 FROM public.notifications n
      WHERE n.customer_id = c.customer_id
        AND n.kind = 'recommendation'
        AND n.product_id = r.product_id
        AND n.created_at > now() - interval '30 days')
    ORDER BY r.score DESC
    LIMIT 1
  ) pick
  JOIN public.products p ON p.product_id = pick.product_id
  WHERE c.auth_user_id IS NOT NULL
    AND (p_customer IS NULL OR c.customer_id = p_customer)
    AND (c.shopper_role IS NOT NULL
         OR EXISTS (SELECT 1 FROM public.events e WHERE e.customer_id = c.customer_id)
         OR EXISTS (SELECT 1 FROM public.events_archive_20260916 a WHERE a.customer_id = c.customer_id)
         OR EXISTS (SELECT 1 FROM public.wishlist_items w WHERE w.customer_id = c.customer_id))
    AND NOT EXISTS (
      SELECT 1 FROM public.notifications n
      WHERE n.customer_id = c.customer_id
        AND n.kind = 'recommendation'
        AND n.created_at > now() - make_interval(days => GREATEST(p_cooldown_days, 0)));

  GET DIAGNOSTICS v_told = ROW_COUNT;
  RETURN v_told;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.send_recommendation_alerts(integer, integer) FROM public, anon;
GRANT  EXECUTE ON FUNCTION public.send_recommendation_alerts(integer, integer) TO authenticated;
