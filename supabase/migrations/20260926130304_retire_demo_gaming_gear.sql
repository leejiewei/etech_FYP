-- The three demo peripherals are not on the shop's 26 Sep inventory record.
-- Hidden, not deleted: zz_backup_order_items_20260910 still holds 2 order lines
-- for 404, and 402 has shopper view events that a delete would cascade away.
update public.products set is_active = 0 where product_id in (401, 402, 404);
