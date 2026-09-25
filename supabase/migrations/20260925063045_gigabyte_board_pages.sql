-- ============================================================
-- Photo and maker's page for the two Gigabyte boards left out of
-- 20260924172201 (gigabyte.com was returning 502 then). Both pages were
-- opened on 25 Sep 2026 and their titles checked. The photo is the
-- angled board-only shot from each board's /gallery page.
-- ============================================================

UPDATE public.products p
SET official_url = v.url,
    image_path   = 'https://etech-fyp.vercel.app/images/products/' || p.product_id || '.webp'
FROM (VALUES
  (2113, 'https://www.gigabyte.com/Motherboard/B860M-EAGLE-WIFI6'),
  (2114, 'https://www.gigabyte.com/Motherboard/B860M-GAMING-WIFI6')
) AS v(product_id, url)
WHERE p.product_id = v.product_id;
