-- ============================================================
-- A deal now also tells the people who put it in their cart.
--
-- 20260915120100_telling_the_people_who_were_watching.sql counted two
-- kinds of watcher: a wishlist save, and three or more views. It left
-- out the plainest sign of all -- somebody who added the product to
-- their cart and then did not buy it. That is the customer a price drop
-- is most likely to turn into an order, and the one the owner asked for
-- by name: "this item has a discount, want to buy it now?"
--
-- Who counts as watching, strongest first. A customer who qualifies
-- more than one way is told once, under the strongest:
--
--   wishlisted   the product is in their wishlist.
--   carted       at least one cart add and no purchase of it. Somebody
--                who has already bought the card does not need telling
--                it is cheaper now.
--   viewed       p_min_views or more views, as before.
--
-- Everything else -- the staff check, the price and time checks, the
-- deal and its messages in one transaction, the count returned -- is
-- unchanged. The Customer Behaviour page and the Dashboard count the
-- same three groups, so the numbers there are the numbers this sends.
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_create_deal(
  p_product_id     integer,
  p_discount_price numeric,
  p_start_time     timestamptz,
  p_end_time       timestamptz,
  p_min_views      integer DEFAULT 3
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_deal_id      integer;
  v_product_name text;
  v_was          numeric;
  v_told         integer := 0;
BEGIN
  IF NOT (SELECT public.is_admin()) THEN
    RAISE EXCEPTION 'Staff access only.' USING ERRCODE = '42501';
  END IF;

  SELECT p.name, p.price INTO v_product_name, v_was
  FROM public.products p WHERE p.product_id = p_product_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'That product no longer exists.' USING ERRCODE = 'P0001';
  END IF;

  IF p_discount_price >= v_was THEN
    RAISE EXCEPTION 'A deal price has to be below the shelf price.' USING ERRCODE = 'P0001';
  END IF;

  IF p_end_time <= p_start_time THEN
    RAISE EXCEPTION 'A deal has to end after it starts.' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.deals (product_id, discount_price, start_time, end_time)
  VALUES (p_product_id, p_discount_price, p_start_time, p_end_time)
  RETURNING deal_id INTO v_deal_id;

  WITH activity AS (
    SELECT e.customer_id,
           count(*) FILTER (WHERE e.event_type = 'view')     AS views,
           count(*) FILTER (WHERE e.event_type = 'cart_add') AS cart_adds,
           count(*) FILTER (WHERE e.event_type = 'purchase') AS purchases
    FROM public.events e
    WHERE e.product_id = p_product_id
      AND e.customer_id IS NOT NULL
    GROUP BY e.customer_id
  ),
  candidates AS (
    SELECT w.customer_id, 1 AS rank
    FROM public.wishlist_items w
    WHERE w.product_id = p_product_id
    UNION ALL
    SELECT a.customer_id, 2 FROM activity a
    WHERE a.cart_adds > 0 AND a.purchases = 0
    UNION ALL
    SELECT a.customer_id, 3 FROM activity a
    WHERE a.views >= p_min_views
  ),
  watchers AS (
    SELECT DISTINCT ON (c.customer_id) c.customer_id, c.rank
    FROM candidates c
    ORDER BY c.customer_id, c.rank
  )
  INSERT INTO public.notifications (customer_id, product_id, kind, title, body)
  SELECT
    watchers.customer_id,
    p_product_id,
    'deal_started',
    CASE watchers.rank
      WHEN 1 THEN 'Price drop on something you saved'
      WHEN 2 THEN 'Something in your cart is on offer'
      ELSE        'Something you looked at is on offer' END,
    v_product_name || ' is now RM ' || to_char(p_discount_price, 'FM999G999D00') ||
    ', down from RM ' || to_char(v_was, 'FM999G999D00') || '. ' ||
    CASE WHEN p_start_time > now()
         THEN 'The offer starts ' || to_char(p_start_time AT TIME ZONE 'Asia/Kuala_Lumpur', 'FMDay DD Mon') || '.'
         ELSE 'The offer ends ' || to_char(p_end_time AT TIME ZONE 'Asia/Kuala_Lumpur', 'FMDay DD Mon') ||
              '. Want to buy it now?'
    END
  FROM watchers;

  GET DIAGNOSTICS v_told = ROW_COUNT;
  RETURN v_told;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_create_deal(integer, numeric, timestamptz, timestamptz, integer) FROM public, anon;
GRANT  EXECUTE ON FUNCTION public.admin_create_deal(integer, numeric, timestamptz, timestamptz, integer) TO authenticated;
