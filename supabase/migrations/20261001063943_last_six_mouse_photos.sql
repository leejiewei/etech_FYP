-- ============================================================
-- Photos for the last six mice, so all 40 (4501-4540) now have one.
-- Found 1 Oct 2026. The user said the photo matters more than the
-- link, so a mouse with no maker page gets the photo alone.
--
--   * 4501 B100, 4502 B175: Logitech no longer has a page for either;
--     photos from retailer listings (B175 is the grey-sided body).
--   * 4516 UGREEN "Ergonomic Wireless Mouse": taken as the M511. Both
--     the M511 and the M371 take 2 x AAA, but the M511 is the one sold
--     as "Ergonomic Wireless Mouse" (the M371 is "Multi-Mode Vertical")
--     and the shop lists no Bluetooth. No UGREEN page found.
--   * 4526 Rapoo M10 Plus: rapoo-eu.com's M10 front shot (same body);
--     its link was already set.
--   * 4528 MT760 Mini: Rapoo's own store lists Standard and Mini on one
--     page with one photo per colour; Black used.
--   * 4538 G502: the HERO, because the shop sells it wired at RM189
--     (the G502 X costs far more).
-- ============================================================

UPDATE public.products p
SET image_path   = 'https://etech-fyp.vercel.app/images/products/' || p.product_id || '.webp',
    official_url = COALESCE(v.url, p.official_url)
FROM (VALUES
  (4501, NULL),
  (4502, NULL),
  (4516, NULL),
  (4526, NULL),
  (4528, 'https://shop.rapoo.com/products/rapoo-mt760-multi-device-wireless-mouse'),
  (4538, 'https://www.logitech.com/en-my/shop/p/g502-hero-gaming-mouse.910-005472')
) AS v(id, url)
WHERE p.product_id = v.id;
