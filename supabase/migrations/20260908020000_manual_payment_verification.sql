-- ============================================================
-- Paying for real, and somebody checking that you did.
--
-- Checkout has until now been a mock card sandbox: sixteen digits that
-- went nowhere, a confirmation that said in as many words that no money
-- had moved. That was the right thing to build first -- a student
-- project has no merchant account -- but it left the shop unable to
-- take a single ringgit.
--
-- What a small Malaysian shop actually does instead of a gateway is
-- this: show a DuitNow QR or a bank account, let the customer pay from
-- their own banking app, have them send the transfer receipt, and have
-- somebody look at it. So that is what this builds. The order carries
-- how it was meant to be paid, whether the payment has been checked
-- yet, and where the photograph of the receipt is.
--
-- The important line is between the two halves:
--
--   status          where the goods are.       Pending -> Processing ->
--                                              Shipped -> Delivered
--   payment_status  whether the money arrived. PENDING -> APPROVED
--                                              or REJECTED
--
-- They are not the same question and they must not share a column. An
-- order can be paid and not yet packed, or packed and never paid, and a
-- shop that cannot say which is which cannot chase either.
-- ============================================================

CREATE TYPE public.payment_method AS ENUM ('QR_CODE', 'BANK_TRANSFER');
CREATE TYPE public.payment_status AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

ALTER TABLE public.orders
  -- Nullable, and a NULL means something: this order was placed before
  -- the shop could be paid, through the card sandbox. Filling those in
  -- with a method nobody used would be inventing a record.
  ADD COLUMN payment_method public.payment_method NULL,
  ADD COLUMN payment_status public.payment_status NOT NULL DEFAULT 'PENDING',
  -- The path of the object inside the payment-receipts bucket, not a
  -- URL. The bucket is private, so a URL would be a signed one that
  -- expires, and storing an expired link is storing nothing.
  ADD COLUMN receipt_image_path VARCHAR(255) NULL;

-- The orders that already exist were placed through the sandbox and
-- were worked through to Shipped and Delivered on the understanding
-- that they were settled. Leaving them at the PENDING default would
-- open this feature with a queue of historical orders waiting for a
-- receipt that was never asked for and does not exist.
UPDATE public.orders SET payment_status = 'APPROVED';

CREATE INDEX idx_order_payment_status ON public.orders (payment_status);


-- ============================================================
-- Somewhere to put the receipts.
--
-- Unlike product-images this bucket is NOT public. A product photo on a
-- shop front is about as public as a thing gets; a bank transfer receipt
-- has a name, an account number and an amount on it, and belongs to one
-- customer and the shop.
--
-- So reads are policed as well as writes, and the object's path is what
-- decides: everything a customer uploads goes under a folder named after
-- their customer_id, and the policies compare that folder against
-- current_customer_id(). Staff are allowed the whole bucket.
--
-- A customer may add receipts and may not delete or overwrite them. If
-- staff reject one, they upload another and both remain -- which is what
-- anybody looking into a dispute afterwards would want to find.
-- ============================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'payment-receipts',
  'payment-receipts',
  false,
  5242880,                                        -- 5MB, as for product photos
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "customers add their own receipts" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'payment-receipts'
    AND (storage.foldername(name))[1] = (SELECT public.current_customer_id())::text
  );

CREATE POLICY "customers read their own receipts" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'payment-receipts'
    AND (storage.foldername(name))[1] = (SELECT public.current_customer_id())::text
  );

CREATE POLICY "staff read every receipt" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'payment-receipts' AND (SELECT public.is_admin()));

CREATE POLICY "staff remove receipts" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'payment-receipts' AND (SELECT public.is_admin()));


-- ============================================================
-- Attaching a receipt to an order.
--
-- Through a function rather than an UPDATE, because a customer has no
-- UPDATE on orders at all and should not gain one. Handing out "you may
-- write to your own order row" to set one column would also hand out
-- the ability to write to shipping_address after dispatch, or to total.
--
-- Three things are checked, and all three are the point:
--
--   * the order is this customer's. Not "the app sent the right id" --
--     the id is read from the session on this side.
--   * the payment has not already been approved. A receipt swapped in
--     after the money was checked is the one thing this whole feature
--     exists to prevent.
--   * the path is inside this customer's own folder, so a valid caller
--     cannot point their order at somebody else's receipt.
--
-- A rejected payment may be re-receipted. That is the recovery path
-- for a blurred photo or the wrong screenshot, and the reason REJECTED
-- goes back to PENDING here rather than being final.
-- ============================================================
CREATE OR REPLACE FUNCTION public.attach_payment_receipt(
  p_order_id integer,
  p_path     text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_customer integer := public.current_customer_id();
  v_status   public.payment_status;
BEGIN
  IF v_customer IS NULL THEN
    RAISE EXCEPTION 'Please log in first.' USING ERRCODE = '42501';
  END IF;

  IF p_path IS NULL OR btrim(p_path) = '' THEN
    RAISE EXCEPTION 'No receipt was uploaded.' USING ERRCODE = 'P0001';
  END IF;

  IF split_part(p_path, '/', 1) <> v_customer::text THEN
    RAISE EXCEPTION 'That receipt does not belong to this account.'
      USING ERRCODE = '42501';
  END IF;

  SELECT o.payment_status INTO v_status
  FROM public.orders o
  WHERE o.order_id = p_order_id AND o.customer_id = v_customer;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'That order could not be found.' USING ERRCODE = 'P0001';
  END IF;

  IF v_status = 'APPROVED' THEN
    RAISE EXCEPTION 'This payment has already been approved.'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.orders
  SET receipt_image_path = btrim(p_path),
      payment_status     = 'PENDING'
  WHERE order_id = p_order_id AND customer_id = v_customer;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.attach_payment_receipt(integer, text) FROM public, anon;
GRANT  EXECUTE ON FUNCTION public.attach_payment_receipt(integer, text) TO authenticated;


-- ============================================================
-- Staff saying yes or no.
--
-- Approving a payment moves the order on as well. An order sitting at
-- Pending with the money confirmed is a job somebody still has to
-- notice; Processing is what Pending means once the payment is in, and
-- the move is written into order_status_history like every other status
-- change so the trail is unbroken.
--
-- Rejecting does not cancel the order. A rejected receipt is usually a
-- blurred photo or the wrong screenshot rather than a customer who never
-- paid, and cancelling on the first bad picture would throw away an
-- order that is about to be fine. The customer uploads another and it
-- comes back to PENDING. Cancelling stays a separate, deliberate act on
-- the Orders page.
-- ============================================================
CREATE OR REPLACE FUNCTION public.admin_set_payment_status(
  p_order_id integer,
  p_status   public.payment_status,
  p_note     text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin  integer;
  v_status public.order_status;
BEGIN
  SELECT a.admin_id INTO v_admin
  FROM public.admins a WHERE a.auth_user_id = auth.uid();

  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'Staff access only.' USING ERRCODE = '42501';
  END IF;

  UPDATE public.orders
  SET payment_status = p_status
  WHERE order_id = p_order_id
  RETURNING status INTO v_status;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'That order no longer exists.' USING ERRCODE = 'P0001';
  END IF;

  IF p_status = 'APPROVED' AND v_status = 'Pending' THEN
    UPDATE public.orders SET status = 'Processing' WHERE order_id = p_order_id;

    INSERT INTO public.order_status_history (order_id, status, changed_by, note)
    VALUES (p_order_id, 'Processing', v_admin,
            COALESCE(NULLIF(btrim(COALESCE(p_note, '')), ''), 'Payment approved'));
  ELSE
    INSERT INTO public.order_status_history (order_id, status, changed_by, note)
    VALUES (p_order_id, v_status, v_admin,
            COALESCE(NULLIF(btrim(COALESCE(p_note, '')), ''),
                     'Payment ' || lower(p_status::text)));
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_set_payment_status(integer, public.payment_status, text)
  FROM public, anon;
GRANT  EXECUTE ON FUNCTION public.admin_set_payment_status(integer, public.payment_status, text)
  TO authenticated;


-- ============================================================
-- What the Orders page reads, with the payment on it.
--
-- CREATE OR REPLACE keeps the existing columns in place and appends the
-- three new ones, so nothing that already reads this view has to change.
-- ============================================================
CREATE OR REPLACE VIEW public.admin_orders WITH (security_invoker = on) AS
SELECT
  o.order_id, o.order_date, o.status, o.subtotal, o.discount, o.total,
  o.coupon_code, o.shipping_name, o.shipping_phone, o.shipping_address,
  o.customer_id,
  c.name  AS customer_name,
  c.email AS customer_email,
  o.payment_method,
  o.payment_status,
  o.receipt_image_path
FROM public.orders o
JOIN public.customers c ON c.customer_id = o.customer_id;


-- ============================================================
-- The till, again.
--
-- One change: the order records how it is going to be paid. The
-- argument has a default, so the two clients that do not yet send it
-- keep working and record a bank transfer, which is what the shop's own
-- details on the checkout page describe.
--
-- Everything else is the deal-aware version from
-- 20260908010000_timed_deals.sql, unchanged. It is restated in full
-- rather than patched, because a function is replaced whole and half a
-- definition is not a thing Postgres will accept.
-- ============================================================
DROP FUNCTION IF EXISTS public.place_order(text, text, text, text);

CREATE FUNCTION public.place_order(
  p_name text,
  p_phone text,
  p_address text,
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

  IF v_name = '' OR v_address = '' THEN
    RAISE EXCEPTION 'Please fill in your delivery details.' USING ERRCODE = 'P0001';
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
     v_name, NULLIF(v_phone, ''), v_address, v_method::public.payment_method)
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

REVOKE EXECUTE ON FUNCTION public.place_order(text, text, text, text, text) FROM public, anon;
GRANT  EXECUTE ON FUNCTION public.place_order(text, text, text, text, text) TO authenticated;
