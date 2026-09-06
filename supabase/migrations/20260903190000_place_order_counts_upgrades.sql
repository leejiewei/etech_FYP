-- ============================================================
-- Making the till charge for the upgrades.
--
-- place_order built its subtotal from products.price * quantity and
-- wrote order_items from the same join. That was complete when a basket
-- line was only ever a product. Now that a line for one of the shop's
-- own builds can carry ticked upgrades, the same query quietly gives
-- them away: the customer picks +RM499 to an RTX 5050, the card shows
-- RM3,498, and the order is written for RM2,999.
--
-- This is the reason the upgrade money has to be added here rather than
-- sent up from the phone. The phone already knows the total it drew, but
-- a client that can name its own price is not a shop -- the same rule
-- that put cart_add and place_order in the database in the first place.
-- The customer's device sends nothing but the tick; the price attached
-- to that tick is read from prebuilt_upgrades, on this side.
--
-- How an upgrade lands in an order:
--
--   * The machine's own line keeps its own base price. Its product_id,
--     unit_price and line_total mean exactly what they meant before, so
--     revenue-per-product and the velocity score are not inflated by an
--     upgrade the product row never charged for.
--   * Each upgrade is written as an extra line with product_id NULL --
--     the column has always been nullable for exactly this shape -- and
--     a name that says which machine it belongs to.
--
-- So the order total gains the upgrade money, and per-product reporting
-- stays honest about what a machine costs. Category revenue, which joins
-- order_items back to products, will not count the upgrade lines; that
-- is the right answer, because an upgrade is not in a category.
--
-- Nothing changes for a basket with no upgrades in it: every join below
-- is a left join or an inner join over an empty table, and the numbers
-- come out identical.
-- ============================================================

create or replace function public.place_order(
  p_name text,
  p_phone text,
  p_address text,
  p_coupon text default null
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

  -- One line is still one line however many upgrades hang off it, so
  -- COUNT(*) counts cart_items and the upgrades only reach the money.
  SELECT COUNT(*),
         COALESCE(SUM((p.price + COALESCE(x.extra, 0)) * c.quantity), 0)
    INTO v_lines, v_subtotal
  FROM public.cart_items c
  JOIN public.products p ON p.product_id = c.product_id
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

  INSERT INTO public.orders
    (customer_id, subtotal, discount, total, coupon_code,
     shipping_name, shipping_phone, shipping_address)
  VALUES
    (v_customer, v_subtotal, v_discount, v_total, v_applied,
     v_name, NULLIF(v_phone, ''), v_address)
  RETURNING order_id INTO v_order_id;

  -- The machines and everything else, at their own prices.
  INSERT INTO public.order_items
    (order_id, product_id, product_name, unit_price, quantity, line_total)
  SELECT v_order_id, p.product_id, p.name, p.price, c.quantity, p.price * c.quantity
  FROM public.cart_items c
  JOIN public.products p ON p.product_id = c.product_id
  WHERE c.customer_id = v_customer;

  -- The upgrades, one line each, named so an invoice reads properly.
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
    'coupon',   v_applied
  );
END;
$function$;
