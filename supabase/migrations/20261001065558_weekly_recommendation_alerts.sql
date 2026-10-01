-- ============================================================
-- Weekly "Picked for you" message (user, 1 Oct 2026: once a week,
-- about what they need or what they keep viewing).
--
-- Each customer gets at most one message a week, choosing:
--   1. a product they viewed 3+ times in the last 14 days and have not
--      bought, still listed and not out of stock ("you keep coming back
--      to it"); the most-viewed wins;
--   2. otherwise their top recommend_products() pick.
-- Either way, no product is sent to the same person twice in 30 days.
--
-- pg_cron runs it Saturdays 02:00 UTC = 10:00 Malaysia time. The job
-- passes a 6-day cooldown, not 7, so last week's message (sent a few
-- seconds after 02:00) never blocks this week's.
-- ============================================================

CREATE OR REPLACE FUNCTION public.send_recommendation_alerts(p_customer integer DEFAULT NULL::integer, p_cooldown_days integer DEFAULT 7)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_told integer := 0;
BEGIN
  IF auth.uid() IS NOT NULL AND NOT (SELECT public.is_admin()) THEN
    RAISE EXCEPTION 'Staff access only.' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.notifications (customer_id, product_id, kind, title, body)
  SELECT c.customer_id,
         pick.product_id,
         'recommendation',
         pick.title,
         p.name || ' is RM ' || to_char(p.price, 'FM999G999D00') || '. ' ||
         pick.reason || '. Tap to take a look.'
  FROM public.customers c
  CROSS JOIN LATERAL (
    SELECT x.product_id, x.title, x.reason
    FROM (
      -- 1. what they keep viewing
      SELECT v.product_id,
             'Still thinking about it?' AS title,
             'You have looked at it ' || v.views || ' times in the last two weeks' AS reason,
             1 AS tier,
             v.views::numeric AS score
      FROM (
        SELECT e.product_id, count(*) AS views
        FROM public.events e
        WHERE e.customer_id = c.customer_id
          AND e.event_type = 'view'
          AND e.created_at > now() - interval '14 days'
        GROUP BY e.product_id
        HAVING count(*) >= 3
      ) v
      JOIN public.products vp ON vp.product_id = v.product_id
      WHERE vp.is_active = 1
        AND vp.stock_status <> 'out'
        AND NOT EXISTS (
          SELECT 1 FROM public.order_items oi
          JOIN public.orders o ON o.order_id = oi.order_id
          WHERE o.customer_id = c.customer_id
            AND oi.product_id = v.product_id
            AND o.status <> 'Cancelled')

      UNION ALL

      -- 2. what the recommender thinks they need
      SELECT r.product_id, 'Picked for you', r.reason, 2, r.score
      FROM public.recommend_products(c.customer_id, 12) r
    ) x
    WHERE NOT EXISTS (
      SELECT 1 FROM public.notifications n
      WHERE n.customer_id = c.customer_id
        AND n.kind = 'recommendation'
        AND n.product_id = x.product_id
        AND n.created_at > now() - interval '30 days')
    ORDER BY x.tier, x.score DESC
    LIMIT 1
  ) pick
  JOIN public.products p ON p.product_id = pick.product_id
  WHERE c.auth_user_id IS NOT NULL
    AND (p_customer IS NULL OR c.customer_id = p_customer)
    AND (c.shopper_role IS NOT NULL
         OR EXISTS (SELECT 1 FROM public.events e WHERE e.customer_id = c.customer_id)
         OR EXISTS (SELECT 1 FROM public.events_archive_20260916 a WHERE a.customer_id = c.customer_id)
         OR EXISTS (SELECT 1 FROM public.wishlist_items w WHERE w.customer_id = c.customer_id))
    AND NOT EXISTS (
      SELECT 1 FROM public.notifications n
      WHERE n.customer_id = c.customer_id
        AND n.kind = 'recommendation'
        AND n.created_at > now() - make_interval(days => GREATEST(p_cooldown_days, 0)));

  GET DIAGNOSTICS v_told = ROW_COUNT;
  RETURN v_told;
END;
$function$;

CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule(
  'weekly-recommendation-alerts',
  '0 2 * * 6',
  $$SELECT public.send_recommendation_alerts(NULL, 6)$$
);
