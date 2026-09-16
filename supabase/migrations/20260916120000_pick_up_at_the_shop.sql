-- ============================================================
-- The shop does not deliver. It never did.
--
-- Every screen in this project was written as though a parcel left the
-- building: checkout asked for a shipping address and would not accept
-- an order without one, the stages ran Pending -> Processing -> Shipped
-- -> Delivered, and the message a customer got said "your order is on
-- its way". None of that is true. eTech is a shop with a counter, and
-- what actually happens is that the order is put aside and the customer
-- walks in and collects it.
--
-- So this migration changes three things, and deliberately changes no
-- data beyond the words used to describe it:
--
--   1. The two middle stages are renamed. Shipped -> Ready,
--      Delivered -> Collected. ALTER TYPE ... RENAME VALUE rewrites the
--      label, not the rows: every existing order keeps the stage it was
--      already at, because an enum column stores a reference to the
--      value and not the text of it. Nothing needs backfilling and
--      nothing can be half-converted.
--
--   2. The notification kind follows. 'order_shipped' becomes
--      'order_ready', and the messages already sent are relabelled with
--      it so the bell does not show two icons for one thing. Their
--      titles and bodies are left exactly as they were sent -- those are
--      a record of what the shop told somebody on a particular day, and
--      rewriting history to be less embarrassing is not a migration.
--
--   3. place_order() stops insisting on an address.
--
-- ------------------------------------------------------------
-- Why shipping_address survives, and why p_address survives with it
--
-- The column stays. It holds the address every order before today was
-- placed against, and those rows are the sales history Objective 2 is
-- trained on; dropping a column to tidy up a word is how a dataset
-- quietly loses a year.
--
-- The argument stays too, and that one is about the Android build.
-- The website updates the moment Vercel deploys, but an APK already on
-- somebody's phone does not, and that copy calls place_order with five
-- named arguments. Remove p_address and every one of those installs
-- starts failing at the Place Order button with "function does not
-- exist". So it keeps its place in the signature, gains a default of
-- NULL, and is simply no longer asked for or required. New clients omit
-- it; old ones send an address and it is stored, which is harmless.
--
-- What changes instead is which field the shop refuses an order without.
-- It was the address. It is now the phone number, because a phone number
-- is how a shop tells somebody their machine is on the counter.
-- ============================================================


-- ------------------------------------------------------------
-- 1. The stages
-- ------------------------------------------------------------
-- Guarded so re-running this file is not an error. RENAME VALUE has no
-- IF EXISTS of its own.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'order_status' AND e.enumlabel = 'Shipped'
  ) THEN
    ALTER TYPE public.order_status RENAME VALUE 'Shipped' TO 'Ready';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'order_status' AND e.enumlabel = 'Delivered'
  ) THEN
    ALTER TYPE public.order_status RENAME VALUE 'Delivered' TO 'Collected';
  END IF;
END
$$;


-- ------------------------------------------------------------
-- 2. The notification kind
-- ------------------------------------------------------------
-- Order matters here, and the obvious order is the wrong one. The new
-- constraint does not permit 'order_shipped', so putting it on before the
-- rows have moved fails on the messages already sent. The old constraint
-- comes off first, the rows move while nothing is policing the column,
-- and the new constraint goes on last over values that already satisfy
-- it -- which is also why it can be validated immediately.
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_kind_check;

UPDATE public.notifications SET kind = 'order_ready' WHERE kind = 'order_shipped';

ALTER TABLE public.notifications ADD CONSTRAINT notifications_kind_check
  CHECK (kind IN ('payment_approved', 'payment_rejected', 'order_ready', 'deal_started'));


-- ------------------------------------------------------------
-- 3. Moving an order along
--
-- The version from 20260911090000_order_notifications.sql with the
-- stage renamed and the message rewritten. A move into Ready is still
-- the one stage change worth a message, and it is worth rather more now
-- than it was: "on its way" was something to wait for, "ready to
-- collect" is something to act on.
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
BEGIN
  SELECT a.admin_id INTO v_admin
  FROM public.admins a WHERE a.auth_user_id = auth.uid();

  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'Staff access only.' USING ERRCODE = '42501';
  END IF;

  -- FOR UPDATE so two members of staff pressing Ready at once cannot
  -- both read "Processing" and both send the message.
  SELECT o.status, o.customer_id INTO v_before, v_customer
  FROM public.orders o WHERE o.order_id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'That order no longer exists.' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.orders SET status = p_status WHERE order_id = p_order_id;

  INSERT INTO public.order_status_history (order_id, status, changed_by, note)
  VALUES (p_order_id, p_status, v_admin, NULLIF(btrim(COALESCE(p_note, '')), ''));

  IF p_status = 'Ready' AND v_before IS DISTINCT FROM 'Ready' THEN
    INSERT INTO public.notifications (customer_id, order_id, kind, title, body)
    VALUES (v_customer, p_order_id, 'order_ready',
            'Your order is ready to collect',
            'Order #' || p_order_id || ' is packed and waiting at the shop. '
            || 'Bring your order number with you.');
  END IF;
END;
$$;


-- ------------------------------------------------------------
-- 4. Placing an order
--
-- The version from 20260908020000_manual_payment_verification.sql, with
-- p_address given a default and the check moved off it and onto the
-- phone number. Restated whole rather than patched, because a function
-- is replaced whole and half a definition is not a thing Postgres will
-- accept.
--
-- CREATE OR REPLACE rather than DROP and CREATE: the signature is
-- unchanged, only a default is added, and replacing in place means the
-- grants on it are never off for a moment.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.place_order(
  p_name text,
  p_phone text,
  p_address text default null,          -- kept only so an older APK still works
  p_coupon text default null,
  p_payment_method text default 'BANK_TRANSFER'
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

  IF v_name = '' OR v_phone = '' THEN
    RAISE EXCEPTION 'Please fill in your name and phone number.' USING ERRCODE = 'P0001';
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
     shipping_name, shipping_phone, shipping_address, payment_method)
  VALUES
    (v_customer, v_subtotal, v_discount, v_total, v_applied,
     v_name, NULLIF(v_phone, ''), NULLIF(v_address, ''), v_method::public.payment_method)
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
    'orderId',  v_order_id,
    'subtotal', v_subtotal,
    'discount', v_discount,
    'total',    v_total,
    'coupon',   v_applied,
    'paymentMethod', v_method
  );
END;
$function$;

