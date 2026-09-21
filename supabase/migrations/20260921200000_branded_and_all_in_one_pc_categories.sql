-- ============================================================
-- Branded PC and All-in-One PC become categories of their own.
--
-- They were two sub-categories under Desktops, next to the shop's own
-- builds (Prebuilt Gaming PCs, Office PC Series, Custom Office CO1).
-- The owner wants them apart: an Asus or Lenovo tower and an HP
-- all-in-one are bought as finished machines, not built here.
--
-- The rows are lifted out and renamed rather than replaced, so the
-- eight products keep their category_id and nothing else moves. Stock
-- is unaffected: prebuilt stock follows prebuilt_components, not the
-- category tree, and none of these eight has a parts list.
--
-- They still appear on the Prebuilt page; web/js/prebuilt.js and
-- mobile/lib/screens/prebuilt.dart now match them by category name.
-- ============================================================

update public.categories
   set parent_id = null, name = 'Branded PC'
 where category_id = 35 and name = 'Branded Desktops';

update public.categories
   set parent_id = null, name = 'All-in-One PC'
 where category_id = 36 and name = 'AIO Desktops';
