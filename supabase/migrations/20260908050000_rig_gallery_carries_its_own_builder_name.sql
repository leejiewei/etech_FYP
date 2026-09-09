-- ============================================================
-- The gallery could not be read signed out.
--
-- Found the moment the page was pointed at the real database: a
-- signed-out visitor got 42501, "permission denied for table customers",
-- and an empty gallery. Which is the whole audience for a shop window.
--
-- rig_gallery is security_invoker, so it runs as whoever queried it, and
-- it joined customers to get the builder's first name.
-- 20260827114650_client_privileges.sql revokes SELECT on customers from
-- anon and grants the columns back to authenticated only, so the join was
-- never going to work for the reader it was written for.
--
-- Two ways out, and the tempting one is wrong. Making the view
-- security_invoker = off would work, and would put a table holding every
-- customer's name, email, phone and address behind a view anon can query,
-- guarded only by that view's WHERE. The guard would hold. It is still
-- more reach than a gallery needs, and the sort of thing that is fine
-- until somebody adds a column to the view.
--
-- So the name is copied onto the rig at submission instead, and the view
-- stops touching customers at all.
--
-- That is not only a workaround. The name beside a published photograph
-- should be the name as it was when it was published, in the same way
-- order_items copies the product name in so an old order still reads
-- correctly. A customer editing their profile two years later should not
-- silently rewrite the caption on somebody's build.
--
-- First name only, as before: it is a shop window, not a directory.
-- ============================================================

ALTER TABLE public.rig_showcases
  ADD COLUMN builder_name VARCHAR(60) NOT NULL DEFAULT 'A customer';

CREATE OR REPLACE FUNCTION public.submit_rig_showcase(
  p_title       text,
  p_description text,
  p_image_urls  text[],
  p_product_ids integer[]
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_customer integer := public.current_customer_id();
  v_title    text    := btrim(COALESCE(p_title, ''));
  v_builder  text;
  v_rig      integer;
BEGIN
  IF v_customer IS NULL THEN
    RAISE EXCEPTION 'Please log in first.' USING ERRCODE = '42501';
  END IF;

  IF v_title = '' THEN
    RAISE EXCEPTION 'Give your build a title.' USING ERRCODE = 'P0001';
  END IF;

  IF p_image_urls IS NULL OR cardinality(p_image_urls) = 0 THEN
    RAISE EXCEPTION 'Add at least one photo of the build.' USING ERRCODE = 'P0001';
  END IF;

  IF cardinality(p_image_urls) > 6 THEN
    RAISE EXCEPTION 'Six photos is the most a build can have.' USING ERRCODE = 'P0001';
  END IF;

  -- Read here rather than accepted as an argument: the caption is the
  -- shop's record of who built it, not something the submitting page
  -- gets to choose.
  SELECT NULLIF(btrim(split_part(c.name, ' ', 1)), '')
    INTO v_builder
  FROM public.customers c
  WHERE c.customer_id = v_customer;

  INSERT INTO public.rig_showcases
    (customer_id, title, description, image_urls, builder_name)
  VALUES
    (v_customer, left(v_title, 120),
     NULLIF(btrim(COALESCE(p_description, '')), ''),
     p_image_urls,
     left(COALESCE(v_builder, 'A customer'), 60))
  RETURNING rig_id INTO v_rig;

  INSERT INTO public.rig_showcase_parts (rig_id, product_id)
  SELECT DISTINCT v_rig, p.product_id
  FROM unnest(COALESCE(p_product_ids, ARRAY[]::integer[])) AS wanted(product_id)
  JOIN public.products p ON p.product_id = wanted.product_id AND p.is_active = 1;

  RETURN v_rig;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.submit_rig_showcase(text, text, text[], integer[])
  FROM public, anon;
GRANT  EXECUTE ON FUNCTION public.submit_rig_showcase(text, text, text[], integer[])
  TO authenticated;

-- No customers join. The view now reads one table, which anon is allowed
-- to read and whose policy already limits it to approved rows.
DROP VIEW public.rig_gallery;

CREATE VIEW public.rig_gallery WITH (security_invoker = on) AS
SELECT
  r.rig_id,
  r.title,
  r.description,
  r.image_urls,
  r.is_asus_verified,
  r.created_at,
  r.builder_name AS builder
FROM public.rig_showcases r
WHERE r.status = 'APPROVED';

REVOKE ALL ON public.rig_gallery FROM anon, authenticated;
GRANT SELECT ON public.rig_gallery TO anon, authenticated;

-- The admin view keeps its customers join. Staff are allowed to read that
-- table, and the moderation queue needs the full name and the email.
CREATE OR REPLACE VIEW public.admin_rig_showcases WITH (security_invoker = on) AS
SELECT
  r.rig_id,
  r.customer_id,
  r.title,
  r.description,
  r.image_urls,
  r.is_asus_verified,
  r.status,
  r.review_note,
  r.created_at,
  r.reviewed_at,
  c.name  AS customer_name,
  c.email AS customer_email,
  (SELECT count(*) FROM public.rig_showcase_parts rp WHERE rp.rig_id = r.rig_id)
    AS tagged_parts
FROM public.rig_showcases r
JOIN public.customers c ON c.customer_id = r.customer_id;

REVOKE ALL ON public.admin_rig_showcases FROM anon, authenticated;
GRANT SELECT ON public.admin_rig_showcases TO authenticated;
