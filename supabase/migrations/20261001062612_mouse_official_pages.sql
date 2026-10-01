-- ============================================================
-- Maker's page for 29 of the 40 mice (4501-4540); 28 also get a
-- photo. Pages checked 30 Sep 2026.
--
-- Link only, no photo:
--   * 4526 Rapoo M10 Plus: rapoo-eu.com only has a desk scene and an
--     underside shot, no clean product photo.
-- Left out on purpose (user, 30 Sep: deploy these now, leave the rest):
--   * 4501 B100, 4502 B175: Logitech no longer has a page for either.
--   * 4528 Rapoo MT760 Mini: rapoo.com only lists the MT760 Infinity.
--   * 4516 UGREEN "Ergonomic Wireless Mouse": fits both M511 and M371.
--   * 4538 Logitech G502: HERO or X, the name doesn't say.
--   * 4517, 4518, 4530, 4531, 4533, 4534 Cliptec: not checked yet.
--
-- Choices:
--   * Multi-colour products use the first listed colour that has a photo
--     (4504 Beige, 4505 Red, 4523 Pink, 4524 Black).
--   * 4506 "Crypto II Wireless" 600mAh = WG7V2 (the WG7V2RD is 300mAh).
--   * 4505 Kanata S Wireless = WG9S; 4523 Kanata S Wired = VX9S.
--   * 4514 M331: Logitech's M331 page uses the M330 photos (same body).
--   * 4535 G102: Logitech's G102 page uses the G203 photos (same mouse).
-- ============================================================

UPDATE public.products p
SET official_url = v.url,
    image_path   = CASE WHEN v.photo
                        THEN 'https://etech-fyp.vercel.app/images/products/' || p.product_id || '.webp'
                        ELSE p.image_path END
FROM (VALUES
  (4503, true,  'https://www.logitech.com/en-my/shop/p/m171-wireless-mouse.910-006870'),
  (4504, true,  'https://fantechworld.com/products/venom-ii-wgc2'),
  (4505, true,  'https://fantechworld.com/products/kanata-s-wireless'),
  (4506, true,  'https://fantechworld.com/products/crypto-ii-wireless-wg7v2'),
  (4507, true,  'https://www.razer.com/gaming-mice/razer-deathadder-v2-x-hyperspeed'),
  (4508, true,  'https://www.razer.com/gaming-mice/razer-basilisk-v3'),
  (4509, true,  'https://www.razer.com/gaming-mice/razer-basilisk-v3-x-hyperspeed'),
  (4510, true,  'https://www.razer.com/gaming-mice/razer-cobra'),
  (4511, true,  'https://www.razer.com/gaming-mice/razer-deathadder-v3-hyperspeed'),
  (4512, true,  'https://rog.asus.com/mice-mouse-pads/mice/ergonomic-right-handed/rog-keris-ii-origin-kjp/'),
  (4513, true,  'https://www.logitech.com/en-my/shop/p/m187-mini-wireless-mouse.910-005372'),
  (4514, true,  'https://www.logitech.com/en-my/shop/p/m331-silent-plus-mouse.910-004914'),
  (4515, true,  'https://www.logitech.com/en-my/shop/p/m240-silent-bluetooth-mouse.910-007123'),
  (4519, true,  'https://rog.asus.com/mice-mouse-pads/mice/ergonomic-right-handed/rog-keris-model/'),
  (4520, true,  'https://www.asus.com/accessories/mice-and-mouse-pads/tuf-gaming/asus-tuf-gaming-m3-gen-ii/'),
  (4521, true,  'https://rog.asus.com/mice-mouse-pads/mice/wireless/rog-strix-impact-iii-wireless/'),
  (4522, true,  'https://rog.asus.com/mice-mouse-pads/mice/ergonomic-right-handed/rog-keris-wireless-aimpoint-model/'),
  (4523, true,  'https://fantechworld.com/products/kanata-s-vx9s'),
  (4524, true,  'https://fantechworld.com/products/phantom-ii-vx6'),
  (4525, true,  'https://www.rapoo.com/en/product/N100C'),
  (4526, false, 'https://www.rapoo-eu.com/product/m10-plus/'),
  (4527, true,  'https://www.rapoo.com/en/product/EV250'),
  (4529, true,  'https://www.razer.com/gaming-mice/kuromi-razer-deathadder-essential-and-goliathus-mouse-mat-bundle'),
  (4532, true,  'https://salpido.com/products/sal-btm100'),
  (4535, true,  'https://www.logitech.com/en-my/shop/p/g102-lightsync-rgb-gaming-mouse.910-005802'),
  (4536, true,  'https://www.logitech.com/en-my/shop/p/g304-lightspeed-wireless-gaming-mouse.910-005284'),
  (4537, true,  'https://www.logitech.com/en-my/shop/p/g309-lightspeed-gaming-mouse'),
  (4539, true,  'https://tecware.co/ex1'),
  (4540, true,  'https://www.msi.com/Gaming-Gear/VERSA-WIRELESS-FRIEREN-EDITION')
) AS v(id, photo, url)
WHERE p.product_id = v.id;
