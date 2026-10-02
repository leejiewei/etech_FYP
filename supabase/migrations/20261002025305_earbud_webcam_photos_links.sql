-- ============================================================
-- Photos and official links for earbuds (category 44) and webcams
-- (category 47). Found 2 Oct 2026, same rules as before: photo first,
-- and a link only to the maker's Malaysian page (or its only site).
--
-- 10 of 11 get a photo; 7 of those also get a link.
--
--   * Jabra left the consumer market; its Asia-Pacific support page is the
--     only page left for the Elite 4. Jabra calls the black one "Dark Grey",
--     so 4753's colour is renamed.
--   * Rapoo has no Malaysian site; rapoo.com/en is its only one.
--   * Photo only:
--     4754 HyperX Cirro Buds Pro Blue -- not on HP Malaysia (photo from HP Indonesia)
--     4756 UGREEN EP105 -- no UGREEN Malaysia page (photo from mlink.com.my,
--          which doesn't name the model; it matches a retailer's EP105
--          photo, EAN 6941876237548; logo removed)
--     4902 Logitech C615 -- Logitech Malaysia no longer lists it
--
-- Skipped (left for the user to confirm with the shop):
--   4758 Monster N-Tube 60 -- no such model found (Monster's N-Tune is headphones)
-- ============================================================

UPDATE public.products p
SET image_path   = 'https://etech-fyp.vercel.app/images/products/' || p.product_id || '.webp',
    official_url = COALESCE(v.url, p.official_url)
FROM (VALUES
  (4751, 'https://rog.asus.com/my/headsets-audio/earbuds/rog-cetra-true-wireless-model/'),
  (4752, 'https://my.creative.com/p/headphones-headsets/creative-zen-air-pro'),
  (4753, 'https://www.jabra.com/en-apac/supportpages/jabra-elite-4'),
  (4754, NULL),
  (4755, 'https://www.hp.com/my-en/shop/hyperx-cloud-earbuds-ii-red-705l8aa.html'),
  (4756, NULL),
  (4757, 'https://salpido.com/products/ep15'),
  (4901, 'https://www.logitech.com/en-my/shop/p/c270-hd-webcam.960-000627'),
  (4902, NULL),
  (4903, 'https://www.rapoo.com/en/product/C500AF')
) AS v(id, url)
WHERE p.product_id = v.id;

UPDATE public.product_attributes SET attr_value = 'Dark Grey'
WHERE product_id = 4753 AND attr_key = 'colour' AND attr_value = 'Black';
