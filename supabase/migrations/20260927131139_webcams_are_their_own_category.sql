-- The owner wants webcams on their own, not under Gaming Gear: the
-- Webcam sub-category (47) becomes the top-level "Webcams". The web
-- Categories menu lists top-level categories by hand, so it gains a
-- Webcams tile in web/js/layout.js; the app builds its list from here.
update public.categories set name = 'Webcams', parent_id = null where category_id = 47;
