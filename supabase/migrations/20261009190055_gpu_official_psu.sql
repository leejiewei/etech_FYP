-- recommendedPsu now holds the GPU makers' own figures, as the user asked
-- (10 Oct 2026), instead of the shop-raised ones from the last migration:
--   NVIDIA "Required System Power", nvidia.com/en-us/geforce/graphics-cards/compare/
--   AMD "Minimum PSU Recommendation", the amd.com RX 9070 XT / 9060 XT pages.
-- GT 710/730/1030 are not on NVIDIA's compare page; 300W is the figure
-- NVIDIA gives for its entry cards (GTX 1650, RTX 3050 6GB).
-- The builder still adds 25% headroom over the estimated draw, and uses
-- whichever of the two is bigger.

UPDATE public.product_attributes a
SET attr_value = v.watts
FROM public.product_attributes chip,
     (VALUES
       ('RTX 5090', '1000'),
       ('RTX 5080', '850'),
       ('RTX 5070 Ti', '750'),
       ('RTX 5070', '650'),
       ('RTX 5060 Ti', '600'),
       ('RTX 5060', '550'),
       ('RTX 5050', '550'),
       ('RTX 3050', '300'),  -- all stocked 3050s are the 6GB card
       ('GTX 1650', '300'),
       ('GT 1030', '300'),
       ('GT 730', '300'),
       ('GT 710', '300'),
       ('RX 9070 XT', '750'),
       ('RX 9060 XT', '450')
     ) AS v(chip, watts)
WHERE a.attr_key = 'recommendedPsu'
  AND chip.product_id = a.product_id
  AND chip.attr_key = 'chip'
  AND chip.attr_value = v.chip;
