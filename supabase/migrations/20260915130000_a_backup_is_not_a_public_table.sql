-- ============================================================
-- Three backup tables that anyone could read, and empty.
--
-- On 2026-09-10 the order tables were copied before a change, by hand in
-- the SQL editor:
--
--   zz_backup_orders_20260910                 37 rows
--   zz_backup_order_items_20260910            84 rows
--   zz_backup_order_status_history_20260910  137 rows
--
-- `CREATE TABLE ... AS SELECT` makes a table with row level security
-- switched off, and this project grants the PostgREST roles table
-- privileges across the public schema, so all three landed with RLS off,
-- no policies at all, and SELECT, INSERT, UPDATE, DELETE and TRUNCATE
-- held by `anon` as well as `authenticated`.
--
-- They are in the exposed schema. The publishable key that does this is
-- printed in web/js/config.js and shipped to every visitor, and the beta
-- is live with recruited testers on it. Anyone who opened the page could
-- have read every one of those orders -- names, addresses, what people
-- bought -- and could have emptied the tables on the way out.
--
-- They are not a redundant copy. The live tables hold 4 orders; these
-- hold 37, so 33 orders exist here and nowhere else. That is why this
-- migration locks them rather than dropping them, and why it is worth
-- deciding on purpose what happens to them next.
--
-- Nothing in the repository refers to them: no query, no migration, no
-- notebook. Locking them costs the application nothing.
--
-- This changes no structure -- no table is created, dropped or altered
-- in shape. It is the same GRANT/REVOKE-and-policy kind of change as
-- 20260905090000_protect_behaviour_capture.sql.
-- ============================================================

-- Both halves, because they fail differently and the belt is not the
-- braces. REVOKE takes the table out of PostgREST's reach: a request
-- from the anon or authenticated key gets permission denied and the row
-- count never enters into it. ENABLE ROW LEVEL SECURITY is what still
-- holds if some later migration grants the schema across in a sweep --
-- with no policy on the table, a role without BYPASSRLS matches no rows.
--
-- The owner and `service_role` bypass RLS, so the Dashboard SQL editor
-- reads these exactly as before. That is the intended way in now.

REVOKE ALL ON public.zz_backup_orders_20260910               FROM anon, authenticated;
REVOKE ALL ON public.zz_backup_order_items_20260910          FROM anon, authenticated;
REVOKE ALL ON public.zz_backup_order_status_history_20260910 FROM anon, authenticated;

ALTER TABLE public.zz_backup_orders_20260910               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.zz_backup_order_items_20260910          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.zz_backup_order_status_history_20260910 ENABLE ROW LEVEL SECURITY;

-- Deliberately no policies. A backup has no reader through the API.

COMMENT ON TABLE public.zz_backup_orders_20260910 IS
  'Hand-made copy of orders taken 2026-09-10. No API reader: RLS on, no '
  'policies, no grants to anon or authenticated. Holds 33 orders the live '
  'table no longer has, so do not drop it without deciding where those go.';

COMMENT ON TABLE public.zz_backup_order_items_20260910 IS
  'Hand-made copy of order_items taken 2026-09-10. No API reader: RLS on, '
  'no policies, no grants to anon or authenticated.';

COMMENT ON TABLE public.zz_backup_order_status_history_20260910 IS
  'Hand-made copy of order_status_history taken 2026-09-10. No API reader: '
  'RLS on, no policies, no grants to anon or authenticated.';
