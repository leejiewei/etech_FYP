<?php
// ============================================================
// Basket and wishlist. Both belong to a signed-in customer, so they
// follow them from one device to another instead of living in one
// browser.
//
// Every statement filters on the session's customer_id, so a request
// can only ever touch its own rows.
// ============================================================

require_once 'db.php';
require_once 'helpers.php';

$customerId = requireLogin();

// Reads the basket, joining the products so the browser gets names,
// prices and pictures in one go.
function cartRows($customerId) {
    return fetchAll(
        "SELECT c.product_id, c.quantity, p.name, p.price, p.icon, p.img_slug, p.image_path, p.stock_status
         FROM cart_items c
         JOIN products p ON p.product_id = c.product_id
         WHERE c.customer_id = ?
         ORDER BY c.added_at",
        [$customerId], 'i'
    );
}

function cartReply($customerId) {
    $items = [];
    $total = 0;
    foreach (cartRows($customerId) as $r) {
        $line = (float) $r['price'] * (int) $r['quantity'];
        $total += $line;
        $items[] = [
            'id'        => (int) $r['product_id'],
            'name'      => $r['name'],
            'price'     => (float) $r['price'],
            'qty'       => (int) $r['quantity'],
            'icon'      => $r['icon'],
            'img'       => $r['img_slug'],
            'imagePath' => $r['image_path'],
            'stock'     => $r['stock_status'],
            'lineTotal' => $line,
        ];
    }
    reply(['ok' => true, 'items' => $items, 'total' => $total]);
}

switch (action()) {

    case 'get':
        cartReply($customerId);

    case 'add': {
        $in  = body();
        $pid = (int) (isset($in['productId']) ? $in['productId'] : 0);

        $product = fetchOne("SELECT product_id, name, stock_status FROM products WHERE product_id = ? AND is_active = 1",
                            [$pid], 'i');
        if (!$product) fail('That product does not exist.');
        if ($product['stock_status'] === 'out') fail('Sorry, ' . $product['name'] . ' is out of stock.');

        // Already there? bump the quantity instead of adding a second row.
        // Postgres spells MySQL's ON DUPLICATE KEY as ON CONFLICT, and wants
        // to be told which key would clash - for a basket row that is the
        // pair (customer, product), which is the table's primary key.
        query("INSERT INTO cart_items (customer_id, product_id, quantity) VALUES (?, ?, 1)
               ON CONFLICT (customer_id, product_id)
               DO UPDATE SET quantity = cart_items.quantity + 1",
              [$customerId, $pid], 'ii');

        // Adding to the basket is a strong signal, worth 3 in the velocity score.
        query("INSERT INTO events (customer_id, product_id, event_type) VALUES (?, ?, 'cart_add')",
              [$customerId, $pid], 'ii');

        cartReply($customerId);
    }

    case 'setQty': {
        $in  = body();
        $pid = (int) (isset($in['productId']) ? $in['productId'] : 0);
        $qty = (int) (isset($in['qty']) ? $in['qty'] : 1);
        if ($qty < 1) $qty = 1;

        query("UPDATE cart_items SET quantity = ? WHERE customer_id = ? AND product_id = ?",
              [$qty, $customerId, $pid], 'iii');
        cartReply($customerId);
    }

    case 'remove': {
        $in  = body();
        $pid = (int) (isset($in['productId']) ? $in['productId'] : 0);
        query("DELETE FROM cart_items WHERE customer_id = ? AND product_id = ?",
              [$customerId, $pid], 'ii');
        cartReply($customerId);
    }

    case 'clear': {
        query("DELETE FROM cart_items WHERE customer_id = ?", [$customerId], 'i');
        cartReply($customerId);
    }

    // ---------------------------------------------------- wishlist
    case 'wishlist': {
        $rows = fetchAll("SELECT product_id FROM wishlist_items WHERE customer_id = ?", [$customerId], 'i');
        reply(['ok' => true, 'productIds' => array_map(fn($r) => (int) $r['product_id'], $rows)]);
    }

    case 'toggleWishlist': {
        $in  = body();
        $pid = (int) (isset($in['productId']) ? $in['productId'] : 0);

        $existing = fetchOne("SELECT product_id FROM wishlist_items WHERE customer_id = ? AND product_id = ?",
                             [$customerId, $pid], 'ii');
        if ($existing) {
            query("DELETE FROM wishlist_items WHERE customer_id = ? AND product_id = ?",
                  [$customerId, $pid], 'ii');
        } else {
            query("INSERT INTO wishlist_items (customer_id, product_id) VALUES (?, ?)",
                  [$customerId, $pid], 'ii');
            query("INSERT INTO events (customer_id, product_id, event_type) VALUES (?, ?, 'wishlist_add')",
                  [$customerId, $pid], 'ii');
        }

        $rows = fetchAll("SELECT product_id FROM wishlist_items WHERE customer_id = ?", [$customerId], 'i');
        reply(['ok' => true, 'productIds' => array_map(fn($r) => (int) $r['product_id'], $rows)]);
    }

    default:
        fail('Unknown action.');
}
