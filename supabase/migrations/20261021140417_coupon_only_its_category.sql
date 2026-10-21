-- ------------------------------------------------------------
-- A coupon only comes off the category it is for.
--
-- Found while testing for Chapter 5 (21 Oct 2026): every coupon names a
-- category ("LAPTOP15 - 15% off all laptops"), but place_order took the
-- percentage off the whole cart. A cart holding only two RM 38 mice got
-- RM 11.40 off with LAPTOP15.
--
-- Only change from 20260926131032: v_coupon_cat / v_eligible, and the
-- discount is worked out on v_eligible instead of v_subtotal.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.place_order(p_name text, p_phone text, p_address text DEFAULT NULL::text, p_coupon text DEFAULT NULL::text, p_payment_method text DEFAULT 'BANK_TRANSFER'::text, p_fulfilment text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  v_coupon_cat integer;
  v_eligible numeric := 0;
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
    SELECT co.code, co.discount_percent, co.category_id
      INTO v_applied, v_percent, v_coupon_cat
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

  -- A coupon is for one category ("15% off all laptops"), so it only
  -- comes off the lines in that category or one of its sub-categories
  -- (PARTS10 is on Components, the SSDs sit in Storage below it). A
  -- coupon with no category is for the whole cart. A coupon none of the
  -- cart qualifies for is treated like an unknown code: no discount, and
  -- no code written on the order.
  IF v_applied IS NOT NULL THEN
    WITH RECURSIVE covered AS (
      SELECT cat.category_id
      FROM public.categories cat
      WHERE cat.category_id = v_coupon_cat
      UNION
      SELECT cat.category_id
      FROM public.categories cat
      JOIN covered cv ON cat.parent_id = cv.category_id
    )
    SELECT COALESCE(SUM((LEAST(p.price, dl.discount_price) + COALESCE(x.extra, 0)) * c.quantity), 0)
      INTO v_eligible
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
    WHERE c.customer_id = v_customer
      AND (v_coupon_cat IS NULL
           OR p.category_id IN (SELECT cv.category_id FROM covered cv));

    IF v_eligible = 0 THEN
      v_applied := NULL;
      v_percent := 0;
    END IF;
  END IF;

  v_discount := round(v_eligible * v_percent / 100, 2);
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

  -- The machines and everything else, at the price they were sold for,
  -- with the colour picked if the product comes in more than one.
  INSERT INTO public.order_items
    (order_id, product_id, product_name, unit_price, quantity, line_total)
  SELECT v_order_id,
         p.product_id,
         p.name || COALESCE(' (' || col.attr_value || ')', ''),
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
  LEFT JOIN LATERAL (
    SELECT a.attr_value
    FROM public.product_attributes a
    WHERE a.product_id = c.product_id
      AND a.attr_key   = 'colourOption'
      AND a.attr_value = c.colour
    LIMIT 1
  ) col ON true
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
