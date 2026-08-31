-- ============================================================
-- The three shop-front jobs that are more than a single statement.
--
-- PostgREST turns one HTTP request into one SQL statement. That covers
-- almost everything the site does, but not the handful of places where
-- the old PHP wrapped several writes together and would have left a
-- mess behind if one of them failed. Those move into the database as
-- functions, which is still the client talking to Supabase directly —
-- there is no server in between, the work simply happens inside
-- Postgres where it always belonged.
--
-- All three are SECURITY DEFINER, because they write to tables the
-- caller is not allowed to write to (that is rather the point: a
-- shopper must not be able to INSERT an order and name its total). Each
-- one therefore starts by asking who is calling and refuses to do
-- anything if the answer is nobody.
-- ============================================================


-- ------------------------------------------------------------
-- Adding to the basket.  Was: api/cart.php?action=add
--
-- Three things happen together — the product is checked, the basket row
-- is written or bumped, and the activity is recorded. The last one is
-- why this is not just a PostgREST upsert: a cart add is worth 3 in the
-- Inventory Velocity score, and the score would be worth nothing if the
-- browser could post those events without actually adding anything.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cart_add(p_product_id integer)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_customer integer := public.current_customer_id();
  v_product  public.products%ROWTYPE;
BEGIN
  IF v_customer IS NULL THEN
    RAISE EXCEPTION 'Please log in first.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_product
  FROM public.products
  WHERE product_id = p_product_id AND is_active = 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'That product does not exist.' USING ERRCODE = 'P0001';
  END IF;

  IF v_product.stock_status = 'out' THEN
    RAISE EXCEPTION 'Sorry, % is out of stock.', v_product.name USING ERRCODE = 'P0001';
  END IF;

  -- Already there? bump the quantity rather than adding a second row.
  -- The alias is what lets the SET clause read the row that is already
  -- in the table; unqualified, "quantity" would mean the new value.
  INSERT INTO public.cart_items AS ci (customer_id, product_id, quantity)
  VALUES (v_customer, p_product_id, 1)
  ON CONFLICT (customer_id, product_id)
  DO UPDATE SET quantity = ci.quantity + 1;

  INSERT INTO public.events (customer_id, product_id, event_type)
  VALUES (v_customer, p_product_id, 'cart_add');
END;
$$;


-- ------------------------------------------------------------
-- Wishlist on/off.  Was: api/cart.php?action=toggleWishlist
--
-- Same reasoning: adding to the wishlist records an event, removing
-- from it does not, and the caller should not get to choose which.
-- Returns the whole list back so the heart icons can be repainted from
-- one round trip.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.toggle_wishlist(p_product_id integer)
RETURNS integer[]
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_customer integer := public.current_customer_id();
  v_removed  integer;
BEGIN
  IF v_customer IS NULL THEN
    RAISE EXCEPTION 'Please log in first.' USING ERRCODE = '42501';
  END IF;

  DELETE FROM public.wishlist_items
  WHERE customer_id = v_customer AND product_id = p_product_id;

  GET DIAGNOSTICS v_removed = ROW_COUNT;

  -- Nothing deleted means it was not on the list, so this click adds it.
  IF v_removed = 0 THEN
    INSERT INTO public.wishlist_items (customer_id, product_id)
    VALUES (v_customer, p_product_id);

    INSERT INTO public.events (customer_id, product_id, event_type)
    VALUES (v_customer, p_product_id, 'wishlist_add');
  END IF;

  RETURN ARRAY(
    SELECT w.product_id FROM public.wishlist_items w
    WHERE w.customer_id = v_customer ORDER BY w.product_id
  );
END;
$$;


-- ------------------------------------------------------------
-- Checkout.  Was: api/orders.php?action=create
--
-- This is the one that genuinely needs to be all-or-nothing. It writes
-- an order, its lines and one event per line, then empties the basket.
-- A half-finished version of that is a customer charged for an order
-- with no items in it. A function body is a single statement as far as
-- Postgres is concerned, so either the whole thing lands or none of it
-- does — which is exactly what dbBegin()/dbCommit() were doing.
--
-- Prices are read from the products table, never taken from the
-- argument list, so editing the page cannot change what you pay. That
-- was true of the PHP too and is the reason checkout could never have
-- been a plain PostgREST insert.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.place_order(
  p_name    text,
  p_phone   text,
  p_address text,
  p_coupon  text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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

  SELECT COUNT(*), COALESCE(SUM(p.price * c.quantity), 0)
    INTO v_lines, v_subtotal
  FROM public.cart_items c
  JOIN public.products p ON p.product_id = c.product_id
  WHERE c.customer_id = v_customer;

  IF v_lines = 0 THEN
    RAISE EXCEPTION 'Your cart is empty.' USING ERRCODE = 'P0001';
  END IF;

  -- Is the coupon real, live, and still running? An unknown or expired
  -- code is quietly ignored rather than refused, which is what the PHP
  -- did and what the checkout page expects.
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

  -- The name and price are copied in, so this order still reads
  -- correctly if the product is later renamed or repriced.
  INSERT INTO public.order_items
    (order_id, product_id, product_name, unit_price, quantity, line_total)
  SELECT v_order_id, p.product_id, p.name, p.price, c.quantity, p.price * c.quantity
  FROM public.cart_items c
  JOIN public.products p ON p.product_id = c.product_id
  WHERE c.customer_id = v_customer;

  -- A purchase is the strongest signal, worth 5 in the velocity score.
  INSERT INTO public.events (customer_id, product_id, event_type)
  SELECT v_customer, c.product_id, 'purchase'
  FROM public.cart_items c
  WHERE c.customer_id = v_customer;

  DELETE FROM public.cart_items WHERE customer_id = v_customer;

  RETURN jsonb_build_object(
    'orderId',  v_order_id,
    'subtotal', v_subtotal,
    'discount', v_discount,
    'total',    v_total,
    'coupon',   v_applied
  );
END;
$$;


REVOKE EXECUTE ON FUNCTION public.cart_add(integer)                        FROM public;
REVOKE EXECUTE ON FUNCTION public.toggle_wishlist(integer)                 FROM public;
REVOKE EXECUTE ON FUNCTION public.place_order(text, text, text, text)      FROM public;

GRANT EXECUTE ON FUNCTION public.cart_add(integer)                    TO authenticated;
GRANT EXECUTE ON FUNCTION public.toggle_wishlist(integer)             TO authenticated;
GRANT EXECUTE ON FUNCTION public.place_order(text, text, text, text)  TO authenticated;
