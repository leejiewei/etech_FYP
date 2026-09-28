-- ============================================================
-- Photo and maker's page for all 11 PSUs (3301-3311).
-- Every page was opened on 28 Sep 2026 and its title checked
-- (Cooler Master and MSI only render in a real browser).
--
-- Notes:
--   * 3302/3304 (non-modular) share Cooler Master's non-modular series
--     page; 3303 (fully modular) is the MWE Gold 750 V3 ATX 3.1.
--   * 3305/3306 are the Prime Gold (AP-750G / AP-850G), not the
--     Black Editions.
--   * 3308: MSI makes no "MAG A1250GS". The shop confirmed it is the
--     MPG A1250GS PCIE5 II, so the name is corrected here.
--   * 3309: the shop confirmed the ROG Thor 1200W is the Platinum III.
--   * 3301 Slev (Slevnergy) is a Malaysian brand; slev.my is the maker.
-- ============================================================

UPDATE public.products p
SET official_url = v.url,
    image_path   = 'https://etech-fyp.vercel.app/images/products/' || p.product_id || '.webp'
FROM (VALUES
  (3301, 'https://slev.my/products/powersupplyunits/quantum600/'),
  (3302, 'https://www.coolermaster.com/en-global/products/mwe-gold-v3-atx-3-1-non-modular-series.html'),
  (3303, 'https://www.coolermaster.com/en-global/products/mwe-gold-750-v3-atx-3-1.html'),
  (3304, 'https://www.coolermaster.com/en-global/products/mwe-gold-v3-atx-3-1-non-modular-series.html'),
  (3305, 'https://www.asus.com/motherboards-components/power-supply-units/prime/ap-750g/'),
  (3306, 'https://www.asus.com/motherboards-components/power-supply-units/prime/ap-850g/'),
  (3307, 'https://www.asus.com/motherboards-components/power-supply-units/tuf-gaming/tuf-gaming-1000g/'),
  (3308, 'https://www.msi.com/Power-Supply/MPG-A1250GS-PCIE5-II'),
  (3309, 'https://rog.asus.com/power-supply-units/rog-thor/rog-thor-1200p3-gaming/'),
  (3310, 'https://rog.asus.com/power-supply-units/rog-thor/rog-thor-1000p2-eva-gaming-model/'),
  (3311, 'https://www.corsair.com/us/en/p/psu/cp-9020261-na/hx1500i-fully-modular-ultra-low-noise-platinum-atx-power-supply-cp-9020261-na')
) AS v(id, url)
WHERE p.product_id = v.id;

UPDATE public.products
SET name = 'MSI MPG A1250GS PCIE5 II Fully modular'
WHERE product_id = 3308;
