-- ============================================================
-- Telling the people who were watching that the price has dropped.
--
-- A deal goes live and nobody hears about it. The customer who saved the
-- card to their wishlist, or came back to the same product three times
-- in a fortnight, finds out only if they happen to open the shop again
-- while it is still running. That is the one moment in this shop where
-- the news is genuinely worth somebody's attention, and it was the one
-- moment nothing was sent.
--
-- 20260911062618_order_notifications.sql set the rule this follows:
-- messages are written from inside the function a member of staff calls,
-- not by a trigger on the table, "so every row here has a member of
-- staff's deliberate action behind it, and a status fixed by hand in the
-- SQL editor does not ping somebody's phone." A trigger on deals would
-- have been fewer lines and would have broken that rule -- backfilling a
-- deal, or nudging an end_time in the dashboard, would message everyone.
--
-- So creating a deal moves into admin_create_deal() below, which inserts
-- the row and sends the messages in one transaction, and returns how
-- many people it told. Inserting into deals directly still works and
-- still sends nothing, which is the correct behaviour for a hand-fixed
-- row and matches how the order functions behave.
--
-- Who counts as watching:
--
--   wishlisted   the product is in their wishlist. An explicit act.
--   viewed       three or more views of that product, which on the
--                current data is 31 customer-product pairs against 103
--                at two views. Two views is a mis-click and a second
--                look; three is somebody deciding.
--
-- Whoever qualifies both ways is told once, as a wishlist watcher, since
-- that is the stronger signal and the better-worded message.
-- ============================================================

-- Where the message points. NULL for the order messages, which point at
-- an order instead, and NULL for anything later that points at neither.
ALTER TABLE public.notifications
  ADD COLUMN product_id INTEGER NULL REFERENCES public.products(product_id) ON DELETE CASCADE;

ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_kind_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_kind_check
  CHECK (kind IN ('payment_approved', 'payment_rejected', 'order_shipped', 'deal_started'));

CREATE INDEX idx_notification_product ON public.notifications (product_id);

COMMENT ON COLUMN public.notifications.product_id IS
  'The product a deal_started message is about. NULL for order messages.';


-- ============================================================
-- Creating a deal, and telling the people who were watching.
--
-- Returns the number of customers messaged, so the Timed Deals page can
-- say "Deal created. 7 customers alerted." rather than leaving staff to
-- wonder whether anything went out.
--
-- p_min_views is a parameter rather than a constant so the threshold can
-- be argued with from the call site without a migration.
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

  -- Everyone watching this product, wishlist beating repeat views where
  -- somebody is both. A customer appears once.
  WITH watchers AS (
    SELECT w.customer_id, true AS saved
    FROM public.wishlist_items w
    WHERE w.product_id = p_product_id
    UNION
    SELECT e.customer_id, false
    FROM public.events e
    WHERE e.product_id = p_product_id
      AND e.event_type = 'view'
      AND e.customer_id IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM public.wishlist_items w2
                      WHERE w2.product_id = p_product_id AND w2.customer_id = e.customer_id)
    GROUP BY e.customer_id
    HAVING count(*) >= p_min_views
  )
  INSERT INTO public.notifications (customer_id, product_id, kind, title, body)
  SELECT
    watchers.customer_id,
    p_product_id,
    'deal_started',
    CASE WHEN watchers.saved
         THEN 'Price drop on something you saved'
         ELSE 'Something you looked at is on offer' END,
    v_product_name || ' is now RM ' || to_char(p_discount_price, 'FM999G999D00') ||
    ', down from RM ' || to_char(v_was, 'FM999G999D00') || '. ' ||
    CASE WHEN p_start_time > now()
         THEN 'The offer starts ' || to_char(p_start_time AT TIME ZONE 'Asia/Kuala_Lumpur', 'FMDay DD Mon') || '.'
         ELSE 'The offer ends ' || to_char(p_end_time   AT TIME ZONE 'Asia/Kuala_Lumpur', 'FMDay DD Mon') || '.'
    END
  FROM watchers;

  GET DIAGNOSTICS v_told = ROW_COUNT;
  RETURN v_told;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_create_deal(integer, numeric, timestamptz, timestamptz, integer) FROM public, anon;
GRANT  EXECUTE ON FUNCTION public.admin_create_deal(integer, numeric, timestamptz, timestamptz, integer) TO authenticated;
