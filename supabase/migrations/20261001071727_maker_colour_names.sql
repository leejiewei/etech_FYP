-- ============================================================
-- Use the maker's colour names (user, 1 Oct 2026: "follow what the
-- website colour"): Rapoo MT760 Mini "White" is Rapoo's Gray, and
-- Cliptec RZS871 "Pink" is Cliptec's Rose Gold. The colour photos were
-- renamed to match (4528-gray.webp, 4530-rose-gold.webp). Any cart
-- already holding the old name is moved over too.
-- ============================================================

UPDATE public.product_attributes SET attr_value = 'Gray' WHERE product_id = 4528 AND attr_key = 'colourOption' AND attr_value = 'White';
UPDATE public.product_attributes SET attr_value = 'Black / Gray' WHERE product_id = 4528 AND attr_key = 'colour';
UPDATE public.products SET description = replace(description, 'Black / White', 'Black / Gray') WHERE product_id = 4528;
UPDATE public.cart_items SET colour = 'Gray' WHERE product_id = 4528 AND colour = 'White';

UPDATE public.product_attributes SET attr_value = 'Rose Gold' WHERE product_id = 4530 AND attr_key = 'colourOption' AND attr_value = 'Pink';
UPDATE public.product_attributes SET attr_value = 'Blue / Purple / Rose Gold' WHERE product_id = 4530 AND attr_key = 'colour';
UPDATE public.products SET description = replace(description, 'Blue / Purple / Pink', 'Blue / Purple / Rose Gold') WHERE product_id = 4530;
UPDATE public.cart_items SET colour = 'Rose Gold' WHERE product_id = 4530 AND colour = 'Pink';
