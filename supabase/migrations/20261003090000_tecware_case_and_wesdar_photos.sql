-- Photos from official pages for products that had none: the six Tecware
-- cases (product cut-outs from tecware.co, not the text banners) and the
-- WESDAR K-968S in black (wesdar.com.cn gallery).
UPDATE products SET image_path = 'https://etech-fyp.vercel.app/images/products/' || product_id || '.webp'
WHERE product_id IN (1502, 1505, 1506, 1507, 1513, 1530, 4857);
