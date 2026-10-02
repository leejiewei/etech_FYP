-- ============================================================
-- Photos and official links for microphones (category 45) and
-- speakers (category 46). Found 2 Oct 2026, same rules as the headsets:
-- photo first, and a link only to the maker's Malaysian page (or its
-- only site).
--
-- 24 of 26 get a photo; 20 of those also get a link.
--
--   * Salpido (salpido.com) and Vinnfier (vinnfier.com) are Malaysian
--     makers; Logitech and Creative have Malaysian pages; Razer has no
--     Malaysian site, so the Asia-Pacific page is used.
--   * 4805 Imperion PG310: Imperion's own site is dead; photo from Salpido,
--     which sells Imperion, so no link (as with the Salpido-sold boards).
--   * Photo only, the maker no longer lists them:
--     4803 Razer Seiren Mini Quartz, 4862 Leviathan V2 Pikachu (Razer's
--     Leviathan V2 X Pokemon edition), 4858 Fantech GS205.
--   * 4801/4802 Leviosa Air: the USB-C receiver version is pictured.
--   * 4870 "Salpido G6" is the G6 CORE, Salpido's only G6.
--   * 4854: Salpido calls the colour "Beige", so "Beach" is renamed.
--
-- Skipped (left for the user to confirm with the shop):
--   4853 Vinnfier Tango Neo 1 -- Vinnfier lists Neo 2/5/6/16/17/19/20, no Neo 1
--   4857 Wesdar K-968S -- no source found
-- ============================================================

UPDATE public.products p
SET image_path   = 'https://etech-fyp.vercel.app/images/products/' || p.product_id || '.webp',
    official_url = COALESCE(v.url, p.official_url)
FROM (VALUES
  (4801, 'https://fantechworld.com/products/leviosa-air'),
  (4802, 'https://fantechworld.com/products/leviosa-air'),
  (4803, NULL),
  (4804, 'https://www.razer.com/ap-en/streaming-microphones/razer-seiren-v3-mini'),
  (4805, NULL),
  (4806, 'https://www.cliptec.com/product/cliptec-rgb-usb-condenser-microphone-with-popping-filter-and-anti-shock-tripod-black/1632'),
  (4851, 'https://salpido.com/products/macchi-300'),
  (4852, 'https://www.vinnfier.com/products/vinnfier-vf-studio-3-20w-usb-powered-2-0-rgb-pc-audio-bluetooth-speaker-aux-usb-play-music-colorful-rgb-lighting'),
  (4854, 'https://salpido.com/products/party-waves-407'),
  (4855, 'https://salpido.com/products/party-waves-226'),
  (4856, 'https://salpido.com/products/party-waves-150'),
  (4858, NULL),
  (4859, 'https://my.creative.com/p/speakers/sound-blaster-gs3'),
  (4860, 'https://fantechworld.com/products/groove-bar-bs163'),
  (4861, 'https://fantechworld.com/products/groove-bar-pro-bs151'),
  (4862, NULL),
  (4863, 'https://salpido.com/products/party-waves-306'),
  (4864, 'https://salpido.com/products/caproni-107'),
  (4865, 'https://my.creative.com/p/speakers/creative-pebble-plus'),
  (4866, 'https://www.logitech.com/en-my/shop/p/z313-speaker-system-subwoofer.980-000413'),
  (4867, 'https://www.logitech.com/en-my/shop/p/z407-bluetooth-computer-speakers.980-001351'),
  (4868, 'https://www.logitech.com/en-my/shop/p/z625-gaming-speakers.980-001297'),
  (4869, 'https://www.logitech.com/en-my/shop/p/g560-rgb-gaming-speakers.980-001304'),
  (4870, 'https://salpido.com/products/g6-core')
) AS v(id, url)
WHERE p.product_id = v.id;

UPDATE public.product_attributes SET attr_value = 'Beige'
WHERE product_id = 4854 AND attr_key = 'colour' AND attr_value = 'Beach';
