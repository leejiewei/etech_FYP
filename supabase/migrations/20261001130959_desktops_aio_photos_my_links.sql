-- Branded desktops (5001-5004) and all-in-ones (5101-5104): photos and
-- official pages. Also moves every laptop link that pointed outside
-- Malaysia onto a Malaysian site (user, 1 Oct 2026: "find Malaysia
-- website, don't go to outside country").
--
-- Malaysian sources only:
--   ASUS   asus.com/my product pages; 210's M1605NAQ has no MY product
--          page, so its ASUS Malaysia support page is used.
--   HP     support.hp.com/my-en spec pages for models the HP Malaysia
--          store no longer sells (228, 229, 5101-5104).
--   Lenovo pcsupport.lenovo.com/my pages for each exact machine type;
--          lenovo.com/my only sells the current generation.
--
-- Left for the owner, not changed here:
--   5003 90XW004XMI is listed by Lenovo as Cloud Grey, 5004 90XS0064MI as
--   Grey with a Sunglow Orange front bezel; the shop calls both White.

update products p
   set image_path = 'https://etech-fyp.vercel.app/images/products/' || v.id || '.webp',
       official_url = v.url
  from (values
  (5001, 'https://www.asus.com/my/displays-desktops/tower-pcs/asus-desktop/asus-v500-mini-tower-v500mv/'),
  (5002, 'https://www.asus.com/my/displays-desktops/tower-pcs/asus-desktop/asus-v500-mini-tower-v500mv/'),
  (5003, 'https://pcsupport.lenovo.com/my/en/products/desktops-and-all-in-ones/tower-series-ideacentre/ideacentre-tower-08irh9/90xw/90xw004xmi'),
  (5004, 'https://pcsupport.lenovo.com/my/en/products/desktops-and-all-in-ones/tower-series-ideacentre/ideacentre-tower-08irr9/90xs/90xs0064mi'),
  (5101, 'https://support.hp.com/my-en/product/product-specs/hp-omnistudio-23.8-inch-all-in-one-desktop-pc-24-cu000/model/2103367386?sku=D71GRPA'),
  (5102, 'https://support.hp.com/my-en/product/product-specs/hp-omnistudio-23.8-inch-all-in-one-desktop-pc-24-cu000/model/2103367386?sku=D71GRPA'),
  (5103, 'https://support.hp.com/my-en/product/product-specs/hp-all-in-one-desktop-pc-27-cr0000i/model/2101581968?sku=9H9P4PA'),
  (5104, 'https://support.hp.com/my-en/product/product-specs/hp-all-in-one-desktop-pc-27-cr0000i/model/2101581968?sku=9H9P4PA')
  ) as v(id, url)
 where p.product_id = v.id;

update products p
   set official_url = v.url
  from (values
  (210, 'https://www.asus.com/my/supportonly/m1605naq/helpdesk_knowledge/'),
  (228, 'https://support.hp.com/my-en/product/product-specs/hp-omnibook-x-flip-14-inch-2-in-1-laptop-next-gen-ai-pc-14-fk0000/model/2102790293?sku=C5AA3PA'),
  (229, 'https://support.hp.com/my-en/product/product-specs/hp-omnibook-5-flip-14-inch-2-in-1-laptop-pc-14-fp0000/model/2102894146?sku=BN2S5PA'),
  (230, 'https://pcsupport.lenovo.com/my/en/products/laptops-and-netbooks/ideapad-s-series-netbooks/ideapad-slim-3-15amn8/82xq/82xq01p3mj'),
  (231, 'https://pcsupport.lenovo.com/my/en/products/laptops-and-netbooks/ideapad-s-series-netbooks/ideapad-slim-3-15amn8/82xq/82xq01p2mj'),
  (232, 'https://pcsupport.lenovo.com/my/en/products/laptops-and-netbooks/ideapad-s-series-netbooks/ideapad-slim-3-15amn8/82xq/82xq00xpmj'),
  (233, 'https://pcsupport.lenovo.com/my/en/products/laptops-and-netbooks/ideapad-s-series-netbooks/lenovo-ideapad-slim-3-15arp10/83k7/83k700c9mj'),
  (234, 'https://pcsupport.lenovo.com/my/en/products/laptops-and-netbooks/ideapad-s-series-netbooks/lenovo-ideapad-slim-3-15arp10/83k7/83k700camj'),
  (235, 'https://pcsupport.lenovo.com/my/en/products/laptops-and-netbooks/ideapad-s-series-netbooks/ideapad-slim-3-15irh10/83k1/83k100rjmj'),
  (236, 'https://pcsupport.lenovo.com/my/en/products/laptops-and-netbooks/ideapad-s-series-netbooks/ideapad-slim-5-14agp11/83s1/83s1005emj'),
  (237, 'https://pcsupport.lenovo.com/my/en/products/laptops-and-netbooks/gaming-series/loq-15arp10e/83s0/83s000ccmj'),
  (238, 'https://pcsupport.lenovo.com/my/en/products/laptops-and-netbooks/gaming-series/loq-15arp10e/83s0/83s00044mj'),
  (239, 'https://pcsupport.lenovo.com/my/en/products/laptops-and-netbooks/gaming-series/loq-15irx9/83dv/83dv01btmj'),
  (240, 'https://pcsupport.lenovo.com/my/en/products/laptops-and-netbooks/gaming-series/loq-essential-15irx11/83sc/83sc004umj'),
  (241, 'https://pcsupport.lenovo.com/my/en/products/laptops-and-netbooks/gaming-series/loq-15ahp10/83jg/83jg00avmj'),
  (242, 'https://pcsupport.lenovo.com/my/en/products/laptops-and-netbooks/legion-series/legion-5-15ahp11/83q7/83q7007lmj')
  ) as v(id, url)
 where p.product_id = v.id;
