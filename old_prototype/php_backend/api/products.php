<?php
// ============================================================
// Sends the whole catalogue to the browser as JSON.
//
// The shape it returns is exactly what the site's JavaScript already
// expected when the products were a hard-coded array, so the shop,
// PC Builder and advisor all carry on working unchanged — they just
// get their data from Supabase now instead of a file.
//
// The Flutter app calls this same file, so the phone and the website are
// never showing two different catalogues.
// ============================================================

require_once 'db.php';
require_once 'helpers.php';

// Specs that can hold several values, so they must come back as a list
// even when there happens to be only one.
$ARRAY_KEYS = ['sockets', 'supportedFormFactors', 'incompatibleSockets'];

// Specs that are numbers. Everything arrives from the database as text,
// and the compatibility checks compare these with < and >, so "90" must
// become 90.
$NUMBER_KEYS = ['tdp', 'coolerRating', 'power', 'length', 'wattage',
                'maxGpuLength', 'pcieGen', 'cores', 'threads'];

$products = fetchAll(
    "SELECT p.product_id, p.name, p.price, p.stock_status, p.description,
            p.icon, p.img_slug, p.image_path, p.exclude_from_builder,
            b.name AS brand,
            c.name AS category_name,
            parent.name AS parent_name
     FROM products p
     JOIN brands b      ON b.brand_id = p.brand_id
     JOIN categories c  ON c.category_id = p.category_id
     LEFT JOIN categories parent ON parent.category_id = c.parent_id
     WHERE p.is_active = 1
     ORDER BY p.product_id"
);

// Pull every spec in one query rather than one query per product.
$attrRows = fetchAll(
    "SELECT a.product_id, a.attr_key, a.attr_value
     FROM product_attributes a
     JOIN products p ON p.product_id = a.product_id
     WHERE p.is_active = 1"
);

// Group the specs by product
$attrsByProduct = [];
foreach ($attrRows as $row) {
    $pid  = (int) $row['product_id'];
    $key  = $row['attr_key'];
    $val  = $row['attr_value'];

    if (in_array($key, $NUMBER_KEYS, true)) {
        $val = is_numeric($val) ? $val + 0 : $val;
    }

    if (in_array($key, $ARRAY_KEYS, true)) {
        if (!isset($attrsByProduct[$pid][$key])) $attrsByProduct[$pid][$key] = [];
        $attrsByProduct[$pid][$key][] = $val;
    } else {
        $attrsByProduct[$pid][$key] = $val;
    }
}

$out = [];
foreach ($products as $p) {
    $pid = (int) $p['product_id'];

    // A category with a parent is a sub-category: "Components > CPU".
    $hasParent   = $p['parent_name'] !== null;
    $category    = $hasParent ? $p['parent_name'] : $p['category_name'];
    $subcategory = $hasParent ? $p['category_name'] : null;

    $item = [
        'id'          => $pid,
        'name'        => $p['name'],
        'brand'       => $p['brand'],
        'category'    => $category,
        'price'       => (float) $p['price'],
        'stock'       => $p['stock_status'],
        'icon'        => $p['icon'],
        'img'         => $p['img_slug'],
        'description' => $p['description'],
        'attrs'       => isset($attrsByProduct[$pid]) ? $attrsByProduct[$pid] : (object) [],
    ];

    if ($subcategory !== null)            $item['subcategory'] = $subcategory;
    if ((int) $p['exclude_from_builder']) $item['excludeFromBuilder'] = true;
    if (!empty($p['image_path']))         $item['imagePath'] = $p['image_path'];

    $out[] = $item;
}

reply(['ok' => true, 'products' => $out]);
