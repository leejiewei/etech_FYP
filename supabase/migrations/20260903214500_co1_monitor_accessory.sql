-- ============================================================
-- The CO1 machines get the monitor too.
--
-- The accessory seed gave the bundled 24" monitor to the three Office
-- PC Series machines only. That followed the descriptions literally:
-- the Office text quotes the monitor separately from the PWP list, and
-- the CO1 text says "Same PWP accessory pricing as the Office PC
-- Series" -- which is the PWP list, not the monitor.
--
-- Lee confirmed on 2026-09-03 that the CO1 machines are sold with the
-- same monitor offer. So the wording was the description's shorthand
-- rather than a difference in what the shop sells, and all six office
-- machines carry it at the same RM349.
-- ============================================================

insert into prebuilt_upgrades
  (prebuilt_id, slot, label, price_delta, sort_order, kind)
values
  (5401, 'monitor', '24" FHD IPS 120Hz monitor', 349.00, 1, 'accessory'),
  (5402, 'monitor', '24" FHD IPS 120Hz monitor', 349.00, 1, 'accessory'),
  (5403, 'monitor', '24" FHD IPS 120Hz monitor', 349.00, 1, 'accessory')
on conflict (prebuilt_id, slot, label) do nothing;
