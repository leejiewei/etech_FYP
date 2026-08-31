-- ============================================================
-- admin_products gains the parent category's id.
--
-- The product list filters by "this category or anything under it".
-- The view already carried the parent's *name*, which is enough to
-- print but not to filter on: the dropdown hands back an id. Selecting
-- c.parent_id as well lets the browser ask for
--
--     category_id = 26 OR parent_category_id = 26
--
-- in one request, instead of first resolving the id to a name.
--
-- security_invoker stays off and the is_admin() guard stays in the
-- WHERE, exactly as in 20260827114759_admin_views.sql — this view
-- exposes cost_price and stock_qty, so that guard is the only thing
-- standing in front of them.
-- ============================================================
CREATE OR REPLACE VIEW public.admin_products WITH (security_invoker = off) AS
SELECT
  p.product_id, p.name, p.brand_id, p.category_id, p.price, p.cost_price,
  p.stock_qty, p.reorder_level, p.stock_status, p.description, p.icon,
  p.img_slug, p.image_path, p.exclude_from_builder, p.is_active,
  p.created_at, p.updated_at,
  b.name       AS brand,
  c.name       AS category,
  parent.name  AS parent_category,
  COALESCE(parent.name, c.name) AS top_category,
  c.parent_id  AS parent_category_id
FROM public.products p
JOIN public.brands b               ON b.brand_id = p.brand_id
JOIN public.categories c           ON c.category_id = p.category_id
LEFT JOIN public.categories parent ON parent.category_id = c.parent_id
WHERE (SELECT public.is_admin());
