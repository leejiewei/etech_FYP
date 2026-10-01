-- Every product the shop sells on its own gets a counted stock of 10
-- (user, 1 Oct 2026). The reorder level is 5 everywhere, so 10 reads as
-- "in" -- the staff console's rule is qty <= reorder_level => low.
--
-- The eleven DIY prebuilt machines are left alone: their stock_status is
-- derived from their parts by products_stock_cascades_to_prebuilts, which
-- fires on the status changes below and recomputes them.
--
-- Before this, stock_qty was NULL on every row except 2001 (3), and the
-- statuses were: out = 206-242, 1221, 1530, 2130, 5001-5004, 5101-5104,
-- 5202, 5303; low = 2001, 5203; everything else in. To put that back:
--
--   update products set stock_qty = null, stock_status = 'in'
--    where product_id not in (select prebuilt_id from prebuilt_components);
--   update products set stock_qty = 3, stock_status = 'low' where product_id = 2001;
--   update products set stock_status = 'out'
--    where product_id between 206 and 242
--       or product_id in (1221, 1530, 2130, 5001, 5002, 5003, 5004,
--                         5101, 5102, 5103, 5104);
--   update products set stock_status = 'out' where product_id in (5202, 5303);
--   update products set stock_status = 'low' where product_id = 5203;

update products
   set stock_qty = 10,
       stock_status = 'in'
 where product_id not in (select prebuilt_id from prebuilt_components);
