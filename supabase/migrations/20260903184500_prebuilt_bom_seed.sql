-- ============================================================
-- Filling in the bill of materials, as far as it can honestly be filled.
--
-- Three passes, in this order, and the order matters:
--
--   1. Every component slot on every DIY machine becomes a row, all of
--      them pending. This is the checklist; nothing is claimed yet.
--   2. The slots that are not products at all are marked not_stocked,
--      so they stop counting as unanswered questions.
--   3. Only the slots that can be matched to exactly one catalogue row
--      are linked, by a rule strict enough that it cannot be wrong.
--
-- Pass 3's rule: the catalogue name is the spec exactly, or the spec
-- with a brand in front of it -- "Asus Prime B760M-A WiFi D4" for the
-- spec "Prime B760M-A WiFi D4". Products in the Desktops tree are
-- excluded so a machine cannot match itself. That is deliberately
-- narrower than "contains": "Hiksemi Wave 256GB" stays pending because
-- the catalogue has both a SATA and an NVMe drive by that name and
-- guessing between them is the shop's call, not this migration's.
--
-- It links 11 of the 47 distinct specs. The other 36 stay pending on
-- purpose, and the admin screen is where they get answered. Until a
-- machine has no pending slots, prebuilt_availability reports pending
-- and the app keeps showing that machine's own stock_status -- so this
-- migration cannot change any badge that is on the site today.
-- ============================================================


-- ------------------------------------------------------------
-- 1. The checklist
--
-- Slots are the eight that name a physical part. Specs like colour,
-- sku, screenSize or touch describe the machine rather than list a
-- component, so they are not stock-bearing and are left out.
-- ------------------------------------------------------------
insert into prebuilt_components (prebuilt_id, slot, spec_text)
select a.product_id, a.attr_key, a.attr_value
from product_attributes a
join products p  on p.product_id = a.product_id
join categories c on c.category_id = p.category_id
where c.name in ('Prebuilt Gaming PCs', 'Office PC Series', 'Custom Office CO1')
  and a.attr_key in ('cpu', 'gpu', 'motherboard', 'ram', 'ssd', 'psu', 'cooler', 'chassis')
on conflict (prebuilt_id, slot) do nothing;


-- ------------------------------------------------------------
-- 2. The slots that are not products
--
-- "Stock" means the cooler that came in the processor's own box -- the
-- shop does not stock it, sell it, or count it. "SE380 (bundled with
-- chassis)" is a power supply that arrives inside the case, so the
-- chassis row already covers its availability and counting it twice
-- would let a case shortage read as two shortages.
-- ------------------------------------------------------------
update prebuilt_components
set not_stocked = true,
    note = case
      when slot = 'cooler' then 'Processor box cooler -- not a stocked line'
      else 'Ships inside the chassis -- covered by the chassis row'
    end
where component_id is null
  and (
    (slot = 'cooler' and lower(spec_text) = 'stock')
    or (slot = 'psu' and lower(spec_text) like '%bundled with chassis%')
  );


-- ------------------------------------------------------------
-- 3. The certain matches
--
-- Written as a correlated update with a strict "exactly one candidate"
-- guard rather than a join, so a catalogue that grows a second product
-- by the same name later cannot silently start linking to whichever one
-- the planner reached first.
-- ------------------------------------------------------------
with candidate as (
  select pc.prebuilt_id,
         pc.slot,
         q.product_id,
         count(*) over (partition by pc.prebuilt_id, pc.slot) as n
  from prebuilt_components pc
  join products q
    on q.is_active = 1
   and (lower(q.name) = lower(pc.spec_text)
        or lower(q.name) like '% ' || lower(pc.spec_text))
  join categories qc on qc.category_id = q.category_id
  where pc.component_id is null
    and not pc.not_stocked
    -- never let a machine, or another machine, stand in for a part
    and coalesce(
          (select pt.name from categories pt where pt.category_id = qc.parent_id),
          qc.name
        ) <> 'Desktops'
)
update prebuilt_components pc
set component_id = candidate.product_id
from candidate
where candidate.prebuilt_id = pc.prebuilt_id
  and candidate.slot = pc.slot
  and candidate.n = 1;


-- ------------------------------------------------------------
-- 4. The upgrade options
--
-- Lifted from the "Upgrades:" sentence at the end of each machine's
-- description, which is the shop's own quoted price for swapping that
-- part at build time. price_delta is what it adds to the machine, not a
-- new total.
--
-- The Office and CO1 descriptions also carry a bundled monitor at RM349
-- and a PWP accessory list (keyboard and mouse RM70, gaming set RM150,
-- speakers RM25). Those are accessories sold alongside the machine
-- rather than changes to the machine, so they are not upgrades and are
-- not seeded here.
--
-- component_id is left null throughout: the upgrade parts are described
-- by capacity ("512GB SSD", "32GB") rather than by a catalogue line, and
-- inventing a link would put this migration back in the guessing
-- business the whole design is avoiding.
-- ------------------------------------------------------------
-- One machine never offers the same swap twice, and saying so lets this
-- seed be re-run without doubling the list.
create unique index if not exists prebuilt_upgrades_unique_option
  on prebuilt_upgrades (prebuilt_id, slot, label);

insert into prebuilt_upgrades (prebuilt_id, slot, label, price_delta, sort_order)
values
  -- 5201 E-Tech ZenForge Ryzen 5 5500 RTX 3050
  (5201, 'gpu',    'RTX 5050 8GB',                   499.00, 1),
  (5201, 'ssd',    '1TB Gen4 NVMe',                  380.00, 2),

  -- 5202 E-Tech Cyber Strike Core Ultra 5 225 RTX 3050
  (5202, 'gpu',    'RTX 5050 8GB',                   359.00, 1),
  (5202, 'ssd',    '512GB M.2 NVMe',                 199.00, 2),
  (5202, 'ram',    '32GB',                           799.00, 3),

  -- 5203 E-Tech Ember Core Ryzen 5 7500F RTX 5050
  (5203, 'gpu',    'RTX 5060 8GB',                   449.00, 1),
  (5203, 'ssd',    '512GB M.2 NVMe',                 199.00, 2),
  (5203, 'ram',    '32GB',                           799.00, 3),
  (5203, 'extras', '4x Asus Prime MR120 ARGB fans',   99.00, 4),

  -- 5204 E-Tech Titan Aegis i7-14700F RTX 5050
  (5204, 'gpu',    'RTX 5060 8GB',                   449.00, 1),
  (5204, 'ssd',    '1TB M.2 NVMe',                   299.00, 2),
  (5204, 'ram',    '32GB',                           499.00, 3),
  (5204, 'extras', '4x Asus Prime MR120 ARGB fans',   99.00, 4),

  -- 5205 E-Tech Inferno Apex Ryzen 7 7800X3D RX 9060 XT
  (5205, 'ssd',    '1TB M.2 NVMe',                   299.00, 1),
  (5205, 'ram',    '32GB',                           799.00, 2),
  (5205, 'cooler', 'TUF LC III 360 ARGB LCD AIO, black', 249.00, 3),
  (5205, 'extras', '4x MR120 ARGB fans',              99.00, 4),

  -- 5301 E-Tech Office PC Ryzen 3 3200G
  (5301, 'cpu',    'Ryzen 5 3400G',                   79.00, 1),
  (5301, 'ssd',    '512GB SSD',                      199.00, 2),
  (5301, 'ram',    '16GB RAM',                       299.00, 3),

  -- 5302 E-Tech Office PC Ryzen 5 5600GT
  (5302, 'ssd',    '512GB SSD',                      199.00, 1),
  (5302, 'ram',    '16GB RAM',                       299.00, 2),

  -- 5303 E-Tech Office PC Core i5-14400
  (5303, 'ssd',    '512GB SSD',                      199.00, 1),
  (5303, 'ram',    '16GB RAM',                       299.00, 2),

  -- 5401 E-Tech Custom Office CO1 Ryzen 5 3400G
  (5401, 'ssd',    '512GB SSD',                      199.00, 1),
  (5401, 'ram',    '16GB RAM',                       299.00, 2),
  (5401, 'gpu',    'Asus GTX 1650 4GB',              599.00, 3),

  -- 5402 E-Tech Custom Office CO1 Ryzen 5 5600GT
  (5402, 'ssd',    '512GB SSD',                      199.00, 1),
  (5402, 'ram',    '16GB RAM',                       299.00, 2),
  (5402, 'gpu',    'Asus GTX 1650 4GB',              599.00, 3),

  -- 5403 E-Tech Custom Office CO1 Ryzen 7 5700X
  (5403, 'ssd',    '512GB SSD',                      199.00, 1),
  (5403, 'gpu',    'Asus RTX 3050 6GB',              899.00, 2)
on conflict (prebuilt_id, slot, label) do nothing;
