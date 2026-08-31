-- Section 8 of the RigWorks record, 12 August 2026: the corrections and
-- clarifications log. Eleven items were flagged and resolved that day.
--
-- The version number in the filename matches the row this migration has
-- in the remote project's history. Renaming it would make Supabase treat
-- it as a new migration and try to apply it again.
--
-- Eight of them were already satisfied when the record was loaded, and are
-- listed here so the log stays traceable rather than because they need SQL:
--
--   1  Vivobook 15 A1504 Silver 8GB SKU: the 8GB poster printed
--      A1504V-ABQ269WS, which is really the 16GB Cool Silver. Product 206
--      was loaded as A1504V-ABQ169WS, and 215 holds the ABQ269WS 16GB.
--   4  Tecware Neo M3+ TG was not previously recorded. Added as 1530.
--   6  "CPS Paladin EX400" in the CO1 build spec is the Pccooler Paladin
--      EX400 ARGB already recorded at RM119 (product 4015). CPS is an
--      abbreviated brand mark. No duplicate row was ever created, and
--      product 5403 already names the cooler in full.
--   7  The SE380 power supply is bundled with the Slev Spotless chassis,
--      which already records a 380W PSU inclusion (product 1501). It was
--      deliberately not added as a standalone SKU.
--   8  Marketing uses Slevnergy for the PSUs and Slevcase for the chassis.
--      The database has only ever carried the single brand "Slev", and no
--      product name or spec value uses either variant.
--   9  ASUS TUF F16 FX608J-MRRV058W and FA608U-PRV028WP are separate
--      products, both in stock. Loaded as 222 and 223.
--  10  Lenovo LOQ 15AHP11-83Q7007LMJ and 15IRX11-83SC004UMJ are separate
--      products, both in stock. Loaded as 242 and 240.
--  11  IdeaPad Slim 3 Ryzen 5 (82XQ00XPMJ) is Arctic Grey only. Noted on
--      product 232.
--
-- The three below do change existing rows.

-- Correction 3. Recorded as "Tecware VXO"; the full model name is
-- Tecware VXO M TG. Price stays at RM179.
UPDATE products
   SET name = 'Tecware VXO M TG (Black)', updated_at = now()
 WHERE product_id = 1502 AND name = 'Tecware VXO (Black)';

-- Correction 5. Recorded with no model name at all. Confirmed by Lee as
-- the Darkflash C275P Dual Chamber ARGB. Price stays at RM199, and the
-- colour stays black and white.
UPDATE products
   SET name = 'Darkflash C275P Dual Chamber ARGB (Black / White)',
       description = 'mATX dual chamber case, Black / White, 3 ARGB fans included.',
       updated_at = now()
 WHERE product_id = 1504 AND name = 'Darkflash (model n/a) (Black / White)';

-- Correction 2. "16GB DDR5" on its own understates the Vivobook 15 A1504
-- 16GB: it is 8GB on-board plus an 8GB SO-DIMM, so it takes 24GB. The
-- descriptions already say so; this brings the spec row into line.
UPDATE product_attributes
   SET attr_value = '16GB DDR5 (8 on-board + 8 SODIMM, upgradeable to 24GB)'
 WHERE product_id IN (215, 216)
   AND attr_key = 'ram'
   AND attr_value = '16GB DDR5 (8 on-board + 8 SODIMM)';
