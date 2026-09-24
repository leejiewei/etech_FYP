-- ============================================================
-- The maker's own page for each motherboard.
--
-- Same as the processor, graphics card and memory links: the shop card
-- and the product screen show "Full specs" and open this page. Every
-- link was opened on 25 Sep 2026 and its title checked against the board
-- (asus.com answers 200 even for a made-up address, so the title is the
-- check, not the status code).
--
-- Left without a link on purpose:
--   2125 Asus P8H61-M LX3 Plus - ASUS only keeps support pages for it,
--        split across two board revisions, and the name does not say
--        which one the shop has.
--   2126-2128 Salpido H81/H110/H310 - no maker's page could be found;
--        salpido.com is a store selling Imperion-branded boards.
--   2113-2114 Gigabyte - gigabyte.com was returning 502 at the time.
-- ============================================================

UPDATE public.products p
SET official_url = v.url
FROM (VALUES
  -- ASUS
  (2101, 'https://www.asus.com/motherboards-components/motherboards/prime/prime-a620m-k/'),
  (2103, 'https://www.asus.com/motherboards-components/motherboards/others/b850m-ayw-gaming-wifi/'),
  (2106, 'https://www.asus.com/motherboards-components/motherboards/tuf-gaming/tuf-gaming-b850m-plus-wifi7/'),
  (2107, 'https://rog.asus.com/motherboards/rog-strix/rog-strix-b850-a-gaming-wifi/'),
  (2108, 'https://rog.asus.com/motherboards/rog-strix/rog-strix-x870-a-gaming-wifi/'),
  (2109, 'https://www.asus.com/motherboards-components/motherboards/proart/proart-x870e-creator-wifi/'),
  (2110, 'https://www.asus.com/motherboards-components/motherboards/prime/prime-a520m-k/'),
  (2111, 'https://www.asus.com/motherboards-components/motherboards/prime/prime-b550m-a-wifi-ii/'),
  (2112, 'https://www.asus.com/motherboards-components/motherboards/prime/prime-h810m-a-wifi/'),
  (2115, 'https://www.asus.com/motherboards-components/motherboards/tuf-gaming/tuf-gaming-b860m-plus-wifi/'),
  (2116, 'https://www.asus.com/motherboards-components/motherboards/tuf-gaming/tuf-gaming-b860-plus-wifi/'),
  (2117, 'https://rog.asus.com/motherboards/rog-strix/rog-strix-b860-g-gaming-wifi/'),
  (2118, 'https://www.asus.com/motherboards-components/motherboards/prime/prime-h610m-f-wifi-d4/'),
  (2119, 'https://www.asus.com/motherboards-components/motherboards/prime/prime-h610m-a-wifi-d4/'),
  (2120, 'https://www.asus.com/motherboards-components/motherboards/prime/prime-b760m-f-wifi/'),
  (2121, 'https://www.asus.com/motherboards-components/motherboards/prime/prime-b760m-a-wifi-d4/'),
  (2124, 'https://rog.asus.com/motherboards/rog-strix/rog-strix-z790-i-gaming-wifi-model/'),
  (2129, 'https://www.asus.com/motherboards-components/motherboards/prime/prime-h510m-k/'),
  -- MSI (2130 is the DDR4 version, as the shop lists it)
  (2102, 'https://www.msi.com/Motherboard/B650M-GAMING-PLUS-WIFI'),
  (2104, 'https://www.msi.com/Motherboard/B850M-GAMING-WIFI'),
  (2105, 'https://www.msi.com/Motherboard/MPG-B650I-EDGE-WIFI'),
  (2122, 'https://www.msi.com/Motherboard/MAG-B760M-MORTAR-WIFI-II'),
  (2123, 'https://www.msi.com/Motherboard/B760M-PROJECT-ZERO'),
  (2130, 'https://www.msi.com/Motherboard/PRO-H610M-E-DDR4')
) AS v(id, url)
WHERE p.product_id = v.id;
