-- ============================================================
-- 4517 Cliptec RZS880 is wireless (user confirmed 1 Oct 2026; it was
-- entered as Wired by mistake). Cliptec's page confirms 2.4GHz with a
-- USB receiver but does not state the battery, so the battery line is
-- removed rather than guessed.
-- ============================================================

UPDATE public.products SET description = 'Mouse. Grey. Connection: 2.4G USB Dongle.' WHERE product_id = 4517;
UPDATE public.product_attributes SET attr_value = '2.4G USB Dongle' WHERE product_id = 4517 AND attr_key = 'connection';
DELETE FROM public.product_attributes WHERE product_id = 4517 AND attr_key = 'battery';
