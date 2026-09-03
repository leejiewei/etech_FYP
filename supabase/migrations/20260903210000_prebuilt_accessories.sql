-- ============================================================
-- The accessories the office machines are sold with.
--
-- The upgrade options put the "Upgrades:" sentence into rows. The office
-- and CO1 descriptions carry a second list that is not upgrades at all:
--
--   "Bundled 24" FHD IPS 120Hz monitor available at RM349. PWP
--    accessories: keyboard and mouse set RM70, gaming
--    keyboard/mouse/headset/mousepad set RM150, 2.0 speakers RM25."
--
-- The difference matters. An upgrade changes what the machine is -- a
-- bigger drive instead of the one it ships with. An accessory is a
-- separate thing sold beside it at a price that only exists because a
-- machine is being bought at the same time. Same tick box to a customer,
-- different fact about the shop.
--
-- Rather than a second table with a second set of triggers, cart rows
-- and order lines behind it, prebuilt_upgrades grows a "kind" column.
-- Everything already built -- the picker, cart_item_upgrades, the
-- upgrade lines place_order writes -- carries on working untouched, and
-- the only new work is that the card draws two sections instead of one.
--
-- Who gets what: the three Office PC Series machines get the monitor and
-- the three PWP accessories. The three CO1 machines get the PWP
-- accessories only -- their description says "Same PWP accessory pricing
-- as the Office PC Series", which is the PWP list; the monitor is quoted
-- separately in the Office text and is not part of it. The five gaming
-- machines have no accessory list of their own and get none.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Telling the two kinds apart
--
-- Defaulting to 'upgrade' leaves all 32 existing rows exactly as they
-- were, so no query that already reads this table has to change.
-- ------------------------------------------------------------
alter table prebuilt_upgrades
  add column if not exists kind varchar(16) not null default 'upgrade';

alter table prebuilt_upgrades
  drop constraint if exists prebuilt_upgrades_kind_known;
alter table prebuilt_upgrades
  add constraint prebuilt_upgrades_kind_known
  check (kind in ('upgrade', 'accessory'));

comment on column prebuilt_upgrades.kind is
  'upgrade = changes the machine itself; accessory = sold alongside it at a with-purchase price.';


-- ------------------------------------------------------------
-- 2. The accessories
--
-- sort_order restarts at 1 within the accessory list; the card sorts
-- each section on its own, so the two do not have to share a sequence.
--
-- The slots are what the one-swap-per-slot rule keys on, and they are
-- chosen so it does the right thing: the two peripheral sets are
-- alternatives, so they share a slot and picking one drops the other.
-- The monitor and the speakers stand alone.
-- ------------------------------------------------------------
insert into prebuilt_upgrades
  (prebuilt_id, slot, label, price_delta, sort_order, kind)
values
  -- Office PC Series -- monitor plus the three PWP accessories
  (5301, 'monitor',     '24" FHD IPS 120Hz monitor',                349.00, 1, 'accessory'),
  (5301, 'peripherals', 'Keyboard and mouse set',                    70.00, 2, 'accessory'),
  (5301, 'peripherals', 'Gaming keyboard, mouse, headset, mousepad', 150.00, 3, 'accessory'),
  (5301, 'audio',       '2.0 speakers',                              25.00, 4, 'accessory'),

  (5302, 'monitor',     '24" FHD IPS 120Hz monitor',                349.00, 1, 'accessory'),
  (5302, 'peripherals', 'Keyboard and mouse set',                    70.00, 2, 'accessory'),
  (5302, 'peripherals', 'Gaming keyboard, mouse, headset, mousepad', 150.00, 3, 'accessory'),
  (5302, 'audio',       '2.0 speakers',                              25.00, 4, 'accessory'),

  (5303, 'monitor',     '24" FHD IPS 120Hz monitor',                349.00, 1, 'accessory'),
  (5303, 'peripherals', 'Keyboard and mouse set',                    70.00, 2, 'accessory'),
  (5303, 'peripherals', 'Gaming keyboard, mouse, headset, mousepad', 150.00, 3, 'accessory'),
  (5303, 'audio',       '2.0 speakers',                              25.00, 4, 'accessory'),

  -- Custom Office CO1 -- the PWP accessories, no monitor
  (5401, 'peripherals', 'Keyboard and mouse set',                    70.00, 2, 'accessory'),
  (5401, 'peripherals', 'Gaming keyboard, mouse, headset, mousepad', 150.00, 3, 'accessory'),
  (5401, 'audio',       '2.0 speakers',                              25.00, 4, 'accessory'),

  (5402, 'peripherals', 'Keyboard and mouse set',                    70.00, 2, 'accessory'),
  (5402, 'peripherals', 'Gaming keyboard, mouse, headset, mousepad', 150.00, 3, 'accessory'),
  (5402, 'audio',       '2.0 speakers',                              25.00, 4, 'accessory'),

  (5403, 'peripherals', 'Keyboard and mouse set',                    70.00, 2, 'accessory'),
  (5403, 'peripherals', 'Gaming keyboard, mouse, headset, mousepad', 150.00, 3, 'accessory'),
  (5403, 'audio',       '2.0 speakers',                              25.00, 4, 'accessory')
on conflict (prebuilt_id, slot, label) do nothing;
