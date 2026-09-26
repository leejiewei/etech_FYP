-- ============================================================
-- Keyboards, mice and mouse pads: the shop's 26 Sep 2026 inventory.
--
-- 105 products from the owner's inventory record: 44 keyboards
-- (bundles and keyboard + mouse combos included, as the record lists
-- them), 40 mice (one mouse + pad combo included) and 21 mouse pads.
--
-- They sit in three new sub-categories under Gaming Gear, so the
-- site and app show them as "Gaming Gear > Keyboard" etc. with no
-- code change, and the advisor's Gaming Gear picks see them too.
-- The three matching demo products (401 keyboard, 402 mouse, 404 pad)
-- move into the new sub-categories; 403 the headset stays in Gaming
-- Gear itself. No coupon logic reads category_id, so GEAR20 is
-- unaffected.
--
-- No photos or official links yet, and stock_qty is left NULL as for
-- the rest of the catalogue. Logitech G512X (4416) has no connection
-- attribute: the record says "Check exact model".
-- ============================================================

insert into public.brands (brand_id, name) values
  (64, 'AULA'),
  (65, 'Cliptec'),
  (66, 'Wesdar'),
  (67, 'Fantech'),
  (68, 'MOFii'),
  (69, 'Kingses'),
  (70, 'Darmoshark'),
  (71, 'Rapoo'),
  (72, 'Handboss'),
  (73, 'Tecgear'),
  (74, 'Probex');

insert into public.categories (category_id, name, parent_id) values
  (40, 'Keyboard',  3),
  (41, 'Mouse',     3),
  (42, 'Mouse Pad', 3);

update public.products set category_id = 40 where product_id = 401;
update public.products set category_id = 41 where product_id = 402;
update public.products set category_id = 42 where product_id = 404;

insert into public.products (product_id, name, brand_id, category_id, price, description, icon, img_slug) values
  (4401, 'ROG Strix Scope II 96 Wireless', (select brand_id from public.brands where name = 'Asus ROG'), 40, 649.00, 'Keyboard. Black. Switch: NX Snow. Connection: BT + 2.4G Dongle + Wired.', '⌨️', 'keyboard'),
  (4402, 'ROG Strix Scope II X', (select brand_id from public.brands where name = 'Asus ROG'), 40, 499.00, 'Keyboard. Black. Switch: NX Storm V2. Connection: Wired USB.', '⌨️', 'keyboard'),
  (4403, 'Cooler Master SK622', (select brand_id from public.brands where name = 'Cooler Master'), 40, 199.00, 'Keyboard. Black. Switch: Blue. Connection: Bluetooth + Wired.', '⌨️', 'keyboard'),
  (4404, 'Logitech G512 Carbon', (select brand_id from public.brands where name = 'Logitech'), 40, 369.00, 'Keyboard. Black. Switch: Red + Brown. Connection: Wired USB.', '⌨️', 'keyboard'),
  (4405, 'Cooler Master CK530 V2 + Wrist Rest', (select brand_id from public.brands where name = 'Cooler Master'), 40, 219.00, 'Keyboard. Black. Switch: Brown. Connection: Wired USB.', '⌨️', 'keyboard'),
  (4406, 'HP Mechanical Gaming Keyboard', (select brand_id from public.brands where name = 'HP'), 40, 149.00, 'Keyboard. Black. Switch: Blue. Connection: Wired.', '⌨️', 'keyboard'),
  (4407, 'Razer Ornata V3 TKL Kuromi Edition', (select brand_id from public.brands where name = 'Razer'), 40, 329.00, 'Keyboard. Kuromi. Switch: Mecha-Membrane. Connection: Wired.', '⌨️', 'keyboard'),
  (4408, 'Razer BlackWidow V3 TKL', (select brand_id from public.brands where name = 'Razer'), 40, 299.00, 'Keyboard. Black. Switch: Green + Yellow. Connection: Wired.', '⌨️', 'keyboard'),
  (4409, 'AULA S100 3-in-1', (select brand_id from public.brands where name = 'AULA'), 40, 115.00, 'Keyboard. Black (Light Grey + Black + Grey keycaps). Switch: Blue. Connection: Wired.', '⌨️', 'keyboard'),
  (4410, 'Razer BlackWidow V4 X', (select brand_id from public.brands where name = 'Razer'), 40, 399.00, 'Keyboard. Black. Switch: Green. Connection: Wired.', '⌨️', 'keyboard'),
  (4411, 'Cliptec RGK850', (select brand_id from public.brands where name = 'Cliptec'), 40, 89.00, 'Keyboard. Beige (Retro Beige). Connection: Wired.', '⌨️', 'keyboard'),
  (4412, 'Cliptec RGK851', (select brand_id from public.brands where name = 'Cliptec'), 40, 89.00, 'Keyboard. Beige (Retro Beige). Connection: Wired.', '⌨️', 'keyboard'),
  (4413, 'Tecware Spectre 75 (Brown Switch)', (select brand_id from public.brands where name = 'Tecware'), 40, 339.00, 'Keyboard. Black + White. Switch: Brown. Connection: BT + 2.4G Dongle + Wired.', '⌨️', 'keyboard'),
  (4414, 'Razer Pikachu TKL', (select brand_id from public.brands where name = 'Razer'), 40, 419.00, 'Keyboard. Yellow (Pikachu Edition). Switch: Green. Connection: Wired.', '⌨️', 'keyboard'),
  (4415, 'MSI Forge TKL Wireless Frieren Edition', (select brand_id from public.brands where name = 'MSI'), 40, 399.00, 'Keyboard. White (Frieren Edition). Switch: Red. Connection: BT + 2.4G Dongle + Wired.', '⌨️', 'keyboard'),
  (4416, 'Logitech G512X', (select brand_id from public.brands where name = 'Logitech'), 40, 799.00, 'Keyboard. Black. Switch: Brown.', '⌨️', 'keyboard'),
  (4417, 'Tecware Spectre 75 (Red Switch)', (select brand_id from public.brands where name = 'Tecware'), 40, 339.00, 'Keyboard. Black + White. Switch: Red. Connection: BT + 2.4G Dongle + Wired.', '⌨️', 'keyboard'),
  (4418, 'Wesdar MK4 Cerberus', (select brand_id from public.brands where name = 'Wesdar'), 40, 53.00, 'Keyboard. Black. Connection: Wired.', '⌨️', 'keyboard'),
  (4419, 'Fantech MK894 Maxpower II', (select brand_id from public.brands where name = 'Fantech'), 40, 169.00, 'Keyboard. Black + White + Pink. Switch: Speed Grey. Connection: Wired.', '⌨️', 'keyboard'),
  (4420, 'Fantech P51 5-in-1 Power Bundle', (select brand_id from public.brands where name = 'Fantech'), 40, 169.00, '5-in-1 Bundle. Pink + Black + White. Connection: Bundle.', '⌨️', 'keyboard'),
  (4421, 'AULA S100 Pro 3-in-1', (select brand_id from public.brands where name = 'AULA'), 40, 159.00, '3-in-1 Bundle. Black. Switch: Red. Connection: Bundle.', '⌨️', 'keyboard'),
  (4422, 'AULA S2022 Pro', (select brand_id from public.brands where name = 'AULA'), 40, 89.00, 'Keyboard. Black. Switch: Blue. Connection: Wired.', '⌨️', 'keyboard'),
  (4423, 'Cliptec RGK932 Attack', (select brand_id from public.brands where name = 'Cliptec'), 40, 99.00, 'Keyboard. White + Blue / White + Orange. Switch: Red. Connection: Wired.', '⌨️', 'keyboard'),
  (4424, 'Fantech Go Mochi 101 Keyboard + Mouse Combo', (select brand_id from public.brands where name = 'Fantech'), 40, 89.00, 'Keyboard + Mouse Combo. Blue + Yellow. Connection: Wireless.', '⌨️', 'keyboard'),
  (4425, 'Cliptec RZK251', (select brand_id from public.brands where name = 'Cliptec'), 40, 22.00, 'Keyboard. Black. Connection: Wired.', '⌨️', 'keyboard'),
  (4426, 'Logitech K120', (select brand_id from public.brands where name = 'Logitech'), 40, 36.00, 'Keyboard. Black. Connection: Wired USB.', '⌨️', 'keyboard'),
  (4427, 'Logitech MK120', (select brand_id from public.brands where name = 'Logitech'), 40, 68.00, 'Keyboard + Mouse Combo. Black. Connection: Wired USB.', '⌨️', 'keyboard'),
  (4428, 'Logitech MK270R', (select brand_id from public.brands where name = 'Logitech'), 40, 108.00, 'Keyboard + Mouse Combo. Black. Connection: 2.4G USB Dongle.', '⌨️', 'keyboard'),
  (4429, 'Logitech Comfort MK345', (select brand_id from public.brands where name = 'Logitech'), 40, 145.00, 'Keyboard + Mouse Combo. Black. Connection: 2.4G USB Dongle.', '⌨️', 'keyboard'),
  (4430, 'MOFii Sweet DM', (select brand_id from public.brands where name = 'MOFii'), 40, 128.00, 'Keyboard + Mouse Combo. Pink + Purple + Green. Connection: Wireless.', '⌨️', 'keyboard'),
  (4431, 'Fantech GoPop Keyboard + Mouse Combo', (select brand_id from public.brands where name = 'Fantech'), 40, 79.00, 'Keyboard + Mouse Combo. Grey + Beach. Connection: Wireless.', '⌨️', 'keyboard'),
  (4432, 'UGREEN KU005 Ultra Slim', (select brand_id from public.brands where name = 'Ugreen'), 40, 119.00, 'Keyboard. Silver + Black. Connection: Wireless.', '⌨️', 'keyboard'),
  (4433, 'Logitech Pebble 2 Combo', (select brand_id from public.brands where name = 'Logitech'), 40, 259.00, 'Keyboard + Mouse Combo. Blue + White. Connection: Bluetooth / Logi Bolt.', '⌨️', 'keyboard'),
  (4434, 'ASUS Marshmallow KW100', (select brand_id from public.brands where name = 'Asus'), 40, 239.00, 'Keyboard. Green (Green Tea Latte). Connection: Bluetooth.', '⌨️', 'keyboard'),
  (4435, 'Logitech K400 Plus', (select brand_id from public.brands where name = 'Logitech'), 40, 165.00, 'Keyboard with Touchpad. Black. Connection: 2.4G USB Dongle.', '⌨️', 'keyboard'),
  (4436, 'Kingses KTL-KB33 Mini Keyboard', (select brand_id from public.brands where name = 'Kingses'), 40, 32.00, 'Mini Keyboard. Black. Connection: Wired.', '⌨️', 'keyboard'),
  (4437, 'Cliptec RZK530', (select brand_id from public.brands where name = 'Cliptec'), 40, 55.00, 'Keyboard. Grey. Connection: Wireless.', '⌨️', 'keyboard'),
  (4438, 'Logitech MK240 Nano', (select brand_id from public.brands where name = 'Logitech'), 40, 93.00, 'Keyboard + Mouse Combo. Black + Yellow. Connection: 2.4G USB Dongle.', '⌨️', 'keyboard'),
  (4439, 'Tecware Spectre 96 (Brown Switch)', (select brand_id from public.brands where name = 'Tecware'), 40, 359.00, 'Keyboard. Black + White. Switch: Brown. Connection: BT + 2.4G Dongle + Wired.', '⌨️', 'keyboard'),
  (4440, 'Tecware Spectre 96 (Red Switch)', (select brand_id from public.brands where name = 'Tecware'), 40, 359.00, 'Keyboard. Black + White. Switch: Red. Connection: BT + 2.4G Dongle + Wired.', '⌨️', 'keyboard'),
  (4441, 'Tecware Phantom S', (select brand_id from public.brands where name = 'Tecware'), 40, 219.00, 'Keyboard. Black. Switch: Red. Connection: BT + 2.4G Dongle + Wired.', '⌨️', 'keyboard'),
  (4442, 'DarkFlash GD87', (select brand_id from public.brands where name = 'Darkflash'), 40, 169.00, 'Keyboard. Blue. Switch: Yellow. Connection: 2.4G Dongle + Wired.', '⌨️', 'keyboard'),
  (4443, 'Darmoshark TOP75', (select brand_id from public.brands where name = 'Darmoshark'), 40, 369.00, 'Keyboard. White. Connection: BT + 2.4G Dongle + Wired.', '⌨️', 'keyboard'),
  (4444, 'Darmoshark TOP98', (select brand_id from public.brands where name = 'Darmoshark'), 40, 299.00, 'Keyboard. Purple (Purple Gradient). Connection: BT + 2.4G Dongle + Wired.', '⌨️', 'keyboard'),
  (4501, 'Logitech B100', (select brand_id from public.brands where name = 'Logitech'), 41, 22.00, 'Mouse. Black. Connection: Wired USB. Power: Wired - No Battery.', '🖱️', 'mouse'),
  (4502, 'Logitech B175', (select brand_id from public.brands where name = 'Logitech'), 41, 38.00, 'Mouse. Black. Connection: 2.4G USB Dongle. Power: 1 x AA Battery.', '🖱️', 'mouse'),
  (4503, 'Logitech M171', (select brand_id from public.brands where name = 'Logitech'), 41, 45.00, 'Mouse. Blue. Connection: 2.4G USB Dongle. Power: 1 x AA Battery.', '🖱️', 'mouse'),
  (4504, 'Fantech Venom II WGC2', (select brand_id from public.brands where name = 'Fantech'), 41, 78.00, 'Mouse. Beige / Green / Purple / Yellow / Blue. Connection: 2.4G USB Dongle. Power: Rechargeable 300mAh.', '🖱️', 'mouse'),
  (4505, 'Fantech Kanata S Wireless', (select brand_id from public.brands where name = 'Fantech'), 41, 109.00, 'Mouse. Red + Yellow. Connection: Wireless. Power: Rechargeable 300mAh Li-ion.', '🖱️', 'mouse'),
  (4506, 'Fantech Crypto II Wireless', (select brand_id from public.brands where name = 'Fantech'), 41, 79.00, 'Mouse. White. Connection: Wireless. Power: Rechargeable 600mAh Li-ion / USB-C.', '🖱️', 'mouse'),
  (4507, 'Razer DeathAdder V2 X HyperSpeed', (select brand_id from public.brands where name = 'Razer'), 41, 179.00, 'Mouse. Black. Connection: 2.4G HyperSpeed + Bluetooth. Power: 1 x AA or 1 x AAA Battery.', '🖱️', 'mouse'),
  (4508, 'Razer Basilisk V3', (select brand_id from public.brands where name = 'Razer'), 41, 209.00, 'Mouse. Black. Connection: Wired. Power: Wired - No Battery.', '🖱️', 'mouse'),
  (4509, 'Razer Basilisk V3 X HyperSpeed', (select brand_id from public.brands where name = 'Razer'), 41, 230.00, 'Mouse. Black. Connection: 2.4G HyperSpeed + Bluetooth. Power: 1 x AA Battery.', '🖱️', 'mouse'),
  (4510, 'Razer Cobra', (select brand_id from public.brands where name = 'Razer'), 41, 159.00, 'Mouse. Black. Connection: Wired. Power: Wired - No Battery.', '🖱️', 'mouse'),
  (4511, 'Razer DeathAdder V3 HyperSpeed', (select brand_id from public.brands where name = 'Razer'), 41, 359.00, 'Mouse. Black. Connection: 2.4G HyperSpeed + Wired USB-C. Power: Rechargeable / USB-C.', '🖱️', 'mouse'),
  (4512, 'ROG Keris II Origin KJP', (select brand_id from public.brands where name = 'Asus ROG'), 41, 739.00, 'Mouse. White (KJP Edition). Connection: Wireless. Power: Rechargeable.', '🖱️', 'mouse'),
  (4513, 'Logitech M187', (select brand_id from public.brands where name = 'Logitech'), 41, 47.00, 'Mouse. Blue. Connection: 2.4G USB Dongle. Power: 1 x AAA Battery.', '🖱️', 'mouse'),
  (4514, 'Logitech M331 Silent', (select brand_id from public.brands where name = 'Logitech'), 41, 68.00, 'Mouse. Black + Blue. Connection: 2.4G USB Dongle. Power: 1 x AA Battery.', '🖱️', 'mouse'),
  (4515, 'Logitech M240 Silent', (select brand_id from public.brands where name = 'Logitech'), 41, 66.00, 'Mouse. Black + Pink + White. Connection: Bluetooth. Power: 1 x AA Battery.', '🖱️', 'mouse'),
  (4516, 'UGREEN Ergonomic Wireless Mouse', (select brand_id from public.brands where name = 'Ugreen'), 41, 38.00, 'Mouse. Black. Connection: Wireless. Power: 2 x AAA Batteries.', '🖱️', 'mouse'),
  (4517, 'Cliptec RZS880 Office Gaming Mouse', (select brand_id from public.brands where name = 'Cliptec'), 41, 35.00, 'Mouse. Grey. Connection: Wired. Power: Wired - No Battery.', '🖱️', 'mouse'),
  (4518, 'Cliptec RZS621', (select brand_id from public.brands where name = 'Cliptec'), 41, 43.00, 'Mouse. Black + Grey. Connection: 2.4G USB Dongle. Power: Rechargeable 500mAh Li-ion / USB-C.', '🖱️', 'mouse'),
  (4519, 'ROG Keris Wired', (select brand_id from public.brands where name = 'Asus ROG'), 41, 149.00, 'Mouse. Black. Connection: Wired. Power: Wired - No Battery.', '🖱️', 'mouse'),
  (4520, 'ASUS TUF Gaming M3 Gen II', (select brand_id from public.brands where name = 'Asus TUF'), 41, 89.00, 'Mouse. Black. Connection: Wired. Power: Wired - No Battery.', '🖱️', 'mouse'),
  (4521, 'ROG Strix Impact III Wireless', (select brand_id from public.brands where name = 'Asus ROG'), 41, 259.00, 'Mouse. Black. Connection: Wireless. Power: 1 x AA or 1 x AAA Battery.', '🖱️', 'mouse'),
  (4522, 'ROG Keris Wireless AimPoint', (select brand_id from public.brands where name = 'Asus ROG'), 41, 309.00, 'Mouse. Black + White. Connection: Wireless. Power: Rechargeable 370mAh.', '🖱️', 'mouse'),
  (4523, 'Fantech Kanata S Wired', (select brand_id from public.brands where name = 'Fantech'), 41, 55.00, 'Mouse. Pink + Black. Connection: Wired. Power: Wired - No Battery.', '🖱️', 'mouse'),
  (4524, 'Fantech Phantom II VX6', (select brand_id from public.brands where name = 'Fantech'), 41, 59.00, 'Mouse. Black + White. Connection: Wired. Power: Wired - No Battery.', '🖱️', 'mouse'),
  (4525, 'Rapoo N100C Type-C', (select brand_id from public.brands where name = 'Rapoo'), 41, 22.00, 'Mouse. Black. Connection: Wired USB Type-C. Power: Wired - No Battery.', '🖱️', 'mouse'),
  (4526, 'Rapoo M10 Plus', (select brand_id from public.brands where name = 'Rapoo'), 41, 29.00, 'Mouse. Black. Connection: 2.4G Wireless Dongle. Power: 1 x AA Battery.', '🖱️', 'mouse'),
  (4527, 'Rapoo EV250 Silent', (select brand_id from public.brands where name = 'Rapoo'), 41, 68.00, 'Mouse. Black. Connection: 2.4G USB Dongle. Power: 2 x AAA Batteries.', '🖱️', 'mouse'),
  (4528, 'Rapoo MT760 Mini', (select brand_id from public.brands where name = 'Rapoo'), 41, 169.00, 'Mouse. Black + White. Connection: Wireless. Power: Rechargeable 800mAh Li-Po / USB-C.', '🖱️', 'mouse'),
  (4529, 'Razer DeathAdder Essential + Goliathus Kuromi Edition', (select brand_id from public.brands where name = 'Razer'), 41, 259.00, 'Mouse + Mouse Pad Combo. Black (Kuromi Edition). Connection: Wired. Power: Wired - No Battery.', '🖱️', 'mouse'),
  (4530, 'Cliptec RZS871', (select brand_id from public.brands where name = 'Cliptec'), 41, 25.00, 'Mouse. Blue + Purple + Pink. Connection: Wireless. Power: 1 x AA Battery.', '🖱️', 'mouse'),
  (4531, 'Cliptec RZS878', (select brand_id from public.brands where name = 'Cliptec'), 41, 25.00, 'Mouse. Pink. Connection: Wireless. Power: 1 x AA Battery.', '🖱️', 'mouse'),
  (4532, 'Salpido SAL-BTM100', (select brand_id from public.brands where name = 'Salpido'), 41, 35.00, 'Mouse. Black. Connection: Wireless. Power: 2 x AAA Batteries.', '🖱️', 'mouse'),
  (4533, 'Cliptec RZS866J', (select brand_id from public.brands where name = 'Cliptec'), 41, 35.00, 'Mouse. Blue (J1 / J2 / J3 variants). Connection: Wireless. Power: 1 x AA Battery.', '🖱️', 'mouse'),
  (4534, 'Cliptec RZS866G G1', (select brand_id from public.brands where name = 'Cliptec'), 41, 35.00, 'Mouse. Orange (Graffiti Design). Connection: Wireless. Power: 1 x AA Battery.', '🖱️', 'mouse'),
  (4535, 'Logitech G102', (select brand_id from public.brands where name = 'Logitech'), 41, 95.00, 'Mouse. White. Connection: Wired. Power: Wired - No Battery.', '🖱️', 'mouse'),
  (4536, 'Logitech G304', (select brand_id from public.brands where name = 'Logitech'), 41, 159.00, 'Mouse. White. Connection: LIGHTSPEED Wireless. Power: 1 x AA Battery.', '🖱️', 'mouse'),
  (4537, 'Logitech G309', (select brand_id from public.brands where name = 'Logitech'), 41, 339.00, 'Mouse. Black + White. Connection: LIGHTSPEED Wireless + Bluetooth. Power: 1 x AA Battery.', '🖱️', 'mouse'),
  (4538, 'Logitech G502', (select brand_id from public.brands where name = 'Logitech'), 41, 189.00, 'Mouse. Black. Connection: Wired. Power: Wired - No Battery.', '🖱️', 'mouse'),
  (4539, 'Tecware EX1', (select brand_id from public.brands where name = 'Tecware'), 41, 179.00, 'Mouse. Black + White. Connection: Wireless. Power: Rechargeable 300mAh + Charging Dock.', '🖱️', 'mouse'),
  (4540, 'MSI Versa Wireless Frieren Edition', (select brand_id from public.brands where name = 'MSI'), 41, 279.00, 'Mouse. White (Frieren Edition). Connection: Wireless. Power: Rechargeable / USB-C.', '🖱️', 'mouse'),
  (4601, 'Handboss Microsoft Mouse Pad', (select brand_id from public.brands where name = 'Handboss'), 42, 16.00, 'Mouse pad. Size: Small / Standard. Black; Microsoft logo.', '🟫', 'mousepad'),
  (4602, 'MSI Agility GD20 Frieren Edition', (select brand_id from public.brands where name = 'MSI'), 42, 119.00, 'Mouse pad. Size: 320 x 220 x 3 mm. Frieren character artwork.', '🟫', 'mousepad'),
  (4603, 'Razer Gigantus V2 Medium', (select brand_id from public.brands where name = 'Razer'), 42, 59.00, 'Mouse pad. Size: 360 x 275 x 3 mm. Black + Green.', '🟫', 'mousepad'),
  (4604, 'ASUS TUF Gaming P1 Hatsune Miku Edition', (select brand_id from public.brands where name = 'Asus TUF'), 42, 89.00, 'Mouse pad. Size: 360 x 260 x 2 mm. Miku character.', '🟫', 'mousepad'),
  (4605, 'Tecgear Dual Deskmat', (select brand_id from public.brands where name = 'Tecgear'), 42, 49.00, 'Mouse pad. Size: 900 x 450 mm. Yellow + Blue / Yellow + Red.', '🟫', 'mousepad'),
  (4606, 'ASUS ROG Mouse Pad', (select brand_id from public.brands where name = 'Asus ROG'), 42, 22.00, 'Mouse pad. Size: Small / Standard. ROG Mecha / Robot design; Black.', '🟫', 'mousepad'),
  (4607, 'ROG Strix Edge Gaming Mouse Pad', (select brand_id from public.brands where name = 'Asus ROG'), 42, 59.00, 'Mouse pad. Size: Large / Vertical Gaming Pad. Black.', '🟫', 'mousepad'),
  (4608, 'Cooler Master Hard Surface Mouse Pad', (select brand_id from public.brands where name = 'Cooler Master'), 42, 15.00, 'Mouse pad. Size: Small / Standard. Black; hard plastic top; non-slip/sticky base.', '🟫', 'mousepad'),
  (4609, 'MSI Mouse Pad', (select brand_id from public.brands where name = 'MSI'), 42, 23.00, 'Mouse pad. Size: Small / Standard. MSI Gaming Artwork; Red + Blue/Purple.', '🟫', 'mousepad'),
  (4610, 'Razer Gigantus V2 3XL', (select brand_id from public.brands where name = 'Razer'), 42, 259.00, 'Mouse pad. Size: 1200 x 550 x 4 mm. Black + Green.', '🟫', 'mousepad'),
  (4611, 'Logitech Studio Series Mouse Pad', (select brand_id from public.brands where name = 'Logitech'), 42, 55.00, 'Mouse pad. Size: 230 x 200 x 2 mm. Blue.', '🟫', 'mousepad'),
  (4612, 'Razer Gigantus V2 Large', (select brand_id from public.brands where name = 'Razer'), 42, 79.00, 'Mouse pad. Size: 450 x 400 x 3 mm. Black + Green.', '🟫', 'mousepad'),
  (4613, 'Razer Gigantus V2 XXL', (select brand_id from public.brands where name = 'Razer'), 42, 169.00, 'Mouse pad. Size: 940 x 410 x 4 mm. Black + Green.', '🟫', 'mousepad'),
  (4614, 'Darmoshark PAD-3', (select brand_id from public.brands where name = 'Darmoshark'), 42, 29.00, 'Mouse pad. Size: Large / Extended Deskmat. White + Blue Graphic / Social Media Design.', '🟫', 'mousepad'),
  (4615, 'Fantech Happy Eid Mubarak Mouse Pad', (select brand_id from public.brands where name = 'Fantech'), 42, 19.00, 'Mouse pad. Size: Small / Standard. White; Eid Mubarak character design.', '🟫', 'mousepad'),
  (4616, 'Fantech MP905-KN', (select brand_id from public.brands where name = 'Fantech'), 42, 68.00, 'Mouse pad. Size: 900 x 400 x 4 mm. Japanese Wave + Koi Fish design.', '🟫', 'mousepad'),
  (4617, 'Fantech MP905-KU', (select brand_id from public.brands where name = 'Fantech'), 42, 68.00, 'Mouse pad. Size: 900 x 400 x 4 mm. Black + Blue Japanese design.', '🟫', 'mousepad'),
  (4618, 'Cooler Master MP511 XL 30th Anniversary Edition', (select brand_id from public.brands where name = 'Cooler Master'), 42, 129.00, 'Mouse pad. Size: 900 x 400 x 3 mm. Black; 30th Anniversary Edition.', '🟫', 'mousepad'),
  (4619, 'Corsair MM400', (select brand_id from public.brands where name = 'Corsair'), 42, 119.00, 'Mouse pad. Size: Small / Standard Hard Pad. Black.', '🟫', 'mousepad'),
  (4620, 'Probex Extended Mouse Pad', (select brand_id from public.brands where name = 'Probex'), 42, 29.00, 'Mouse pad. Size: Large / Extended Deskmat. Designs: Razer Chroma / Razer Green / Corsair / ROG.', '🟫', 'mousepad'),
  (4621, 'Probex Gel Wrist Support Mouse Pad', (select brand_id from public.brands where name = 'Probex'), 42, 18.00, 'Mouse pad. Size: Small / Standard. Black / Blue / Purple.', '🟫', 'mousepad');
