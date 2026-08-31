-- ============================================================
-- Finishing what the earlier REVOKEs meant to say.
--
-- 20260827114650_client_privileges.sql and the two files after it lock
-- each function down with the same pair of lines:
--
--     REVOKE EXECUTE ON FUNCTION ... FROM public;
--     GRANT  EXECUTE ON FUNCTION ... TO authenticated;
--
-- which reads as "only a signed-in caller may run this". It is not what
-- the database ended up doing. Supabase ships a default privilege on the
-- public schema that hands EXECUTE to anon on every function as it is
-- created, and that arrives as an *explicit* grant to the anon role —
-- not as part of PUBLIC. Revoking from PUBLIC leaves it untouched, so
-- every one of these functions stayed callable with nothing but the
-- publishable key that sits in web/js/config.js.
--
-- Nothing leaked, because each function checks the caller before it does
-- anything: the admin ones look the caller up in admins and return
-- nothing (or raise 'Staff access only.') when they miss, and the shop
-- ones resolve current_customer_id() first. That inner guard was doing
-- all of the work on its own. This file puts the outer layer back so
-- there are two again.
--
-- The same default is why several tables still carry TRUNCATE, TRIGGER
-- and REFERENCES for anon: the earlier files revoked SELECT, INSERT,
-- UPDATE and DELETE by name and left the rest of GRANT ALL behind.
-- PostgREST cannot issue any of the three, so this is tidying rather
-- than a repair, but it removes the gap between what the files claim and
-- what the database holds.
-- ============================================================


-- ------------------------------------------------------------
-- Functions: authenticated only, as intended.
-- ------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.cart_add(integer)                   FROM anon;
REVOKE EXECUTE ON FUNCTION public.toggle_wishlist(integer)            FROM anon;
REVOKE EXECUTE ON FUNCTION public.place_order(text, text, text, text) FROM anon;

REVOKE EXECUTE ON FUNCTION public.admin_product_scores(integer, integer)                     FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_set_order_status(integer, public.order_status, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_next_product_id()                                    FROM anon;

-- is_admin() is called from inside SECURITY DEFINER bodies and from the
-- WHERE of admin_dashboard and admin_products, both of which are
-- security_invoker = off and so run as the view's owner. Every policy
-- that names it is scoped TO authenticated. Nothing anon does can reach
-- it, so anon has no business being able to call it.
REVOKE EXECUTE ON FUNCTION public.is_admin() FROM anon;

-- current_customer_id() is deliberately left alone. The INSERT policies
-- "anyone may record activity" on events and "anyone may log a chat" on
-- chatbot_logs are granted TO anon, and their WITH CHECK calls it — a
-- policy expression is evaluated with the caller's own privileges, so
-- revoking it here would stop a logged-out visitor from being tracked or
-- from using the chatbot at all. It returns NULL for anon, which is what
-- those two policies expect.


-- ------------------------------------------------------------
-- category_options: the admin category dropdown, and nothing else.
--
-- 20260827114759_admin_views.sql revokes this view from anon and then
-- grants it straight back — the one line in that file that contradicts
-- itself. Only product_edit.js and products.js read it, both behind an
-- admin session. Anon loses nothing: the category names it exposes are
-- already public through the categories table.
-- ------------------------------------------------------------
REVOKE ALL ON public.category_options FROM anon;


-- ------------------------------------------------------------
-- The two surviving v_ views from the MySQL schema.
--
-- These predate the admin_ views and never had the REVOKE/GRANT pass the
-- others got, so they still carry the whole of GRANT ALL for anon —
-- including INSERT, UPDATE and DELETE. Both are security_invoker, so the
-- underlying tables have been refusing anon all along, but the grants
-- should not read that way. Only v_product_velocity is still read, by
-- the Inventory Velocity page, and that is an admin page.
-- ------------------------------------------------------------
REVOKE ALL ON public.v_product_velocity FROM anon, authenticated;
REVOKE ALL ON public.v_monthly_sales    FROM anon, authenticated;
GRANT SELECT ON public.v_product_velocity TO authenticated;
GRANT SELECT ON public.v_monthly_sales    TO authenticated;


-- ------------------------------------------------------------
-- Table privileges left over from GRANT ALL.
--
-- anon keeps exactly the reads the shop front needs, which the
-- column-level grants in client_privileges already describe. TRUNCATE,
-- TRIGGER and REFERENCES were never part of that.
-- ------------------------------------------------------------
REVOKE TRUNCATE, TRIGGER, REFERENCES ON public.products           FROM anon;
REVOKE TRUNCATE, TRIGGER, REFERENCES ON public.categories         FROM anon;
REVOKE TRUNCATE, TRIGGER, REFERENCES ON public.brands             FROM anon;
REVOKE TRUNCATE, TRIGGER, REFERENCES ON public.product_attributes FROM anon;
REVOKE TRUNCATE, TRIGGER, REFERENCES ON public.coupons            FROM anon;
REVOKE TRUNCATE, TRIGGER, REFERENCES ON public.customers          FROM anon;
REVOKE TRUNCATE, TRIGGER, REFERENCES ON public.events             FROM anon;
REVOKE TRUNCATE, TRIGGER, REFERENCES ON public.chatbot_logs       FROM anon;
