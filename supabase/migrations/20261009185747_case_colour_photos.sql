-- Colour photos for the two-colour cases, so picking a colour shows it:
-- <id>-black.webp / <id>-white.webp beside the main photo, found by
-- naming convention (colourImageOf in web/js/ui.js), so they need no
-- column. Only 1510 ZOTAC GAMING ALLOY mATX had no photo at all; it gets
-- the Black/Gold one as its main photo (Allit Hypermarket, MY retailer --
-- zotac.com blocks downloads, and no White/Silver photo was found).
-- Tecware Aero M and Timber M have no clean white photo anywhere, so
-- picking White still shows the black main photo for those two.
UPDATE public.products
SET image_path = 'https://etech-fyp.vercel.app/images/products/1510.webp'
WHERE product_id = 1510 AND image_path IS NULL;
