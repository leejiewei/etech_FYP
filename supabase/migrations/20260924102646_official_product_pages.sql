-- ============================================================
-- A link to the maker's own page for a product.
--
-- The shop lists a handful of specs per part; the maker's page lists all
-- of them. Customers asked to be able to check the full sheet, so a
-- product can now carry the URL of its official page, and the product
-- screen shows it under the price.
--
-- Filled in for the processors and graphics cards, every link opened and
-- checked against the product name on 24 Sep 2026. Three old cards have
-- none: ASUS no longer has a page for the GT 730 SL or GT 1030 SL, and
-- "GTX 1650 OC" is several ASUS models with no way to tell which one
-- the shop stocks. Left NULL, the link simply does not appear.
--
-- Only https links are allowed, because the value ends up in an href.
-- ============================================================

ALTER TABLE public.products
  ADD COLUMN official_url VARCHAR(500) NULL
    CONSTRAINT products_official_url_https CHECK (official_url ~ '^https://');

-- The products table is readable column by column (see
-- 20260827114650_client_privileges.sql), so a new column is hidden until
-- it is granted.
GRANT SELECT (official_url) ON public.products TO anon, authenticated;

UPDATE public.products p
SET official_url = v.url
FROM (VALUES
  -- AMD
  (2001, 'https://www.amd.com/en/products/processors/desktops/ryzen/7000-series/amd-ryzen-5-7500f.html'),
  (2002, 'https://www.amd.com/en/products/processors/desktops/ryzen/7000-series/amd-ryzen-5-7600x.html'),
  (2003, 'https://www.amd.com/en/products/processors/desktops/ryzen/7000-series/amd-ryzen-5-7500x3d.html'),
  (2004, 'https://www.amd.com/en/products/processors/desktops/ryzen/9000-series/amd-ryzen-5-9600x.html'),
  (2005, 'https://www.amd.com/en/products/processors/desktops/ryzen/7000-series/amd-ryzen-7-7800x3d.html'),
  (2006, 'https://www.amd.com/en/products/processors/desktops/ryzen/9000-series/amd-ryzen-7-9700x.html'),
  (2007, 'https://www.amd.com/en/products/processors/desktops/ryzen/9000-series/amd-ryzen-9-9900x.html'),
  (2008, 'https://www.amd.com/en/products/processors/desktops/ryzen/9000-series/amd-ryzen-7-9800x3d.html'),
  (2009, 'https://www.amd.com/en/products/processors/desktops/ryzen/9000-series/amd-ryzen-9-9950x3d.html'),
  (2010, 'https://www.amd.com/en/support/downloads/drivers.html/processors/ryzen/ryzen-3000-series/amd-ryzen-3-3200g.html'),
  (2011, 'https://www.amd.com/en/support/downloads/drivers.html/processors/ryzen/ryzen-5000-series/amd-ryzen-5-5500.html'),
  (2012, 'https://www.amd.com/en/support/downloads/drivers.html/processors/ryzen/ryzen-3000-series/amd-ryzen-5-3400g.html'),
  (2013, 'https://www.amd.com/en/support/downloads/drivers.html/processors/ryzen/ryzen-5000-series/amd-ryzen-5-5600.html'),
  (2014, 'https://www.amd.com/en/support/downloads/drivers.html/processors/ryzen/ryzen-5000-series/amd-ryzen-5-5600gt.html'),
  (2015, 'https://www.amd.com/en/support/downloads/drivers.html/processors/ryzen/ryzen-5000-series/amd-ryzen-7-5700x.html'),
  (2016, 'https://www.amd.com/en/products/processors/desktops/ryzen/5000-series/amd-ryzen-7-5800x3d.html'),
  -- Intel
  (2017, 'https://www.intel.com/content/www/us/en/products/sku/241070/intel-core-ultra-5-processor-225-20m-cache-up-to-4-90-ghz/specifications.html'),
  (2018, 'https://www.intel.com/content/www/us/en/products/sku/241066/intel-core-ultra-5-processor-245kf-24m-cache-up-to-5-20-ghz/specifications.html'),
  (2019, 'https://www.intel.com/content/www/us/en/products/sku/241063/intel-core-ultra-7-processor-265k-30m-cache-up-to-5-50-ghz/specifications.html'),
  (2020, 'https://www.intel.com/content/www/us/en/products/sku/245692/intel-core-ultra-7-processor-270k-plus-36m-cache-up-to-5-50-ghz/specifications.html'),
  (2021, 'https://www.intel.com/content/www/us/en/products/sku/241060/intel-core-ultra-9-processor-285k-36m-cache-up-to-5-70-ghz/specifications.html'),
  (2022, 'https://www.intel.com/content/www/us/en/products/sku/236777/intel-core-i5-processor-14400f-20m-cache-up-to-4-70-ghz/specifications.html'),
  (2023, 'https://www.intel.com/content/www/us/en/products/sku/236788/intel-core-i5-processor-14400-20m-cache-up-to-4-70-ghz/specifications.html'),
  (2024, 'https://www.intel.com/content/www/us/en/products/sku/236799/intel-core-i5-processor-14600k-24m-cache-up-to-5-30-ghz/specifications.html'),
  (2025, 'https://www.intel.com/content/www/us/en/products/sku/134591/intel-core-i712700-processor-25m-cache-up-to-4-90-ghz/specifications.html'),
  (2026, 'https://www.intel.com/content/www/us/en/products/sku/236854/intel-core-i7-processor-14700f-33m-cache-up-to-5-40-ghz/specifications.html'),
  (2027, 'https://www.intel.com/content/www/us/en/products/sku/236781/intel-core-i7-processor-14700-33m-cache-up-to-5-40-ghz/specifications.html'),
  (2028, 'https://www.intel.com/content/www/us/en/products/sku/236773/intel-core-i9-processor-14900k-36m-cache-up-to-6-00-ghz/specifications.html'),
  -- Graphics cards
  (2201, 'https://www.msi.com/Graphics-Card/GeForce-RTX-5050-8G-SHADOW-2X-OC'),
  (2202, 'https://www.asus.com/motherboards-components/graphics-cards/dual/dual-rtx5050-o8g/'),
  (2203, 'https://www.msi.com/Graphics-Card/GeForce-RTX-5060-8G-SHADOW-2X-OC'),
  (2204, 'https://www.asus.com/motherboards-components/graphics-cards/dual/dual-rtx5060-o8g/'),
  (2205, 'https://www.msi.com/Graphics-Card/GeForce-RTX-5060-8G-VENTUS-2X-OC-WHITE'),
  (2206, 'https://www.asus.com/motherboards-components/graphics-cards/tuf-gaming/tuf-rtx5060-o8g-gaming/'),
  (2207, 'https://www.asus.com/motherboards-components/graphics-cards/dual/dual-rtx5060ti-o16g/'),
  (2208, 'https://www.msi.com/Graphics-Card/GeForce-RTX-5060-Ti-16G-VANGUARD-SOC'),
  (2209, 'https://www.asus.com/motherboards-components/graphics-cards/prime/prime-rtx5060ti-o16g/'),
  (2210, 'https://www.asus.com/motherboards-components/graphics-cards/dual/dual-rtx5060ti-o16g-white/'),
  (2211, 'https://www.zotac.com/us/product/graphics_card/zotac-gaming-geforce-rtx-5070-amp-white-edition'),
  (2212, 'https://www.asus.com/motherboards-components/graphics-cards/prime/prime-rtx5070-o12g/'),
  (2213, 'https://www.msi.com/Graphics-Card/GeForce-RTX-5070-12G-GAMING-TRIO-OC'),
  (2214, 'https://www.msi.com/Graphics-Card/GeForce-RTX-5070-12G-VANGUARD-SOC'),
  (2215, 'https://www.msi.com/Graphics-Card/GeForce-RTX-5070-12G-World-of-Warcraft-MIDNIGHT-LIGHT-EDITION-OC'),
  (2216, 'https://www.msi.com/Graphics-Card/GeForce-RTX-5070-12G-GAMING-TRIO-OC-WHITE'),
  (2217, 'https://rog.asus.com/graphics-cards/graphics-cards/rog-strix/rog-strix-rtx5070-o12g-gaming/'),
  (2218, 'https://www.msi.com/Graphics-Card/GeForce-RTX-5070-Ti-16G-FRIEREN-EDITION-OC'),
  (2219, 'https://www.msi.com/Graphics-Card/GeForce-RTX-5070-Ti-16G-GAMING-TRIO-OC'),
  (2220, 'https://www.asus.com/motherboards-components/graphics-cards/tuf-gaming/tuf-rtx5070ti-o16g-gaming/'),
  (2221, 'https://www.asus.com/motherboards-components/graphics-cards/tuf-gaming/tuf-rtx5070ti-o16g-white-gaming/'),
  (2222, 'https://www.asus.com/motherboards-components/graphics-cards/prime/prime-rtx5080-o16g/'),
  (2223, 'https://rog.asus.com/graphics-cards/graphics-cards/rog-astral/rog-astral-rtx5080-o16g-gaming/'),
  (2224, 'https://rog.asus.com/graphics-cards/graphics-cards/rog-astral/rog-astral-rtx5080-o16g-white/'),
  (2225, 'https://rog.asus.com/graphics-cards/graphics-cards/rog-astral/rog-astral-rtx5090-o32g-white/'),
  (2226, 'https://www.asus.com/motherboards-components/graphics-cards/tuf-gaming/tuf-rx9060xt-o16g-gaming/'),
  (2227, 'https://www.asus.com/motherboards-components/graphics-cards/prime/prime-rx9070xt-o16g/'),
  (2228, 'https://www.sapphiretech.com/en/consumer/nitro-radeon-rx-9070-xt-16g-gddr6'),
  (2229, 'https://www.asus.com/motherboards-components/graphics-cards/others/gt710-sl-2gd5/'),
  (2233, 'https://www.msi.com/Graphics-Card/GeForce-RTX-3050-VENTUS-2X-6G-OC'),
  (2234, 'https://www.asus.com/motherboards-components/graphics-cards/dual/dual-rtx3050-o6g/')
) AS v(product_id, url)
WHERE p.product_id = v.product_id;
