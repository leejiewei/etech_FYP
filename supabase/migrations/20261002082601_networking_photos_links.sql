-- ============================================================
-- Photos and official links for networking (categories 31 Router,
-- 32 Mesh WiFi, 33 Cellular Router). Found 2 Oct 2026: all 13 get a
-- photo and a Malaysian maker link.
--
--   * ASUS (6): asus.com/my pages; 2400px renders from the odinapi
--     listing (ProductLevel1Code=networking-iot-servers,
--     ProductLevel2Code=wifi-routers, WebsiteCode=global; =my is empty).
--   * TP-Link (7): tp-link.com/my pages; 1000px gallery shots, mirror
--     reflection under the black routers cut off. Deco X10 2-pack and
--     3-pack use TP-Link's own 2- and 3-unit renders.
-- ============================================================

UPDATE products p SET
  image_path   = 'https://etech-fyp.vercel.app/images/products/' || v.id || '.webp',
  official_url = v.url
FROM (VALUES
  (4101, 'https://www.tp-link.com/my/home-networking/wifi-router/archer-ax12/'),
  (4102, 'https://www.asus.com/my/networking-iot-servers/wifi-routers/asus-wifi-routers/rt-ax53u/'),
  (4103, 'https://www.asus.com/my/networking-iot-servers/wifi-routers/asus-wifi-routers/rt-ax1800hp/'),
  (4104, 'https://www.tp-link.com/my/home-networking/wifi-router/archer-ax53/'),
  (4105, 'https://www.asus.com/my/networking-iot-servers/wifi-7/all-series/rt-be58u/'),
  (4106, 'https://www.asus.com/my/networking-iot-servers/wifi-routers/asus-gaming-routers/tuf-gaming-be3600/'),
  (4107, 'https://www.tp-link.com/my/home-networking/wifi-router/archer-be400/'),
  (4108, 'https://www.asus.com/my/networking-iot-servers/wifi-routers/asus-wifi-routers/rt-be82u/'),
  (4109, 'https://www.asus.com/my/networking-iot-servers/wifi-7/all-series/asus-rt-be92u/'),
  (4110, 'https://www.tp-link.com/my/home-networking/deco/deco-x10/'),
  (4111, 'https://www.tp-link.com/my/home-networking/deco/deco-x10/'),
  (4112, 'https://www.tp-link.com/my/home-networking/5g-4g-router/tl-mr101/'),
  (4113, 'https://www.tp-link.com/my/home-networking/5g-4g-router/archer-nx205/')
) AS v(id, url)
WHERE p.product_id = v.id;
