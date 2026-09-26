-- The owner asked for the three demo peripherals to be deleted outright
-- (they were hidden in retire_demo_gaming_gear). Cascades their 2 view
-- events on 402; zz_backup_order_items_20260910 keeps its 2 lines for
-- 404 as plain numbers (no foreign key).
delete from public.products where product_id in (401, 402, 404);
