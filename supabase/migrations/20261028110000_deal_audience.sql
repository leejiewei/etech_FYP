-- ============================================================
-- Who a deal messages: one rule, used by the preview and the send.
--
-- Found in Chapter 4 testing (Figure 4.36): the Timed Deals page said
-- "Nobody is waiting on it yet" for a product a customer had saved.
-- The preview counted from admin_customer_activity, which only holds
-- customers with tracked events, so a wishlist entry with no recorded
-- view was invisible to it -- while admin_create_deal() read the
-- wishlist directly and would have messaged them. Two rules, two
-- answers. And neither looked at what is in a cart right now: both
-- relied on past cart_add events.
--
-- admin_deal_audience() is now the rule. In order of how strongly the
-- customer wanted it (the first that applies names the message):
--   1 saved      on their wishlist
--   2 in_cart    in their cart right now
--   3 carted     added to a cart before and not bought
--   4 viewed     opened it p_min_views times or more
-- has_push says whether they have a phone registered for push, so the
-- page can say how many of the messages also went to a phone.
-- ============================================================

CREATE OR REPLACE FUNCTION public.admin_deal_audience(p_product_id integer, p_min_views integer DEFAULT 3)
RETURNS TABLE (customer_id integer, reason text, has_push boolean)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NOT (SELECT public.is_admin()) THEN
    RAISE EXCEPTION 'Staff access only.' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH activity AS (
    SELECT e.customer_id,
           count(*) FILTER (WHERE e.event_type = 'view')     AS views,
           count(*) FILTER (WHERE e.event_type = 'cart_add') AS cart_adds,
           count(*) FILTER (WHERE e.event_type = 'purchase') AS purchases
    FROM public.events e
    WHERE e.product_id = p_product_id AND e.customer_id IS NOT NULL
    GROUP BY e.customer_id
  ),
  candidates AS (
    SELECT w.customer_id, 1 AS rank FROM public.wishlist_items w
    WHERE w.product_id = p_product_id
    UNION ALL
    SELECT c.customer_id, 2 FROM public.cart_items c
    WHERE c.product_id = p_product_id
    UNION ALL
    SELECT a.customer_id, 3 FROM activity a
    WHERE a.cart_adds > 0 AND a.purchases = 0
    UNION ALL
    SELECT a.customer_id, 4 FROM activity a
    WHERE a.views >= p_min_views
  ),
  watchers AS (
    SELECT DISTINCT ON (c.customer_id) c.customer_id, c.rank
    FROM candidates c
    ORDER BY c.customer_id, c.rank
  )
  SELECT w.customer_id,
         (ARRAY['saved', 'in_cart', 'carted', 'viewed'])[w.rank],
         EXISTS (SELECT 1 FROM public.device_tokens d WHERE d.customer_id = w.customer_id)
  FROM watchers w;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_deal_audience(integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_deal_audience(integer, integer) TO authenticated, service_role;

-- ------------------------------------------------------------
-- Creating a deal. Now returns what was actually sent rather than one
-- number: in_app is the notifications written (each shows in the
-- customer's bell at once); push_queued is how many of those customers
-- have a phone registered, whose push the notifications trigger handed
-- to the push function. Queued, not delivered -- Firebase answers after
-- this transaction, and the page says so.
--
-- The return type changes (integer -> jsonb), so the old function is
-- dropped first and its grants restated.
-- ------------------------------------------------------------
DROP FUNCTION public.admin_create_deal(integer, numeric, timestamp with time zone, timestamp with time zone, integer);

CREATE FUNCTION public.admin_create_deal(p_product_id integer, p_discount_price numeric, p_start_time timestamp with time zone, p_end_time timestamp with time zone, p_min_views integer DEFAULT 3)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_deal_id      integer;
  v_product_name text;
  v_was          numeric;
  v_in_app       integer := 0;
  v_push         integer := 0;
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

  WITH sent AS (
    INSERT INTO public.notifications (customer_id, product_id, kind, title, body)
    SELECT
      a.customer_id,
      p_product_id,
      'deal_started',
      CASE a.reason
        WHEN 'saved'   THEN 'Price drop on something you saved'
        WHEN 'in_cart' THEN 'Something in your cart is on offer'
        WHEN 'carted'  THEN 'Something you added to your cart is on offer'
        ELSE                'Something you looked at is on offer' END,
      v_product_name || ' is now RM ' || to_char(p_discount_price, 'FM999G999D00') ||
      ', down from RM ' || to_char(v_was, 'FM999G999D00') || '. ' ||
      CASE WHEN p_start_time > now()
           THEN 'The offer starts ' || to_char(p_start_time AT TIME ZONE 'Asia/Kuala_Lumpur', 'FMDay DD Mon') || '.'
           ELSE 'The offer ends ' || to_char(p_end_time AT TIME ZONE 'Asia/Kuala_Lumpur', 'FMDay DD Mon') ||
                '. Want to buy it now?'
      END
    FROM public.admin_deal_audience(p_product_id, p_min_views) a
    RETURNING notifications.customer_id
  )
  SELECT count(*),
         count(*) FILTER (WHERE EXISTS (
           SELECT 1 FROM public.device_tokens d WHERE d.customer_id = sent.customer_id))
    INTO v_in_app, v_push
  FROM sent;

  RETURN jsonb_build_object('deal_id', v_deal_id, 'in_app', v_in_app, 'push_queued', v_push);
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_create_deal(integer, numeric, timestamp with time zone, timestamp with time zone, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_create_deal(integer, numeric, timestamp with time zone, timestamp with time zone, integer) TO authenticated, service_role;
