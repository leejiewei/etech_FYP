-- Photos and official pages for all 37 laptops (206-242), 1 Oct 2026.
--
-- Each colour is its own product row, so each gets a photo in its own
-- colour. Sources: ASUS listing renders; HP Malaysia store shots (the rear
-- view for 224 Gold and 227 Moonlight Blue, whose colour is only on the
-- lid); Lenovo PSREF renders. 215/216 share 206/208's photo (same A1504,
-- ASUS's only silver and blue), 218 shares 217, 232 shares 230, 238 shares
-- 237.
--
-- Links: ASUS Malaysia pages, except 210 (the M1605NAQ with Ryzen 5 150 is
-- only on the global page). HP Malaysia store pages for 224-227; 228 and
-- 229 are no longer sold on the Malaysian store, so HP's product-details
-- pages are used. Lenovo: the PSREF page for each exact machine type.
--
-- Left for the owner, not changed here:
--   229 is listed by HP with a Core i5-1334U, not the "Core 5 120U" in
--       its name, and is an OmniBook 5 *Flip* 14 (2-in-1).
--   242 machine type 83Q7007LMJ is a Legion 5 15AHP11, not a LOQ.
--   240 is officially the "LOQ Essential" 15IRX11.

update products p
   set image_path   = 'https://etech-fyp.vercel.app/images/products/' || v.id || '.webp',
       official_url = v.url
  from (values
  (206, 'https://www.asus.com/my/laptops/for-home/vivobook/asus-vivobook-15-a1504/'),
  (207, 'https://www.asus.com/my/laptops/for-home/vivobook/asus-vivobook-15-a1504/'),
  (208, 'https://www.asus.com/my/laptops/for-home/vivobook/asus-vivobook-15-a1504/'),
  (209, 'https://www.asus.com/my/laptops/for-home/vivobook/vivobook-go-15-e1504f/'),
  (210, 'https://www.asus.com/laptops/for-home/vivobook/asus-vivobook-16-oled-m1605/'),
  (211, 'https://www.asus.com/my/laptops/for-home/vivobook/asus-vivobook-14-a1405/'),
  (212, 'https://www.asus.com/my/laptops/for-home/vivobook/asus-vivobook-14-a1405/'),
  (213, 'https://www.asus.com/my/laptops/for-home/vivobook/vivobook-16-a1605/'),
  (214, 'https://www.asus.com/my/laptops/for-home/vivobook/vivobook-16-a1605/'),
  (215, 'https://www.asus.com/my/laptops/for-home/vivobook/asus-vivobook-15-a1504/'),
  (216, 'https://www.asus.com/my/laptops/for-home/vivobook/asus-vivobook-15-a1504/'),
  (217, 'https://www.asus.com/my/laptops/for-home/vivobook/asus-vivobook-s14-s3407/'),
  (218, 'https://www.asus.com/my/laptops/for-home/vivobook/asus-vivobook-s14-s3407/'),
  (219, 'https://www.asus.com/my/laptops/for-home/vivobook/asus-vivobook-s14-s3407/'),
  (220, 'https://www.asus.com/my/laptops/for-gaming/tuf-gaming/2021-asus-tuf-gaming-a15/'),
  (221, 'https://rog.asus.com/my/laptops/rog-strix/rog-strix-g16-2025/'),
  (222, 'https://www.asus.com/my/laptops/for-gaming/tuf-gaming/asus-tuf-gaming-f16-2025/'),
  (223, 'https://www.asus.com/my/laptops/for-gaming/tuf-gaming/asus-tuf-gaming-a16-2025/'),
  (224, 'https://www.hp.com/my-en/shop/hp-laptop-14-em0302au-dw3m8pa.html'),
  (225, 'https://www.hp.com/my-en/shop/hp-laptop-14-em0303au-dw3m9pa.html'),
  (226, 'https://www.hp.com/my-en/shop/hp-laptop-ai-15-fd2117tu-d4qu7pa.html'),
  (227, 'https://www.hp.com/my-en/shop/hp-laptop-ai-15-fd2116tu-d4qu6pa.html'),
  (228, 'https://www.hp.com/lk-en/products/laptops/product-details/2103315082'),
  (229, 'https://www.hp.com/lk-en/products/laptops/product-details/2103054961'),
  (230, 'https://psref.lenovo.com/Detail/IdeaPad/IdeaPad_Slim_3_15AMN8?M=82XQ01P3MJ'),
  (231, 'https://psref.lenovo.com/Detail/IdeaPad/IdeaPad_Slim_3_15AMN8?M=82XQ01P2MJ'),
  (232, 'https://psref.lenovo.com/Detail/IdeaPad/IdeaPad_Slim_3_15AMN8?M=82XQ00XPMJ'),
  (233, 'https://psref.lenovo.com/Detail/IdeaPad/IdeaPad_Slim_3_15ARP10?M=83K700C9MJ'),
  (234, 'https://psref.lenovo.com/Detail/IdeaPad/IdeaPad_Slim_3_15ARP10?M=83K700CAMJ'),
  (235, 'https://psref.lenovo.com/Detail/IdeaPad/IdeaPad_Slim_3_15IRH10?M=83K100RJMJ'),
  (236, 'https://psref.lenovo.com/Detail/IdeaPad/IdeaPad_Slim_5_14AGP11?M=83S1005EMJ'),
  (237, 'https://psref.lenovo.com/Detail/LOQ/LOQ_15ARP10E?M=83S000CCMJ'),
  (238, 'https://psref.lenovo.com/Detail/LOQ/LOQ_15ARP10E?M=83S00044MJ'),
  (239, 'https://psref.lenovo.com/Detail/LOQ/LOQ_15IRX9?M=83DV01BTMJ'),
  (240, 'https://psref.lenovo.com/Detail/LOQ/LOQ_15IRX11?M=83SC004UMJ'),
  (241, 'https://psref.lenovo.com/Detail/LOQ/LOQ_15AHP10?M=83JG00AVMJ'),
  (242, 'https://psref.lenovo.com/Detail/Legion/Legion_5_15AHP11?M=83Q7007LMJ')
  ) as v(id, url)
 where p.product_id = v.id;
