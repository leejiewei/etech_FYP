-- ============================================================
-- What the admin panel reads.
--
-- Every admin page used to be a .php file that ran its own SQL and
-- printed the answer. With the panel served as plain HTML, those
-- queries have to live somewhere the browser can reach — and the one
-- thing a browser cannot send is a GROUP BY. PostgREST turns a URL into
-- a single SELECT; it will not accept an aggregate written by the
-- client, and that is a good thing, because it means the shape of every
-- report is fixed here rather than being whatever the page asks for.
--
-- So each report becomes a view, and the two that take arguments become
-- functions. Nothing new is computed: these are the same statements
-- that were in web/admin/*.php, moved down one layer.
--
-- Two flavours, and the difference matters:
--
--   security_invoker = on   the view runs as whoever queried it, so the
--                           RLS policies on the underlying tables still
--                           apply. Staff see everything because their
--                           policies say so; anybody else sees nothing.
--                           This is the default choice.
--
--   security_invoker = off  the view runs as its owner and so is not
--                           subject to RLS or to column grants. Needed
--                           only where a report must show cost_price or
--                           stock_qty, which are revoked from every
--                           client role. Those views gate themselves on
--                           is_admin() in a WHERE clause instead.
--
-- Month buckets are cut in Malaysian time. The PHP connection used to
-- ask for that zone on every connect (SET TIME ZONE); PostgREST works
-- in UTC, so the conversion is written into each expression, otherwise
-- an order placed at 3am on the 1st would land in the previous month.
-- ============================================================


-- ============================================================
-- Dashboard tiles.  Was: the eleven fetchValue() calls at the top of
-- admin/index.php. One row, so the page makes one request.
--
-- security_invoker = off because two of these count products by
-- cost_price and stock_qty, which no client role may read.
-- ============================================================
CREATE VIEW public.admin_dashboard WITH (security_invoker = off) AS
SELECT
  (SELECT count(*) FROM public.products WHERE is_active = 1)                        AS product_count,
  (SELECT count(*) FROM public.products WHERE is_active = 1 AND stock_status = 'out') AS out_of_stock,
  (SELECT count(*) FROM public.products WHERE is_active = 1 AND stock_status = 'low') AS low_stock,
  (SELECT count(*) FROM public.customers)                                            AS customer_count,
  (SELECT count(*) FROM public.orders)                                               AS order_count,
  (SELECT count(*) FROM public.orders WHERE status = 'Pending')                      AS pending_orders,
  (SELECT COALESCE(sum(total), 0) FROM public.orders WHERE status <> 'Cancelled')    AS revenue,
  (SELECT count(*) FROM public.coupons
    WHERE is_active = 1 AND starts_at <= now()
      AND (ends_at IS NULL OR ends_at >= now()))                                     AS live_coupons,
  (SELECT count(*) FROM public.products WHERE is_active = 1 AND cost_price IS NULL)  AS missing_cost,
  (SELECT count(*) FROM public.products WHERE is_active = 1 AND stock_qty IS NULL)   AS missing_qty
WHERE (SELECT public.is_admin());


-- ============================================================
-- The catalogue as staff see it — every column, including the two the
-- shop front is not allowed near, plus the brand and category names the
-- list and the edit form both need.
--
-- security_invoker = off for cost_price and stock_qty; the is_admin()
-- test in the WHERE clause is what stands in for the RLS that is
-- therefore skipped.
-- ============================================================
CREATE VIEW public.admin_products WITH (security_invoker = off) AS
SELECT
  p.product_id, p.name, p.brand_id, p.category_id, p.price, p.cost_price,
  p.stock_qty, p.reorder_level, p.stock_status, p.description, p.icon,
  p.img_slug, p.image_path, p.exclude_from_builder, p.is_active,
  p.created_at, p.updated_at,
  b.name       AS brand,
  c.name       AS category,
  parent.name  AS parent_category,
  COALESCE(parent.name, c.name) AS top_category,
  -- The product list filters by "this category or anything under it",
  -- so it needs the parent's id and not only its name.
  c.parent_id  AS parent_category_id
FROM public.products p
JOIN public.brands b               ON b.brand_id = p.brand_id
JOIN public.categories c           ON c.category_id = p.category_id
LEFT JOIN public.categories parent ON parent.category_id = c.parent_id
WHERE (SELECT public.is_admin());


-- ============================================================
-- Orders, with the customer's name attached.  Was: admin/orders.php
-- and the "latest orders" panel on the dashboard.
--
-- Plain security_invoker: the staff policy on orders already decides
-- who may see these rows.
-- ============================================================
CREATE VIEW public.admin_orders WITH (security_invoker = on) AS
SELECT
  o.order_id, o.order_date, o.status, o.subtotal, o.discount, o.total,
  o.coupon_code, o.shipping_name, o.shipping_phone, o.shipping_address,
  o.customer_id,
  c.name  AS customer_name,
  c.email AS customer_email
FROM public.orders o
JOIN public.customers c ON c.customer_id = o.customer_id;

-- The status filter chips across the top of the orders page.
CREATE VIEW public.admin_order_status_counts WITH (security_invoker = on) AS
SELECT status, count(*) AS orders
FROM public.orders
GROUP BY status;

-- Who moved an order along, and when.
CREATE VIEW public.admin_order_history WITH (security_invoker = on) AS
SELECT h.history_id, h.order_id, h.status, h.note, h.changed_at,
       a.name AS staff
FROM public.order_status_history h
LEFT JOIN public.admins a ON a.admin_id = h.changed_by;


-- ============================================================
-- Promotions, with the category they apply to and how many orders have
-- used each one.  Was: the two-part query in admin/coupons.php.
-- ============================================================
CREATE VIEW public.admin_coupons WITH (security_invoker = on) AS
SELECT
  co.coupon_id, co.code, co.description, co.category_id,
  co.discount_percent, co.starts_at, co.ends_at, co.is_active, co.created_at,
  cat.name AS category,
  (SELECT count(*) FROM public.orders o WHERE o.coupon_code = co.code) AS times_used
FROM public.coupons co
LEFT JOIN public.categories cat ON cat.category_id = co.category_id;


-- ============================================================
-- Chatbot transcript, with the customer's name where there was one.
-- Was: admin/chatlogs.php.
-- ============================================================
CREATE VIEW public.admin_chat_logs WITH (security_invoker = on) AS
SELECT l.log_id, l.question, l.answer, l.was_build_request, l.created_at,
       l.customer_id,
       c.name AS customer_name
FROM public.chatbot_logs l
LEFT JOIN public.customers c ON c.customer_id = l.customer_id;


-- ============================================================
-- The category tree, flattened the way every dropdown in the panel
-- wants it: parents first, each followed by its children.
-- ============================================================
CREATE VIEW public.category_options WITH (security_invoker = on) AS
SELECT c.category_id, c.name, c.parent_id, parent.name AS parent
FROM public.categories c
LEFT JOIN public.categories parent ON parent.category_id = c.parent_id
ORDER BY COALESCE(parent.name, c.name), (c.parent_id IS NOT NULL), c.name;


-- ============================================================
-- Sales reporting.  Was: admin/reports.php and admin/forecast.php.
--
-- Both pages read the same monthly series; reports trims it to the last
-- twelve months in the browser, and the forecast fits its line to all
-- of it. Cancelled orders are excluded everywhere, as they always were.
-- ============================================================
CREATE VIEW public.admin_monthly_sales WITH (security_invoker = on) AS
SELECT
  to_char(o.order_date AT TIME ZONE 'Asia/Kuala_Lumpur', 'YYYY-MM') AS month,
  count(DISTINCT o.order_id) AS orders,
  sum(oi.quantity)           AS units,
  sum(oi.line_total)         AS revenue
FROM public.orders o
JOIN public.order_items oi ON oi.order_id = o.order_id
WHERE o.status <> 'Cancelled'
GROUP BY 1
ORDER BY 1;

-- Which categories are growing or shrinking, month by month.
CREATE VIEW public.admin_category_monthly WITH (security_invoker = on) AS
SELECT
  COALESCE(parent.name, c.name) AS category,
  to_char(o.order_date AT TIME ZONE 'Asia/Kuala_Lumpur', 'YYYY-MM') AS month,
  sum(oi.line_total) AS revenue,
  sum(oi.quantity)   AS units
FROM public.order_items oi
JOIN public.orders o     ON o.order_id = oi.order_id
JOIN public.products p   ON p.product_id = oi.product_id
JOIN public.categories c ON c.category_id = p.category_id
LEFT JOIN public.categories parent ON parent.category_id = c.parent_id
WHERE o.status <> 'Cancelled'
GROUP BY 1, 2
ORDER BY 1, 2;

-- Best sellers, by money taken. Grouped on the copied product_name, so
-- a product that has since been renamed or deleted still appears.
CREATE VIEW public.admin_top_products WITH (security_invoker = on) AS
SELECT oi.product_name,
       sum(oi.quantity)   AS units,
       sum(oi.line_total) AS revenue
FROM public.order_items oi
JOIN public.orders o ON o.order_id = oi.order_id
WHERE o.status <> 'Cancelled'
GROUP BY oi.product_name
ORDER BY revenue DESC;

CREATE VIEW public.admin_category_revenue WITH (security_invoker = on) AS
SELECT COALESCE(parent.name, c.name) AS category,
       sum(oi.line_total) AS revenue,
       sum(oi.quantity)   AS units
FROM public.order_items oi
JOIN public.orders o     ON o.order_id = oi.order_id
JOIN public.products p   ON p.product_id = oi.product_id
JOIN public.categories c ON c.category_id = p.category_id
LEFT JOIN public.categories parent ON parent.category_id = c.parent_id
WHERE o.status <> 'Cancelled'
GROUP BY 1
ORDER BY revenue DESC;

-- One row per customer per category. The page adds these up into the
-- three segments; the rule for which segment somebody lands in stays in
-- the browser, because it is a business judgement that gets argued
-- about, not a fact about the data.
CREATE VIEW public.admin_customer_spend WITH (security_invoker = on) AS
SELECT o.customer_id,
       cu.name  AS customer_name,
       cu.email AS customer_email,
       COALESCE(parent.name, c.name) AS category,
       sum(oi.line_total) AS spend
FROM public.order_items oi
JOIN public.orders o     ON o.order_id = oi.order_id
JOIN public.customers cu ON cu.customer_id = o.customer_id
JOIN public.products p   ON p.product_id = oi.product_id
JOIN public.categories c ON c.category_id = p.category_id
LEFT JOIN public.categories parent ON parent.category_id = c.parent_id
WHERE o.status <> 'Cancelled'
GROUP BY o.customer_id, cu.name, cu.email, COALESCE(parent.name, c.name);


-- ============================================================
-- Inventory Velocity.  Was: the one big query at the top of both
-- admin/velocity.php and admin/alerts.php — they asked for the same
-- thing with different filters, so this is written once.
--
--     score = (views x 1) + (cart adds x 3) + (purchases x 5)
--
-- A product with no activity scores 0 rather than NULL, so untouched
-- stock sorts properly at the bottom — which is exactly what the
-- dead-stock alert needs to find.
--
-- A function rather than a view because the window and the category are
-- chosen on the page. They were being pasted into the SQL string in
-- PHP; as arguments they cannot be anything but a number.
--
-- SECURITY DEFINER for cost_price, stock_qty and reorder_level, which
-- the alerts page needs and no client role may read — so it checks
-- is_admin() itself before doing anything.
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_product_scores(
  p_days     integer DEFAULT 90,
  p_category integer DEFAULT NULL
)
RETURNS TABLE (
  product_id    integer,
  name          varchar,
  price         numeric,
  cost_price    numeric,
  stock_qty     integer,
  reorder_level integer,
  stock_status  public.stock_status,
  created_at    timestamptz,
  category      varchar,
  parent        varchar,
  views         bigint,
  cart_adds     bigint,
  purchases     bigint,
  score         bigint,
  last_seen     timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    p.product_id, p.name, p.price, p.cost_price, p.stock_qty, p.reorder_level,
    p.stock_status, p.created_at,
    c.name AS category, parent.name AS parent,
    count(*) FILTER (WHERE e.event_type = 'view')     AS views,
    count(*) FILTER (WHERE e.event_type = 'cart_add') AS cart_adds,
    count(*) FILTER (WHERE e.event_type = 'purchase') AS purchases,
      count(*) FILTER (WHERE e.event_type = 'view')     * 1
    + count(*) FILTER (WHERE e.event_type = 'cart_add') * 3
    + count(*) FILTER (WHERE e.event_type = 'purchase') * 5 AS score,
    max(e.created_at) AS last_seen
  FROM public.products p
  JOIN public.categories c            ON c.category_id = p.category_id
  LEFT JOIN public.categories parent  ON parent.category_id = c.parent_id
  -- The window is part of the join, not a WHERE, so a product with no
  -- activity in it still comes back with a row of zeroes.
  LEFT JOIN public.events e
         ON e.product_id = p.product_id
        AND (p_days IS NULL OR p_days <= 0
             OR e.created_at >= now() - make_interval(days => p_days))
  WHERE p.is_active = 1
    AND (p_category IS NULL OR p_category <= 0
         OR p.category_id = p_category OR c.parent_id = p_category)
    AND (SELECT public.is_admin())
  GROUP BY p.product_id, p.name, p.price, p.cost_price, p.stock_qty,
           p.reorder_level, p.stock_status, p.created_at, c.name, parent.name
  ORDER BY score DESC, p.name;
$$;


-- ============================================================
-- Moving an order along.  Was: the two writes inside a transaction at
-- the top of admin/orders.php.
--
-- The status change and the history line belong together — a status
-- that changed with nothing recording who changed it is the one thing
-- the history table exists to prevent. SECURITY DEFINER so it can look
-- up which admin row the caller is and stamp it on the history line.
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_set_order_status(
  p_order_id integer,
  p_status   public.order_status,
  p_note     text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin integer;
BEGIN
  SELECT a.admin_id INTO v_admin
  FROM public.admins a WHERE a.auth_user_id = auth.uid();

  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'Staff access only.' USING ERRCODE = '42501';
  END IF;

  UPDATE public.orders SET status = p_status WHERE order_id = p_order_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'That order no longer exists.' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.order_status_history (order_id, status, changed_by, note)
  VALUES (p_order_id, p_status, v_admin, NULLIF(btrim(COALESCE(p_note, '')), ''));
END;
$$;


-- ============================================================
-- The next product id.
--
-- Product ids are not generated: they match the picture files in
-- web/images, so a new product takes the next number above the highest
-- in use. admin/product_edit.php read that with MAX(product_id) + 1,
-- which the browser cannot do now that MAX is an aggregate — and which
-- two people saving at once could get wrong anyway.
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_next_product_id()
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE WHEN (SELECT public.is_admin())
              THEN COALESCE(max(p.product_id), 0) + 1
         END
  FROM public.products p;
$$;


-- ============================================================
-- Who may read what
-- ============================================================
REVOKE ALL ON public.admin_dashboard            FROM anon, authenticated;
REVOKE ALL ON public.admin_products             FROM anon, authenticated;
REVOKE ALL ON public.admin_orders               FROM anon, authenticated;
REVOKE ALL ON public.admin_order_status_counts  FROM anon, authenticated;
REVOKE ALL ON public.admin_order_history        FROM anon, authenticated;
REVOKE ALL ON public.admin_coupons              FROM anon, authenticated;
REVOKE ALL ON public.admin_chat_logs            FROM anon, authenticated;
REVOKE ALL ON public.admin_monthly_sales        FROM anon, authenticated;
REVOKE ALL ON public.admin_category_monthly     FROM anon, authenticated;
REVOKE ALL ON public.admin_top_products         FROM anon, authenticated;
REVOKE ALL ON public.admin_category_revenue     FROM anon, authenticated;
REVOKE ALL ON public.admin_customer_spend       FROM anon, authenticated;
REVOKE ALL ON public.category_options           FROM anon, authenticated;

GRANT SELECT ON public.admin_dashboard           TO authenticated;
GRANT SELECT ON public.admin_products            TO authenticated;
GRANT SELECT ON public.admin_orders              TO authenticated;
GRANT SELECT ON public.admin_order_status_counts TO authenticated;
GRANT SELECT ON public.admin_order_history       TO authenticated;
GRANT SELECT ON public.admin_coupons             TO authenticated;
GRANT SELECT ON public.admin_chat_logs           TO authenticated;
GRANT SELECT ON public.admin_monthly_sales       TO authenticated;
GRANT SELECT ON public.admin_category_monthly    TO authenticated;
GRANT SELECT ON public.admin_top_products        TO authenticated;
GRANT SELECT ON public.admin_category_revenue    TO authenticated;
GRANT SELECT ON public.admin_customer_spend      TO authenticated;

-- The category dropdowns appear on admin forms only, but the view holds
-- nothing the catalogue does not already show, so anon may read it too.
GRANT SELECT ON public.category_options TO anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.admin_product_scores(integer, integer)                        FROM public;
REVOKE EXECUTE ON FUNCTION public.admin_set_order_status(integer, public.order_status, text)    FROM public;
REVOKE EXECUTE ON FUNCTION public.admin_next_product_id()                                       FROM public;

GRANT EXECUTE ON FUNCTION public.admin_product_scores(integer, integer)                     TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_order_status(integer, public.order_status, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_next_product_id()                                    TO authenticated;
