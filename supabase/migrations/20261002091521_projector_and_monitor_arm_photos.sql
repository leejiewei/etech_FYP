-- ============================================================
-- Photos for the projector group (14 Projector, 15 Accessory,
-- 16 Screen) and monitor arms (9). Found 2 Oct 2026: 6 of 8 get a
-- photo, 1 gets a link.
--
--   * 1305 Epson EB-E24: photo + epson.com.my page.
--   * 1301 Yaber Mini L1 / 1304 L2 Plus: yaber.com no longer lists
--     either and Yaber has no Malaysian site, so photo only (from
--     altitude.ph, Yaber's Philippine dealer).
--   * 1303 Meki screen: photo from Allit Hypermarket; Meki has no site.
--   * 1401 MachDesk MD34-A01B: photo from Sun Cycle (MY distributor).
--   * 1403 Loctek D5F2: photo from Gadget Zone MY; Loctek's English
--     site has no D5F2 page.
--   * Skipped: 1302 Yaber Mini L1 stand (no photo of the stand alone),
--     1402 Loctek VNDLB503D (every photo found is the single arm).
-- ============================================================

UPDATE products SET image_path = 'https://etech-fyp.vercel.app/images/products/' || product_id || '.webp'
WHERE product_id IN (1301, 1303, 1304, 1305, 1401, 1403);

UPDATE products SET official_url = 'https://www.epson.com.my/Projectors/Corporate-and-Education/EB-E24-XGA-3LCD-Projector/p/V11HB51052'
WHERE product_id = 1305;
