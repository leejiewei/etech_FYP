-- ============================================================
-- Photos and official links for the keyboards (category 40).
-- Found 2 Oct 2026. Same rules as the mice: the photo matters more
-- than the link, and a link must be the maker's Malaysian page
-- (or the maker's only site when it has no Malaysian one).
--
-- 34 of 44 keyboards get a photo; 25 of those also get a link.
--
--   * Razer has no Malaysian site, so its Asia-Pacific pages
--     (razer.com/ap-en, which serves Malaysia) are used. The Kuromi
--     Ornata V3 TKL (4407) and the "Pikachu TKL" (4414, Razer's
--     Pokemon BlackWidow V3 Tenkeyless, Green switch) are not on
--     ap-en any more: photo only.
--   * Logitech Malaysia no longer lists the G512 Carbon (4404), MK120
--     (4427) or MK240 Nano (4438): photo only, from a retailer.
--   * Cooler Master Malaysia has pulled the SK622 (4403) and CK530 V2
--     (4405): photo only, from retailers.
--   * Fantech P51 (4420) is not on fantechworld.com: photo only, cut
--     from a Malaysian retailer's (Jayacom) three-colour shot.
--   * UGREEN KU005 (4432): no UGREEN page; retailer photo only.
--   * Fantech, Tecware, Cliptec, darkFlash, Darmoshark and MSI have no
--     Malaysian site; their only site is linked (as for the mice).
--   * Pebble 2 Combo (4433): Logitech's Malaysian page shows the Tonal
--     Blue; the white is Logitech's Tonal White.
--
-- Colour photos (web/images/products/<id>-<colour>.webp) for the 10
-- keyboards with real colour options. Fantech calls the GoPop's second
-- colour "Beige", so 4431's "Beach" is renamed to match (no basket or
-- order used it).
--
-- Skipped (left for the user to confirm with the shop):
--   4406 HP "Mechanical Gaming Keyboard" -- matches no HP model
--   4409, 4421, 4422 AULA S100 / S100 Pro / S2022 Pro -- no clean source
--   4411, 4412 Cliptec RGK850 / RGK851 -- not on cliptec.com
--   4418 Wesdar MK4 Cerberus, 4436 Kingses KTL-KB33 -- no source
--   4430 MOFii Sweet DM -- Pink/Purple/Green set not found
--   4444 Darmoshark TOP98 "Purple Gradient" -- Darmoshark sells it in
--        black or white only
-- ============================================================

UPDATE public.products p
SET image_path   = 'https://etech-fyp.vercel.app/images/products/' || p.product_id || '.webp',
    official_url = COALESCE(v.url, p.official_url)
FROM (VALUES
  (4401, 'https://rog.asus.com/my/keyboards/keyboards/compact/rog-strix-scope-ii-96-wireless/'),
  (4402, 'https://rog.asus.com/my/keyboards/keyboards/aura-rgb/rog-strix-scope-ii-x/'),
  (4403, NULL),
  (4404, NULL),
  (4405, NULL),
  (4407, NULL),
  (4408, 'https://www.razer.com/ap-en/gaming-keyboards/razer-blackwidow-v3-tenkeyless'),
  (4410, 'https://www.razer.com/ap-en/gaming-keyboards/razer-blackwidow-v4-x'),
  (4413, 'https://www.tecware.co/spectre-75-96'),
  (4414, NULL),
  (4415, 'https://www.msi.com/Gaming-Gear/FORGE-TKL-WIRELESS-FRIEREN-EDITION'),
  (4416, 'https://www.logitech.com/en-my/shop/p/g512-x-98-gaming-keyboard.920-014010'),
  (4417, 'https://www.tecware.co/spectre-75-96'),
  (4419, 'https://fantechworld.com/products/maxpower-ii-mk894'),
  (4420, NULL),
  (4423, 'https://www.cliptec.com/product/cliptec-78keys-usb-mechanical-illumination-backlit-gaming-keyboard-with-knob-attack78-blue/2722'),
  (4424, 'https://fantechworld.com/products/go-mochi101-wk899'),
  (4425, 'https://www.cliptec.com/product/cliptec-rzk251-usb-1-standard-keyboard-primo-black/1478'),
  (4426, 'https://www.logitech.com/en-my/shop/p/k120-usb-standard-computer.920-002582'),
  (4427, NULL),
  (4428, 'https://www.logitech.com/en-my/shop/p/mk270r-wireless-keyboard-mouse.920-006314'),
  (4429, 'https://www.logitech.com/en-my/shop/p/mk345-keyboard-mouse-wireless.920-006491'),
  (4431, 'https://fantechworld.com/products/go-pop-wk895'),
  (4432, NULL),
  (4433, 'https://www.logitech.com/en-my/shop/p/pebble-2-keyboard-mouse-combo.920-012191'),
  (4434, 'https://www.asus.com/my/accessories/keyboards/asus-keyboard/asus-marshmallow-keyboard-kw100/'),
  (4435, 'https://www.logitech.com/en-my/shop/p/k400-plus-touchpad-keyboard.920-007165'),
  (4437, 'https://www.cliptec.com/product/cliptec-rzk530-dual-mode-rechargeable-wireless-multimedia-silent-keyboard-dualconn-grey/2262'),
  (4438, NULL),
  (4439, 'https://www.tecware.co/spectre-75-96'),
  (4440, 'https://www.tecware.co/spectre-75-96'),
  (4441, 'https://www.tecware.co/phantom-s'),
  (4442, 'https://www.darkflash.com/product/gd87'),
  (4443, 'https://darmoshark.com/products/darmoshark-top75-trio-mode-mechanical-keyboard')
) AS v(id, url)
WHERE p.product_id = v.id;

-- GoPop: use Fantech's colour name.
UPDATE public.product_attributes
SET attr_value = 'Beige'
WHERE product_id = 4431 AND attr_key = 'colourOption' AND attr_value = 'Beach';

UPDATE public.product_attributes
SET attr_value = 'Grey / Beige'
WHERE product_id = 4431 AND attr_key = 'colour' AND attr_value = 'Grey / Beach';
