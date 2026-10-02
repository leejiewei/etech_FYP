-- ============================================================
-- Photos and official links for the case fans (category 25).
-- Found 2 Oct 2026: all 18 get a photo, 13 get a link.
--
--   * Slev (6): slev.my pages and photos. Vortex Forward/Reverse share
--     one photo per colour; Spectra S Reverse uses Slev's rear shot.
--   * Cooler Master: MF120 Lite on coolermaster.com/en-my. SickleFlow
--     120 ARGB White and both MF120 Halo 3in1 packs are dead pages on
--     every CM site, so photo only (Jayacom MY, JIB TH, MD Computers IN;
--     Jayacom watermark painted out).
--   * ASUS Prime MR120 (2): not on ASUS Malaysia, so photo only.
--   * Makers with no Malaysian site link to their own site, as the
--     coolers did: Thermalright, Jonsbo, Tecware, be quiet!, HYTE.
--     Lumi Link photo from Jayacom; Silent Wings 4 from dateks.lv (be
--     quiet!'s own render is on black).
--   * 4216 HYTE THICC FP12: HYTE sells it only in Black/White; the
--     shop lists Black. Photo is the 3-pack with the NP50 portal.
-- ============================================================

UPDATE products SET image_path = 'https://etech-fyp.vercel.app/images/products/' || product_id || '.webp'
WHERE product_id BETWEEN 4201 AND 4218;

UPDATE products p SET official_url = v.url
FROM (VALUES
  (4201, 'https://slev.my/products/fans/slevflow-asq-vortex-pwm-argb-120mm-fan/'),
  (4202, 'https://slev.my/products/fans/slevflow-asq-vortex-pwm-argb-120mm-fan/'),
  (4203, 'https://slev.my/products/fans/slevflow-asq-vortex-pwm-argb-120mm-fan/'),
  (4204, 'https://slev.my/products/fans/slevflow-asq-vortex-pwm-argb-120mm-fan/'),
  (4205, 'https://slev.my/products/fans/slevflow-asq-spectra-s-pwm-argb-120mm-fan/'),
  (4206, 'https://slev.my/products/fans/slevflow-asq-spectra-s-pwm-argb-120mm-fan/'),
  (4207, 'https://www.thermalright.com/product/tl-c14c/'),
  (4208, 'https://www.coolermaster.com/en-my/products/mf120-lite.html'),
  (4209, 'https://www.jonsbo.com/en/products/ZA-120BBR.html'),
  (4213, 'https://www.tecware.co/lumi-link'),
  (4214, 'https://www.bequiet.com/en/casefans/3700'),
  (4215, 'https://www.jonsbo.com/en/products/ZA-360BBR.html'),
  (4216, 'https://hyte.com/store/thicc-fp12')
) AS v(id, url)
WHERE p.product_id = v.id;
