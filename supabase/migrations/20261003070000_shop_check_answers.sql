-- Answers from the user's in-shop check on Sat 3 Oct 2026
-- (Today_Claude_Parts_A_to_I_and_Desktop_Cases.docx): confirmed model names,
-- colours and links. Photos for the changed models come in a separate migration.

-- Part A: monitors
UPDATE products p SET name = v.name, official_url = COALESCE(v.url, p.official_url)
FROM (VALUES
  (1211, 'Acer Nitro XV270 M3 27" FHD 180Hz (Black)',               NULL),
  (1214, 'MSI MAG 32C6X 31.5" FHD 250Hz (Black)',                   'https://my.msi.com/Monitor/MAG-32C6X'),
  (1220, 'MSI MAG 272QPW QD-OLED X28 26.5" 2K 280Hz (White)',       'https://my.msi.com/Monitor/MAG-272QPW-QD-OLED-X28'),
  (1216, 'MSI Modern MD342CQP 34" UWQHD 120Hz (Black)',             'https://my.msi.com/Business-Productivity-Monitor/Modern-MD342CQP'),
  (1202, 'Asus VY249HGR 23.8" FHD 120Hz (Black)',                   'https://www.asus.com/my/displays-desktops/monitors/eye-care/vy249hgr/'),
  (1203, 'MSI PRO MP251 E14A 24.5" FHD 120Hz (Black)',              'https://my.msi.com/Business-Productivity-Monitor/PRO-MP251-E14A'),
  (1204, 'MSI PRO MP251W E14A 24.5" FHD 144Hz (White)',             'https://my.msi.com/Business-Productivity-Monitor/PRO-MP251W-E14A'),
  (1206, 'MSI PRO MP273 E14A 27" FHD 144Hz (Black)',                'https://my.msi.com/Business-Productivity-Monitor/PRO-MP273-E14A'),
  (1207, 'MSI PRO MP273W E14A 27" FHD 144Hz (White)',               'https://my.msi.com/Business-Productivity-Monitor/PRO-MP273W-E14A'),
  (1210, 'Acer Nitro ED270R S3 27" FHD 180Hz (Black)',              'https://www.displayspecifications.com/en/model/76553c11'),
  (1212, 'MSI MAG 274QF X24 27" 2K 240Hz (Black)',                  'https://my.msi.com/Monitor/MAG-274QF-X24'),
  (1218, 'Asus ROG Strix XG27ACS-W 27" 2K 180Hz (White)',           'https://rog.asus.com/my/monitors/27-to-31-5-inches/rog-strix-xg27acs-w/'),
  (1221, 'MSI PRO MP225 E12VL 21.45" FHD 100Hz (Black)',            'https://my.msi.com/Business-Productivity-Monitor/PRO-MP225-E12VL'),
  (1205, 'Lenovo Legion 24-10 24" FHD 240Hz (Black)',               'https://support.lenovo.com/my/en/solutions/pd500817-lenovo-legion-24-10-overview')
) AS v(id, name, url)
WHERE p.product_id = v.id;

UPDATE products SET description = replace(description, '25" FHD', '24.5" FHD') WHERE product_id IN (1203, 1204);
UPDATE products SET description = replace(description, '24" FHD', '23.8" FHD') WHERE product_id = 1202;
UPDATE products SET description = replace(description, '32" FHD', '31.5" FHD') WHERE product_id = 1214;
UPDATE products SET description = replace(description, '27" 2K, 280Hz, OLED panel', '26.5" 2K, 280Hz, QD-OLED panel') WHERE product_id = 1220;
UPDATE products SET description = '21.45" FHD 1920x1080 monitor at 100Hz, Black.' WHERE product_id = 1221;
UPDATE products SET description = replace(description, 'Black, LTPS stand', 'Raven Black, LTPS stand') WHERE product_id = 1205;

-- Part B: laptops and desktops
-- 229: the HP MY page for 14-fp0000 lists a different CPU, so the link goes; the shop's spec stands.
UPDATE products SET name = 'HP OmniBook 5 Flip 2-in-1 14-fp0027TU Core 5 120U 16GB (Sky Blue)',
  official_url = NULL,
  description = '14" IPS WUXGA 1920x1200 touchscreen, 300nits, 62.5% sRGB. Core 5 120U (10C/12T, up to 5.0GHz, 12MB cache), Intel Iris Xe graphics, 16GB LPDDR5 5200 on-board, 512GB M.2 NVMe. Wi-Fi 6, Bluetooth 5.4. HP Stylus included. Windows 11 Home, MS Office Home Edition, 2 years HP on-site warranty. PWP Kaspersky Standard at RM59. RM100 cash rebate.'
WHERE product_id = 229;

UPDATE products SET name = 'Lenovo Legion 5 15AHP11 Ryzen 7 250 RTX 5070 OLED',
  description = replace(replace(description, '15.3" WQXGA OLED 165Hz gaming laptop.', '15.3" WQXGA OLED 165Hz gaming laptop, Eclipse Black (83Q7007LMJ).'), 'from the 15IRX11', 'from the LOQ Essential 15IRX11')
WHERE product_id = 242;

UPDATE products SET name = 'Lenovo LOQ Essential 15IRX11 i5-13450HX RTX 5050',
  official_url = 'https://www.lenovo.com/my/en/p/laptops/loq-laptops/lenovo-loq-essential-15irx11/len101q0014',
  description = replace(replace(description, '15.6" FHD IPS 144Hz gaming laptop.', '15.6" FHD IPS 144Hz gaming laptop, 300 nits, 100% sRGB, Luna Grey (83SC004UMJ).'), 'from the 15AHP11', 'from the Legion 5 15AHP11')
WHERE product_id = 240;

UPDATE products SET name = 'Lenovo IdeaCentre Tower 08IRH9 i5-13420H (Cloud Grey)',
  official_url = 'https://pcsupport.lenovo.com/my/en/products/desktops-and-all-in-ones/tower-series-ideacentre/ideacentre-tower-08irh9/90xw/90xw00abmi',
  description = replace(description, 'Tower desktop.', 'Tower desktop, Cloud Grey (90XW00ABMI).')
WHERE product_id = 5003;

UPDATE products SET name = 'Lenovo IdeaCentre Tower 08IRR9 i5-14400 (Grey / Sunglow Orange)',
  description = replace(description, 'Tower desktop.', 'Tower desktop, Grey with Sunglow Orange front bezel (90XS0064MI).')
WHERE product_id = 5004;

-- Part C: parts
UPDATE products SET name = 'Deepcool AK400 Digital Pro WH (White)',
  official_url = 'https://www.deepcool.com/products/Cooling/cpuaircoolers/AK400-Digital-Pro-WH-Cooler-With-Multi-line-Display-1851-1700-AM5/2024/19628.shtml'
WHERE product_id = 4023;

UPDATE products p SET name = v.name, official_url = v.url, description = v.d
FROM (VALUES
  (1520, 'Jonsbo D31 MESH SCREEN (Black)', 'https://www.jonsbo.com/en/products/D31meshfupingbanBlack.html', 'mATX case, mesh front with built-in side screen, Black, no fans included.'),
  (1522, 'Jonsbo D31 MESH SCREEN (White)', 'https://www.jonsbo.com/en/products/D31meshfupingbanWhite.html', 'mATX case, mesh front with built-in side screen, White, no fans included.')
) AS v(id, name, url, d)
WHERE p.product_id = v.id;

UPDATE products SET name = 'UGREEN UG-M511 Wireless Mouse',
  official_url = 'https://www.mlink.com.my/ugreen-ergonomic-shape-design-wireless-mouse-2-4-ghz-with-6-button',
  description = 'Mouse. Black. Connection: 2.4GHz wireless USB receiver. Buttons: 6. Power: 1 x AA battery.'
WHERE product_id = 4516;

UPDATE products SET description = 'Mouse. Grey. Connection: 2.4GHz wireless USB dongle. Power: 1 x AA battery.' WHERE product_id = 4517;

-- Part D: keyboards
UPDATE products SET name = 'HP GK400Y Mechanical Gaming Keyboard',
  official_url = 'https://myitworld.com/p/hp-gk400y-mechanical-gaming-keyboard',
  description = 'Keyboard. Full-size. Black. RGB backlight. Switch: Blue. Connection: USB wired.'
WHERE product_id = 4406;

UPDATE products SET name = 'Darmoshark TOP98 (Purple Gradient)',
  description = 'Keyboard. Purple Gradient colourway, Erhat series badge. Connection: BT + 2.4G Dongle + Wired.'
WHERE product_id = 4444;

UPDATE products SET name = 'MOFii Sweet Mixed Wireless Keyboard & Mouse Combo',
  official_url = 'https://www.gadgetzone.com.my/product/mofii-sweet-mixed-black-24ghz-wireless-keyboard-mouse-combo',
  description = 'Keyboard + Mouse Combo. Mixed Green / Mixed Purple / Mixed Pink. Connection: 2.4GHz wireless USB receiver.'
WHERE product_id = 4430;

UPDATE products SET name = 'AULA S100',
  description = 'Keyboard. Black (Light Grey + Black + Grey keycaps). Switch: Blue. Connection: USB wired.'
WHERE product_id = 4409;

UPDATE products SET name = 'AULA S100 Pro',
  official_url = 'https://www.aulastar.com/mechanical-keyboard/399.html',
  description = 'Keyboard. 99 keys (95%). Black Orange. Switch: Red. Connection: Tri-mode (USB wired + 2.4GHz + Bluetooth).'
WHERE product_id = 4421;

UPDATE products SET name = 'Fantech GO MOCHI101 WK899 Wireless Keyboard & Mouse Combo',
  description = 'Keyboard + Mouse Combo. Blue / Yellow. Connection: Bluetooth 3.0 + Bluetooth 5.0 + 2.4GHz wireless.'
WHERE product_id = 4424;

-- Part E: headsets, earbuds, speakers
UPDATE products p SET name = v.name, official_url = v.url, description = v.d
FROM (VALUES
  (4709, 'Wesdar K-288H Wireless Bluetooth Headphones', NULL, 'Headset. Black / Purple / Orange / Blue / Green. Connection: Bluetooth. Charging: USB-C.'),
  (4710, 'Wesdar K-285H Wireless Bluetooth Headphones', NULL, 'Headset. Black / Grey. Connection: Bluetooth. Charging: USB-C.'),
  (4712, 'KT-Link Wired Over-Ear Stereo Headset', NULL, 'Headset with microphone. Black / White. Connection: 3.5mm wired.'),
  (4713, 'Fantech GO VIBE WH05', 'https://fantechmalaysia.com.my/headphones/fantech-go-vibe-wh05-wireless-headphone', 'Headset. Black. Connection: Bluetooth + 3.5mm wired dual mode. Charging: USB-C.'),
  (4715, 'Fantech HQ53 Flash Lightweight Wired Gaming Headset', 'https://fantechmalaysia.com.my/fantech-hq53-flash-lightweight-wired-gaming-headset', 'Headset. Black. Connection: Dual 3.5mm, plus USB-A for the LED.'),
  (4718, 'Fantech MH86 VALOR Multi-Platform Gaming Headset', 'https://fantechmalaysia.com.my/headphones/fantech-green-mh86-valor-multi-platform-gaming-headset-me-series', 'Headset. Black. Connection: 3.5mm wired.'),
  (4758, 'Monster N-Tune 60 Wired In-Ear Earphones', NULL, 'Earphones. Black. Connection: 3.5mm wired.'),
  (4853, 'Vinnfier Tango Neo 1 Portable Speaker', 'https://brightstarcomp.com/products/vinnfier-tango-neo-1-portable-speaker', 'Speaker. Blue / Red. Connection: Bluetooth. Plays from Bluetooth, USB, microSD and FM radio.'),
  (4857, 'WESDAR K-968S Portable Wireless Speaker', 'https://wesdar.com.cn/products/wesdar-3-inch-horn-60w-wireless-bt-50-rgb-portable-outdoor-speaker', 'Speaker. Black / Blue. 60W. Connection: Bluetooth. Battery: 4000mAh, USB-C charging.')
) AS v(id, name, url, d)
WHERE p.product_id = v.id;

-- Part F: printers and paper
UPDATE products SET name = 'Canon imageCLASS LBP6030w',
  description = 'Mono laser. Print only. USB 2.0 and Wi-Fi. Ink/toner: Canon Cartridge 325.'
WHERE product_id = 1013;

UPDATE products SET name = 'Canon Standard Paper 80gsm A4 (500 sheets)',
  official_url = 'https://my.canon/en/pro-imaging/products/search?consumableType=PAPER&category=printing&subCategory=consumables'
WHERE product_id = 1101;

-- Part G: fans and accessories
UPDATE products SET name = replace(name, 'ASQ Vortex ', 'ASQ Vortex S '),
  official_url = 'https://slev.my/products/fans/slevflow-asq-vortex-s-pwm-argb-120mm-fan/'
WHERE product_id BETWEEN 4201 AND 4204;

UPDATE products SET name = 'Slev SLEV.30 Premium Sleeved Extension Cable',
  official_url = 'https://slev.my/products/extensioncables/slev-30/',
  description = 'PSU extension kit. Black/Grey, Black/White, Black/Red, Black/Orange.'
WHERE product_id = 4304;

UPDATE products SET name = 'Thermaltake TtMod Sleeved Extension Cable (Rainbow)', description = 'PSU sleeve cable. Rainbow.' WHERE product_id = 4305;

UPDATE products SET name = 'Cooler Master 12VHPWR 90 Degree Adapter (Type 1)' WHERE product_id = 4308;

UPDATE products SET name = 'Tecware Orbis RGB LED Strip (TWAC-ORBLED)',
  description = 'LED strip, 400mm, 20 LEDs, DC 5V. Connector: 3-pin 5V ARGB. IMPORTANT: 3-pin 5V ARGB and 4-pin 12V RGB are NOT interchangeable - plugging this into a 12V RGB header will destroy it.'
WHERE product_id = 4310;

-- The LN70 runs off HYTE's Nexus Link (USB-C), not a motherboard ARGB header.
UPDATE products SET name = 'HYTE Noodle LN70-W LED Strip (White)',
  description = 'LED strip, White. Connector: HYTE Nexus Link (USB-C) - needs a HYTE Nexus controller, it does not plug into a 3-pin 5V ARGB header.'
WHERE product_id = 4317;

UPDATE products SET name = 'Slev SLEV.30 ARGB Flexible Light Board V2 Set',
  description = 'Light board set with hub and remote control. Black / White. Connector: 3-pin 5V ARGB. IMPORTANT: 3-pin 5V ARGB and 4-pin 12V RGB are NOT interchangeable - plugging this into a 12V RGB header will destroy it.'
WHERE product_id = 4318;

-- Part H: mouse pads
UPDATE products p SET name = v.name, description = v.d
FROM (VALUES
  (4616, 'Fantech MP905 ATO Deskmat (Kujira Nami)', 'Desk mat. Size: 900 x 400 x 4 mm. Kujira Nami design (Japanese wave + koi).'),
  (4617, 'Fantech MP905 ATO Deskmat (Kujira Umi)',  'Desk mat. Size: 900 x 400 x 4 mm. Kujira Umi design (black + blue Japanese).'),
  (4606, 'ASUS ROG Gaming Mouse Pad',              'Mouse pad. Size: Small / Standard. ROG mecha design; Black.'),
  (4608, 'Cooler Master Gaming Mouse Pad',         'Mouse pad. Size: Small / Standard. Black with blue/purple accent; hard plastic top; non-slip base.'),
  (4609, 'MSI Gaming Mouse Pad',                   'Mouse pad. Size: Small / Standard. MSI TRUE GAMING mecha artwork.')
) AS v(id, name, d)
WHERE p.product_id = v.id;

-- Desktop cases
UPDATE products SET name = 'Tecware Timber M (Black Wood / White Wood)', description = 'mATX case, Black Wood / White Wood, 4 fans included.' WHERE product_id = 1506;
UPDATE products SET name = 'Tecware VX Prism M (Black)' WHERE product_id = 1513;
UPDATE products SET name = 'ZOTAC GAMING ALLOY mATX (Black/Gold, White/Silver)' WHERE product_id = 1510;
