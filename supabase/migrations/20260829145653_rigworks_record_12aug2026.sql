-- RigWorks product record, 12 August 2026.
--
-- The version number in the filename matches the row this migration has
-- in the remote project's history. Renaming it would make Supabase treat
-- it as a new migration and try to apply it again.
--
-- Adds the five complete-system categories under a new "Desktops" parent,
-- the E-Tech house brand, and the entries from the record:
--   37 laptops, 4 branded towers, 4 AIO desktops, 5 prebuilt gaming PCs,
--   3 Office PC Series, 3 Custom Office CO1, 3 new components = 59 rows.
--
-- The record's header says "34 laptops", but its five laptop tables hold
-- 37 rows (14 Vivobook + 4 ASUS gaming + 6 HP + 7 IdeaPad + 6 LOQ). All 37
-- are loaded here; the header count is the thing that is wrong.
--
-- Product ids are typed in by hand, as everywhere else in this schema, so
-- images/<id> keeps matching. Blocks used:
--   206-242            Laptops (cat 2, after the 5 already there)
--   5001-5004          Branded Desktops
--   5101-5104          AIO Desktops
--   5201-5205          Prebuilt Gaming PCs
--   5301-5303          Office PC Series
--   5401-5403          Custom Office CO1
--   1221, 1530, 2130   next free id in Monitors, Case, Motherboard
--
-- stock_qty, cost_price and image_path stay NULL and every row goes in as
-- stock_status 'out', per the record's own "Outstanding" list.
--
-- exclude_from_builder is left at 0: the PC Builder picks by subcategory
-- name (builderSlots in web/js/products.js) and none of the new categories
-- is a builder slot.
--
-- Every statement is written to be safely re-runnable.

-- ------------------------------------------------------------
-- Brand
-- ------------------------------------------------------------
INSERT INTO brands (name) VALUES ('E-Tech') ON CONFLICT (name) DO NOTHING;

-- ------------------------------------------------------------
-- Categories
-- ------------------------------------------------------------
INSERT INTO categories (category_id, name, parent_id) VALUES
  (34, 'Desktops',            NULL),
  (35, 'Branded Desktops',    34),
  (36, 'AIO Desktops',        34),
  (37, 'Prebuilt Gaming PCs', 34),
  (38, 'Office PC Series',    34),
  (39, 'Custom Office CO1',   34)
ON CONFLICT (category_id) DO NOTHING;

-- Move the identity counters past the ids just typed in, the same way
-- 03_sequences.sql does after a bulk load.
SELECT setval(pg_get_serial_sequence('public.categories', 'category_id'),
              (SELECT MAX(category_id) FROM categories) + 1, false);
SELECT setval(pg_get_serial_sequence('public.brands', 'brand_id'),
              (SELECT MAX(brand_id) FROM brands) + 1, false);

-- ------------------------------------------------------------
-- Products
--
-- Brands join by name rather than a hard-coded id, so this does not depend
-- on which brand_id the E-Tech insert above happened to receive.
-- ------------------------------------------------------------
INSERT INTO products (product_id, name, brand_id, category_id, price, stock_status, description, icon, img_slug)
SELECT v.product_id, v.name, b.brand_id, v.category_id, v.price, 'out'::stock_status, v.description, v.icon, v.img_slug
FROM (VALUES
-- ASUS Vivobook, everyday / non-gaming (14)
(206,'ASUS Vivobook 15 A1504 Core 5 120U 8GB (Silver)','Asus',2,2899.00,'15.6" FHD 60Hz everyday laptop. Core 5 120U, 8GB DDR5, 512GB. 2 years global warranty plus 1 year accidental damage protection, MIL-STD-810H, ASUS backpack and MS Office bundle included. RM50 cash rebate.','💻','laptop'),
(207,'ASUS Vivobook 15 A1504 Core 5 120U 8GB (Terra Cotta)','Asus',2,2899.00,'15.6" FHD 60Hz everyday laptop. Core 5 120U, 8GB DDR5, 512GB. 2 years global warranty plus 1 year accidental damage protection, MIL-STD-810H, ASUS backpack and MS Office bundle included. RM50 cash rebate.','💻','laptop'),
(208,'ASUS Vivobook 15 A1504 Core 5 120U 8GB (Quiet Blue)','Asus',2,2899.00,'15.6" FHD 60Hz everyday laptop. Core 5 120U, 8GB DDR5, 512GB. 2 years global warranty plus 1 year accidental damage protection, MIL-STD-810H, ASUS backpack and MS Office bundle included. RM50 cash rebate.','💻','laptop'),
(209,'ASUS Vivobook 15 Go E1504F Ryzen 5 7520U 16GB (Black)','Asus',2,2999.00,'15.6" FHD everyday laptop. Ryzen 5 7520U, 16GB LPDDR5 on-board, 512GB. 2 years global warranty plus 1 year accidental damage protection, MIL-STD-810H, ASUS backpack and MS Office bundle included. RM50 cash rebate.','💻','laptop'),
(210,'ASUS Vivobook 16 M1605N Ryzen 5 150 16GB (Black)','Asus',2,3099.00,'16" WUXGA IPS 300nits. Ryzen 5 150 (6C/12T), 16GB DDR5 4800 (8GB soldered + 8GB SODIMM), 512GB. 2 years global warranty plus 1 year accidental damage protection, MIL-STD-810H, ASUS backpack and MS Office bundle included. RM50 cash rebate.','💻','laptop'),
(211,'ASUS Vivobook 14 A1405VAL i5-13420H 16GB (Black)','Asus',2,3199.00,'14" WUXGA 16:10. i5-13420H, 16GB DDR4 (8GB on-board + 8GB SODIMM), 512GB. 2 years global warranty plus 1 year accidental damage protection, MIL-STD-810H, ASUS backpack and MS Office bundle included. RM50 cash rebate.','💻','laptop'),
(212,'ASUS Vivobook 14 A1405VAL i5-13420H 16GB (Silver)','Asus',2,3199.00,'14" WUXGA 16:10. i5-13420H, 16GB DDR4 (8GB on-board + 8GB SODIMM), 512GB. 2 years global warranty plus 1 year accidental damage protection, MIL-STD-810H, ASUS backpack and MS Office bundle included. RM50 cash rebate.','💻','laptop'),
(213,'ASUS Vivobook 16 A1605V i5-13420H 16GB (Black)','Asus',2,3199.00,'16" FHD IPS 16:10. i5-13420H, 16GB, 512GB. 2 years global warranty plus 1 year accidental damage protection, MIL-STD-810H, ASUS backpack and MS Office bundle included. RM50 cash rebate.','💻','laptop'),
(214,'ASUS Vivobook 16 A1605V i5-13420H 16GB (Silver)','Asus',2,3199.00,'16" FHD IPS 16:10. i5-13420H, 16GB, 512GB. 2 years global warranty plus 1 year accidental damage protection, MIL-STD-810H, ASUS backpack and MS Office bundle included. RM50 cash rebate.','💻','laptop'),
(215,'ASUS Vivobook 15 A1504 Core 5 120U 16GB (Cool Silver)','Asus',2,3499.00,'15.6" FHD 60Hz. Core 5 120U, 16GB DDR5 (8GB on-board + 8GB SODIMM, upgradeable to 24GB), 512GB. 2 years global warranty plus 1 year accidental damage protection, MIL-STD-810H, ASUS backpack and MS Office bundle included. RM50 cash rebate.','💻','laptop'),
(216,'ASUS Vivobook 15 A1504 Core 5 120U 16GB (Blue)','Asus',2,3499.00,'15.6" FHD 60Hz. Core 5 120U, 16GB DDR5 (8GB on-board + 8GB SODIMM, upgradeable to 24GB), 512GB. 2 years global warranty plus 1 year accidental damage protection, MIL-STD-810H, ASUS backpack and MS Office bundle included. RM50 cash rebate.','💻','laptop'),
(217,'ASUS Vivobook S14 S3407 Core 5 210H 16GB (Grey)','Asus',2,3699.00,'14" 16:10 with a 70WHrs battery. Core 5 210H, 16GB DDR5, 1TB. 1.39kg, 1.59cm, up to 20 hours battery, durable metallic design. 2 years global warranty plus 1 year accidental damage protection, ASUS backpack and MS Office bundle included. RM100 cash rebate.','💻','laptop'),
(218,'ASUS Vivobook S14 S3407 Core Ultra 7 255H 16GB (Grey)','Asus',2,4699.00,'14" 16:10 with a 70WHrs battery and a 13 TOPS NPU. Core Ultra 7 255H, 16GB DDR5 on-board plus one SODIMM slot, 512GB. 1.39kg, 1.59cm, up to 20 hours battery, durable metallic design. 2 years global warranty plus 1 year accidental damage protection, ASUS backpack and MS Office bundle included. RM100 cash rebate.','💻','laptop'),
(219,'ASUS Vivobook S14 S3407 Core Ultra 7 255H 16GB (Silver)','Asus',2,4699.00,'14" 16:10 with a 70WHrs battery and a 13 TOPS NPU. Core Ultra 7 255H, 16GB DDR5 on-board plus one SODIMM slot, 512GB. 1.39kg, 1.59cm, up to 20 hours battery, durable metallic design. 2 years global warranty plus 1 year accidental damage protection, ASUS backpack and MS Office bundle included. RM100 cash rebate.','💻','laptop'),
-- ASUS gaming, TUF and ROG (4)
(220,'ASUS TUF Gaming A15 FA506N Ryzen 7 8845HS RTX 3050','Asus',2,3699.00,'15.6" FHD IPS 144Hz gaming laptop. Ryzen 7 8845HS (8C/16T), RTX 3050 4GB (60W), 8GB DDR5 5600 with one spare slot (max 64GB), 512GB with one spare slot. Add-ons: +RM499 for 8GB RAM, +RM849 for 16GB RAM, +RM799 for 1TB SSD.','💻','laptop'),
(221,'ASUS ROG Strix G16 i5-13450HX RTX 5050','Asus',2,5999.00,'16" FHD+ 165Hz G-Sync 300nits. i5-13450HX (55W TDP), RTX 5050 8GB (115W TGP), 16GB DDR5 SODIMM, 1TB. 170W total system power, tri-fan and vapour chamber, up to 15C cooler CPU temperatures. RM100 rebate, ROG backpack and 3 months of PC Game Pass included.','💻','laptop'),
(222,'ASUS TUF Gaming F16 FX608J i7-14650HX RTX 5060','Asus',2,6899.00,'16" FHD+ IPS 165Hz. i7-14650HX (16C/24T), RTX 5060 8GB GDDR7 (115W), 16GB DDR5 5600 across 2 slots, 1TB with one spare slot. Free ASUS TUF gaming backpack. Add-ons: +RM849 for 16GB RAM, +RM799 for 1TB SSD. A separate product from the FA608U F16, not a duplicate.','💻','laptop'),
(223,'ASUS TUF Gaming F16 FA608U Ryzen 7 260 RTX 5070','Asus',2,7499.00,'16" FHD+ IPS 165Hz. Ryzen 7 260 (8C/16T), RTX 5070 8GB GDDR7 (115W), 16GB DDR5 5600 across 2 slots, 512GB with one spare slot. Free ASUS TUF gaming backpack. Add-ons: +RM849 for 16GB RAM, +RM799 for 1TB SSD. A separate product from the FX608J F16, not a duplicate.','💻','laptop'),
-- HP (6)
(224,'HP Laptop 14 EM0302AU Ryzen 7 7730U 16GB (Gold)','HP',2,3199.00,'14" IPS FHD 300nits 45% NTSC. Ryzen 7 7730U (8C/16T), 16GB DDR4 3200 (2x8GB), 512GB. 2 years warranty with on-site service, MS Office Home Edition, PWP Kaspersky Standard at RM59. RM50 cash rebate.','💻','laptop'),
(225,'HP Laptop 14 EM0303AU Ryzen 7 7730U 16GB (Silver)','HP',2,3199.00,'14" IPS FHD 300nits 45% NTSC. Ryzen 7 7730U (8C/16T), 16GB DDR4 3200 (2x8GB), 512GB. 2 years warranty with on-site service, MS Office Home Edition, PWP Kaspersky Standard at RM59. RM50 cash rebate.','💻','laptop'),
(226,'HP Laptop 15 FD2117TU Core Ultra 5 225U 16GB (Silver)','HP',2,3499.00,'15.6" IPS FHD 300nits 62.5% sRGB. Core Ultra 5 225U (12C/14T), 16GB DDR5 5600, 512GB. 2 years warranty with on-site service, MS Office Home Edition, PWP Kaspersky Standard at RM59. RM100 cash rebate.','💻','laptop'),
(227,'HP Laptop 15 FD2116TU Core Ultra 5 225U 16GB (Blue)','HP',2,3499.00,'15.6" IPS FHD 300nits 62.5% sRGB. Core Ultra 5 225U (12C/14T), 16GB DDR5 5600, 512GB. 2 years warranty with on-site service, MS Office Home Edition, PWP Kaspersky Standard at RM59. RM100 cash rebate.','💻','laptop'),
(228,'HP OmniBook X Flip 14 FK0101AU Ryzen AI 5 340 16GB (Meteor Silver)','HP',2,4099.00,'14" IPS WUXGA touchscreen, 400nits, Gorilla Glass 3. A Copilot+ PC with Ryzen AI 5 340 (6C/12T, 50 NPU TOPs), 16GB LPDDR5x 7500 on-board, 512GB. Stylus included. 2 years warranty with on-site service, MS Office Home Edition, PWP Kaspersky Standard at RM59. RM100 cash rebate.','💻','laptop'),
(229,'HP OmniBook 5 14 FP0027TU Core 5 120U 16GB (Blue)','HP',2,4199.00,'14" IPS WUXGA touchscreen, 300nits. Core 5 120U (10C/12T), 16GB LPDDR5 5200 on-board, 512GB. Stylus included. 2 years warranty with on-site service, MS Office Home Edition, PWP Kaspersky Standard at RM59. RM100 cash rebate.','💻','laptop'),
-- Lenovo IdeaPad, everyday (7)
(230,'Lenovo IdeaPad Slim 3 15AMN8 Ryzen 3 30 8GB (Arctic Grey)','Lenovo',2,2499.00,'15.6" IPS FHD 300nits. Ryzen 3 30 (4C/8T), 8GB LPDDR5 5500 on-board, 512GB M.2 2242. 2 years warranty with on-site service, MS Office Home Edition, PWP Kaspersky Standard at RM59. RM100 cash rebate.','💻','laptop'),
(231,'Lenovo IdeaPad Slim 3 15AMN8 Ryzen 3 30 8GB (Abyss Blue)','Lenovo',2,2499.00,'15.6" IPS FHD 300nits. Ryzen 3 30 (4C/8T), 8GB LPDDR5 5500 on-board, 512GB M.2 2242. 2 years warranty with on-site service, MS Office Home Edition, PWP Kaspersky Standard at RM59. RM100 cash rebate.','💻','laptop'),
(232,'Lenovo IdeaPad Slim 3 15AMN8 Ryzen 5 7520U 16GB (Arctic Grey)','Lenovo',2,2999.00,'15.6" IPS FHD 300nits. Ryzen 5 7520U (4C/8T), 16GB LPDDR5 5500 on-board, 512GB M.2 2242. Arctic Grey only, there is no second colour variant of this SKU. 2 years warranty with on-site service, MS Office Home Edition, PWP Kaspersky Standard at RM59. RM50 cash rebate.','💻','laptop'),
(233,'Lenovo IdeaPad Slim 3 15ARP10 Ryzen 7 7735HS 16GB (Luna Grey)','Lenovo',2,3299.00,'15.3" IPS WUXGA 300nits. Ryzen 7 7735HS (8C/16T), 16GB DDR5 4800 (8GB soldered + 8GB SODIMM), 512GB with one spare slot. 2 years warranty with on-site service, MS Office Home Edition, PWP Kaspersky Standard at RM59. RM50 cash rebate.','💻','laptop'),
(234,'Lenovo IdeaPad Slim 3 15ARP10 Ryzen 7 7735HS 16GB (Cosmic Blue)','Lenovo',2,3299.00,'15.3" IPS WUXGA 300nits. Ryzen 7 7735HS (8C/16T), 16GB DDR5 4800 (8GB soldered + 8GB SODIMM), 512GB with one spare slot. 2 years warranty with on-site service, MS Office Home Edition, PWP Kaspersky Standard at RM59. RM50 cash rebate.','💻','laptop'),
(235,'Lenovo IdeaPad Slim 3i 15IRH10 i7-13620H 16GB (Cosmic Blue)','Lenovo',2,3699.00,'15.3" IPS WUXGA 300nits. i7-13620H (10C/16T), 16GB DDR5 4800 (8GB soldered + 8GB SODIMM), 512GB with one spare slot. Includes a free Lenovo WL310 Bluetooth silent mouse. 2 years warranty with on-site service, MS Office Home Edition, PWP Kaspersky Standard at RM59. RM100 cash rebate.','💻','laptop'),
(236,'Lenovo IdeaPad Slim 5A 14AGP11 Ryzen AI 7 445 32GB OLED (Luna Grey)','Lenovo',2,4599.00,'14" OLED WUXGA 400nits 100% DCI-P3. Ryzen AI 7 445 (6C/12T), 32GB DDR5 5600 (2x16GB), 512GB with one spare slot. 2 years warranty with on-site service, MS Office Home Edition, PWP Kaspersky Standard at RM59. RM100 cash rebate.','💻','laptop'),
-- Lenovo LOQ gaming (6)
(237,'Lenovo LOQ 15ARP10E Ryzen 7 7735HS RTX 3050','Lenovo',2,4099.00,'15.6" FHD 144Hz IPS 100% sRGB gaming laptop. Ryzen 7 7735HS (8C/16T), RTX 3050 6GB GDDR6 Refresh Edition, 16GB DDR5 4800 (1x16GB with an empty slot), 512GB PCIe 4.0. Windows 11 Home, MS Office Home Edition, 2 years on-site warranty. RM100 cash rebate.','💻','laptop'),
(238,'Lenovo LOQ 15ARP10E Ryzen 7 7735HS RTX 4050','Lenovo',2,4599.00,'15.6" FHD 144Hz IPS 100% sRGB gaming laptop. Ryzen 7 7735HS (8C/16T), RTX 4050 6GB GDDR6, 16GB DDR5 4800 (1x16GB with an empty slot), 512GB PCIe 4.0. Windows 11 Home, MS Office Home Edition, 2 years on-site warranty. RM100 cash rebate.','💻','laptop'),
(239,'Lenovo LOQ 15IRX9 i5-13450HX RTX 4050','Lenovo',2,4599.00,'15.6" FHD 144Hz IPS 100% sRGB gaming laptop. i5-13450HX (10C/16T), RTX 4050 6GB GDDR6, 16GB DDR5 4800 (1x16GB with an empty slot), 512GB PCIe 4.0. Windows 11 Home, MS Office Home Edition, 2 years Premium on-site warranty. RM100 cash rebate.','💻','laptop'),
(240,'Lenovo LOQ 15IRX11 i5-13450HX RTX 5050','Lenovo',2,4899.00,'15.6" FHD IPS 144Hz gaming laptop. i5-13450HX (10C/16T), RTX 5050 8GB GDDR7 (65W), 16GB DDR5 4800 (1x16GB with an empty slot), 512GB with one spare M.2 slot. Windows 11 Home, MS Office Home Edition, 2 years on-site warranty. RM100 cash rebate. Add-ons: +RM849 for 16GB RAM, +RM799 for 1TB SSD. A separate product from the 15AHP11, not a duplicate.','💻','laptop'),
(241,'Lenovo LOQ 15AHP10 Ryzen 7 250 AI RTX 5060','Lenovo',2,5799.00,'15.6" FHD 144Hz IPS 100% sRGB gaming laptop. Ryzen 7 250 AI (8C/16T), RTX 5060 8GB GDDR7, 16GB DDR5 5600 (1x16GB with an empty slot), 512GB PCIe 4.0. Windows 11 Home, MS Office Home Edition, 2 years Premium on-site warranty. RM100 cash rebate.','💻','laptop'),
(242,'Lenovo LOQ 15AHP11 Ryzen 7 250 RTX 5070 OLED','Lenovo',2,7899.00,'15.3" WQXGA OLED 165Hz gaming laptop. Ryzen 7 250 (8C/16T), RTX 5070 8GB GDDR7 (115W), 16GB DDR5 5600 (max 32GB), 512GB with one spare M.2 slot. Windows 11 Home, MS Office Home Edition, 2 years on-site warranty. RM100 cash rebate. Add-ons: +RM849 for 16GB RAM, +RM799 for 1TB SSD. A separate product from the 15IRX11, not a duplicate.','💻','laptop'),
-- Branded desktop towers (4)
(5001,'ASUS V500MV White Edition i5-13420H (White)','Asus',35,2899.00,'Compact tower. i5-13420H (8C/12T), 8GB SO-DIMM DDR5 with one empty slot, 512GB PCIe NVMe with one spare slot, Intel UHD graphics. WiFi 6, Bluetooth 5.4, USB-C 3.2 Gen 1, DisplayPort 1.4 and HDMI 1.4. Windows 11 Home, 3 years on-site warranty, pre-installed Microsoft Office Home, wireless keyboard and mouse included.','🖥️','prebuilt'),
(5002,'ASUS V500MV i5-13420H (Black)','Asus',35,2899.00,'Compact tower. i5-13420H (8C/12T), 8GB SO-DIMM DDR5 with one empty slot, 512GB PCIe NVMe with one spare slot, Intel UHD graphics. WiFi 6, Bluetooth 5.4, USB-C 3.2 Gen 1, DisplayPort 1.4 and HDMI 1.4. Windows 11 Home, 3 years on-site warranty, pre-installed Microsoft Office Home, wireless keyboard and mouse included.','🖥️','prebuilt'),
(5003,'Lenovo IdeaCentre Tower 08IRH9 i5-13420H (White)','Lenovo',35,2899.00,'Tower desktop. i5-13420H (8C/12T), 8GB DDR5 5200 SO-DIMM (1x8GB), 512GB PCIe NVMe with one spare slot, Intel UHD graphics. 2 RAM slots and a 3.5" HDD bay. Windows 11 Home, 3 years on-site warranty, pre-installed Microsoft Office Home, wired keyboard and mouse included.','🖥️','prebuilt'),
(5004,'Lenovo IdeaCentre Tower 08IRR9 i5-14400 (White)','Lenovo',35,3599.00,'Tower desktop. i5-14400 (10C/16T), 16GB DDR5 4800 (1x16GB), 1TB PCIe NVMe, Intel UHD 730 graphics. 2 RAM slots and a 3.5" HDD bay. Windows 11 Home, 3 years on-site warranty, pre-installed Microsoft Office Home, wired keyboard and mouse included.','🖥️','prebuilt'),
-- All-in-One desktops (4). Each pair differs only by RAM and the model
-- number is identical, so the capacity has to stay in the title.
(5101,'HP OmniStudio 24-CU0031D Core 5 120U 8GB','HP',36,3299.00,'23.8" FHD 1920x1080 all-in-one, non-touch. Core 5 120U (10C/12T), 8GB DDR5 5200 SODIMM with one spare slot, 512GB PCIe NVMe. Windows 11 Home Single Language, 3 years HP on-site warranty, wireless white keyboard and mouse, pre-installed Microsoft Office Home.','🖥️','monitor'),
(5102,'HP OmniStudio 24-CU0031D Core 5 120U 24GB','HP',36,3899.00,'23.8" FHD 1920x1080 all-in-one, non-touch. Core 5 120U (10C/12T), 24GB DDR5 5200 SODIMM, 512GB PCIe NVMe. Windows 11 Home Single Language, 3 years HP on-site warranty, wireless white keyboard and mouse, pre-installed Microsoft Office Home.','🖥️','monitor'),
(5103,'HP 27-CR0039D i5-1335U 8GB Touch','HP',36,4299.00,'27" FHD antiglare 250nits IPS touchscreen all-in-one. i5-1335U (10C/12T), 8GB DDR4, 1TB PCIe NVMe. Windows 11 Home Single Language, 3 years HP on-site warranty, wireless white keyboard and mouse, pre-installed Microsoft Office Home.','🖥️','monitor'),
(5104,'HP 27-CR0039D i5-1335U 24GB Touch','HP',36,4999.00,'27" FHD antiglare 250nits IPS touchscreen all-in-one. i5-1335U (10C/12T), 24GB DDR4, 1TB PCIe NVMe. Windows 11 Home Single Language, 3 years HP on-site warranty, wireless white keyboard and mouse, pre-installed Microsoft Office Home.','🖥️','monitor'),
-- E-Tech prebuilt gaming PCs (5)
(5201,'E-Tech ZenForge Ryzen 5 5500 RTX 3050','E-Tech',37,2999.00,'Ryzen 5 5500 (AM4) on an Asus Prime A520M-K CSM, RTX 3050 6GB Dual OC, 16GB DDR4, MSI Spatium M450 500GB Gen4, Slev Quantum 600W, stock cooler, Darkflash C275P Dual Chamber ARGB chassis in white. Upgrades: +RM499 to RTX 5050 8GB, +RM380 to 1TB Gen4 NVMe. 4 year premium warranty covering motherboard and VGA only, registration required.','🖥️','prebuilt'),
(5202,'E-Tech Cyber Strike Core Ultra 5 225 RTX 3050','E-Tech',37,3699.00,'Core Ultra 5 225 (LGA1851) on an Asus Prime H810M-A WiFi, RTX 3050 6GB Dual, Adata 16GB DDR5 5600 U-DIMM, Hiksemi Wave (P) 256GB, Slev Quantum 600W, stock cooler, Tecware Neo M3+ TG ARGB mATX with 3x120mm ARGB fans. Adata rather than Essencore memory: Essencore DDR5 is shop-confirmed incompatible with LGA1851. Upgrades: +RM359 to RTX 5050 8GB, +RM199 to 512GB M.2 NVMe, +RM799 to 32GB. 4 year premium warranty covering motherboard and VGA only, registration required.','🖥️','prebuilt'),
(5203,'E-Tech Ember Core Ryzen 5 7500F RTX 5050','E-Tech',37,4699.00,'Ryzen 5 7500F (AM5) on a B850M-AYW WiFi, RTX 5050 8GB Dual, Essencore 16GB DDR5 5600 UDIMM, Hiksemi Wave (P) 256GB, Asus Prime AP-750G, Asus Prime LC 360 ARGB AIO in white, Asus A31 ATX in black. Upgrades: +RM449 to RTX 5060 8GB, +RM199 to 512GB M.2 NVMe, +RM799 to 32GB, +RM99 for 4x Asus Prime MR120 ARGB fans. 4 year premium warranty covering motherboard and VGA only, registration required.','🖥️','prebuilt'),
(5204,'E-Tech Titan Aegis i7-14700F RTX 5050','E-Tech',37,5499.00,'i7-14700F (LGA1700) on an Asus Prime B760M-A WiFi D4, RTX 5050 8GB Dual, Hiksemi UDIMM 16GB DDR4 3200, Hiksemi Wave (P) 512GB, Asus Prime AP-750G, Asus Prime LC 360 ARGB AIO in white, Asus Prime AP202 mATX TG ARGB in white. Upgrades: +RM449 to RTX 5060 8GB, +RM299 to 1TB M.2 NVMe, +RM499 to 32GB, +RM99 for 4x Asus Prime MR120 ARGB fans. 4 year premium warranty covering motherboard and VGA only, registration required.','🖥️','prebuilt'),
(5205,'E-Tech Inferno Apex Ryzen 7 7800X3D RX 9060 XT','E-Tech',37,6699.00,'Ryzen 7 7800X3D (AM5) on a B850M-AYW WiFi, TUF RX 9060 XT 16GB OC, Essencore 16GB DDR5 5600 UDIMM, Hiksemi Wave (P) 512GB, Asus Prime AP-750G, Asus Prime LC 360 ARGB AIO in white, Asus A31 ATX in black. Upgrades: +RM299 to 1TB M.2 NVMe, +RM799 to 32GB, +RM249 to a TUF LC III 360 ARGB LCD AIO in black, +RM99 for 4x MR120 ARGB fans. 4 year premium warranty covering motherboard and VGA only, registration required.','🖥️','prebuilt'),
-- E-Tech Office PC Series (3)
(5301,'E-Tech Office PC Ryzen 3 3200G','E-Tech',38,1299.00,'Ryzen 3 3200G on an Asus Prime A520M-K, 8GB DDR4, 256GB SATA SSD, SE380 power supply bundled with the Slev Spotless mATX chassis. Upgrades: +RM79 to Ryzen 5 3400G, +RM199 to 512GB SSD, +RM299 to 16GB RAM. Bundled 24" FHD IPS 120Hz monitor available at RM349. PWP accessories: keyboard and mouse set RM70, gaming keyboard/mouse/headset/mousepad set RM150, 2.0 speakers RM25.','🖥️','prebuilt'),
(5302,'E-Tech Office PC Ryzen 5 5600GT','E-Tech',38,1599.00,'Ryzen 5 5600GT on an Asus Prime A520M-K, 8GB DDR4, 256GB SATA SSD, SE380 power supply bundled with the Slev Spotless mATX chassis. Upgrades: +RM199 to 512GB SSD, +RM299 to 16GB RAM. Bundled 24" FHD IPS 120Hz monitor available at RM349. PWP accessories: keyboard and mouse set RM70, gaming keyboard/mouse/headset/mousepad set RM150, 2.0 speakers RM25.','🖥️','prebuilt'),
(5303,'E-Tech Office PC Core i5-14400','E-Tech',38,2299.00,'Core i5-14400 on an MSI Pro H610M-E, 8GB DDR4, 256GB SATA SSD, SE380 power supply bundled with the Slev Spotless mATX chassis. Upgrades: +RM199 to 512GB SSD, +RM299 to 16GB RAM. Bundled 24" FHD IPS 120Hz monitor available at RM349. PWP accessories: keyboard and mouse set RM70, gaming keyboard/mouse/headset/mousepad set RM150, 2.0 speakers RM25.','🖥️','prebuilt'),
-- Custom Office CO1 Series (3). A distinct line from the Office PC Series
-- above: better chassis, and an aftermarket cooler on the 5700X.
(5401,'E-Tech Custom Office CO1 Ryzen 5 3400G','E-Tech',39,1389.00,'Ryzen 5 3400G on an Asus Prime A520M-K, Hiksemi 8GB DDR4 3200, Hiksemi Wave 256GB, Slev Quantum 600W, stock cooler, Tecware VXO M TG mATX in black with 3 ARGB fans. Upgrades: +RM199 to 512GB SSD, +RM299 to 16GB RAM, +RM599 for an Asus GTX 1650 4GB. Same PWP accessory pricing as the Office PC Series.','🖥️','prebuilt'),
(5402,'E-Tech Custom Office CO1 Ryzen 5 5600GT','E-Tech',39,1749.00,'Ryzen 5 5600GT on an Asus Prime A520M-K, Hiksemi 8GB DDR4 3200, Hiksemi Wave 256GB, Slev Quantum 600W, stock cooler, Tecware VXO M TG mATX in black with 3 ARGB fans. Upgrades: +RM199 to 512GB SSD, +RM299 to 16GB RAM, +RM599 for an Asus GTX 1650 4GB. Same PWP accessory pricing as the Office PC Series.','🖥️','prebuilt'),
(5403,'E-Tech Custom Office CO1 Ryzen 7 5700X','E-Tech',39,2399.00,'Ryzen 7 5700X on an Asus Prime B550M-A WiFi II, Hiksemi 16GB DDR4 3200, Hiksemi Wave 256GB, Slev Quantum 600W, Pccooler Paladin EX400 ARGB cooler, Tecware VXO M TG mATX in black with 3 ARGB fans. Upgrades: +RM199 to 512GB SSD, +RM899 for an Asus RTX 3050 6GB. Same PWP accessory pricing as the Office PC Series.','🖥️','prebuilt'),
-- New components pulled out of the build specs (3)
(2130,'MSI Pro H610M-E','MSI',19,399.00,'LGA1700 mATX motherboard on the H610 chipset, DDR4. Used in the E-Tech Office PC Core i5-14400 build.','🔌','motherboard'),
(1530,'Tecware Neo M3+ TG (Black)','Tecware',17,199.00,'mATX tempered glass case in black with 4x ARGB fans included. Used in the E-Tech Cyber Strike build.','🖥️','case'),
(1221,'MSI PRO MP225V 22" FHD 100Hz','MSI',7,279.00,'22" FHD 1920x1080 monitor at 100Hz.','🖵','monitor')
) AS v(product_id, name, brand, category_id, price, description, icon, img_slug)
JOIN brands b ON b.name = v.brand
ON CONFLICT (product_id) DO NOTHING;

-- ------------------------------------------------------------
-- Attributes
--
-- One row per spec, as the schema intends. The columns below are
-- unpivoted by the LATERAL VALUES, and NULLs simply produce no row --
-- a tower has no screen size, an office build has no graphics card.
-- ------------------------------------------------------------

-- Laptops
INSERT INTO product_attributes (product_id, attr_key, attr_value)
SELECT s.product_id, x.attr_key, x.attr_value
FROM (VALUES
(206,'A1504V-ABQ169WS','Core 5 120U',NULL::text,'8GB DDR5','512GB','15.6"','Silver'),
(207,'A1504V-ABQ170WS','Core 5 120U',NULL,'8GB DDR5','512GB','15.6"','Terra Cotta'),
(208,'A1504V-ABQ168WS','Core 5 120U',NULL,'8GB DDR5','512GB','15.6"','Quiet Blue'),
(209,'E1504F-ABQ471WMS','Ryzen 5 7520U',NULL,'16GB LPDDR5 (on-board)','512GB','15.6"','Black'),
(210,'M1605N-AQMB150WS','Ryzen 5 150 (6C/12T)',NULL,'16GB DDR5 4800 (8 soldered + 8 SODIMM)','512GB','16"','Black'),
(211,'A1405V-ALY409WS','i5-13420H',NULL,'16GB DDR4 (8 on-board + 8 SODIMM)','512GB','14"','Black'),
(212,'A1405V-ALY410WS','i5-13420H',NULL,'16GB DDR4 (8 on-board + 8 SODIMM)','512GB','14"','Silver'),
(213,'A1605V-AMB9088WS','i5-13420H',NULL,'16GB','512GB','16"','Black'),
(214,'A1605V-AMB9089WS','i5-13420H',NULL,'16GB','512GB','16"','Silver'),
(215,'A1504V-ABQ269WS','Core 5 120U',NULL,'16GB DDR5 (8 on-board + 8 SODIMM)','512GB','15.6"','Cool Silver'),
(216,'A1504V-ABQ268WS','Core 5 120U',NULL,'16GB DDR5 (8 on-board + 8 SODIMM)','512GB','15.6"','Blue'),
(217,'S3407-ALY268WS','Core 5 210H',NULL,'16GB DDR5','1TB','14"','Grey'),
(218,'S3407-ASF745WS','Core Ultra 7 255H',NULL,'16GB DDR5 on-board + 1x SODIMM slot','512GB','14"','Grey'),
(219,'S3407-ASF746WS','Core Ultra 7 255H',NULL,'16GB DDR5 on-board + 1x SODIMM slot','512GB','14"','Silver'),
(220,'FA506N-CGHN777WS','Ryzen 7 8845HS (8C/16T)','RTX 3050 4GB (60W)','8GB DDR5 5600 (1 extra slot, max 64GB)','512GB (1 extra slot)','15.6"',NULL),
(221,'G615J / G614J','i5-13450HX (55W TDP)','RTX 5050 8GB (115W TGP)','16GB DDR5 SODIMM','1TB','16"',NULL),
(222,'FX608J-MRRV058W','i7-14650HX (16C/24T)','RTX 5060 8GB GDDR7 (115W)','16GB DDR5 5600 (2 slots)','1TB (1 extra slot)','16"',NULL),
(223,'FA608U-PRV028WP','Ryzen 7 260 (8C/16T)','RTX 5070 8GB GDDR7 (115W)','16GB DDR5 5600 (2 slots)','512GB (1 extra slot)','16"',NULL),
(224,'EM0302AU','Ryzen 7 7730U (8C/16T)',NULL,'16GB DDR4 3200 (2x8GB)','512GB','14"','Gold'),
(225,'EM0303AU','Ryzen 7 7730U (8C/16T)',NULL,'16GB DDR4 3200 (2x8GB)','512GB','14"','Silver'),
(226,'FD2117TU','Core Ultra 5 225U (12C/14T)',NULL,'16GB DDR5 5600','512GB','15.6"','Silver'),
(227,'FD2116TU','Core Ultra 5 225U (12C/14T)',NULL,'16GB DDR5 5600','512GB','15.6"','Blue'),
(228,'FK0101AU','Ryzen AI 5 340 (6C/12T, 50 NPU TOPs)',NULL,'16GB LPDDR5x 7500 (on-board)','512GB','14"','Meteor Silver'),
(229,'FP0027TU','Core 5 120U (10C/12T)',NULL,'16GB LPDDR5 5200 (on-board)','512GB','14"','Blue'),
(230,'82XQ01P3MJ','Ryzen 3 30 (4C/8T)',NULL,'8GB LPDDR5 5500 (on-board)','512GB M.2 2242','15.6"','Arctic Grey'),
(231,'82XQ01P2MJ','Ryzen 3 30 (4C/8T)',NULL,'8GB LPDDR5 5500 (on-board)','512GB M.2 2242','15.6"','Abyss Blue'),
(232,'82XQ00XPMJ','Ryzen 5 7520U (4C/8T)',NULL,'16GB LPDDR5 5500 (on-board)','512GB M.2 2242','15.6"','Arctic Grey'),
(233,'83K700C9MJ','Ryzen 7 7735HS (8C/16T)',NULL,'16GB DDR5 4800 (8 soldered + 8 SODIMM)','512GB (1 extra slot)','15.3"','Luna Grey'),
(234,'83K700CAMJ','Ryzen 7 7735HS (8C/16T)',NULL,'16GB DDR5 4800 (8 soldered + 8 SODIMM)','512GB (1 extra slot)','15.3"','Cosmic Blue'),
(235,'83K100RJMJ','i7-13620H (10C/16T)',NULL,'16GB DDR5 4800 (8 soldered + 8 SODIMM)','512GB (1 extra slot)','15.3"','Cosmic Blue'),
(236,'83S1005EMJ','Ryzen AI 7 445 (6C/12T)',NULL,'32GB DDR5 5600 (2x16GB)','512GB (1 extra slot)','14"','Luna Grey'),
(237,'15ARP10E-83S000CCMJ','Ryzen 7 7735HS (8C/16T)','RTX 3050 6GB GDDR6 Refresh Ed.','16GB DDR5 4800 (1x16 + empty)','512GB PCIe 4.0','15.6"',NULL),
(238,'15ARP10E-83S00044MJ','Ryzen 7 7735HS (8C/16T)','RTX 4050 6GB GDDR6','16GB DDR5 4800 (1x16 + empty)','512GB PCIe 4.0','15.6"',NULL),
(239,'15IRX9-83DV01BTMJ','i5-13450HX (10C/16T)','RTX 4050 6GB GDDR6','16GB DDR5 4800 (1x16 + empty)','512GB PCIe 4.0','15.6"',NULL),
(240,'15IRX11-83SC004UMJ','i5-13450HX (10C/16T)','RTX 5050 8GB GDDR7 (65W)','16GB DDR5 4800 (1x16 + empty)','512GB (1 extra M.2 slot)','15.6"',NULL),
(241,'15AHP10-83JG00AVMJ','Ryzen 7 250 AI (8C/16T)','RTX 5060 8GB GDDR7','16GB DDR5 5600 (1x16 + empty)','512GB PCIe 4.0','15.6"',NULL),
(242,'15AHP11-83Q7007LMJ','Ryzen 7 250 (8C/16T)','RTX 5070 8GB GDDR7 (115W)','16GB DDR5 5600 (max 32GB)','512GB (1 extra M.2 slot)','15.3"',NULL)
) AS s(product_id, sku, cpu, gpu, ram, storage, screen, colour)
CROSS JOIN LATERAL (VALUES
  ('sku', s.sku), ('cpu', s.cpu), ('gpu', s.gpu), ('ram', s.ram),
  ('storageSize', s.storage), ('screenSize', s.screen), ('colour', s.colour)
) AS x(attr_key, attr_value)
WHERE x.attr_value IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM product_attributes a
                  WHERE a.product_id = s.product_id AND a.attr_key = x.attr_key);

-- Branded desktop towers
INSERT INTO product_attributes (product_id, attr_key, attr_value)
SELECT s.product_id, x.attr_key, x.attr_value
FROM (VALUES
(5001,'V500MV-13420H067WS','i5-13420H (8C/12T)','Intel UHD','8GB SO-DIMM DDR5 (1 empty slot)','512GB PCIe NVMe (1 extra slot)','White'),
(5002,'V500MV-13420H047WS','i5-13420H (8C/12T)','Intel UHD','8GB SO-DIMM DDR5 (1 empty slot)','512GB PCIe NVMe (1 extra slot)','Black'),
(5003,'90XW004XMI','i5-13420H (8C/12T)','Intel UHD','8GB DDR5 5200 SO-DIMM (1x8GB)','512GB PCIe NVMe (1 extra slot)','White'),
(5004,'90XS0064MI','i5-14400 (10C/16T)','Intel UHD 730','16GB DDR5 4800 (1x16GB)','1TB PCIe NVMe','White')
) AS s(product_id, sku, cpu, gpu, ram, storage, colour)
CROSS JOIN LATERAL (VALUES
  ('sku', s.sku), ('cpu', s.cpu), ('gpu', s.gpu), ('ram', s.ram),
  ('storageSize', s.storage), ('colour', s.colour)
) AS x(attr_key, attr_value)
WHERE x.attr_value IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM product_attributes a
                  WHERE a.product_id = s.product_id AND a.attr_key = x.attr_key);

-- All-in-One desktops
INSERT INTO product_attributes (product_id, attr_key, attr_value)
SELECT s.product_id, x.attr_key, x.attr_value
FROM (VALUES
(5101,'24-CU0031D','Core 5 120U (10C/12T)','8GB DDR5 5200 SODIMM (1 extra slot)','512GB PCIe NVMe','23.8"','FHD 1920x1080','No'),
(5102,'24-CU0031D','Core 5 120U (10C/12T)','24GB DDR5 5200 SODIMM','512GB PCIe NVMe','23.8"','FHD 1920x1080','No'),
(5103,'27-CR0039D','i5-1335U (10C/12T)','8GB DDR4','1TB PCIe NVMe','27"','FHD Antiglare 250 IPS','Yes'),
(5104,'27-CR0039D','i5-1335U (10C/12T)','24GB DDR4','1TB PCIe NVMe','27"','FHD Antiglare 250 IPS','Yes')
) AS s(product_id, sku, cpu, ram, storage, screen, resolution, touch)
CROSS JOIN LATERAL (VALUES
  ('sku', s.sku), ('cpu', s.cpu), ('ram', s.ram), ('storageSize', s.storage),
  ('screenSize', s.screen), ('resolution', s.resolution), ('touch', s.touch)
) AS x(attr_key, attr_value)
WHERE x.attr_value IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM product_attributes a
                  WHERE a.product_id = s.product_id AND a.attr_key = x.attr_key);

-- Prebuilt gaming, Office PC Series and Custom Office CO1
INSERT INTO product_attributes (product_id, attr_key, attr_value)
SELECT s.product_id, x.attr_key, x.attr_value
FROM (VALUES
(5201,'Ryzen 5 5500 (AM4)','Prime A520M-K CSM','RTX 3050 6GB Dual OC','16GB DDR4','MSI Spatium M450 500GB Gen4','Slev Quantum 600W','Stock','Darkflash C275P Dual Chamber ARGB - White'),
(5202,'Core Ultra 5 225 (LGA1851)','Prime H810M-A WiFi','RTX 3050 6GB Dual','Adata 16GB DDR5 5600 U-DIMM','Hiksemi Wave (P) 256GB','Slev Quantum 600W','Stock','Tecware Neo M3+ TG ARGB mATX (3x120mm ARGB)'),
(5203,'Ryzen 5 7500F (AM5)','B850M-AYW WiFi','RTX 5050 8GB Dual','Essencore 16GB DDR5 5600 UDIMM','Hiksemi Wave (P) 256GB','Asus Prime AP-750G','Asus Prime LC 360 ARGB AIO - White','Asus A31 ATX - Black'),
(5204,'i7-14700F (LGA1700)','Prime B760M-A WiFi D4','RTX 5050 8GB Dual','Hiksemi UDIMM 16GB DDR4 3200','Hiksemi Wave (P) 512GB','Asus Prime AP-750G','Asus Prime LC 360 ARGB AIO - White','Asus Prime AP202 mATX TG ARGB - White'),
(5205,'Ryzen 7 7800X3D (AM5)','B850M-AYW WiFi','TUF RX 9060 XT 16GB OC','Essencore 16GB DDR5 5600 UDIMM','Hiksemi Wave (P) 512GB','Asus Prime AP-750G','Asus Prime LC 360 ARGB AIO - White','Asus A31 ATX - Black'),
(5301,'Ryzen 3 3200G','Asus Prime A520M-K',NULL,'8GB DDR4','256GB SATA SSD','SE380 (bundled with chassis)',NULL,'Slev Spotless mATX'),
(5302,'Ryzen 5 5600GT','Asus Prime A520M-K',NULL,'8GB DDR4','256GB SATA SSD','SE380 (bundled with chassis)',NULL,'Slev Spotless mATX'),
(5303,'Core i5-14400','MSI Pro H610M-E',NULL,'8GB DDR4','256GB SATA SSD','SE380 (bundled with chassis)',NULL,'Slev Spotless mATX'),
(5401,'Ryzen 5 3400G','Asus Prime A520M-K',NULL,'Hiksemi 8GB DDR4 3200','Hiksemi Wave 256GB','Slev Quantum 600W','Stock','Tecware VXO M TG mATX Black (3x ARGB fans)'),
(5402,'Ryzen 5 5600GT','Asus Prime A520M-K',NULL,'Hiksemi 8GB DDR4 3200','Hiksemi Wave 256GB','Slev Quantum 600W','Stock','Tecware VXO M TG mATX Black (3x ARGB fans)'),
(5403,'Ryzen 7 5700X','Asus Prime B550M-A WiFi II',NULL,'Hiksemi 16GB DDR4 3200','Hiksemi Wave 256GB','Slev Quantum 600W','Pccooler Paladin EX400 ARGB','Tecware VXO M TG mATX Black (3x ARGB fans)')
) AS s(product_id, cpu, motherboard, gpu, ram, ssd, psu, cooler, chassis)
CROSS JOIN LATERAL (VALUES
  ('cpu', s.cpu), ('motherboard', s.motherboard), ('gpu', s.gpu), ('ram', s.ram),
  ('ssd', s.ssd), ('psu', s.psu), ('cooler', s.cooler), ('chassis', s.chassis)
) AS x(attr_key, attr_value)
WHERE x.attr_value IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM product_attributes a
                  WHERE a.product_id = s.product_id AND a.attr_key = x.attr_key);

-- The three new components, keyed like their existing neighbours
INSERT INTO product_attributes (product_id, attr_key, attr_value)
SELECT v.product_id, v.attr_key, v.attr_value
FROM (VALUES
(2130,'socket','LGA1700'),
(2130,'chipset','H610'),
(2130,'formFactor','mATX'),
(2130,'ramGen','DDR4'),
(1530,'formFactor','mATX'),
(1530,'supportedFormFactors','mini-ITX'),
(1530,'colour','Black'),
(1530,'fansIncluded','4x ARGB'),
(1530,'acceptsAtxPsu','Yes'),
(1221,'screenSize','22"'),
(1221,'resolution','FHD'),
(1221,'refreshRate','100Hz')
) AS v(product_id, attr_key, attr_value)
WHERE NOT EXISTS (SELECT 1 FROM product_attributes a
                  WHERE a.product_id = v.product_id AND a.attr_key = v.attr_key);
