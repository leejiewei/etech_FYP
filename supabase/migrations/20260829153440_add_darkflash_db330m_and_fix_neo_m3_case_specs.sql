-- Two things, both about the Case category.
--
-- The version number in the filename matches the row this migration has
-- in the remote project's history. Renaming it would make Supabase treat
-- it as a new migration and try to apply it again.
--
-- 1. Backfill the Darkflash DB330M.
--
-- The RigWorks record of 12 August 2026 puts Casings at 31; the database
-- held 30. The DB330M is the missing one: confirmed by Lee as a separate
-- product from the C275P Dual Chamber ARGB (product 1504), which keeps the
-- name the corrections log gave it. mATX, black and white, 3 fans, RM199.
--
-- It appears nowhere in the project's history -- not in sql/03_seed.sql,
-- not in sql/supabase/02_data.sql, not in the old prototype's products.js
-- -- so this is a genuine gap in the original catalogue entry rather than
-- something that was deleted. It goes in as stock_status 'in' to match the
-- other 30 casings, all of which were seeded that way.
--
-- 2. Repair product 1530, Tecware Neo M3+ TG, added earlier the same day.
--
-- supportedFormFactors is multi-valued: one row per board size the case
-- accepts, and build.js reads the whole set (`pcCase.attrs
-- .supportedFormFactors || []`). 1530 was given only mini-ITX, so the PC
-- Builder refused mATX boards in it even though it is an mATX case.
--
-- It was also left without maxGpuLength, and build.js falls back to
-- `|| 0` -- so no graphics card at all would fit it. Both are fixed below.
--
-- NOTE ON maxGpuLength: 320mm is the catalogue's value for 16 of the 30
-- existing cases and is used here for both the Neo M3+ TG and the DB330M
-- as a working default. Neither figure came from the record or from the
-- shop. Confirm both against the manufacturer spec and correct them.

-- ---- 1. Darkflash DB330M ----
INSERT INTO products (product_id, name, brand_id, category_id, price, stock_status, description, icon, img_slug)
SELECT 1531, 'Darkflash DB330M (Black / White)', b.brand_id, 17, 199.00, 'in'::stock_status,
       'mATX case, Black / White, 3 fans included.', '🖥️', 'case'
FROM brands b WHERE b.name = 'Darkflash'
ON CONFLICT (product_id) DO NOTHING;

INSERT INTO product_attributes (product_id, attr_key, attr_value)
SELECT v.product_id, v.attr_key, v.attr_value
FROM (VALUES
(1531,'formFactor','mATX'),
(1531,'colour','Black / White'),
(1531,'fansIncluded','3'),
(1531,'acceptsAtxPsu','Yes'),
(1531,'maxGpuLength','320'),
(1531,'supportedFormFactors','mini-ITX'),
(1531,'supportedFormFactors','mATX')
) AS v(product_id, attr_key, attr_value)
WHERE NOT EXISTS (SELECT 1 FROM product_attributes a
                  WHERE a.product_id = v.product_id
                    AND a.attr_key = v.attr_key
                    AND a.attr_value = v.attr_value);

-- ---- 2. Repair 1530 ----
INSERT INTO product_attributes (product_id, attr_key, attr_value)
SELECT v.product_id, v.attr_key, v.attr_value
FROM (VALUES
(1530,'supportedFormFactors','mATX'),
(1530,'maxGpuLength','320')
) AS v(product_id, attr_key, attr_value)
WHERE NOT EXISTS (SELECT 1 FROM product_attributes a
                  WHERE a.product_id = v.product_id
                    AND a.attr_key = v.attr_key
                    AND a.attr_value = v.attr_value);
