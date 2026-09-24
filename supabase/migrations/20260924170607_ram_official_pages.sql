-- ============================================================
-- The maker's own page for every memory kit.
--
-- Same idea as 20260924102646_official_product_pages.sql, which did the
-- processors and graphics cards: the shop card and the product screen
-- show "Full specs" and open the page this points at.
--
-- Every link was opened and its title checked against the product on
-- 25 Sep 2026. Where a maker publishes one page per series (Kingston,
-- G.Skill, Patriot, Klevv, ADATA, Hiksemi, Apacer, Addlink) the link is
-- the series page. Where it only publishes one page per exact kit
-- (Corsair, TeamGroup, Crucial) the link is the kit that matches the
-- capacity, speed and colour in the product name; the shop's names do
-- not give the CAS latency, so these pick the common CL for that speed.
--
-- Two judgement calls, both written down so they can be undone:
--   3002 "Essencore Value RAM" -> KLEVV standard DDR5 U-DIMM. KLEVV is
--        Essencore's own brand and this is its value DDR5 line.
--   3031 "Kingston Value RAM 8GB DDR3-1600 Green" -> part KVR16N11/8,
--        the standard 8GB green ValueRAM stick at that speed.
-- ============================================================

UPDATE public.products p
SET official_url = v.url
FROM (VALUES
  -- Kingston
  (3001, 'https://www.kingston.com/en/memory/gaming/kingston-fury-beast-ddr5-memory'),
  (3004, 'https://www.kingston.com/en/memory/gaming/kingston-fury-beast-ddr5-memory'),
  (3022, 'https://www.kingston.com/en/memory/gaming/kingston-fury-beast-ddr4-rgb-memory'),
  (3024, 'https://www.kingston.com/en/memory/gaming/kingston-fury-beast-ddr4-memory'),
  (3029, 'https://www.kingston.com/en/memory/gaming/kingston-fury-beast-ddr4-memory'),
  (3031, 'https://www.kingston.com/en/memory/search?partid=KVR16N11%2F8'),
  (3104, 'https://www.kingston.com/en/memory/gaming/kingston-fury-impact-ddr4-memory'),
  (3106, 'https://www.kingston.com/en/memory/gaming/kingston-fury-impact-ddr4-memory'),
  (3111, 'https://www.kingston.com/en/memory/gaming/kingston-fury-impact-ddr5-memory'),
  -- Corsair
  (3008, 'https://www.corsair.com/us/en/p/memory/cmk32gx5m2b6000c30/vengeance-32gb-2x16gb-ddr5-dram-6000mt-s-c30-memory-kit-black-cmk32gx5m2b6000c30'),
  (3009, 'https://www.corsair.com/us/en/p/memory/cmh32gx5m2d6000c36/vengeance-rgb-32gb-2x16gb-ddr5-dram-6000mhz-c36-memory-kit-black-cmh32gx5m2d6000c36'),
  (3010, 'https://www.corsair.com/us/en/p/memory/cmh32gx5m2b5600c36/vengeance-rgb-32gb-2x16gb-ddr5-dram-5600mhz-c36-memory-kit-black-cmh32gx5m2b5600c36'),
  (3015, 'https://www.corsair.com/us/en/p/memory/cmp64gx5m2b6400c32/dominator-titanium-rgb-64gb-2x32gb-ddr5-dram-6400mts-cl32-memory-kit-black-cmp64gx5m2b6400c32'),
  (3107, 'https://www.corsair.com/us/en/p/memory/cmsx16gx5m1a4800c40/vengeance-ddr5-sodimm-16gb-1x16gb-ddr5-4800-pc5-38400-c40-1-1v-cmsx16gx5m1a4800c40'),
  (3108, 'https://www.corsair.com/us/en/p/memory/cmsx16gx5m1a5600c48/vengeance-ddr5-sodimm-16gb-1x16gb-ddr5-5600mts-cl48-cmsx16gx5m1a5600c48'),
  (3109, 'https://www.corsair.com/us/en/p/memory/cmsx32gx5m1a4800c40/vengeance-ddr5-sodimm-32gb-1x32gb-ddr5-4800-pc5-38400-c40-1-1v-cmsx32gx5m1a4800c40'),
  (3110, 'https://www.corsair.com/us/en/p/memory/cmsx32gx5m1a5600c48/vengeance-ddr5-sodimm-32gb-1x32gb-ddr5-5600mts-cl48-cmsx32gx5m1a5600c48'),
  -- G.Skill
  (3013, 'https://www.gskill.com/products/1/165/371/Trident-Z5-DDR5-Intel-XMP'),
  (3014, 'https://www.gskill.com/product/165/374/1688607694/F5-6000J3040G32GX2-TZ5RW'),
  (3021, 'https://www.gskill.com/products/1/165/185/Aegis-DDR4'),
  (3023, 'https://www.gskill.com/products/1/165/326/Trident-Z-Neo-For-AMD'),
  (3028, 'https://www.gskill.com/products/1/165/326/Trident-Z-Neo-For-AMD'),
  (3025, 'https://www.gskill.com/products/1/165/166/Trident-Z-RGB'),
  -- TeamGroup / T-Force
  (3006, 'https://www.teamgroupinc.com/en/product-detail/memory/T-FORCE/delta-rgb-ddr5-black/delta-rgb-ddr5-black-FF3D516G6000HC38A01/'),
  (3007, 'https://www.teamgroupinc.com/en/product-detail/memory/T-FORCE/delta-rgb-ddr5-black/delta-rgb-ddr5-black-FF3D532G6000HC38ADC01/'),
  (3011, 'https://www.teamgroupinc.com/en/product-detail/memory/T-FORCE/delta-rgb-ddr5-white/delta-rgb-ddr5-white-FF4D532G6000HC38ADC01/'),
  (3016, 'https://www.teamgroupinc.com/en/product-detail/memory/T-FORCE/vulcan-z-ddr4-gray/vulcan-z-ddr4-gray-TLZGD48G3200HC16C01/'),
  (3020, 'https://www.teamgroupinc.com/en/product-detail/memory/T-FORCE/xtreem-argb-ddr4-white/xtreem-argb-ddr4-white-TF13D416G3200HC16CDC01/'),
  (3026, 'https://www.teamgroupinc.com/en/product-detail/memory/T-FORCE/xtreem-argb-ddr4-white/xtreem-argb-ddr4-white-TF13D432G3200HC16CDC01/'),
  (3101, 'https://www.teamgroupinc.com/en/product-detail/memory/TEAMGROUP/elite-so-dimm-ddr3/elite-so-dimm-ddr3-TED3L4G1600C11-S01/'),
  (3102, 'https://www.teamgroupinc.com/en/product-detail/memory/TEAMGROUP/elite-so-dimm-ddr3/elite-so-dimm-ddr3-TED3L8G1600C11-S01/'),
  -- Patriot
  (3005, 'https://www.patriotmemory.com/products/viper-venom-ddr5-performance-ram'),
  (3019, 'https://www.patriotmemory.com/products/signature-line-ddr4'),
  -- Crucial
  (3027, 'https://www.crucial.com/memory/ddr4/cp2k16g4dfra32a'),
  -- KLEVV / Essencore
  (3002, 'https://www.klevv.com/ken/products_details/memory/D5_UDIMM'),
  (3012, 'https://www.klevv.com/ken/products_details/memory/Klevv_CrasVRGB'),
  -- ADATA
  (3003, 'https://www.adata.com/en/consumer/category/computer-memory/dram-module-ddr5-5600-u-dimm/'),
  -- Hiksemi
  (3017, 'https://www.hiksemitech.com/en/hiksemi/all-products/memory/memory-udimm/hs-udimm-u1.html'),
  (3018, 'https://www.hiksemitech.com/en/hiksemi/all-products/memory/memory-udimm/hs-udimm-u1.html'),
  -- Apacer
  (3030, 'https://www.apacer.com/en/product/personal-product/detail/personal_dram/ddr3_desktop_memory_module'),
  -- Addlink (AddGame)
  (3103, 'https://www.addlink.com.tw/ddr4-spidern4'),
  (3105, 'https://www.addlink.com.tw/ddr4-spidern4')
) AS v(id, url)
WHERE p.product_id = v.id;
