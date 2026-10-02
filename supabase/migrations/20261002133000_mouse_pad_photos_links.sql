-- ============================================================
-- Photos and official links for Mouse Pads (category 42). Found 2 Oct
-- 2026: 9 of 21 get a photo, 8 get a link.
--
-- User rule (2 Oct): only pads with a clear model AND an official
-- maker page. Skipped:
--   * 4601 Handboss Microsoft, 4605 Tecgear Dual Deskmat,
--     4620/4621 Probex: no maker page.
--   * 4606 "ROG Mouse Pad", 4608 "Cooler Master Hard Surface",
--     4609 "MSI Mouse Pad": no model named.
--   * 4614 Darmoshark PAD-3 (darmoshark site down), 4615 Fantech Eid,
--     4616/4617 Fantech MP905-KN/KU (look like Kujira Nami/Umi, but
--     fantechworld.com lists neither): no official page.
--   * 4619 Corsair MM400: discontinued, gone from corsair.com.
--
-- Links:
--   * 4602 MSI Malaysia. 4607 ROG Malaysia. 4611 Logitech MY
--     (956-000034 = Blue Grey). 4618 Cooler Master MY.
--   * Razer has no Malaysian site, so razer.com/ap-en SKU pages:
--     0200 Medium, 0300 Large, 0400 XXL, 0500 3XL (read from the
--     size picker on each page).
--   * 4604 TUF P1 Miku: only on ASUS Global (asus.com/my returns a
--     generic TUF page), so photo only.
-- Photos: Razer sizes from JIB (Razer's own shots are all dark scenes);
-- the rest from the makers.
-- ============================================================

UPDATE products SET image_path = 'https://etech-fyp.vercel.app/images/products/' || product_id || '.webp'
WHERE product_id IN (4602, 4603, 4604, 4607, 4610, 4611, 4612, 4613, 4618);

UPDATE products SET official_url = v.url
FROM (VALUES
  (4602, 'https://my.msi.com/Gaming-Gear/AGILITY-GD20-FRIEREN-EDITION'),
  (4603, 'https://www.razer.com/ap-en/gaming-mouse-mats/razer-gigantus-v2/RZ02-03330200-R3M1'),
  (4612, 'https://www.razer.com/ap-en/gaming-mouse-mats/razer-gigantus-v2/RZ02-03330300-R3M1'),
  (4613, 'https://www.razer.com/ap-en/gaming-mouse-mats/razer-gigantus-v2/RZ02-03330400-R3M1'),
  (4610, 'https://www.razer.com/ap-en/gaming-mouse-mats/razer-gigantus-v2/RZ02-03330500-R3M1'),
  (4607, 'https://rog.asus.com/my/mice-mouse-pads/mouse-pads/rog-strix-edge-model/'),
  (4611, 'https://www.logitech.com/en-my/shop/p/mouse-pad-studio-series.956-000034'),
  (4618, 'https://www.coolermaster.com/en-my/products/mp511-30th-anniversary-edition.html')
) AS v(id, url)
WHERE products.product_id = v.id;

-- Logitech calls this colour "Blue Grey".
UPDATE products SET description = 'Mouse pad. Size: 230 x 200 x 2 mm. Blue Grey.'
WHERE product_id = 4611;
