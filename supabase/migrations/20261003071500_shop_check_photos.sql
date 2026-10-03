-- Photos for the models confirmed at the shop on 3 Oct 2026.
-- 1203/1221 were renamed to E14A/E12VL, whose MSI spec pages say 144Hz and 120Hz
-- (the old names carried the older models' 120Hz/100Hz).
-- 4201-4204 are Vortex S, not plain Vortex, so the photos are Slev's Vortex S renders.
UPDATE products SET image_path = 'https://etech-fyp.vercel.app/images/products/' || product_id || '.webp'
WHERE product_id IN (1203, 1221, 1520, 4023, 4201, 4202, 4203, 4204, 4304, 4421, 4616, 4617, 4713);

UPDATE products SET name = replace(name, 'FHD 120Hz', 'FHD 144Hz'), description = replace(description, '120Hz', '144Hz')
WHERE product_id = 1203;
UPDATE products SET name = replace(name, 'FHD 100Hz', 'FHD 120Hz'), description = replace(description, '100Hz', '120Hz')
WHERE product_id = 1221;
