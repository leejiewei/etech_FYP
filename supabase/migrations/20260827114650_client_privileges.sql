-- ============================================================
-- Column privileges, and the Row Level Security policies the previous
-- RLS migration deliberately left unwritten.
--
-- Until now the only thing reading this database was web/api/*.php,
-- connecting as the table owner. An owner is not subject to RLS, so a
-- deny-everything policy set was enough: the site worked and the anon
-- key saw nothing. That stops being true the moment the browser and the
-- phone hold the anon key themselves, which is what this release does.
--
-- What PHP was enforcing, and what enforces it now:
--
--   WHERE customer_id = $_SESSION[...]   ->  a policy on each table
--   requireAdmin() at the top of a page  ->  is_admin() inside a policy
--   never SELECTing cost_price           ->  a column-level GRANT
-- ============================================================


-- ============================================================
-- 1. Column privileges
--
-- A policy filters rows, not columns. It can say "you may read your own
-- orders"; it cannot say "you may read this order but not its cost".
-- That job belongs to GRANT, and it is the half of the old etech_client
-- MySQL login that policies alone cannot reproduce.
--
-- A table-level GRANT SELECT beats any column-level one, so the broad
-- grant has to come off before the narrow one goes on. Supabase grants
-- anon and authenticated everything on every table in public by
-- default, which is why each block starts with a REVOKE.
--
-- One consequence worth knowing: asking these tables for select=* now
-- returns an error rather than a row. Every query in web/js and in
-- mobile/lib names the columns it wants.
-- ============================================================

-- What we pay for stock, and how many sit on the shelf, are not the
-- shopper's business. The admin panel reads both through admin_products.
REVOKE SELECT ON public.products FROM anon, authenticated;
GRANT  SELECT (product_id, name, brand_id, category_id, price, stock_status,
               description, icon, img_slug, image_path, exclude_from_builder,
               is_active, created_at, updated_at)
  ON public.products TO anon, authenticated;

-- unit_cost is the margin on one line of one order. Same reasoning.
REVOKE SELECT ON public.order_items FROM anon, authenticated;
GRANT  SELECT (order_item_id, order_id, product_id, product_name,
               unit_price, quantity, line_total)
  ON public.order_items TO authenticated;

-- The old PHP password hashes stay in the table for now, but nothing
-- has any reason to read them again.
REVOKE SELECT ON public.customers FROM anon, authenticated;
GRANT  SELECT (customer_id, name, email, phone, address, created_at, auth_user_id)
  ON public.customers TO authenticated;

-- A customer edits their own name, phone and address and nothing else.
-- Without this, "save your profile" would also be "point your row at
-- somebody else's login".
REVOKE INSERT, UPDATE, DELETE ON public.customers FROM anon, authenticated;
GRANT  UPDATE (name, phone, address) ON public.customers TO authenticated;

-- Staff rows are read by is_admin(), which is SECURITY DEFINER and so
-- needs no grant of its own, and by the admin panel's own header.
REVOKE ALL ON public.admins FROM anon, authenticated;
GRANT  SELECT (admin_id, username, name, created_at) ON public.admins TO authenticated;

-- Tracking is write-only from the shop front, exactly as it was when
-- etech_client held INSERT on these two and nothing else.
REVOKE UPDATE, DELETE ON public.events       FROM anon, authenticated;
REVOKE UPDATE, DELETE ON public.chatbot_logs FROM anon, authenticated;
REVOKE SELECT          ON public.events       FROM anon;
REVOKE SELECT          ON public.chatbot_logs FROM anon;

-- Nothing signed out has any business in these at all.
REVOKE ALL ON public.orders               FROM anon;
REVOKE ALL ON public.order_items          FROM anon;
REVOKE ALL ON public.order_status_history FROM anon;
REVOKE ALL ON public.cart_items           FROM anon;
REVOKE ALL ON public.wishlist_items       FROM anon;
REVOKE ALL ON public.login_attempts       FROM anon, authenticated;

-- Orders are written by place_order() and by staff, never by a plain
-- client statement, or a shopper could name their own total.
REVOKE INSERT, UPDATE, DELETE ON public.orders      FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.order_items FROM authenticated;

-- The catalogue is read-only to the public. Staff write to it through
-- the policies below, which need the table grant left in place.
REVOKE INSERT, UPDATE, DELETE ON public.brands             FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.categories         FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.products           FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.product_attributes FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.coupons            FROM anon;


-- ============================================================
-- 2. Policies
--
-- Two habits run through all of these:
--
--   * is_admin() and current_customer_id() are always written as
--     (SELECT ...). Postgres then treats the call as an InitPlan and
--     runs it once per statement instead of once per row, which matters
--     on events, where the dashboard sweeps thousands of rows.
--
--   * several policies on one table OR together, so the narrow customer
--     rule and the wide staff rule sit side by side rather than being
--     folded into one tangled condition.
-- ============================================================

-- ---------------------------------------------------- catalogue
-- The shop is browsable signed out, so anon is included here.
CREATE POLICY "catalogue is public" ON public.products
  FOR SELECT TO anon, authenticated USING (is_active = 1);

CREATE POLICY "brands are public" ON public.brands
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "categories are public" ON public.categories
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "specs are public" ON public.product_attributes
  FOR SELECT TO anon, authenticated USING (true);

CREATE POLICY "staff manage products" ON public.products
  FOR ALL TO authenticated
  USING ((SELECT public.is_admin())) WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "staff manage brands" ON public.brands
  FOR ALL TO authenticated
  USING ((SELECT public.is_admin())) WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "staff manage categories" ON public.categories
  FOR ALL TO authenticated
  USING ((SELECT public.is_admin())) WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "staff manage specs" ON public.product_attributes
  FOR ALL TO authenticated
  USING ((SELECT public.is_admin())) WITH CHECK ((SELECT public.is_admin()));

-- ---------------------------------------------------- promotions
-- Switched off or out of date is filtered here, so the Deals page no
-- longer has to be trusted to filter it in the browser.
CREATE POLICY "live promotions are public" ON public.coupons
  FOR SELECT TO anon, authenticated USING (
    is_active = 1
    AND starts_at <= now()
    AND (ends_at IS NULL OR ends_at >= now())
  );

CREATE POLICY "staff manage promotions" ON public.coupons
  FOR ALL TO authenticated
  USING ((SELECT public.is_admin())) WITH CHECK ((SELECT public.is_admin()));

-- ---------------------------------------------------- accounts
CREATE POLICY "customers read themselves" ON public.customers
  FOR SELECT TO authenticated USING (auth_user_id = (SELECT auth.uid()));

CREATE POLICY "customers edit themselves" ON public.customers
  FOR UPDATE TO authenticated
  USING (auth_user_id = (SELECT auth.uid()))
  WITH CHECK (auth_user_id = (SELECT auth.uid()));

-- The reports name the customer behind an order, so staff read this too.
CREATE POLICY "staff read customers" ON public.customers
  FOR SELECT TO authenticated USING ((SELECT public.is_admin()));

CREATE POLICY "staff read staff" ON public.admins
  FOR SELECT TO authenticated USING ((SELECT public.is_admin()));

-- ---------------------------------------------------- basket and wishlist
CREATE POLICY "own basket" ON public.cart_items
  FOR ALL TO authenticated
  USING (customer_id = (SELECT public.current_customer_id()))
  WITH CHECK (customer_id = (SELECT public.current_customer_id()));

CREATE POLICY "own wishlist" ON public.wishlist_items
  FOR ALL TO authenticated
  USING (customer_id = (SELECT public.current_customer_id()))
  WITH CHECK (customer_id = (SELECT public.current_customer_id()));

-- ---------------------------------------------------- orders
CREATE POLICY "own orders" ON public.orders
  FOR SELECT TO authenticated
  USING (customer_id = (SELECT public.current_customer_id()));

CREATE POLICY "own order lines" ON public.order_items
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.order_id = order_items.order_id
      AND o.customer_id = (SELECT public.current_customer_id())
  ));

CREATE POLICY "staff manage orders" ON public.orders
  FOR ALL TO authenticated
  USING ((SELECT public.is_admin())) WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "staff manage order lines" ON public.order_items
  FOR ALL TO authenticated
  USING ((SELECT public.is_admin())) WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "staff manage order history" ON public.order_status_history
  FOR ALL TO authenticated
  USING ((SELECT public.is_admin())) WITH CHECK ((SELECT public.is_admin()));

-- ---------------------------------------------------- tracking
-- Write-only for shoppers. A signed-out view carries no customer_id; a
-- signed-in one may only carry its own, so nobody can pad somebody
-- else's history or read what other people have been looking at.
CREATE POLICY "anyone may record activity" ON public.events
  FOR INSERT TO anon, authenticated
  WITH CHECK (customer_id IS NULL OR customer_id = (SELECT public.current_customer_id()));

CREATE POLICY "anyone may log a chat" ON public.chatbot_logs
  FOR INSERT TO anon, authenticated
  WITH CHECK (customer_id IS NULL OR customer_id = (SELECT public.current_customer_id()));

CREATE POLICY "staff read activity" ON public.events
  FOR SELECT TO authenticated USING ((SELECT public.is_admin()));

CREATE POLICY "staff read chat logs" ON public.chatbot_logs
  FOR SELECT TO authenticated USING ((SELECT public.is_admin()));

-- login_attempts keeps RLS on and no policy at all. It counted failed
-- sign-ins for the PHP admin login screen; Supabase Auth does its own
-- rate limiting, so nothing reads or writes this table any more.
