-- The supply eTech itself recommends for a full rig with each card, in
-- watts (shopPsu). recommendedPsu keeps NVIDIA's / AMD's own figure for
-- the spec table; the PC builder asks for shopPsu when a card has one.
--
-- The user's figures (10 Oct 2026): RTX 5080 1000W, 5070 Ti 850W, 5070
-- 750W -- the makers' numbers assume their own test system, and a full
-- rig (more fans, RGB, drives, a hotter CPU) wants the next size up. The
-- other tiers follow the same one-step-up rule. Entry cards (RTX 3050,
-- GTX 1650, GT 710/730/1030) have none: the smallest supply the shop
-- stocks (600W) already covers them.

INSERT INTO public.product_attributes (product_id, attr_key, attr_value)
SELECT chip.product_id, 'shopPsu', v.watts
FROM public.product_attributes chip
JOIN (VALUES
  ('RTX 5090', '1200'),
  ('RTX 5080', '1000'),
  ('RTX 5070 Ti', '850'),
  ('RTX 5070', '750'),
  ('RTX 5060 Ti', '650'),
  ('RTX 5060', '600'),
  ('RTX 5050', '600'),
  ('RX 9070 XT', '850'),
  ('RX 9060 XT', '600')
) AS v(chip, watts) ON chip.attr_key = 'chip' AND chip.attr_value = v.chip
WHERE NOT EXISTS (
  SELECT 1 FROM public.product_attributes a
  WHERE a.product_id = chip.product_id AND a.attr_key = 'shopPsu'
);
