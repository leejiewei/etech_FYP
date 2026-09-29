-- ============================================================
-- Maker's page for 29 of the 31 PC cases (1501-1531); 22 also get a
-- photo. Pages checked 29 Sep 2026.
--
-- Link only, no photo:
--   * Tecware (1502, 1505, 1506, 1507, 1513, 1530): tecware.co only has
--     banner scenes showing several colours at once, no product shot.
--   * 1510 Zotac Alloy: zotac.com blocks automated browsers.
-- Left out on purpose:
--   * 1520/1522 Jonsbo D31: Jonsbo sells D31 STD, MESH and SCREEN
--     versions and the name doesn't say which (user: skip unclear ones).
--
-- Choices:
--   * "Black / White" products use the first colour's photo.
--   * 1506 Timber is mATX, so the Timber M page (Timber is ATX).
--   * 1516 CG530 includes 4 fans, so the CG530 4F page.
--   * 1524 "ProArt Wood TG" with 3 fans = PA401 Wood Edition TG
--     (2x160 + 1x120 pre-installed); the PA602 is ~2x the price.
--   * 1528/1529 are the plain ROG Cronox / Cronox White Edition.
-- ============================================================

UPDATE public.products p
SET official_url = v.url,
    image_path   = 'https://etech-fyp.vercel.app/images/products/' || p.product_id || '.webp'
FROM (VALUES
  (1501, 'https://slev.my/products/pccases/spotless/'),
  (1503, 'https://slev.my/products/pccases/envision/'),
  (1504, 'https://www.darkflash.com/product/c275p'),
  (1508, 'https://www.coolermaster.com/en-global/products/masterbox-mb600l-v2.html'),
  (1509, 'https://www.deepcool.com/products/Cases/CH160-WH-Portable-High-Airflow-M-ITX-Case/2024/18116.shtml'),
  (1511, 'https://www.deepcool.com/products/Cases/CH160-PLUS-Portable-M-ATX-Compact-Case/2025/21475.shtml'),
  (1512, 'https://www.deepcool.com/products/Cases/CH260-WH-High-Airflow-M-ATX-Compact-Case-Supports-Rear-Connector-Motherboards/2025/20031.shtml'),
  (1514, 'https://www.jonsbo.com/en/products/D200.html'),
  (1515, 'https://www.deepcool.com/products/Cases/CH260-High-Airflow-Compact-M-ATX-Wood-Grain-Case-Supports-Rear-Connector-Motherboards/2025/22574.shtml'),
  (1516, 'https://www.deepcool.com/products/Cases/CG530-Panoramic-Tempered-Glass-Panels-Dual-Chamber-ATX-FISHTANK-Case-with-4-ARGB-PWM-Fans/2024/19604.shtml'),
  (1517, 'https://www.asus.com/motherboards-components/cases/asus/asus-a23-hatsune-miku-edition/'),
  (1518, 'https://www.asus.com/motherboards-components/cases/asus/asus-a31-case/'),
  (1519, 'https://www.coolermaster.com/en-global/products/masterbox-td500-mesh-v2.html'),
  (1521, 'https://www.asus.com/motherboards-components/cases/prime/asus-prime-ap202/'),
  (1523, 'https://lian-li.com/product/o11-vision-compact/'),
  (1524, 'https://www.asus.com/motherboards-components/cases/proart/proart-pa401-wood-edition-tempered-glass-panel/'),
  (1525, 'https://www.asus.com/motherboards-components/cases/tuf-gaming/tuf-gaming-gt502/'),
  (1526, 'https://www.asus.com/motherboards-components/cases/tuf-gaming/tuf-gaming-gt502-horizon/'),
  (1527, 'https://rog.asus.com/cases/rog-hyperion-gr701-model/'),
  (1528, 'https://rog.asus.com/cases/rog-cronox/'),
  (1529, 'https://rog.asus.com/cases/rog-cronox-white-edition/'),
  (1531, 'https://www.darkflash.com/product/db330m')
) AS v(id, url)
WHERE p.product_id = v.id;

UPDATE public.products p
SET official_url = v.url
FROM (VALUES
  (1502, 'https://www.tecware.co/vxo-m'),
  (1505, 'https://www.tecware.co/aero-m'),
  (1506, 'https://www.tecware.co/timber-m'),
  (1507, 'https://www.tecware.co/vxn-plus'),
  (1513, 'https://www.tecware.co/vx-prism-m'),
  (1530, 'https://www.tecware.co/neo-m3'),
  (1510, 'https://www.zotac.com/my/product/pc-case/zotac-gaming-alloy-matx-computer-case-black')
) AS v(id, url)
WHERE p.product_id = v.id;
