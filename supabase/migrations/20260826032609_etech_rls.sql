-- Generated from sql/supabase/04_rls.sql by sql/supabase/tools/build_migrations.py.
-- Edit the source file and rebuild; do not edit this copy.
--
-- The version number in the filename matches the row this migration has
-- in the remote project's history. Renaming it would make Supabase treat
-- it as a new migration and try to apply it again.
--
-- The outer BEGIN/COMMIT is stripped because `supabase db push` runs each
-- migration inside a transaction of its own.

-- ============================================================
-- Row Level Security — the replacement for ../02_users.sql
--
-- On MySQL the shop connected as etech_client and the admin panel as
-- etech_admin, and the database itself refused a price update or a
-- SELECT of cost_price on the client connection. That protection was
-- worth having and it should not be lost in the move.
--
-- Supabase has no equivalent of two application logins, because the
-- thing on the other end of the wire is different. Anything holding the
-- anon key — a browser, the Flutter app — reaches PostgREST directly,
-- and PostgREST decides what it may see by asking Row Level Security.
-- So the boundary moves from GRANT to per-table policy.
--
-- This file takes the strict reading: RLS on for every table, and no
-- policy granting anon or authenticated anything at all. The effect is
-- that the anon key can read nothing and write nothing, exactly as if
-- the tables were not there.
--
-- That is the correct setting for the app as it stands today, because
-- every read already goes through web/api/*.php, and PHP connects over
-- the Postgres connection string. That connection is the table owner,
-- and an owner is not subject to RLS — so the site keeps working while
-- the public API surface stays shut.
--
-- If the Flutter client is later pointed straight at Supabase instead
-- of at the PHP API, open up only what the shop front is allowed to
-- see: the block at the bottom of this file is that starting point,
-- and it is the same line etech_client was drawing.
--
--     psql "$SUPABASE_DB_URL" -f 04_rls.sql
-- ============================================================

ALTER TABLE brands               ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories           ENABLE ROW LEVEL SECURITY;
ALTER TABLE products             ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_attributes   ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers            ENABLE ROW LEVEL SECURITY;
ALTER TABLE admins               ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupons              ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders               ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items          ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE cart_items           ENABLE ROW LEVEL SECURITY;
ALTER TABLE wishlist_items       ENABLE ROW LEVEL SECURITY;
ALTER TABLE events               ENABLE ROW LEVEL SECURITY;
ALTER TABLE chatbot_logs         ENABLE ROW LEVEL SECURITY;
ALTER TABLE login_attempts       ENABLE ROW LEVEL SECURITY;

-- A view runs with the privileges of whoever defined it, which would
-- let the anon key read v_product_velocity and walk around the policies
-- above. security_invoker makes the view obey the caller's rights, so
-- the RLS on products and events applies through it too.
ALTER VIEW v_product_velocity SET (security_invoker = on);
ALTER VIEW v_monthly_sales    SET (security_invoker = on);

-- The two logins from the MySQL setup do not exist here and are not
-- recreated. What replaces them:
--
--   etech_client  ->  the anon key plus the policies below (none yet)
--   etech_admin   ->  the service_role key, or the direct connection
--                     string the PHP admin panel uses. Both bypass RLS.
--
-- Keep the service_role key out of the browser and out of the Flutter
-- bundle. It ignores every policy in this file.


-- ============================================================
-- Shop-front policies, for when the client talks to Supabase directly.
--
-- Uncomment as a set. They reproduce what etech_client was allowed:
-- read the catalogue, read live promotions, and nothing else. Note
-- what is still missing even then — cost_price is readable here,
-- because a Postgres policy filters rows, not columns. Hiding that
-- column needs either a view over the safe columns or a column-level
-- REVOKE, and the REVOKE is included below.
-- ============================================================

-- CREATE POLICY "catalogue is public" ON products
--   FOR SELECT TO anon, authenticated USING (is_active = 1);
--
-- CREATE POLICY "brands are public" ON brands
--   FOR SELECT TO anon, authenticated USING (true);
--
-- CREATE POLICY "categories are public" ON categories
--   FOR SELECT TO anon, authenticated USING (true);
--
-- CREATE POLICY "specs are public" ON product_attributes
--   FOR SELECT TO anon, authenticated USING (true);
--
-- CREATE POLICY "live promotions are public" ON coupons
--   FOR SELECT TO anon, authenticated USING (
--     is_active = 1
--     AND starts_at <= now()
--     AND (ends_at IS NULL OR ends_at > now())
--   );
--
-- -- What we pay for stock is not the shopper's business. This is the
-- -- column-level half of what etech_client's GRANT used to do.
-- REVOKE SELECT (cost_price) ON products FROM anon, authenticated;
