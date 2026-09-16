-- ============================================================
-- Collect it, or have it sent.
--
-- This morning the shop was made collection-only, on the grounds that it
-- has a counter and not a courier account. That was half right. The owner
-- does both: most orders are picked up at Bukit Jambul, and some are
-- sent. So delivery comes back -- not as the assumption it used to be,
-- but as a choice the customer makes at checkout, next to a choice that
-- now genuinely exists.
--
-- ------------------------------------------------------------
-- One stage list, two vocabularies
--
-- The tempting design is to add Shipped and Delivered back beside Ready
-- and Collected, giving seven stages. It is the wrong one. Staff would
-- get a dropdown where two entries are meaningless for whichever order
-- they are looking at, and every report grouping by status would have to
-- know that Ready and Shipped are the same rung of the same ladder.
--
-- So the ladder keeps four rungs and the *words* change with the method:
--
--   stage        PICKUP             DELIVERY
--   Pending      Pending            Pending
--   Processing   Processing         Processing
--   Ready        Ready to collect   Shipped
--   Collected    Collected          Delivered
--
-- That translation is a presentation concern and lives in the clients.
-- What lives here is the fact the clients translate against:
-- orders.fulfilment_method.
--
-- ------------------------------------------------------------
-- What each method requires
--
-- DELIVERY needs somewhere to send it, so the address becomes required
-- again -- but only for that method. PICKUP needs nobody's address and
-- still refuses an order without a phone number, because a phone number
-- is how the shop says the thing is on the counter.
-- ============================================================


-- ------------------------------------------------------------
-- 1. The method itself
-- ------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'fulfilment_method') THEN
    CREATE TYPE public.fulfilment_method AS ENUM ('PICKUP', 'DELIVERY');
  END IF;
END
$$;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS fulfilment_method public.fulfilment_method
  NOT NULL DEFAULT 'PICKUP';

-- The orders that already exist were placed when the checkout asked for
-- an address and would not proceed without one, so the ones carrying an
-- address were, by the only definition available at the time, deliveries.
-- Marking them PICKUP would be tidier and would also be a lie about what
-- the customer was told when they placed it.
UPDATE public.orders
SET fulfilment_method = 'DELIVERY'
WHERE shipping_address IS NOT NULL
  AND btrim(shipping_address) <> ''
  AND fulfilment_method = 'PICKUP';


-- ------------------------------------------------------------
-- 2. Staff need to see which it is
--
-- Restated whole because CREATE OR REPLACE VIEW can only append columns
-- and the option has to be respelled: security_invoker=on is what makes
-- the policies on orders apply to whoever is reading, and dropping it
-- here would quietly turn this view into a definer view.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW public.admin_orders
WITH (security_invoker = on) AS
SELECT o.order_id,
       o.order_date,
       o.status,
       o.subtotal,
       o.discount,
       o.total,
       o.coupon_code,
       o.shipping_name,
       o.shipping_phone,
       o.shipping_address,
       o.customer_id,
       c.name  AS customer_name,
       c.email AS customer_email,
       o.payment_method,
       o.payment_status,
       o.receipt_image_path,
       o.fulfilment_method
FROM public.orders o
JOIN public.customers c ON c.customer_id = o.customer_id;


-- ------------------------------------------------------------
-- 3. Placing an order, with a method attached
--
-- The signature gains p_fulfilment, which means DROP and CREATE rather
-- than CREATE OR REPLACE: a different argument count is a different
-- function, and replacing in place would leave the five-argument version
-- standing beside it. Two overloads both reachable by five named
-- arguments is not an ambiguity Postgres resolves -- it is an error at
-- every call site.
--
-- Dropping it does mean re-granting EXECUTE, which is done at the bottom
-- of this file. The whole migration is one transaction, so there is no
-- moment where the function exists ungranted.
--
-- ------------------------------------------------------------
-- p_fulfilment defaults to NULL rather than to 'PICKUP', and that is
-- load-bearing.
--
-- An APK already on somebody's phone calls this with five named
-- arguments including a real address typed into a field labelled
-- "Shipping address". Defaulting the missing sixth to PICKUP would file
-- that as a collection and quietly throw away the address the customer
-- went to the trouble of typing. So NULL means "the caller did not say",
-- and the function decides the only way it honestly can: an address was
-- given, so it is a delivery.
--
-- Today's web and today's app both send it explicitly and never rely on
-- that inference.
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS public.place_order(text, text, text, text, text);

CREATE FUNCTION public.place_order(
  p_name text,
  p_phone text,
  p_address text default null,
  p_coupon text default null,
  p_payment_method text default 'BANK_TRANSFER',
  p_fulfilment text default null            -- NULL means "caller did not say"
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
DECLARE
  v_customer integer := public.current_customer_id();
  v_name     text    := btrim(COALESCE(p_name, ''));
  v_phone    text    := btrim(COALESCE(p_phone, ''));
  v_address  text    := btrim(COALESCE(p_address, ''));
  v_code     text    := upper(btrim(COALESCE(p_coupon, '')));
  v_method   text    := upper(btrim(COALESCE(p_payment_method, 'BANK_TRANSFER')));
  v_fulfil   text    := upper(btrim(COALESCE(p_fulfilment, '')));
  v_percent  numeric := 0;
  v_applied  text    := NULL;
  v_subtotal numeric := 0;
  v_discount numeric := 0;
  v_total    numeric := 0;
  v_order_id integer;
  v_lines    integer;
BEGIN
  IF v_customer IS NULL THEN
    RAISE EXCEPTION 'Please log in first.' USING ERRCODE = '42501';
  END IF;

  -- An older client that says nothing: an address means they meant it to
  -- be sent somewhere, no address means they did not.
  IF v_fulfil = '' THEN
    v_fulfil := CASE WHEN v_address <> '' THEN 'DELIVERY' ELSE 'PICKUP' END;
  END IF;

  IF v_fulfil NOT IN ('PICKUP', 'DELIVERY') THEN
    RAISE EXCEPTION 'Please choose collection or delivery.' USING ERRCODE = 'P0001';
  END IF;

  -- The phone number is required either way. It is how the shop says the
  -- order is on the counter, and how the driver finds the gate.
  IF v_name = '' OR v_phone = '' THEN
    RAISE EXCEPTION 'Please fill in your name and phone number.' USING ERRCODE = 'P0001';
  END IF;

  -- The address is required for one method and meaningless for the other.
  IF v_fulfil = 'DELIVERY' AND v_address = '' THEN
    RAISE EXCEPTION 'Please give us an address to deliver to.' USING ERRCODE = 'P0001';
  END IF;

  -- Not merely ignored for a collection -- actively dropped, so a stray
  -- address cannot ride along on an order nobody is delivering.
  IF v_fulfil = 'PICKUP' THEN
    v_address := '';
  END IF;

  -- Checked here rather than left to the cast, so a bad value comes back
  -- as a sentence a customer can read instead of "invalid input value
  -- for enum".
  IF v_method NOT IN ('QR_CODE', 'BANK_TRANSFER') THEN
    RAISE EXCEPTION 'Please choose how you are paying.' USING ERRCODE = 'P0001';
  END IF;

  -- One line is still one line however many upgrades hang off it, so
  -- COUNT(*) counts cart_items and the upgrades only reach the money.
  --
  -- The deal is read here, not sent up from the phone. This function is
  -- SECURITY DEFINER and so is not subject to the policy on deals, which
  -- is why the window is spelled out again in the subquery.
  SELECT COUNT(*),
         COALESCE(SUM((LEAST(p.price, dl.discount_price) + COALESCE(x.extra, 0)) * c.quantity), 0)
    INTO v_lines, v_subtotal
  FROM public.cart_items c
  JOIN public.products p ON p.product_id = c.product_id
  LEFT JOIN LATERAL (
    SELECT MIN(d.discount_price) AS discount_price
    FROM public.deals d
    WHERE d.product_id = c.product_id
      AND d.is_active = 1
      AND d.start_time <= now()
      AND d.end_time > now()
  ) dl ON true
  LEFT JOIN LATERAL (
    SELECT SUM(pu.price_delta) AS extra
    FROM public.cart_item_upgrades ciu
    JOIN public.prebuilt_upgrades pu ON pu.upgrade_id = ciu.upgrade_id
    WHERE ciu.customer_id = c.customer_id
      AND ciu.product_id  = c.product_id
  ) x ON true
  WHERE c.customer_id = v_customer;

  IF v_lines = 0 THEN
    RAISE EXCEPTION 'Your cart is empty.' USING ERRCODE = 'P0001';
  END IF;

  IF v_code <> '' THEN
    SELECT co.code, co.discount_percent INTO v_applied, v_percent
    FROM public.coupons co
    WHERE co.code = v_code
      AND co.is_active = 1
      AND co.starts_at <= now()
      AND (co.ends_at IS NULL OR co.ends_at >= now());

    IF NOT FOUND THEN
      v_applied := NULL;
      v_percent := 0;
    END IF;
  END IF;

  v_discount := round(v_subtotal * v_percent / 100, 2);
  v_total    := v_subtotal - v_discount;

  -- payment_status takes its PENDING default. Nobody has looked at the
  -- money yet, and that is exactly what the column is for.
  INSERT INTO public.orders
    (customer_id, subtotal, discount, total, coupon_code,
     shipping_name, shipping_phone, shipping_address, payment_method,
     fulfilment_method)
  VALUES
    (v_customer, v_subtotal, v_discount, v_total, v_applied,
     v_name, NULLIF(v_phone, ''), NULLIF(v_address, ''),
     v_method::public.payment_method,
     v_fulfil::public.fulfilment_method)
  RETURNING order_id INTO v_order_id;

  -- The machines and everything else, at the price they were sold for.
  INSERT INTO public.order_items
    (order_id, product_id, product_name, unit_price, quantity, line_total)
  SELECT v_order_id,
         p.product_id,
         p.name,
         LEAST(p.price, dl.discount_price),
         c.quantity,
         LEAST(p.price, dl.discount_price) * c.quantity
  FROM public.cart_items c
  JOIN public.products p ON p.product_id = c.product_id
  LEFT JOIN LATERAL (
    SELECT MIN(d.discount_price) AS discount_price
    FROM public.deals d
    WHERE d.product_id = c.product_id
      AND d.is_active = 1
      AND d.start_time <= now()
      AND d.end_time > now()
  ) dl ON true
  WHERE c.customer_id = v_customer;

  -- The upgrades, one line each, named so an invoice reads properly.
  -- A deal is on the machine, not on the option bolted to it, so these
  -- are untouched.
  INSERT INTO public.order_items
    (order_id, product_id, product_name, unit_price, quantity, line_total)
  SELECT v_order_id,
         NULL,
         p.name || ' + ' || pu.label,
         pu.price_delta,
         c.quantity,
         pu.price_delta * c.quantity
  FROM public.cart_items c
  JOIN public.products p ON p.product_id = c.product_id
  JOIN public.cart_item_upgrades ciu
    ON ciu.customer_id = c.customer_id
   AND ciu.product_id  = c.product_id
  JOIN public.prebuilt_upgrades pu ON pu.upgrade_id = ciu.upgrade_id
  WHERE c.customer_id = v_customer;

  INSERT INTO public.events (customer_id, product_id, event_type)
  SELECT v_customer, c.product_id, 'purchase'
  FROM public.cart_items c
  WHERE c.customer_id = v_customer;

  -- cart_item_upgrades is keyed on the basket line and cascades, so the
  -- ticks go with it.
  DELETE FROM public.cart_items WHERE customer_id = v_customer;

  RETURN jsonb_build_object(
    'orderId',   v_order_id,
    'subtotal',  v_subtotal,
    'discount',  v_discount,
    'total',     v_total,
    'coupon',    v_applied,
    'paymentMethod', v_method,
    'fulfilment',    v_fulfil
  );
END;
$function$;

-- Put back what DROP took away. Same shape as every other customer-facing
-- function here: nothing for anon, execute for a signed-in customer.
REVOKE EXECUTE ON FUNCTION
  public.place_order(text, text, text, text, text, text) FROM public, anon;
GRANT EXECUTE ON FUNCTION
  public.place_order(text, text, text, text, text, text) TO authenticated;


-- ------------------------------------------------------------
-- 4. The message when it moves
--
-- One stage, two things worth saying. The version from this morning
-- always said the order was waiting at the shop, which is the wrong news
-- entirely for somebody who asked for it to be sent.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_set_order_status(
  p_order_id integer,
  p_status   public.order_status,
  p_note     text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin    integer;
  v_before   public.order_status;
  v_customer integer;
  v_fulfil   public.fulfilment_method;
BEGIN
  SELECT a.admin_id INTO v_admin
  FROM public.admins a WHERE a.auth_user_id = auth.uid();

  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'Staff access only.' USING ERRCODE = '42501';
  END IF;

  -- FOR UPDATE so two members of staff pressing the same button at once
  -- cannot both read "Processing" and both send the message.
  SELECT o.status, o.customer_id, o.fulfilment_method
    INTO v_before, v_customer, v_fulfil
  FROM public.orders o WHERE o.order_id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'That order no longer exists.' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.orders SET status = p_status WHERE order_id = p_order_id;

  INSERT INTO public.order_status_history (order_id, status, changed_by, note)
  VALUES (p_order_id, p_status, v_admin, NULLIF(btrim(COALESCE(p_note, '')), ''));

  IF p_status = 'Ready' AND v_before IS DISTINCT FROM 'Ready' THEN
    IF v_fulfil = 'DELIVERY' THEN
      INSERT INTO public.notifications (customer_id, order_id, kind, title, body)
      VALUES (v_customer, p_order_id, 'order_ready',
              'Your order is on its way',
              'Order #' || p_order_id || ' has been sent to the address you '
              || 'gave us.');
    ELSE
      INSERT INTO public.notifications (customer_id, order_id, kind, title, body)
      VALUES (v_customer, p_order_id, 'order_ready',
              'Your order is ready to collect',
              'Order #' || p_order_id || ' is packed and waiting at the shop. '
              || 'Bring your order number with you.');
    END IF;
  END IF;
END;
$$;
