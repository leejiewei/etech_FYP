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


-- ============================================================
-- Added 21 Oct 2026 (evening) for Chapter 5 sections 5.2.4-5.2.9.
-- Every block runs as test customer 44 (or staff admin 1) and ends
-- in ROLLBACK. Blocks that stop with an ERROR are meant to: the
-- error message IS the result to screenshot.
-- Products used: 4502 Logitech B175 (RM 38), 4501 Logitech B100
-- (RM 22), 4504 Fantech Venom II WGC2 (colours), 206 ASUS Vivobook
-- 15 (RM 2,899, a laptop), 3201 Hiksemi Wave 256GB SSD (RM 239),
-- 4531 Cliptec RZS878 (RM 25).
-- ============================================================


-- ------------------------------------------------------------
-- CART-01 + CART-02  Add an in-stock product, then add it again
-- 21 Oct: PASS. quantity 1, then 2 on the same line.
-- ------------------------------------------------------------
begin;
select set_config('request.jwt.claims', json_build_object('sub', (select auth_user_id from public.customers where customer_id = 44), 'role', 'authenticated')::text, true);
set local role authenticated;
delete from public.cart_items where customer_id = 44;
select public.cart_add(4502);
create temp table cart1 as select 'after 1st add' as step, product_id, quantity from public.cart_items where customer_id = 44;
select public.cart_add(4502);
insert into cart1 select 'after 2nd add', product_id, quantity from public.cart_items where customer_id = 44;
select * from cart1;
rollback;

-- CART-03  Out of stock. 21 Oct: PASS.
--   ERROR: Sorry, ASUS Vivobook 15 A1504 Core 5 120U 8GB (Silver) is out of stock.
begin;
update public.products set stock_status = 'out' where product_id = 206;
select set_config('request.jwt.claims', json_build_object('sub', (select auth_user_id from public.customers where customer_id = 44), 'role', 'authenticated')::text, true);
set local role authenticated;
select public.cart_add(206);
rollback;

-- CART-04  Product that does not exist. 21 Oct: PASS.
--   ERROR: That product does not exist.
begin;
select set_config('request.jwt.claims', json_build_object('sub', (select auth_user_id from public.customers where customer_id = 44), 'role', 'authenticated')::text, true);
set local role authenticated;
select public.cart_add(999999);
rollback;

-- CART-05  Colour not offered. 21 Oct: PASS.
--   ERROR: Fantech Venom II WGC2 does not come in Orange.
--   (Change 'Orange' to 'Beige' to show a real colour is accepted.)
begin;
select set_config('request.jwt.claims', json_build_object('sub', (select auth_user_id from public.customers where customer_id = 44), 'role', 'authenticated')::text, true);
set local role authenticated;
select public.cart_add(4504, 'Orange');
rollback;

-- CART-06  Signed out. 21 Oct: PASS.
--   ERROR: permission denied for function cart_add
begin;
set local role anon;
select public.cart_add(4502);
rollback;

-- WISH-01  Wishlist toggle. 21 Oct: PASS. {4502}, then 4502 gone.
begin;
select set_config('request.jwt.claims', json_build_object('sub', (select auth_user_id from public.customers where customer_id = 44), 'role', 'authenticated')::text, true);
set local role authenticated;
create temp table wish1 as select 'first press' as step, public.toggle_wishlist(4502)::text as wishlist_now;
insert into wish1 select 'second press', public.toggle_wishlist(4502)::text;
select * from wish1;
rollback;


-- ------------------------------------------------------------
-- ORD-01  Valid order, LAPTOP15 on a laptop. 21 Oct: PASS.
--   subtotal 2899.00, discount 434.85, total 2464.15, cart empty after.
-- ------------------------------------------------------------
begin;
select set_config('request.jwt.claims', json_build_object('sub', (select auth_user_id from public.customers where customer_id = 44), 'role', 'authenticated')::text, true);
set local role authenticated;
delete from public.cart_items where customer_id = 44;
select public.cart_add(206);
create temp table ord1 as select public.place_order('Test', '0123456789', null, 'LAPTOP15') as result;
select result, (select count(*) from public.cart_items where customer_id = 44) as cart_lines_after from ord1;
rollback;

-- ORD-02 .. ORD-06: run this block once per test, swapping the
-- place_order(...) line. Each one stops with its error.
--   ORD-02  place_order('', '0123456789')
--           -> Please fill in your name and phone number.
--   ORD-03  place_order('Test', '   ')
--           -> Please fill in your name and phone number.
--   ORD-04  place_order('Test', '0123456789', null, null, 'BANK_TRANSFER', 'DELIVERY')
--           -> Please give us an address to deliver to.
--   ORD-05  place_order('Test', '0123456789', null, null, 'CASH')
--           -> Please choose how you are paying.
--   ORD-06  (delete the cart_add line first) place_order('Test', '0123456789')
--           -> Your cart is empty.
begin;
select set_config('request.jwt.claims', json_build_object('sub', (select auth_user_id from public.customers where customer_id = 44), 'role', 'authenticated')::text, true);
set local role authenticated;
delete from public.cart_items where customer_id = 44;
select public.cart_add(4502);
select public.place_order('', '0123456789');
rollback;

-- ORD-07  Unknown coupon. 21 Oct: PASS. discount 0.00, coupon null.
-- ORD-08  Coupon outside its category.
--   21 Oct BEFORE the fix: FAIL. 2 x RM 38 mice + LAPTOP15 -> discount 11.40.
--   Fix: 20261021140417_coupon_only_its_category.sql (applied 21 Oct).
--   21 Oct RETEST: PASS.
--     mouse only + LAPTOP15     -> discount 0.00, coupon null
--     laptop + LAPTOP15         -> discount 434.85
--     SSD + PARTS10             -> discount 23.90 (Storage is under Components)
--     laptop + mouse + LAPTOP15 -> discount 434.85 (laptop only; was 438.15)
--     mouse + FREE100           -> discount 0.00 (ORD-07)
begin;
select set_config('request.jwt.claims', json_build_object('sub', (select auth_user_id from public.customers where customer_id = 44), 'role', 'authenticated')::text, true);
set local role authenticated;
create temp table ord8 (test text, result jsonb);
delete from public.cart_items where customer_id = 44;
select public.cart_add(4501);
insert into ord8 select 'mouse only + LAPTOP15', public.place_order('Test', '0123456789', null, 'LAPTOP15');
select public.cart_add(206);
insert into ord8 select 'laptop + LAPTOP15', public.place_order('Test', '0123456789', null, 'LAPTOP15');
select public.cart_add(3201);
insert into ord8 select 'SSD + PARTS10', public.place_order('Test', '0123456789', null, 'PARTS10');
select public.cart_add(206);
select public.cart_add(4501);
insert into ord8 select 'laptop + mouse + LAPTOP15', public.place_order('Test', '0123456789', null, 'LAPTOP15');
select public.cart_add(4501);
insert into ord8 select 'mouse + FREE100', public.place_order('Test', '0123456789', null, 'FREE100');
select test, result->>'subtotal' as subtotal, result->>'discount' as discount,
       result->>'total' as total, result->>'coupon' as coupon from ord8;
rollback;


-- ------------------------------------------------------------
-- MSG-01..04  Weekly recommendation message, run as the scheduler
-- (no signed-in user). 21 Oct: PASS.
--   MSG-01 1 sent: "Logitech B100 is RM 22.00. Based on your Mouse views."
--   MSG-02 0 sent (cooldown)  MSG-03 0 sent (customer 46, nothing known)
--   MSG-04 every customer: no message with an empty body
-- Nothing reaches a phone: the push request is rolled back too.
-- ------------------------------------------------------------
begin;
create temp table msg (test text, sent int, latest text);
insert into msg select 'MSG-01 customer 44, cooldown 0', public.send_recommendation_alerts(44, 0),
  (select title || ' / ' || body from public.notifications where customer_id = 44 and kind = 'recommendation' order by notification_id desc limit 1);
insert into msg select 'MSG-02 again, cooldown 7', public.send_recommendation_alerts(44, 7), null;
insert into msg select 'MSG-03 customer 46', public.send_recommendation_alerts(46, 0), null;
insert into msg select 'MSG-04 everyone', public.send_recommendation_alerts(null, 7),
  'empty bodies: ' || (select count(*) from public.notifications where kind = 'recommendation' and created_at > now() - interval '1 minute' and coalesce(body, '') = '');
select * from msg;
rollback;


-- ------------------------------------------------------------
-- DEAL-01 + STF-01  Staff start a deal; staff mark order 1 Ready.
-- 21 Oct: PASS. 1 customer told about Cliptec RZS878 (RM 25 -> 23);
--   order 1 Ready with "Your order is on its way".
-- ------------------------------------------------------------
begin;
select set_config('request.jwt.claims', json_build_object('sub', (select auth_user_id from public.admins where admin_id = 1), 'role', 'authenticated')::text, true);
set local role authenticated;
create temp table stf (test text, result text);
insert into stf select 'DEAL-01 customers told', public.admin_create_deal(4531, 23, now(), now() + interval '7 days')::text;
select public.admin_set_order_status(1, 'Ready');
reset role;
insert into stf select 'DEAL-01 message', (select title || ' / ' || body from public.notifications where kind = 'deal_started' and product_id = 4531 order by notification_id desc limit 1);
insert into stf select 'STF-01 order 1 status', (select status::text from public.orders where order_id = 1);
insert into stf select 'STF-01 message', (select title || ' / ' || body from public.notifications where order_id = 1 and kind = 'order_ready' order by notification_id desc limit 1);
select * from stf;
rollback;

-- STF-02..07: one per run, as staff (STF-07 as customer 44). Each errors.
--   STF-02 admin_set_order_status(999999, 'Ready') -> That order no longer exists.
--   STF-03 admin_set_order_status(1, 'Flying')     -> invalid input value for enum order_status
--   STF-04 admin_create_deal(206, 3200, now(), now() + interval '7 days')
--                                                  -> A deal price has to be below the shelf price.
--   STF-05 admin_create_deal(206, 2500, now() + interval '7 days', now())
--                                                  -> A deal has to end after it starts.
--   STF-06 admin_create_deal(999999, 10, now(), now() + interval '1 day')
--                                                  -> That product no longer exists.
--   STF-07 (customer 44) admin_set_order_status(1, 'Ready') and send_recommendation_alerts(44)
--                                                  -> Staff access only.
begin;
select set_config('request.jwt.claims', json_build_object('sub', (select auth_user_id from public.admins where admin_id = 1), 'role', 'authenticated')::text, true);
set local role authenticated;
select public.admin_set_order_status(999999, 'Ready');
rollback;


-- ------------------------------------------------------------
-- SQ7  Staff search filter injection (run in a terminal, not here).
-- 21 Oct: PASS. Raw text -> all 546 products; cleaned the way
-- web/staff-console/js/products.js:71 does it -> 0 products.
-- ------------------------------------------------------------
