-- ============================================================
-- Photos and official links for Cable Kits (27), Power Adapters (28),
-- ARGB Lighting (29) and Mounting (30). Found 2 Oct 2026: 12 of 21
-- get a photo and a link.
--
-- User rule (2 Oct): only parts with a clear model AND an official
-- page. Skipped:
--   * 4304 Slev "Black / Grey": Slev sells Grey Black Stripe, Black
--     Grey Red and Titanium Grey; can't tell which.
--   * 4305 Thermaltake TtMod "Multicolour Pack": TtMod comes in single
--     colourways (Red/Black, Orange/Black, Green/Black, Blue/Black).
--   * 4306/4307 Generic 90-degree adapters: no maker.
--   * 4308 Cooler Master 12VHPWR 90-degree: Type 1 and Type 2 exist
--     (for different PSU series); not on CM Malaysia.
--   * 4310 Tecware "Orbis" LED strip: no such product found.
--   * 4313 CM MasterFan ARGB + PWM Hub: page dead on every CM locale.
--   * 4317 HYTE LN70: Black and White exist; name has no colour.
--   * 4318 Slev Light Board "V2 Kit": Slev lists only one light board.
--
-- Links: Slev and Cooler Master are Malaysian pages. Corsair,
-- Deepcool, darkFlash, ID-Cooling, Thermalright and NZXT have no
-- Malaysian site, so their global page (as for coolers and fans).
-- 4320: Thermalright also sells "Black V2"; the shop name has no V2.
-- 4309: Corsair's CP-8920284 page is now titled 12V-2x6 (same cable).
-- Photos: the three Slev cable sets only exist as dark scene shots, so
-- they are full photos, not cut-outs.
-- ============================================================

UPDATE products SET image_path = 'https://etech-fyp.vercel.app/images/products/' || product_id || '.webp'
WHERE product_id IN (4301, 4302, 4303, 4309, 4311, 4312, 4314, 4315, 4316, 4319, 4320, 4321);

UPDATE products SET official_url = v.url
FROM (VALUES
  (4301, 'https://slev.my/products/extensioncables/slevlink-slev-30-premium-pre-braided-cable-orange-white/'),
  (4302, 'https://slev.my/products/extensioncables/slevlink-slev-30-premium-pre-braided-cable-black-red/'),
  (4303, 'https://slev.my/products/extensioncables/slevlink-slev-30-premium-pre-braided-cable-black-white/'),
  (4309, 'https://www.corsair.com/ww/en/p/pc-components-accessories/cp-8920284/600w-pcie-5-0-12vhpwr-type-4-psu-power-cable-cp-8920284'),
  (4311, 'https://slev.my/10-port-pwm-argb-hub/'),
  (4312, 'https://www.coolermaster.com/en-my/products/mini-addressable-rgb-led-controller.html'),
  (4314, 'https://deepcool.com/products/Accessories/graphiccardaccessories/2021/14100.shtml'),
  (4315, 'https://slev.my/products/extensioncables/slevlink-slev-30-argb-flexible-light-board/'),
  (4316, 'https://www.darkflash.com/product/dl280'),
  (4319, 'https://www.idcooling.com/product/detail?id=407&name=ABF-1700'),
  (4320, 'https://www.thermalright.com/product/am5-secure-frame-black/'),
  (4321, 'https://nzxt.com/products/internal-usb-hub-gen-3')
) AS v(id, url)
WHERE products.product_id = v.id;
