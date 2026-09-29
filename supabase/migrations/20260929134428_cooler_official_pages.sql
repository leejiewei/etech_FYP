-- ============================================================
-- Photo and maker's page for 21 of the 23 CPU coolers (4001-4023).
-- Every page was opened on 29 Sep 2026 and its title checked.
--
-- Left out on purpose:
--   * 4014 CPE R120 (Intel stock cooler): no maker page.
--   * 4023 Deepcool AK400 Digital Pro (White): Deepcool only lists the
--     AK400 Digital Pro in black, so the colour can't be matched.
--
-- Notes:
--   * 4001 is the plain FX360 (the shop lists no ARGB), not FX360 ARGB.
--   * 4013 is the original SL240 White: its 78 CFM / 2.68 mmH2O fans
--     match the shop's specs; the SL240 V2 is 79.7 CFM / 3.65 mmH2O.
--   * 4017 Thermalright splits the Refined SE ARGB White into one page
--     per socket kit; the LGA1700/1851 page is used.
--   * 4022 is the AG620 Digital BK (no ARGB), matching the shop's name.
--   * 4015 Pccooler's new site has dropped the EX400 page; the maker's
--     archived page on old.pccooler.com is the only one left.
--   * ID-Cooling and Deepcool photos came on flat black/white; the
--     background was made transparent.
-- ============================================================

UPDATE public.products p
SET official_url = v.url,
    image_path   = 'https://etech-fyp.vercel.app/images/products/' || p.product_id || '.webp'
FROM (VALUES
  (4001, 'https://www.idcooling.com/product/detail?id=434'),
  (4002, 'https://www.asus.com/motherboards-components/cooling/prime/prime-lc-360-argb/'),
  (4003, 'https://www.asus.com/motherboards-components/cooling/prime/prime-lc-360-argb-white-edition/'),
  (4004, 'https://www.idcooling.com/product/detail?id=566'),
  (4005, 'https://www.idcooling.com/product/detail?id=569'),
  (4006, 'https://www.asus.com/motherboards-components/cooling/tuf-gaming/tuf-gaming-lc-iii-360-argb-lcd/'),
  (4007, 'https://rog.asus.com/cooling/cpu-liquid-coolers/rog-ryuo/rog-ryuo-iv-slc-360-argb/'),
  (4008, 'https://rog.asus.com/cooling/cpu-liquid-coolers/rog-ryuo/rog-ryuo-iv-slc-360-argb-white-edition/'),
  (4009, 'https://www.idcooling.com/product/detail?id=570'),
  (4010, 'https://www.idcooling.com/product/detail?id=571'),
  (4011, 'https://www.idcooling.com/product/detail?id=453'),
  (4012, 'https://www.idcooling.com/product/detail?id=454'),
  (4013, 'https://www.idcooling.com/product/detail?id=403'),
  (4015, 'https://old.pccooler.com/Products/product_1/id/185'),
  (4016, 'https://www.idcooling.com/product/detail?id=322'),
  (4017, 'https://www.thermalright.com/product/assassin-x-120-refined-se-argb-white-lga17001851/'),
  (4018, 'https://www.deepcool.com/products/Cooling/cpuaircoolers/AK400-DIGITAL-SE-CPU-Cooler-With-A-Status-Display/2025/21645.shtml'),
  (4019, 'https://www.thermalright.com/product/assassin-x-120-r-digital-argb-white/'),
  (4020, 'https://www.idcooling.com/product/detail?id=525'),
  (4021, 'https://www.idcooling.com/product/detail?id=545'),
  (4022, 'https://www.deepcool.com/products/Cooling/cpuaircoolers/AG620-DIGITAL-BK-Temperature-Display-Cooler-1851-1700-AM5/2023/17664.shtml')
) AS v(id, url)
WHERE p.product_id = v.id;
