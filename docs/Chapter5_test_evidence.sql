-- ============================================================
-- Chapter 5 proof pack: run each block on its own in the
-- Supabase Dashboard -> SQL Editor, then screenshot the result.
-- Every block that adds data ends in ROLLBACK, so nothing is kept.
-- Results recorded on 21 Oct 2026 are written under each block.
--
-- Code to screenshot for the "Screenshot of the code" column:
--   Picked for you (TC1-TC6):
--     supabase/migrations/20261001032630_picked_for_you.sql
--       recommend_products()  -- the scoring and the reason text
--       recommend_for_me()    -- signed-in check, limit kept 1..24, grants
--     web/js/home.js          -- sb.rpc("recommend_for_me", { p_limit: 8 })
--   TC6 fix:
--     supabase/migrations/20261021060000_recommender_skip_deleted_products.sql
--       the EXISTS line in signals
--   SQL injection (SQ1-SQ6):
--     web/js/checkout.js      -- sb.rpc("place_order", {...}) values sent as parameters
--     web/js/auth.js          -- sign-in through Supabase Auth
-- ============================================================


-- ------------------------------------------------------------
-- TC1  Signed-in customer with history gets 8 picks
-- Expected: 8 rows, picks follow the customer's own views.
-- 21 Oct: PASS. 5 Mouse ("Based on your Mouse views") + 2 Storage
--         + 1 CPU ("Shoppers who liked ... also chose this").
-- ------------------------------------------------------------
begin;
select set_config('request.jwt.claims',
  json_build_object('sub', (select auth_user_id from public.customers where customer_id = 44),
                    'role', 'authenticated')::text, true);
set local role authenticated;
create temp table tc1 as
  select r.product_id, p.name as product, c.name as category, round(r.score, 3) as score, r.reason
  from public.recommend_for_me(8) r
  join public.products p using (product_id)
  left join public.categories c on c.category_id = p.category_id;
select * from tc1;
rollback;


-- ------------------------------------------------------------
-- TC2  The picks change when the customer looks at monitors
-- Expected: monitors appear in the "after" list.
-- 21 Oct: PASS. Places 6-8 changed from Storage/CPU to 3 Monitors.
-- ------------------------------------------------------------
begin;
create temp table before_views as
  select row_number() over () as n, r.* from public.recommend_products(44, 8) r;
insert into public.events (customer_id, product_id, event_type, created_at, source)
  select 44, p.product_id, 'view', now(), 'web'
  from public.products p join public.categories c on c.category_id = p.category_id
  where c.name ilike 'monitor%' order by p.product_id limit 5;
insert into public.events (customer_id, product_id, event_type, created_at, source)
  select customer_id, product_id, event_type, now(), source
  from public.events where customer_id = 44 and created_at > now() - interval '1 minute';
create temp table after_views as
  select row_number() over () as n, r.* from public.recommend_products(44, 8) r;
select 'before' as test, b.n, c.name as category, b.reason
  from before_views b join public.products p using (product_id) join public.categories c on c.category_id = p.category_id
union all
select 'after', a.n, c.name, a.reason
  from after_views a join public.products p using (product_id) join public.categories c on c.category_id = p.category_id
order by 1 desc, 2;
rollback;


-- ------------------------------------------------------------
-- TC3  Invalid number of picks asked for
-- Expected: never fewer than 1 or more than 24; empty means 8.
-- 21 Oct: PASS. 0 -> 1, -5 -> 1, 1000 -> 24, NULL -> 8.
-- ------------------------------------------------------------
begin;
select set_config('request.jwt.claims',
  json_build_object('sub', (select auth_user_id from public.customers where customer_id = 44),
                    'role', 'authenticated')::text, true);
set local role authenticated;
create temp table tc3 as
            select 'p_limit = 0'    as input, (select count(*) from public.recommend_for_me(0))    as rows_returned
  union all select 'p_limit = -5',            (select count(*) from public.recommend_for_me(-5))
  union all select 'p_limit = 1000',          (select count(*) from public.recommend_for_me(1000))
  union all select 'p_limit = NULL',          (select count(*) from public.recommend_for_me(NULL));
select * from tc3;
rollback;


-- ------------------------------------------------------------
-- TC4a  Signed out (anon) asks for picks
-- Expected: refused.
-- 21 Oct: PASS. ERROR: permission denied for function recommend_for_me
-- ------------------------------------------------------------
begin;
set local role anon;
select * from public.recommend_for_me(8);
rollback;

-- ------------------------------------------------------------
-- TC4b  Signed-in customer asks for ANOTHER customer's picks
-- Expected: refused.
-- 21 Oct: PASS. ERROR: permission denied for function recommend_products
-- ------------------------------------------------------------
begin;
set local role authenticated;
select * from public.recommend_products(44, 8);
rollback;


-- ------------------------------------------------------------
-- TC5  New customers with no history (missing data)
-- Expected: still 8 picks, never an error.
-- 21 Oct: PASS. Gamer with no history (49): 4 GPU, 3 CPU, 1 Prebuilt
--         ("Picked for gamers"). No role, no history (46): 8 x
--         "Popular right now".
-- ------------------------------------------------------------
select 'gamer, no history' as customer, r.product_id, c.name as category, r.reason
  from public.recommend_products(49, 8) r join public.products p using (product_id) join public.categories c on c.category_id = p.category_id
union all
select 'no role, no history', r.product_id, c.name, r.reason
  from public.recommend_products(46, 8) r join public.products p using (product_id) join public.categories c on c.category_id = p.category_id
order by 1;


-- ------------------------------------------------------------
-- TC6  Every pick has a reason
-- Expected: null_reasons = 0.
-- 21 Oct, before the fix: FAIL. 3 of 128 picks had no reason.
--   Cause: 4 products in events_archive_20260916 had been deleted.
-- 21 Oct, fix tested in a rolled-back transaction: 0 of 128.
-- 21 Oct, retest after 20261021060000 went live: PASS. 0 of 128.
-- ------------------------------------------------------------
select count(*) filter (where r.reason is null) as null_reasons,
       count(*) as picks,
       count(distinct c.customer_id) as customers
from public.customers c
cross join lateral public.recommend_products(c.customer_id, 8) r;

-- The cause, for the write-up:
select count(distinct a.product_id) filter (where p.product_id is null) as deleted_products,
       count(*) filter (where p.product_id is null) as events_pointing_at_them
from public.events_archive_20260916 a
left join public.products p using (product_id);


-- ------------------------------------------------------------
-- SQ0  No database function builds SQL out of text
-- Expected: no rows (nothing uses EXECUTE or format()).
-- 21 Oct: PASS. 0 rows.
-- ------------------------------------------------------------
select p.proname
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and (p.prosrc ~* 'execute\s' or p.prosrc ~* 'format\(');


-- ============================================================
-- SQL injection tests done in the BROWSER (screenshot the page):
--
-- SQ1  Login page, email: ' OR '1'='1' --   password: ' OR '1'='1
--      21 Oct: PASS. "Invalid login credentials".
-- SQ2  Login page, email: any real-looking email
--      password: anything' OR 1=1 --
--      21 Oct: PASS. "Invalid login credentials".
-- SQ3  Open this in the browser address bar:
--      https://asawhkjvturznjitsqfk.supabase.co/rest/v1/products?name=eq.' OR 1=1 --
--      21 Oct: PASS. Cloudflare "Sorry, you have been blocked" page.
-- SQ4  Same, with:  ?name=eq.'; DROP TABLE products; --
--      21 Oct: PASS. Blocked by Cloudflare. Products still 546 rows after.
-- SQ5  UNION attack: ?select=product_id&name=eq.x' UNION SELECT email FROM customers --
--      21 Oct: PASS. [] (empty list, no emails returned).
-- SQ6  Reading customers without signing in:
--      /rest/v1/customers?select=email
--      21 Oct: PASS. "permission denied for table customers".
-- (SQ5 and SQ6 need the key: add &apikey=<publishable key from web/js/config.js>)
-- ============================================================
