-- ============================================================
-- The rest of the bill of materials, answered by the shop.
--
-- The seed migration linked only the 11 distinct specs whose catalogue
-- name matched exactly, or matched with a brand in front of it. That
-- left 39 slots that a person had to settle, because the spec lines are
-- written the way the build sheet writes them and not the way the
-- catalogue names a product: "8GB DDR4" instead of "Hiksemi Value RAM
-- 8GB DDR4-3200MHz", "Wave (P) 256GB" for the PCIe drive as against the
-- SATA one, "Prime A520M-K CSM" for a commercial variant the shop does
-- not stock separately.
--
-- Lee answered them on 2026-09-03 against the shop's own build sheets.
-- Recorded here rather than left as a hand-edit so the mapping survives
-- a rebuild and can be read back later. Three of the answers are worth
-- writing down because they are judgements rather than lookups:
--
--   * "Prime A520M-K CSM" is linked to the plain Asus Prime A520M-K.
--     The CSM is the commercial-channel variant of the same board and
--     the shop does not carry it as its own line.
--   * "Asus Prime AP-750G" is linked to "Asus Prime 750W Fully
--     modular". Same supply, catalogue name written the long way.
--   * The gaming cards written as "Dual" and "Dual OC" are both the
--     Asus Dual OC card; the record drops the OC on some lines.
--
-- After this every one of the 79 slots is answered, so all eleven
-- machines switch from their own stock_status to a status derived from
-- their parts. That changes what the shop shows: nine machines that were
-- manually marked "out" become available, and the two that stay out now
-- name the part that is missing rather than saying nothing.
-- ============================================================

update prebuilt_components pc
set component_id = m.component_id,
    not_stocked  = false,
    note         = null
from (values
  -- Memory. The office and CO1 machines share the Hiksemi value line;
  -- the DDR5 gaming builds are Essencore except the Cyber Strike, whose
  -- description already records why it is Adata -- Essencore DDR5 is
  -- shop-confirmed incompatible with LGA1851.
  ('ram',         '8GB DDR4',                                    3017),
  ('ram',         'Hiksemi 8GB DDR4 3200',                       3017),
  ('ram',         '16GB DDR4',                                   3018),
  ('ram',         'Hiksemi 16GB DDR4 3200',                      3018),
  ('ram',         'Hiksemi UDIMM 16GB DDR4 3200',                3018),
  ('ram',         'Essencore 16GB DDR5 5600 UDIMM',              3002),
  ('ram',         'Adata 16GB DDR5 5600 U-DIMM',                 3003),

  -- Storage. "(P)" in the record means the PCIe drive; without it, the
  -- 2.5" SATA one. Both capacities exist in the catalogue under both
  -- interfaces, which is exactly why this could not be guessed.
  ('ssd',         '256GB SATA SSD',                              3201),
  ('ssd',         'Hiksemi Wave 256GB',                          3201),
  ('ssd',         'Hiksemi Wave (P) 256GB',                      3208),
  ('ssd',         'Hiksemi Wave (P) 512GB',                      3209),
  ('ssd',         'MSI Spatium M450 500GB Gen4',                 3211),

  -- Processors. The record carries the socket in brackets; the
  -- catalogue carries the maker in front.
  ('cpu',         'Ryzen 5 5500 (AM4)',                          2011),
  ('cpu',         'Ryzen 5 7500F (AM5)',                         2001),
  ('cpu',         'Ryzen 7 7800X3D (AM5)',                       2005),
  ('cpu',         'Core Ultra 5 225 (LGA1851)',                  2017),
  ('cpu',         'i7-14700F (LGA1700)',                         2026),

  -- Graphics.
  ('gpu',         'RTX 3050 6GB Dual',                           2234),
  ('gpu',         'RTX 3050 6GB Dual OC',                        2234),
  ('gpu',         'RTX 5050 8GB Dual',                           2202),
  ('gpu',         'TUF RX 9060 XT 16GB OC',                      2226),

  -- Motherboards.
  ('motherboard', 'B850M-AYW WiFi',                              2103),
  ('motherboard', 'Prime A520M-K CSM',                           2110),

  -- Power supplies.
  ('psu',         'Slev Quantum 600W',                           3301),
  ('psu',         'Asus Prime AP-750G',                          3305),

  -- Cooling. The record names the colour; the catalogue keeps black and
  -- white as separate lines for this one, so the white is chosen.
  ('cooler',      'Asus Prime LC 360 ARGB AIO - White',          4003),

  -- Chassis. Most catalogue cases cover both colours in one row.
  ('chassis',     'Slev Spotless mATX',                          1501),
  ('chassis',     'Tecware VXO M TG mATX Black (3x ARGB fans)',  1502),
  ('chassis',     'Darkflash C275P Dual Chamber ARGB - White',   1504),
  ('chassis',     'Asus A31 ATX - Black',                        1518),
  ('chassis',     'Asus Prime AP202 mATX TG ARGB - White',       1521),
  ('chassis',     'Tecware Neo M3+ TG ARGB mATX (3x120mm ARGB)', 1530)
) as m(slot, spec_text, component_id)
where pc.slot = m.slot
  and pc.spec_text = m.spec_text;


-- A guard rather than a comment. If a product id above is ever wrong,
-- or a machine grows a slot nobody answered, this fails loudly at
-- migration time instead of quietly showing a customer the wrong badge.
do $$
declare
  v_pending integer;
begin
  select count(*) into v_pending
  from prebuilt_components
  where component_id is null and not not_stocked;

  if v_pending > 0 then
    raise exception
      'Bill of materials incomplete: % slot(s) still unanswered.', v_pending;
  end if;
end $$;
