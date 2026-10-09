-- The power supply each graphics card should be paired with, in watts.
--
-- The PC builder used to accept any supply that covered CPU + GPU + 100W
-- with nothing to spare, so an RTX 5080 passed on a 650W unit. It now
-- asks for the larger of this figure and the estimated draw plus 25%.
--
-- Figures follow the card makers' recommended PSU for the tier, raised
-- to the shop's own floor where the shop builds with more margin (the
-- 5070 Ti, 5080 and 9070 XT get 850W).

INSERT INTO public.product_attributes (product_id, attr_key, attr_value)
SELECT p.product_id, 'recommendedPsu', v.watts
FROM public.products p
JOIN (VALUES
  (2201, '550'), (2202, '550'),                                  -- RTX 5050
  (2203, '550'), (2204, '550'), (2205, '550'), (2206, '550'),    -- RTX 5060
  (2207, '650'), (2208, '650'), (2209, '650'), (2210, '650'),    -- RTX 5060 Ti
  (2211, '750'), (2212, '750'), (2213, '750'), (2214, '750'),
  (2215, '750'), (2216, '750'), (2217, '750'),                   -- RTX 5070
  (2218, '850'), (2219, '850'), (2220, '850'), (2221, '850'),    -- RTX 5070 Ti
  (2222, '850'), (2223, '850'), (2224, '850'),                   -- RTX 5080
  (2225, '1000'),                                                -- RTX 5090
  (2226, '650'),                                                 -- RX 9060 XT
  (2227, '850'), (2228, '850'),                                  -- RX 9070 XT
  (2229, '400'), (2230, '400'), (2231, '400'), (2232, '400'),    -- GT 710/730/1030, GTX 1650
  (2233, '550'), (2234, '550')                                   -- RTX 3050
) AS v(product_id, watts) ON v.product_id = p.product_id
WHERE NOT EXISTS (
  SELECT 1 FROM public.product_attributes a
  WHERE a.product_id = p.product_id AND a.attr_key = 'recommendedPsu'
);
