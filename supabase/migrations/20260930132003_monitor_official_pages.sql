-- ============================================================
-- Maker's page and photo for all 21 monitors (1201-1221).
-- Pages checked 30 Sep 2026.
--
-- Choices:
--   * 1202 "VY249 120Hz Black" = VY249HGR (the only black 120Hz VY249;
--     HF is 100Hz, HGE/HG2 are 144Hz, HGR-W is white).
--   * 1203 "MP251 120Hz Black" = PRO MP251 E2 (speakers; MP251L E2 has none).
--   * 1204 "MP251 144Hz White" = PRO MP251W E14A.
--   * 1206/1207 "MP273 144Hz" = PRO MP273 E14A / MP273W E14A (speakers;
--     MP273L E14 has none).
--   * 1210 Nitro ED270R 180Hz = ED270R S3; 1212 = MAG 274QF X24.
--   * 1211 "XV270YM3" = Nitro XV270 M3 and 1220 "MAG 279QPW" = MAG 272QPW
--     QD-OLED X28: neither name exists; user said 30 Sep to link them to
--     those models but keep the owner's names.
--   * Acer's XV270 M3 page uses the XV0-family photo, so 1211 does too.
--   * Acer, Lenovo Legion and HP have no Malaysian page for these models
--     (or it redirects), so their CA/IL/US/IE pages are used.
-- ============================================================

UPDATE public.products p
SET official_url = v.url,
    image_path   = 'https://etech-fyp.vercel.app/images/products/' || p.product_id || '.webp'
FROM (VALUES
  (1201, 'https://www.lenovo.com/my/en/p/accessories-and-software/monitors/home/68c2kac1my'),
  (1202, 'https://www.asus.com/displays-desktops/monitors/eye-care/vy249hgr/'),
  (1203, 'https://www.msi.com/Business-Productivity-Monitor/PRO-MP251-E2'),
  (1204, 'https://www.msi.com/Business-Productivity-Monitor/PRO-MP251W-E14A'),
  (1205, 'https://www.lenovo.com/us/en/p/accessories-and-software/monitors/gaming/68c4gac4us'),
  (1206, 'https://www.msi.com/Business-Productivity-Monitor/PRO-MP273-E14A'),
  (1207, 'https://www.msi.com/Business-Productivity-Monitor/PRO-MP273W-E14A'),
  (1208, 'https://www.asus.com/displays-desktops/monitors/zenscreen/asus-zenscreen-mb169ck/'),
  (1209, 'https://www.asus.com/displays-desktops/monitors/tuf-gaming/tuf-gaming-vg279qm5a/'),
  (1210, 'https://www.acer.com/il-en/monitors/gaming/nitro-ed0/pdp/UM.HE0EE.305'),
  (1211, 'https://www.acer.com/ca-en/monitors/gaming/nitro-xv0/pdp/UM.HX0AA.302'),
  (1212, 'https://www.msi.com/Monitor/MAG-274QF-X24'),
  (1213, 'https://www.hp.com/ie-en/products/monitors/product-details/product-specifications/2102046956'),
  (1214, 'https://www.msi.com/Monitor/MAG-32C6X'),
  (1215, 'https://rog.asus.com/monitors/27-to-31-5-inches/rog-strix-xg309cm-model/'),
  (1216, 'https://www.msi.com/Business-Productivity-Monitor/Modern-MD342CQP'),
  (1217, 'https://www.msi.com/Monitor/G321Q'),
  (1218, 'https://rog.asus.com/monitors/27-to-31-5-inches/rog-strix-xg27acs-w/'),
  (1219, 'https://www.asus.com/displays-desktops/monitors/proart/proart-display-pa279crv/'),
  (1220, 'https://www.msi.com/Monitor/MAG-272QPW-QD-OLED-X28'),
  (1221, 'https://www.msi.com/Business-Productivity-Monitor/PRO-MP225V')
) AS v(id, url)
WHERE p.product_id = v.id;
