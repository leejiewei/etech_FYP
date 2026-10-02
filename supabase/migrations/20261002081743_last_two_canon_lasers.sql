-- ============================================================
-- Photos for the last two printers, both skipped on 2 Oct morning
-- (20261002031401_printer_photos_links.sql).
--
--   * 1007 Canon LBP3010: Canon's own i-SENSYS LBP3010 render (via
--     Icecat). Photo only: Canon Malaysia no longer lists the model,
--     and links must be Malaysian.
--   * 1013 Canon LBP3010W: Canon never made a wireless LBP3010. The
--     user said 2 Oct to treat it as the imageCLASS LBP6030w; photo
--     from Canon's Shopify, link to Canon Malaysia. Name and
--     description are the owner's and stay as they are (the listing
--     says Cartridge 312; the LBP6030w takes Cartridge 325).
-- ============================================================

UPDATE products SET image_path = 'https://etech-fyp.vercel.app/images/products/1007.webp'
WHERE product_id = 1007;

UPDATE products SET
  image_path   = 'https://etech-fyp.vercel.app/images/products/1013.webp',
  official_url = 'https://my.canon/en/consumer/imageclass-lbp6030w/main/product'
WHERE product_id = 1013;
