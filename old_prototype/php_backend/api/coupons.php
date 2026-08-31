<?php
// ============================================================
// The promotions currently running, for the Deals page and for the
// notification that pops up when a shopper's favourite category is
// on offer.
//
// Only live coupons come back — anything switched off or out of date
// is filtered out here rather than in the browser.
// ============================================================

require_once 'db.php';
require_once 'helpers.php';

$rows = fetchAll(
    "SELECT c.code, c.description, c.discount_percent, c.ends_at,
            cat.name AS category
     FROM coupons c
     LEFT JOIN categories cat ON cat.category_id = c.category_id
     WHERE c.is_active = 1
       AND c.starts_at <= NOW()
       AND (c.ends_at IS NULL OR c.ends_at >= NOW())
     ORDER BY c.discount_percent DESC"
);

$deals = [];
foreach ($rows as $r) {
    $deals[] = [
        'code'            => $r['code'],
        'description'     => $r['description'],
        'discountPercent' => (float) $r['discount_percent'],
        'category'        => $r['category'],       // null means it applies to everything
        'endsAt'          => $r['ends_at'],
    ];
}

reply(['ok' => true, 'deals' => $deals]);
