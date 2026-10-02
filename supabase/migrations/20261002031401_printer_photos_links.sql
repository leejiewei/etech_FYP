-- ============================================================
-- Photos and official links for the printers (categories 11 Inkjet,
-- 12 Laser, 13 Ink Tank). Found 2 Oct 2026: photo first, link only to
-- the maker's Malaysian page (or its Malaysian support page).
--
-- 18 of 20 get a photo and a link.
--
--   * Brother (8): brother.com.my product pages, photos from their gallery
--     with the spec icons / award badge painted out.
--   * Epson (3): epson.com.my. The L14150 gallery is small, so Epson's own
--     render was taken from Allit Hypermarket's listing.
--   * HP (2): hp.com/my-en store.
--   * Canon (4 of 6): my.canon product pages. Canon Malaysia's images are
--     362px, so photos came from Canon Singapore's store (E410, E470,
--     E4570) and Allit Hypermarket (G2010, G3010).
--     The E4570 is not on Canon Malaysia's product pages, only its
--     support page, which is the link.
--
-- Skipped (left for the user to confirm with the shop):
--   1007 Canon LBP3010 -- no Canon Malaysia page or Malaysian seller found
--   1013 Canon LBP3010W -- Canon makes no wireless LBP3010; the nearest is
--        the imageCLASS LBP6030w (which uses Cartridge 325, not 312)
-- ============================================================

UPDATE public.products p
SET image_path   = 'https://etech-fyp.vercel.app/images/products/' || p.product_id || '.webp',
    official_url = COALESCE(v.url, p.official_url)
FROM (VALUES
  (1001, 'https://my.canon/en/consumer/pixma-e410/product'),
  (1002, 'https://my.canon/en/consumer/pixma-e470/product'),
  (1003, 'https://www.hp.com/my-en/shop/hp-deskjet-ink-advantage-2875-all-in-one-printer-588j7b.html'),
  (1004, 'https://www.brother.com.my/en/printers/all-printers/hl-1110'),
  (1005, 'https://www.brother.com.my/en/printers/all-printers/hl-1210w'),
  (1006, 'https://my.canon/en/consumer/pixma-g2010/product'),
  (1008, 'https://my.canon/en/support/PIXMA%20E4570/model'),
  (1009, 'https://www.hp.com/my-en/shop/hp-smart-tank-580-all-in-one-printer-1f3y2a.html'),
  (1010, 'https://www.epson.com.my/For-Home/Printers/Home-Office-Printers/Epson-EcoTank-L3310-A4-All-in-One-Ink-Tank-Printer/p/C11CL61501'),
  (1011, 'https://my.canon/en/consumer/pixma-g3010/product'),
  (1012, 'https://www.epson.com.my/For-Home/Printers/Home-Office-Printers/Epson-EcoTank-L3350-A4-Wi-Fi-All-in-One-Ink-Tank-Printer/p/C11CL62503'),
  (1014, 'https://www.brother.com.my/en/printers/all-printers/dcp-1610w'),
  (1015, 'https://www.brother.com.my/en/printers/all-printers/dcp-t430w'),
  (1016, 'https://www.brother.com.my/en/printers/all-printers/mfc-1910w'),
  (1017, 'https://www.brother.com.my/en/printers/all-printers/dcp-t530dw'),
  (1018, 'https://www.brother.com.my/en/printers/all-printers/dcp-l2640dw'),
  (1019, 'https://www.brother.com.my/en/printers/all-printers/dcp-t730dw'),
  (1020, 'https://www.epson.com.my/For-Home/Printers/Ink-Tank/Ink-Tank-System-Printers/Epson-EcoTank-L14150-A3%2B-Wi-Fi-Duplex-Wide-Format-All-in-One-Ink-Tank-Printer/p/C11CH96502')
) AS v(id, url)
WHERE p.product_id = v.id;
