-- ============================================================
-- Photos and official links for the headsets (category 43).
-- Found 2 Oct 2026, same rules as the keyboards: photo first, and a
-- link only to the maker's Malaysian page (or its only site).
--
-- 13 of 19 headsets get a photo; 10 of those also get a link.
--
--   * Razer: Asia-Pacific page (no Malaysian site). The Kraken V3 X
--     Pikachu Edition (4703) is gone from it: photo only.
--   * Logitech Malaysia doesn't list the G435 (4705) or H150 (4706):
--     retailer photos only.
--   * HyperX Cloud Stinger 2 Core (4711) is sold on HP Malaysia's store.
--   * Colour photos: ROG Pelta Black/White, H150 White/Blue (Logitech's
--     Cloud White / Sky Blue), H390 Black/Rose. Logitech calls the H390's
--     pink "Rose", so 4719's "Pink" is renamed (no basket or order used it).
--
-- Skipped (left for the user to confirm with the shop):
--   4709, 4710 Wesdar K-288H / K-285H -- no source found
--   4712 KT-Link Wired Headset -- no model number
--   4713 Fantech Go Vibe -- Fantech has two: WH05 and WH05A
--   4715 Fantech Flash HQ53 -- Fantech lists White and Pink only; shop says Black
--   4718 Fantech Valor MH86 -- Fantech lists only the newer Valor II MH89
-- ============================================================

UPDATE public.products p
SET image_path   = 'https://etech-fyp.vercel.app/images/products/' || p.product_id || '.webp',
    official_url = COALESCE(v.url, p.official_url)
FROM (VALUES
  (4701, 'https://rog.asus.com/my/headsets-audio/headsets/wireless-headsets/rog-pelta/'),
  (4702, 'https://www.razer.com/ap-en/gaming-headsets/razer-blackshark-v2-x'),
  (4703, NULL),
  (4704, 'https://www.logitech.com/en-my/shop/p/g522-lightspeed'),
  (4705, NULL),
  (4706, NULL),
  (4707, 'https://www.logitech.com/en-my/shop/p/h111-stereo-headset.981-000588'),
  (4708, 'https://www.logitech.com/en-my/shop/p/h151-stereo-headset.981-000587'),
  (4711, 'https://www.hp.com/my-en/shop/hyperx-cloud-stinger-2-core-gaming-headsets-683l9aa.html'),
  (4714, 'https://www.tecware.co/q3-headset'),
  (4716, 'https://fantechworld.com/products/carbon-7-1-hg30'),
  (4717, 'https://fantechworld.com/products/tone-ii-hq56'),
  (4719, 'https://www.logitech.com/en-my/shop/p/h390-usb-headset')
) AS v(id, url)
WHERE p.product_id = v.id;

UPDATE public.product_attributes SET attr_value = 'Rose'
WHERE product_id = 4719 AND attr_key = 'colourOption' AND attr_value = 'Pink';
UPDATE public.product_attributes SET attr_value = 'Black / Rose'
WHERE product_id = 4719 AND attr_key = 'colour' AND attr_value = 'Black / Pink';
