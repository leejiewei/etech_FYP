<?php
// ============================================================
// Stock alerts — the two things the velocity numbers are actually for.
//
//   Restock:    products selling well that are about to run out.
//   Dead stock: money sitting on a shelf that nobody has touched.
//
// Both come from the same weighted score as the velocity page:
//   score = (views x 1) + (cart adds x 3) + (purchases x 5)
// ============================================================

require_once 'inc/auth.php';
require_once 'inc/layout.php';
requireAdmin();

$days = (int) (isset($_GET['days']) ? $_GET['days'] : 90);
if (!in_array($days, [30, 90, 180], true)) $days = 90;

// Creating a discount straight from an alert
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['make_coupon'])) {
    checkCsrf();
    $pid = (int) $_POST['product_id'];
    $product = fetchOne("SELECT p.name, p.category_id, c.name AS cat FROM products p
                         JOIN categories c ON c.category_id = p.category_id
                         WHERE p.product_id = ?", [$pid], 'i');
    if ($product) {
        $code = 'CLEAR' . $pid;
        if (!fetchOne("SELECT coupon_id FROM coupons WHERE code = ?", [$code])) {
            query("INSERT INTO coupons (code, description, category_id, discount_percent, ends_at)
                   VALUES (?, ?, ?, 15, NOW() + INTERVAL '30 days')",
                  [$code, '15% off ' . $product['cat'] . ' - clearing slow stock', (int) $product['category_id']],
                  'ssi');
            flash("Created $code — 15% off " . $product['cat'] . ". Customers browsing that category will be notified.");
        } else {
            flash("$code already exists — see Promotions.");
        }
    }
    header('Location: alerts.php?days=' . $days);
    exit;
}

// ------------------------------------------------------------
// Everything with its score for the chosen window
//
// COUNT(*) FILTER (WHERE ...) is Postgres's way of counting only some of
// the rows in a group - see the note in velocity.php.
// ------------------------------------------------------------
$all = fetchAll(
    "SELECT p.product_id, p.name, p.price, p.cost_price, p.stock_qty, p.reorder_level,
            p.stock_status, p.created_at,
            c.name AS category, parent.name AS parent,
            COUNT(*) FILTER (WHERE e.event_type = 'view')     AS views,
            COUNT(*) FILTER (WHERE e.event_type = 'cart_add') AS cart_adds,
            COUNT(*) FILTER (WHERE e.event_type = 'purchase') AS purchases,
            COUNT(*) FILTER (WHERE e.event_type = 'view')     * 1
          + COUNT(*) FILTER (WHERE e.event_type = 'cart_add') * 3
          + COUNT(*) FILTER (WHERE e.event_type = 'purchase') * 5 AS score,
            MAX(e.created_at) AS last_seen
     FROM products p
     JOIN categories c ON c.category_id = p.category_id
     LEFT JOIN categories parent ON parent.category_id = c.parent_id
     LEFT JOIN events e ON e.product_id = p.product_id
          AND e.created_at >= NOW() - INTERVAL '$days days'
     WHERE p.is_active = 1
     GROUP BY p.product_id, p.name, p.price, p.cost_price, p.stock_qty, p.reorder_level,
              p.stock_status, p.created_at, c.name, parent.name");

usort($all, fn($a, $b) => (int) $b['score'] <=> (int) $a['score']);

$active = array_values(array_filter($all, fn($r) => (int) $r['score'] > 0));
$highCut = (int) ceil(count($active) * 0.20);
$highIds = [];
for ($i = 0; $i < $highCut; $i++) $highIds[(int) $active[$i]['product_id']] = true;

// ------------------------------------------------------------
// RESTOCK — High velocity, actually selling, and running out.
//
// The "actually selling" part matters: a product can rank highly on
// views alone, and telling someone to reorder something nobody has
// bought would be bad advice.
// ------------------------------------------------------------
$restock = array_values(array_filter($all, function ($r) use ($highIds) {
    if (!isset($highIds[(int) $r['product_id']])) return false;
    if ((int) $r['purchases'] === 0) return false;
    return $r['stock_status'] === 'out' || $r['stock_status'] === 'low';
}));
usort($restock, fn($a, $b) => (int) $b['purchases'] <=> (int) $a['purchases']);

// ------------------------------------------------------------
// DEAD STOCK — nothing sold in the window
//
// "High-cost" should mean cost price x quantity held. Neither figure is
// recorded yet, so for now we rank by retail price as a stand-in and say
// so plainly. Once cost_price and stock_qty are filled in, this becomes
// a real money-at-risk figure.
// ------------------------------------------------------------
$dead = array_values(array_filter($all, fn($r) =>
    (int) $r['purchases'] === 0 && (float) $r['price'] >= 300));

usort($dead, function ($a, $b) {
    $va = ($a['cost_price'] !== null && $a['stock_qty'] !== null)
        ? (float) $a['cost_price'] * (int) $a['stock_qty'] : (float) $a['price'];
    $vb = ($b['cost_price'] !== null && $b['stock_qty'] !== null)
        ? (float) $b['cost_price'] * (int) $b['stock_qty'] : (float) $b['price'];
    return $vb <=> $va;
});

$deadTotal = 0;
foreach ($dead as $d) $deadTotal += (float) $d['price'];

$haveCosts = (int) fetchValue("SELECT COUNT(*) FROM products WHERE is_active = 1 AND cost_price IS NOT NULL");

adminHeader('Stock Alerts', 'alerts');
?>

<form method="get" class="filters">
  <div class="field">
    <label>Judge activity over</label>
    <select name="days" onchange="this.form.submit()">
      <option value="30"  <?= $days === 30  ? 'selected' : '' ?>>Last 30 days</option>
      <option value="90"  <?= $days === 90  ? 'selected' : '' ?>>Last 90 days</option>
      <option value="180" <?= $days === 180 ? 'selected' : '' ?>>Last 6 months</option>
    </select>
  </div>
</form>

<!-- ---------------- RESTOCK ---------------- -->
<h2>Restock these</h2>
<p class="hint">
  High-velocity products that are low or out of stock. These are selling &mdash; every day
  they are unavailable is a sale going elsewhere.
</p>

<?php if (count($restock) === 0): ?>
  <div class="card" style="color:#1e8e3e;">Nothing urgent &mdash; everything selling well is in stock.</div>
<?php else: ?>
<div class="table-wrap">
<table class="data">
  <thead><tr><th>Product</th><th>Category</th><th class="num">Sold</th>
             <th class="num">Score</th><th class="num">Qty left</th><th>Status</th><th></th></tr></thead>
  <tbody>
  <?php foreach ($restock as $r): ?>
    <tr>
      <td><strong><?= e(mb_strimwidth($r['name'], 0, 42, '…')) ?></strong><br />
          <small style="color:#999;"><?= e(money($r['price'])) ?></small></td>
      <td><small><?= e($r['parent'] ? $r['parent'] . ' > ' . $r['category'] : $r['category']) ?></small></td>
      <td class="num"><?= (int) $r['purchases'] ?></td>
      <td class="num"><strong><?= (int) $r['score'] ?></strong></td>
      <td class="num"><?= $r['stock_qty'] === null ? '<small style="color:#bbb;">not counted</small>' : (int) $r['stock_qty'] ?></td>
      <td><span class="badge <?= e($r['stock_status']) ?>"><?= $r['stock_status'] === 'out' ? 'Out of stock' : 'Low' ?></span></td>
      <td><a href="product_edit.php?id=<?= (int) $r['product_id'] ?>" class="btn small">Update stock</a></td>
    </tr>
  <?php endforeach; ?>
  </tbody>
</table>
</div>
<?php endif; ?>

<!-- ---------------- DEAD STOCK ---------------- -->
<h2 style="margin-top:30px;">Dead stock</h2>
<p class="hint">
  Nothing sold in the last <?= $days ?> days, and priced at RM300 or more &mdash; the items where
  standing still costs the most. <?= count($dead) ?> products, <?= e(money($deadTotal)) ?> of shelf value.
</p>

<?php if ($haveCosts === 0): ?>
<div class="card" style="border-top-color:#b8860b; padding:14px 18px;">
  <strong>Ranked by retail price for now.</strong>
  <span style="font-size:14px;">
    This module is meant to rank by <em>money tied up</em> &mdash; cost price &times; quantity held.
    Neither is recorded yet, so it falls back to the shelf price. Fill in cost and quantity on the
    product pages and these figures become real.
  </span>
</div>
<?php endif; ?>

<?php if (count($dead) === 0): ?>
  <div class="card" style="color:#1e8e3e;">Nothing stagnant &mdash; every product over RM300 has sold recently.</div>
<?php else: ?>
<div class="table-wrap">
<table class="data">
  <thead><tr><th>Product</th><th>Category</th><th class="num">Views</th><th class="num">Cart</th>
             <th class="num">Value</th><th>Last activity</th><th>Suggested action</th></tr></thead>
  <tbody>
  <?php foreach (array_slice($dead, 0, 30) as $r):
      $views = (int) $r['views'];
      $carts = (int) $r['cart_adds'];
      // What to do depends on WHY it isn't selling. Interest but no sale
      // is a pricing problem, which a discount can fix. No interest at all
      // is a demand problem, and cutting the price won't create demand.
      if ($carts > 0) {
          $action = 'discount';
          $why = 'Being added to baskets but not bought — price is the likely blocker.';
      } elseif ($views >= 3) {
          $action = 'discount';
          $why = 'Getting looked at but never added to a basket. A discount may convert that interest.';
      } elseif ($views > 0) {
          $action = 'halt';
          $why = 'Barely any interest. Sell through what is here, but do not reorder.';
      } else {
          $action = 'halt';
          $why = 'Nobody has even looked at it. A discount will not create demand — stop reordering.';
      }
  ?>
    <tr>
      <td><strong><?= e(mb_strimwidth($r['name'], 0, 40, '…')) ?></strong><br />
          <small style="color:#999;"><?= e(money($r['price'])) ?><?php
            if ($r['stock_qty'] !== null) echo ' &times; ' . (int) $r['stock_qty'] . ' held'; ?></small></td>
      <td><small><?= e($r['parent'] ? $r['parent'] . ' > ' . $r['category'] : $r['category']) ?></small></td>
      <td class="num"><?= $views ?></td>
      <td class="num"><?= $carts ?></td>
      <td class="num"><?= e(money($r['price'])) ?></td>
      <td><small><?= $r['last_seen'] ? e(date('j M', strtotime($r['last_seen']))) : '<span style="color:#c0392b;">never</span>' ?></small></td>
      <td>
        <div style="font-size:12px; color:#777; margin-bottom:5px;"><?= e($why) ?></div>
        <?php if ($action === 'discount'): ?>
          <form method="post" style="display:inline;">
            <input type="hidden" name="csrf" value="<?= e(csrfToken()) ?>" />
            <input type="hidden" name="product_id" value="<?= (int) $r['product_id'] ?>" />
            <button type="submit" name="make_coupon" value="1" class="btn small"
                    onclick="return confirm('Create a 15% promotion on this category for 30 days?');">
              Discount 15%
            </button>
          </form>
        <?php else: ?>
          <span class="badge out">Halt restock</span>
        <?php endif; ?>
      </td>
    </tr>
  <?php endforeach; ?>
  </tbody>
</table>
</div>
<?php if (count($dead) > 30): ?>
  <p class="hint" style="margin-top:12px;">Showing the 30 costliest of <?= count($dead) ?>.</p>
<?php endif; ?>
<?php endif; ?>

<?php adminFooter(); ?>
