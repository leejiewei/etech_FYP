-- ============================================================
-- Orders: which stage may follow which, and no goods before money.
--
-- Found in Chapter 4 testing (Figures 4.21, 4.27, 4.28, 4.34): a
-- delivery order reached Delivered while its bank-transfer receipt was
-- still unchecked, and a collection order sat at Ready with no receipt
-- at all. admin_set_order_status() wrote whatever stage it was handed,
-- from whatever stage the order was at, and never looked at the money.
-- The staff page's dropdown offered every stage, so one wrong pick was
-- enough.
--
-- The rules live in a trigger on orders rather than in the function,
-- because "staff manage orders" also lets a signed-in member of staff
-- UPDATE the table directly; a check only in the function would be a
-- check in one of two doors.
--
-- The ladder (the top two rungs read Shipped/Delivered for a delivery,
-- Ready to collect/Collected for a collection -- see js/fulfilment.js):
--
--   Pending -> Processing -> Ready -> Collected
--   Pending, Processing or Ready -> Cancelled
--   Ready -> Processing            (marked ready by mistake)
--   Processing -> Pending          (only when the payment is rejected)
--
-- Collected and Cancelled are final. Processing, Ready and Collected
-- need the payment APPROVED, for every order that has a payment at all;
-- the old card-sandbox orders (payment_method NULL) never asked for one.
--
-- Nothing already in the table is rewritten. An order that got past a
-- stage without a checked payment keeps its stage and its history; it
-- simply cannot move further until the payment is approved.
-- ============================================================

CREATE OR REPLACE FUNCTION public.orders_enforce_workflow()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
  v_paid boolean := NEW.payment_method IS NULL OR NEW.payment_status = 'APPROVED';
BEGIN
  -- ---- The payment track ----
  IF NEW.payment_status IS DISTINCT FROM OLD.payment_status THEN
    -- Approving and rejecting are both a verdict on a receipt; with none
    -- uploaded there is nothing to judge. (A customer's own upload sets
    -- PENDING, which needs no receipt check.)
    IF NEW.payment_status IN ('APPROVED', 'REJECTED') AND NEW.receipt_image_path IS NULL
       AND NEW.payment_method IS NOT NULL THEN
      RAISE EXCEPTION 'There is no receipt to check yet.' USING ERRCODE = 'P0001';
    END IF;
    -- Once the goods have left, saying the money never arrived is a
    -- conversation with the customer, not a button.
    IF NEW.payment_status = 'REJECTED' AND OLD.status IN ('Ready', 'Collected') THEN
      RAISE EXCEPTION 'This order has already been handed over or sent, so its payment can no longer be rejected here.'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  -- ---- The goods track ----
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF OLD.status IN ('Collected', 'Cancelled') THEN
      RAISE EXCEPTION 'Order #% is already %, so its stage cannot change.',
        OLD.order_id, lower(OLD.status::text) USING ERRCODE = 'P0001';
    END IF;

    IF NOT (
         (OLD.status = 'Pending'    AND NEW.status IN ('Processing', 'Cancelled'))
      OR (OLD.status = 'Processing' AND NEW.status IN ('Ready', 'Cancelled'))
      OR (OLD.status = 'Processing' AND NEW.status = 'Pending' AND NEW.payment_status = 'REJECTED')
      OR (OLD.status = 'Ready'      AND NEW.status IN ('Collected', 'Processing', 'Cancelled'))
    ) THEN
      RAISE EXCEPTION 'Order #% cannot go from % to %. Move it one stage at a time.',
        OLD.order_id, OLD.status, NEW.status USING ERRCODE = 'P0001';
    END IF;

    IF NEW.status IN ('Processing', 'Ready', 'Collected') AND NOT v_paid THEN
      RAISE EXCEPTION 'Approve the payment for order #% first. It cannot be prepared, sent or handed over until the receipt has been checked.',
        OLD.order_id USING ERRCODE = 'P0001';
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_orders_enforce_workflow ON public.orders;
CREATE TRIGGER trg_orders_enforce_workflow
  BEFORE UPDATE OF status, payment_status ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.orders_enforce_workflow();

-- A delivered delivery order now tells the customer too.
ALTER TABLE public.notifications DROP CONSTRAINT notifications_kind_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_kind_check
  CHECK (kind IN ('payment_approved', 'payment_rejected', 'order_ready',
                  'order_delivered', 'deal_started', 'recommendation'));

-- ------------------------------------------------------------
-- Moving an order along. The trigger decides whether the move is
-- allowed; this records who made it and tells the customer.
--
-- Each message goes once per order. Before this, an order taken from
-- Ready back to Processing and forward again sent "ready to collect" a
-- second time (6 order_ready rows for 5 orders on 28 Oct).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_set_order_status(p_order_id integer, p_status public.order_status, p_note text DEFAULT NULL::text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
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

  IF p_status = v_before THEN
    RAISE EXCEPTION 'Order #% is already at that stage.', p_order_id USING ERRCODE = 'P0001';
  END IF;

  -- The trigger refuses anything out of order or unpaid.
  UPDATE public.orders SET status = p_status WHERE order_id = p_order_id;

  INSERT INTO public.order_status_history (order_id, status, changed_by, note)
  VALUES (p_order_id, p_status, v_admin, NULLIF(btrim(COALESCE(p_note, '')), ''));

  IF p_status = 'Ready' AND NOT EXISTS (
       SELECT 1 FROM public.notifications n
       WHERE n.order_id = p_order_id AND n.kind = 'order_ready') THEN
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

  -- A collection ends with the customer at the counter, so only a
  -- delivery needs telling that it has arrived.
  IF p_status = 'Collected' AND v_fulfil = 'DELIVERY' AND NOT EXISTS (
       SELECT 1 FROM public.notifications n
       WHERE n.order_id = p_order_id AND n.kind = 'order_delivered') THEN
    INSERT INTO public.notifications (customer_id, order_id, kind, title, body)
    VALUES (v_customer, p_order_id, 'order_delivered',
            'Your order has been delivered',
            'Order #' || p_order_id || ' has been delivered. Thank you for '
            || 'shopping with eTech.');
  END IF;
END;
$function$;

-- ------------------------------------------------------------
-- Approving or rejecting a payment.
--
-- Approving a Pending order moves it to Processing, as before. Rejecting
-- the payment of an order already being prepared stops it: back to
-- Pending until a receipt that matches arrives. "Payment received" goes
-- once per order; a rejection goes each time a receipt is turned down,
-- since each is a new receipt the customer needs to hear about.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_set_payment_status(p_order_id integer, p_status public.payment_status, p_note text DEFAULT NULL::text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_admin    integer;
  v_status   public.order_status;
  v_before   public.payment_status;
  v_customer integer;
  v_after    public.order_status;
BEGIN
  SELECT a.admin_id INTO v_admin
  FROM public.admins a WHERE a.auth_user_id = auth.uid();

  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'Staff access only.' USING ERRCODE = '42501';
  END IF;

  SELECT o.payment_status, o.status, o.customer_id INTO v_before, v_status, v_customer
  FROM public.orders o WHERE o.order_id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'That order no longer exists.' USING ERRCODE = 'P0001';
  END IF;

  IF v_status = 'Cancelled' THEN
    RAISE EXCEPTION 'Order #% was cancelled.', p_order_id USING ERRCODE = 'P0001';
  END IF;

  IF p_status = 'PENDING' THEN
    RAISE EXCEPTION 'Choose approve or reject.' USING ERRCODE = 'P0001';
  END IF;

  v_after := CASE
    WHEN p_status = 'APPROVED' AND v_status = 'Pending'    THEN 'Processing'
    WHEN p_status = 'REJECTED' AND v_status = 'Processing' THEN 'Pending'
    ELSE v_status
  END;

  -- One statement, so the trigger sees the new payment and the new stage
  -- together.
  UPDATE public.orders SET payment_status = p_status, status = v_after
  WHERE order_id = p_order_id;

  INSERT INTO public.order_status_history (order_id, status, changed_by, note)
  VALUES (p_order_id, v_after, v_admin,
          COALESCE(NULLIF(btrim(COALESCE(p_note, '')), ''),
                   'Payment ' || lower(p_status::text)));

  IF p_status IS DISTINCT FROM v_before THEN
    IF p_status = 'APPROVED' AND NOT EXISTS (
         SELECT 1 FROM public.notifications n
         WHERE n.order_id = p_order_id AND n.kind = 'payment_approved') THEN
      INSERT INTO public.notifications (customer_id, order_id, kind, title, body)
      VALUES (v_customer, p_order_id, 'payment_approved',
              'Payment received',
              'We have confirmed your payment for order #' || p_order_id ||
              CASE WHEN v_status = 'Pending'
                   THEN '. We are preparing it now.'
                   ELSE '.' END);
    ELSIF p_status = 'REJECTED' THEN
      INSERT INTO public.notifications (customer_id, order_id, kind, title, body)
      VALUES (v_customer, p_order_id, 'payment_rejected',
              'Please send another receipt',
              'We could not match your receipt to order #' || p_order_id ||
              '. Please upload a clear photo showing the amount and the date.');
    END IF;
  END IF;
END;
$function$;

-- ------------------------------------------------------------
-- A customer attaching a receipt. Unchanged except that a cancelled
-- order no longer takes one. It never approves anything: the payment
-- goes (back) to PENDING, which staff see as "Receipt sent - check it".
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.attach_payment_receipt(p_order_id integer, p_path text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_customer integer := public.current_customer_id();
  v_status   public.payment_status;
  v_stage    public.order_status;
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

  SELECT o.payment_status, o.status INTO v_status, v_stage
  FROM public.orders o
  WHERE o.order_id = p_order_id AND o.customer_id = v_customer;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'That order could not be found.' USING ERRCODE = 'P0001';
  END IF;

  IF v_status = 'APPROVED' THEN
    RAISE EXCEPTION 'This payment has already been approved.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_stage = 'Cancelled' THEN
    RAISE EXCEPTION 'This order was cancelled, so no payment is needed.'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.orders
  SET receipt_image_path = btrim(p_path),
      payment_status     = 'PENDING'
  WHERE order_id = p_order_id AND customer_id = v_customer;
END;
$function$;
