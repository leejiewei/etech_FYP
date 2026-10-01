-- ============================================================
-- Maker's page and photo for the six Cliptec mice. Pages checked
-- 1 Oct 2026 on cliptec.com.
--
-- Choices:
--   * 4517 RZS880: Cliptec sells it as a 2.4GHz wireless mouse
--     (banner: "Office Gaming Mouse"); the shop's description says
--     Wired. Linked to the Grey variant; the description is not changed.
--   * 4518 RZS621 Black / Grey: Black page.
--   * 4530 RZS871 = "Xilent Tone" (page lists RZS871); Blue page.
--   * 4533 RZS866J J1 / J2 / J3: J1 page.
-- ============================================================

UPDATE public.products p
SET official_url = v.url,
    image_path   = 'https://etech-fyp.vercel.app/images/products/' || p.product_id || '.webp'
FROM (VALUES
  (4517, 'https://www.cliptec.com/product/cliptec-rzs880-2400dpi-24ghz-silent-wireless-mouse-speedmove-grey/2320'),
  (4518, 'https://www.cliptec.com/product/cliptec-rzs621-24ghz-3200dpi-office-gaming-rechargeable-silent-wireless-mouse-ion-move-black/2139'),
  (4530, 'https://www.cliptec.com/product/cliptec-1600dpi-24ghz-silent-wireless-mouse-xilent-tone-blue/1800'),
  (4531, 'https://www.cliptec.com/product/cliptec-rzs878-1600dpi-24ghz-silent-wireless-mouse-xilent-metal-pink/2241'),
  (4533, 'https://www.cliptec.com/product/cliptec-rzs866j-wireless-silent-mouse-xilent-j-j1/796'),
  (4534, 'https://www.cliptec.com/product/cliptec-rzs866g-24ghz-wireless-silent-mouse-xilent-graffiti-g1/1460')
) AS v(id, url)
WHERE p.product_id = v.id;
