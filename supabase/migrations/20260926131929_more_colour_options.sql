-- ============================================================
-- Colour options for 22 more peripherals, from the shop's colour list
-- of 26 Sep 2026 (the six added in colour_options are unchanged).
--
-- For these the old 'colour' detail ("Black + White") read as a
-- two-tone product; it now lists the choices ("Black / White") and the
-- description follows. The Logitech G512 Carbon and Razer BlackWidow
-- V3 TKL are black either way -- their choice is the switch, so the
-- options are "Red Switch" / "Brown Switch" and their colour stays.
-- ============================================================

insert into public.product_attributes (product_id, attr_key, attr_value) values
  (4404, 'colourOption', 'Red Switch'),
  (4404, 'colourOption', 'Brown Switch'),
  (4408, 'colourOption', 'Green Switch'),
  (4408, 'colourOption', 'Yellow Switch'),
  (4413, 'colourOption', 'Black'),
  (4413, 'colourOption', 'White'),
  (4417, 'colourOption', 'Black'),
  (4417, 'colourOption', 'White'),
  (4419, 'colourOption', 'Black'),
  (4419, 'colourOption', 'White'),
  (4419, 'colourOption', 'Pink'),
  (4420, 'colourOption', 'Pink'),
  (4420, 'colourOption', 'Black'),
  (4420, 'colourOption', 'White'),
  (4424, 'colourOption', 'Blue'),
  (4424, 'colourOption', 'Yellow'),
  (4430, 'colourOption', 'Pink'),
  (4430, 'colourOption', 'Purple'),
  (4430, 'colourOption', 'Green'),
  (4431, 'colourOption', 'Grey'),
  (4431, 'colourOption', 'Beach'),
  (4433, 'colourOption', 'Blue'),
  (4433, 'colourOption', 'White'),
  (4439, 'colourOption', 'Black'),
  (4439, 'colourOption', 'White'),
  (4440, 'colourOption', 'Black'),
  (4440, 'colourOption', 'White'),
  (4505, 'colourOption', 'Red'),
  (4505, 'colourOption', 'Yellow'),
  (4514, 'colourOption', 'Black'),
  (4514, 'colourOption', 'Blue'),
  (4515, 'colourOption', 'Black'),
  (4515, 'colourOption', 'Pink'),
  (4515, 'colourOption', 'White'),
  (4518, 'colourOption', 'Black'),
  (4518, 'colourOption', 'Grey'),
  (4522, 'colourOption', 'Black'),
  (4522, 'colourOption', 'White'),
  (4523, 'colourOption', 'Pink'),
  (4523, 'colourOption', 'Black'),
  (4524, 'colourOption', 'Black'),
  (4524, 'colourOption', 'White'),
  (4528, 'colourOption', 'Black'),
  (4528, 'colourOption', 'White'),
  (4530, 'colourOption', 'Blue'),
  (4530, 'colourOption', 'Purple'),
  (4530, 'colourOption', 'Pink'),
  (4537, 'colourOption', 'Black'),
  (4537, 'colourOption', 'White'),
  (4539, 'colourOption', 'Black'),
  (4539, 'colourOption', 'White');

-- Colour line and description, for the products whose colour is the choice.
update public.products p set description = replace(p.description, a.attr_value || '.', 'Black / White.')
  from public.product_attributes a
 where a.product_id = p.product_id and a.attr_key = 'colour' and p.product_id = 4413;
update public.product_attributes set attr_value = 'Black / White' where product_id = 4413 and attr_key = 'colour';
update public.products p set description = replace(p.description, a.attr_value || '.', 'Black / White.')
  from public.product_attributes a
 where a.product_id = p.product_id and a.attr_key = 'colour' and p.product_id = 4417;
update public.product_attributes set attr_value = 'Black / White' where product_id = 4417 and attr_key = 'colour';
update public.products p set description = replace(p.description, a.attr_value || '.', 'Black / White / Pink.')
  from public.product_attributes a
 where a.product_id = p.product_id and a.attr_key = 'colour' and p.product_id = 4419;
update public.product_attributes set attr_value = 'Black / White / Pink' where product_id = 4419 and attr_key = 'colour';
update public.products p set description = replace(p.description, a.attr_value || '.', 'Pink / Black / White.')
  from public.product_attributes a
 where a.product_id = p.product_id and a.attr_key = 'colour' and p.product_id = 4420;
update public.product_attributes set attr_value = 'Pink / Black / White' where product_id = 4420 and attr_key = 'colour';
update public.products p set description = replace(p.description, a.attr_value || '.', 'Blue / Yellow.')
  from public.product_attributes a
 where a.product_id = p.product_id and a.attr_key = 'colour' and p.product_id = 4424;
update public.product_attributes set attr_value = 'Blue / Yellow' where product_id = 4424 and attr_key = 'colour';
update public.products p set description = replace(p.description, a.attr_value || '.', 'Pink / Purple / Green.')
  from public.product_attributes a
 where a.product_id = p.product_id and a.attr_key = 'colour' and p.product_id = 4430;
update public.product_attributes set attr_value = 'Pink / Purple / Green' where product_id = 4430 and attr_key = 'colour';
update public.products p set description = replace(p.description, a.attr_value || '.', 'Grey / Beach.')
  from public.product_attributes a
 where a.product_id = p.product_id and a.attr_key = 'colour' and p.product_id = 4431;
update public.product_attributes set attr_value = 'Grey / Beach' where product_id = 4431 and attr_key = 'colour';
update public.products p set description = replace(p.description, a.attr_value || '.', 'Blue / White.')
  from public.product_attributes a
 where a.product_id = p.product_id and a.attr_key = 'colour' and p.product_id = 4433;
update public.product_attributes set attr_value = 'Blue / White' where product_id = 4433 and attr_key = 'colour';
update public.products p set description = replace(p.description, a.attr_value || '.', 'Black / White.')
  from public.product_attributes a
 where a.product_id = p.product_id and a.attr_key = 'colour' and p.product_id = 4439;
update public.product_attributes set attr_value = 'Black / White' where product_id = 4439 and attr_key = 'colour';
update public.products p set description = replace(p.description, a.attr_value || '.', 'Black / White.')
  from public.product_attributes a
 where a.product_id = p.product_id and a.attr_key = 'colour' and p.product_id = 4440;
update public.product_attributes set attr_value = 'Black / White' where product_id = 4440 and attr_key = 'colour';
update public.products p set description = replace(p.description, a.attr_value || '.', 'Red / Yellow.')
  from public.product_attributes a
 where a.product_id = p.product_id and a.attr_key = 'colour' and p.product_id = 4505;
update public.product_attributes set attr_value = 'Red / Yellow' where product_id = 4505 and attr_key = 'colour';
update public.products p set description = replace(p.description, a.attr_value || '.', 'Black / Blue.')
  from public.product_attributes a
 where a.product_id = p.product_id and a.attr_key = 'colour' and p.product_id = 4514;
update public.product_attributes set attr_value = 'Black / Blue' where product_id = 4514 and attr_key = 'colour';
update public.products p set description = replace(p.description, a.attr_value || '.', 'Black / Pink / White.')
  from public.product_attributes a
 where a.product_id = p.product_id and a.attr_key = 'colour' and p.product_id = 4515;
update public.product_attributes set attr_value = 'Black / Pink / White' where product_id = 4515 and attr_key = 'colour';
update public.products p set description = replace(p.description, a.attr_value || '.', 'Black / Grey.')
  from public.product_attributes a
 where a.product_id = p.product_id and a.attr_key = 'colour' and p.product_id = 4518;
update public.product_attributes set attr_value = 'Black / Grey' where product_id = 4518 and attr_key = 'colour';
update public.products p set description = replace(p.description, a.attr_value || '.', 'Black / White.')
  from public.product_attributes a
 where a.product_id = p.product_id and a.attr_key = 'colour' and p.product_id = 4522;
update public.product_attributes set attr_value = 'Black / White' where product_id = 4522 and attr_key = 'colour';
update public.products p set description = replace(p.description, a.attr_value || '.', 'Pink / Black.')
  from public.product_attributes a
 where a.product_id = p.product_id and a.attr_key = 'colour' and p.product_id = 4523;
update public.product_attributes set attr_value = 'Pink / Black' where product_id = 4523 and attr_key = 'colour';
update public.products p set description = replace(p.description, a.attr_value || '.', 'Black / White.')
  from public.product_attributes a
 where a.product_id = p.product_id and a.attr_key = 'colour' and p.product_id = 4524;
update public.product_attributes set attr_value = 'Black / White' where product_id = 4524 and attr_key = 'colour';
update public.products p set description = replace(p.description, a.attr_value || '.', 'Black / White.')
  from public.product_attributes a
 where a.product_id = p.product_id and a.attr_key = 'colour' and p.product_id = 4528;
update public.product_attributes set attr_value = 'Black / White' where product_id = 4528 and attr_key = 'colour';
update public.products p set description = replace(p.description, a.attr_value || '.', 'Blue / Purple / Pink.')
  from public.product_attributes a
 where a.product_id = p.product_id and a.attr_key = 'colour' and p.product_id = 4530;
update public.product_attributes set attr_value = 'Blue / Purple / Pink' where product_id = 4530 and attr_key = 'colour';
update public.products p set description = replace(p.description, a.attr_value || '.', 'Black / White.')
  from public.product_attributes a
 where a.product_id = p.product_id and a.attr_key = 'colour' and p.product_id = 4537;
update public.product_attributes set attr_value = 'Black / White' where product_id = 4537 and attr_key = 'colour';
update public.products p set description = replace(p.description, a.attr_value || '.', 'Black / White.')
  from public.product_attributes a
 where a.product_id = p.product_id and a.attr_key = 'colour' and p.product_id = 4539;
update public.product_attributes set attr_value = 'Black / White' where product_id = 4539 and attr_key = 'colour';

-- The two keyboards whose choice is the switch: the switch line now says so.
update public.product_attributes set attr_value = 'Red / Brown' where product_id = 4404 and attr_key = 'switch';
update public.products set description = replace(description, 'Switch: Red + Brown.', 'Switch: Red / Brown.') where product_id = 4404;
update public.product_attributes set attr_value = 'Green / Yellow' where product_id = 4408 and attr_key = 'switch';
update public.products set description = replace(description, 'Switch: Green + Yellow.', 'Switch: Green / Yellow.') where product_id = 4408;
