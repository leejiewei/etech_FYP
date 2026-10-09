-- Cases the shop stocks in two colours, as one product with one stock
-- count, now offer the colour as a choice (colourOption), the same way
-- keyboards offer a switch. The product popup, both PC builders and the
-- cart all read colourOption; cart_add() rejects any colour not listed
-- here, and the chosen one rides on the cart line and the order.
--
-- The existing 'colour' attribute ("Black / White") stays: it is the
-- spec-table line, this is the picker.

INSERT INTO public.product_attributes (product_id, attr_key, attr_value)
SELECT v.product_id, 'colourOption', v.colour
FROM (VALUES
  (1501, 'Black'),      (1501, 'White'),       -- Slev Spotless
  (1503, 'White'),      (1503, 'Black'),       -- Slev Envision
  (1504, 'Black'),      (1504, 'White'),       -- Darkflash C275P
  (1505, 'Black'),      (1505, 'White'),       -- Tecware Aero M TG
  (1506, 'Black Wood'), (1506, 'White Wood'),  -- Tecware Timber M
  (1510, 'Black/Gold'), (1510, 'White/Silver'),-- ZOTAC GAMING ALLOY mATX
  (1516, 'Black'),      (1516, 'White'),       -- Deepcool CG530
  (1518, 'Black'),      (1518, 'White'),       -- Asus A31
  (1521, 'Black'),      (1521, 'White'),       -- Asus AP202
  (1531, 'Black'),      (1531, 'White')        -- Darkflash DB330M
) AS v(product_id, colour)
WHERE NOT EXISTS (
  SELECT 1 FROM public.product_attributes a
  WHERE a.product_id = v.product_id
    AND a.attr_key = 'colourOption'
    AND a.attr_value = v.colour
);
