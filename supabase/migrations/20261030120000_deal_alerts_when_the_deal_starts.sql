-- ============================================================
-- Deal alerts go out when the deal STARTS, not when staff save it.
--
-- Found in Chapter 5 testing (SYS-04, 30 Oct): admin_create_deal()
-- messaged whoever was watching at the moment the deal was saved, and
-- never again. So
--   * a deal set for next Friday told people on Tuesday, before the
--     price had dropped, and nobody was told on Friday; and
--   * anyone who saved or carted the product between the save and the
--     start was never told at all.
--
-- Now each deal is alerted once, by send_deal_alerts(), at the first
-- moment it is live: straight away from admin_create_deal() when it
-- starts now, otherwise from a one-minute pg_cron job.
--
--   deals.alerts_sent_at  set by whichever call claims the deal first;
--                         a second run, a refresh, a cron tick that
--                         overlaps -- all find it set and send nothing.
--   notifications.deal_id with a unique index on (deal_id, customer_id),
--                         so one customer gets one message per deal even
--                         with the product in both wishlist and cart.
--
-- A customer who saves a product after its deal has started is not
-- messaged: the deal price is already on every card and page they see.
-- The audience rule itself (saved > in cart > carted > viewed 3+) is
-- unchanged from 20261028110000_deal_audience.sql.
-- ============================================================

ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS alert_min_views integer NOT NULL DEFAULT 3,
  ADD COLUMN IF NOT EXISTS alerts_sent_at timestamptz;

-- Every deal made before today had its one chance at creation; sending
-- now would message people about deals they found on their own.
UPDATE public.deals SET alerts_sent_at = created_at WHERE alerts_sent_at IS NULL;

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS deal_id integer REFERENCES public.deals (deal_id) ON DELETE SET NULL;

CREATE UNIQUE INDEX IF NOT EXISTS notifications_one_per_customer_per_deal
  ON public.notifications (deal_id, customer_id)
  WHERE deal_id IS NOT NULL;


-- The rule, without the staff check, for the two callers that are not
-- staff: the scheduler, and admin_create_deal() itself. Not callable
-- from the browser.
CREATE OR REPLACE FUNCTION public.deal_watchers(p_product_id integer, p_min_views integer DEFAULT 3)
RETURNS TABLE (customer_id integer, reason text, has_push boolean)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
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

REVOKE ALL ON FUNCTION public.deal_watchers(integer, integer) FROM PUBLIC, anon, authenticated;

-- The staff preview reads the same rule, so its count cannot drift.
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

  RETURN QUERY SELECT * FROM public.deal_watchers(p_product_id, p_min_views);
END;
$function$;


-- Sends one deal's alerts if it is live and nobody has sent them yet.
-- Each row it writes fires notify_push(), so phones are covered by the
-- same insert as the bell.
CREATE OR REPLACE FUNCTION public.send_deal_alerts(p_deal_id integer)
RETURNS TABLE (in_app integer, push_queued integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_deal public.deals%ROWTYPE;
  v_name text;
  v_was  numeric;
BEGIN
  -- Claiming and checking in one statement: of two calls at once, only
  -- one gets the row back.
  UPDATE public.deals d
     SET alerts_sent_at = now()
   WHERE d.deal_id = p_deal_id
     AND d.alerts_sent_at IS NULL
     AND d.is_active = 1
     AND d.start_time <= now()
     AND d.end_time > now()
  RETURNING d.* INTO v_deal;

  IF NOT FOUND THEN
    RETURN QUERY SELECT 0, 0;
    RETURN;
  END IF;

  SELECT p.name, p.price INTO v_name, v_was
  FROM public.products p
  WHERE p.product_id = v_deal.product_id AND p.is_active = 1;

  -- Delisted since the deal was made: nothing to send them to.
  IF NOT FOUND THEN
    RETURN QUERY SELECT 0, 0;
    RETURN;
  END IF;

  RETURN QUERY
  WITH sent AS (
    INSERT INTO public.notifications (customer_id, product_id, deal_id, kind, title, body)
    SELECT
      w.customer_id,
      v_deal.product_id,
      v_deal.deal_id,
      'deal_started',
      CASE w.reason
        WHEN 'saved'   THEN 'Price drop on something you saved'
        WHEN 'in_cart' THEN 'Something in your cart is on offer'
        WHEN 'carted'  THEN 'Something you added to your cart is on offer'
        ELSE                'Something you looked at is on offer' END,
      v_name || ' is now RM ' || to_char(v_deal.discount_price, 'FM999G999D00') ||
      ', down from RM ' || to_char(v_was, 'FM999G999D00') || '. ' ||
      'The offer ends ' || to_char(v_deal.end_time AT TIME ZONE 'Asia/Kuala_Lumpur', 'FMDay DD Mon') ||
      '. Want to buy it now?'
    FROM public.deal_watchers(v_deal.product_id, v_deal.alert_min_views) w
    ON CONFLICT (deal_id, customer_id) WHERE deal_id IS NOT NULL DO NOTHING
    RETURNING notifications.customer_id
  )
  SELECT count(*)::integer,
         (count(*) FILTER (WHERE EXISTS (
           SELECT 1 FROM public.device_tokens d WHERE d.customer_id = sent.customer_id)))::integer
  FROM sent;
END;
$function$;

REVOKE ALL ON FUNCTION public.send_deal_alerts(integer) FROM PUBLIC, anon, authenticated;

-- What the scheduler runs: every deal that has started, is still on,
-- and has not been sent. Returns how many messages went out.
CREATE OR REPLACE FUNCTION public.send_due_deal_alerts()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_deal_id integer;
  v_total   integer := 0;
  v_sent    integer;
BEGIN
  FOR v_deal_id IN
    SELECT d.deal_id FROM public.deals d
    WHERE d.alerts_sent_at IS NULL
      AND d.is_active = 1
      AND d.start_time <= now()
      AND d.end_time > now()
    ORDER BY d.start_time
  LOOP
    SELECT s.in_app INTO v_sent FROM public.send_deal_alerts(v_deal_id) s;
    v_total := v_total + COALESCE(v_sent, 0);
  END LOOP;
  RETURN v_total;
END;
$function$;

REVOKE ALL ON FUNCTION public.send_due_deal_alerts() FROM PUBLIC, anon, authenticated;


-- Staff save the deal; if it is already live the alerts go now and the
-- count comes back as before. A deal that starts later comes back with
-- scheduled = true and zero sent; the scheduler sends it on the minute.
CREATE OR REPLACE FUNCTION public.admin_create_deal(
  p_product_id integer,
  p_discount_price numeric,
  p_start_time timestamp with time zone,
  p_end_time timestamp with time zone,
  p_min_views integer DEFAULT 3)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_deal_id integer;
  v_was     numeric;
  v_in_app  integer := 0;
  v_push    integer := 0;
BEGIN
  IF NOT (SELECT public.is_admin()) THEN
    RAISE EXCEPTION 'Staff access only.' USING ERRCODE = '42501';
  END IF;

  SELECT p.price INTO v_was
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

  INSERT INTO public.deals (product_id, discount_price, start_time, end_time, alert_min_views)
  VALUES (p_product_id, p_discount_price, p_start_time, p_end_time, COALESCE(p_min_views, 3))
  RETURNING deal_id INTO v_deal_id;

  SELECT s.in_app, s.push_queued INTO v_in_app, v_push
  FROM public.send_deal_alerts(v_deal_id) s;

  RETURN jsonb_build_object(
    'deal_id', v_deal_id,
    'in_app', v_in_app,
    'push_queued', v_push,
    'scheduled', p_start_time > now());
END;
$function$;


-- Once a minute is as late as a scheduled deal's alerts can be.
SELECT cron.unschedule('deal-alerts-on-start')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'deal-alerts-on-start');

SELECT cron.schedule('deal-alerts-on-start', '* * * * *',
  'SELECT public.send_due_deal_alerts()');
