<?php
// ============================================================
// Placing an order, and listing a customer's own orders.
//
// Checkout writes to three tables (orders, order_items, events) and
// empties the basket. If any one of those failed halfway we would be
// left with a broken half-order, so the whole thing runs inside a
// transaction: either every step lands, or none of them do.
// ============================================================

require_once 'db.php';
require_once 'helpers.php';

$customerId = requireLogin();

switch (action()) {

    // ---------------------------------------------------- my orders
    case 'list': {
        $orders = fetchAll(
            "SELECT order_id, order_date, status, subtotal, discount, total,
                    coupon_code, shipping_name, shipping_phone, shipping_address
             FROM orders WHERE customer_id = ? ORDER BY order_date DESC",
            [$customerId], 'i'
        );

        foreach ($orders as &$o) {
            $o['items'] = fetchAll(
                "SELECT product_id, product_name, unit_price, quantity, line_total
                 FROM order_items WHERE order_id = ?",
                [(int) $o['order_id']], 'i'
            );
        }
        reply(['ok' => true, 'orders' => $orders]);
    }

    // ---------------------------------------------------- checkout
    case 'create': {
        $in       = body();
        $name     = trim(isset($in['name'])    ? $in['name']    : '');
        $phone    = trim(isset($in['phone'])   ? $in['phone']   : '');
        $address  = trim(isset($in['address']) ? $in['address'] : '');
        $couponIn = strtoupper(trim(isset($in['coupon']) ? $in['coupon'] : ''));

        if ($name === '' || $address === '') fail('Please fill in your delivery details.');

        // Prices come from the database, never from the browser — otherwise
        // someone could edit the page and pay whatever they liked.
        $rows = fetchAll(
            "SELECT c.product_id, c.quantity, p.name, p.price, p.category_id
             FROM cart_items c JOIN products p ON p.product_id = c.product_id
             WHERE c.customer_id = ?",
            [$customerId], 'i'
        );
        if (count($rows) === 0) fail('Your cart is empty.');

        // Is the coupon real, live, and for something in this basket?
        $discountPercent = 0;
        $couponCode = null;
        if ($couponIn !== '') {
            $coupon = fetchOne(
                "SELECT code, category_id, discount_percent FROM coupons
                 WHERE code = ? AND is_active = 1
                   AND starts_at <= NOW() AND (ends_at IS NULL OR ends_at >= NOW())",
                [$couponIn]
            );
            if ($coupon) {
                $couponCode = $coupon['code'];
                $discountPercent = (float) $coupon['discount_percent'];
            }
        }

        $subtotal = 0;
        foreach ($rows as $r) $subtotal += (float) $r['price'] * (int) $r['quantity'];
        $discount = round($subtotal * $discountPercent / 100, 2);
        $total    = $subtotal - $discount;

        dbBegin();
        try {
            // RETURNING gives back the new order's id, which the order lines
            // below need. MySQL used insert_id for this.
            $orderId = (int) fetchValue(
                "INSERT INTO orders
                     (customer_id, subtotal, discount, total, coupon_code,
                      shipping_name, shipping_phone, shipping_address)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                 RETURNING order_id",
                [$customerId, $subtotal, $discount, $total, $couponCode, $name, $phone, $address],
                'idddssss');

            foreach ($rows as $r) {
                $line = (float) $r['price'] * (int) $r['quantity'];
                // The name and price are copied in, so this order still
                // reads correctly if the product is later renamed or repriced.
                query("INSERT INTO order_items
                          (order_id, product_id, product_name, unit_price, quantity, line_total)
                       VALUES (?, ?, ?, ?, ?, ?)",
                      [$orderId, (int) $r['product_id'], $r['name'],
                       (float) $r['price'], (int) $r['quantity'], $line],
                      'iisdid');

                // A purchase is the strongest signal, worth 5 in the velocity score.
                query("INSERT INTO events (customer_id, product_id, event_type)
                       VALUES (?, ?, 'purchase')",
                      [$customerId, (int) $r['product_id']], 'ii');
            }

            query("DELETE FROM cart_items WHERE customer_id = ?", [$customerId], 'i');

            dbCommit();
        } catch (Exception $e) {
            dbRollback();
            fail('Could not place the order. Nothing was charged.', 500);
        }

        reply(['ok' => true, 'orderId' => $orderId,
               'subtotal' => $subtotal, 'discount' => $discount, 'total' => $total,
               'coupon' => $couponCode]);
    }

    default:
        fail('Unknown action.');
}
