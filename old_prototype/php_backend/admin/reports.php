<?php
// ============================================================
// Sales trend and customer segmentation.
//
// Charts are drawn as plain HTML and SVG rather than pulled from a
// charting library, so the panel works with no internet connection and
// there is nothing to explain that isn't in this file.
//
// The demand forecast line is deliberately not here yet — that was
// parked until the projection method is decided.
// ============================================================

require_once 'inc/auth.php';
require_once 'inc/layout.php';
requireAdmin();

// ------------------------------------------------------------
// Monthly sales
// ------------------------------------------------------------
$monthly = fetchAll(
    "SELECT to_char(o.order_date, 'YYYY-MM') AS month,
            COUNT(DISTINCT o.order_id) AS orders,
            SUM(oi.quantity)           AS units,
            SUM(oi.line_total)         AS revenue
     FROM orders o
     JOIN order_items oi ON oi.order_id = o.order_id
     WHERE o.status <> 'Cancelled'
       AND o.order_date >= NOW() - INTERVAL '12 months'
     GROUP BY to_char(o.order_date, 'YYYY-MM')
     ORDER BY month");

$maxRevenue = 0;
foreach ($monthly as $m) $maxRevenue = max($maxRevenue, (float) $m['revenue']);

$totalRevenue = 0; $totalOrders = 0; $totalUnits = 0;
foreach ($monthly as $m) {
    $totalRevenue += (float) $m['revenue'];
    $totalOrders  += (int) $m['orders'];
    $totalUnits   += (int) $m['units'];
}

// ------------------------------------------------------------
// Best sellers
// ------------------------------------------------------------
$bestSellers = fetchAll(
    "SELECT oi.product_name, SUM(oi.quantity) AS units, SUM(oi.line_total) AS revenue
     FROM order_items oi JOIN orders o ON o.order_id = oi.order_id
     WHERE o.status <> 'Cancelled'
     GROUP BY oi.product_name
     ORDER BY revenue DESC LIMIT 8");

// ------------------------------------------------------------
// Revenue by category
// ------------------------------------------------------------
$byCategory = fetchAll(
    "SELECT COALESCE(parent.name, c.name) AS category,
            SUM(oi.line_total) AS revenue, SUM(oi.quantity) AS units
     FROM order_items oi
     JOIN orders o     ON o.order_id = oi.order_id
     JOIN products p   ON p.product_id = oi.product_id
     JOIN categories c ON c.category_id = p.category_id
     LEFT JOIN categories parent ON parent.category_id = c.parent_id
     WHERE o.status <> 'Cancelled'
     GROUP BY COALESCE(parent.name, c.name)
     ORDER BY revenue DESC");

$catMax = 0;
foreach ($byCategory as $c) $catMax = max($catMax, (float) $c['revenue']);

// ------------------------------------------------------------
// Customer segmentation
//
// Customers are grouped by WHAT they buy, not by who they say they are.
// Every category is put in one of three baskets, we add up each
// customer's spend in each, and whichever is biggest decides the group.
// The one exception is spend: someone whose whole history is small and
// cheap is a student whatever they bought.
// ------------------------------------------------------------
$GAMING     = ['Components', 'Case Fans', 'Accessories', 'Gaming Gear'];
$CORPORATE  = ['Printers', 'Consumables', 'Monitor Arms', 'Projectors', 'Networking'];
// Monitors and Laptops sit in both worlds, so they don't decide anything.

$spend = fetchAll(
    "SELECT o.customer_id, cu.name, cu.email,
            COALESCE(parent.name, c.name) AS category,
            SUM(oi.line_total) AS spend
     FROM order_items oi
     JOIN orders o     ON o.order_id = oi.order_id
     JOIN customers cu ON cu.customer_id = o.customer_id
     JOIN products p   ON p.product_id = oi.product_id
     JOIN categories c ON c.category_id = p.category_id
     LEFT JOIN categories parent ON parent.category_id = c.parent_id
     WHERE o.status <> 'Cancelled'
     GROUP BY o.customer_id, cu.name, cu.email, COALESCE(parent.name, c.name)");

$people = [];
foreach ($spend as $row) {
    $id = (int) $row['customer_id'];
    if (!isset($people[$id])) {
        $people[$id] = ['name' => $row['name'], 'email' => $row['email'],
                        'total' => 0, 'gaming' => 0, 'corporate' => 0, 'top' => '', 'topSpend' => 0];
    }
    $amount = (float) $row['spend'];
    $people[$id]['total'] += $amount;
    if (in_array($row['category'], $GAMING, true))    $people[$id]['gaming'] += $amount;
    if (in_array($row['category'], $CORPORATE, true)) $people[$id]['corporate'] += $amount;
    if ($amount > $people[$id]['topSpend']) {
        $people[$id]['topSpend'] = $amount;
        $people[$id]['top'] = $row['category'];
    }
}

// Somebody whose entire history is under this is treated as a student.
define('STUDENT_CEILING', 3000);

foreach ($people as $id => &$p) {
    if ($p['corporate'] > $p['gaming']) {
        $p['segment'] = 'Corporate';
        $p['why'] = 'Most of their spend is on office equipment';
    } elseif ($p['total'] < STUDENT_CEILING) {
        $p['segment'] = 'Student';
        $p['why'] = 'Small total spend on budget parts';
    } else {
        $p['segment'] = 'Gamer / Enthusiast';
        $p['why'] = 'Mostly PC components, fans and lighting';
    }
}
unset($p);

$segments = ['Gamer / Enthusiast' => ['count' => 0, 'revenue' => 0],
             'Corporate'          => ['count' => 0, 'revenue' => 0],
             'Student'            => ['count' => 0, 'revenue' => 0]];
foreach ($people as $p) {
    $segments[$p['segment']]['count']++;
    $segments[$p['segment']]['revenue'] += $p['total'];
}
$segRevenueMax = 0;
foreach ($segments as $s) $segRevenueMax = max($segRevenueMax, $s['revenue']);
$buyerCount = count($people);

$segColour = ['Gamer / Enthusiast' => '#d62839', 'Corporate' => '#2c5d8f', 'Student' => '#1e8e3e'];

adminHeader('Sales & Customers', 'reports');
?>

<div class="tiles">
  <div class="tile">
    <div class="label">Revenue (12 months)</div>
    <div class="value"><?= e(money($totalRevenue)) ?></div>
    <div class="sub"><?= $totalOrders ?> orders, <?= $totalUnits ?> items</div>
  </div>
  <div class="tile">
    <div class="label">Average order</div>
    <div class="value"><?= e(money($totalOrders > 0 ? $totalRevenue / $totalOrders : 0)) ?></div>
    <div class="sub">Across all orders</div>
  </div>
  <div class="tile">
    <div class="label">Customers who bought</div>
    <div class="value"><?= $buyerCount ?></div>
    <div class="sub">Grouped into <?= count(array_filter($segments, fn($s) => $s['count'] > 0)) ?> segments</div>
  </div>
</div>

<!-- ---------------- SALES TREND ---------------- -->
<h2>Sales trend</h2>
<div class="card">
  <?php if (count($monthly) === 0): ?>
    <p style="color:#888;">No sales recorded yet.</p>
  <?php else: ?>
    <div style="display:flex; align-items:flex-end; gap:14px; height:230px; padding:10px 0 0;">
      <?php foreach ($monthly as $m):
          $h = $maxRevenue > 0 ? round((float) $m['revenue'] / $maxRevenue * 180) : 0;
      ?>
        <div style="flex:1; text-align:center; display:flex; flex-direction:column; justify-content:flex-end; height:100%;">
          <div style="font-size:11px; color:#666; margin-bottom:4px; white-space:nowrap;">
            <?= e(number_format((float) $m['revenue'] / 1000, 1)) ?>k
          </div>
          <div title="<?= e(money($m['revenue'])) ?> from <?= (int) $m['orders'] ?> orders"
               style="background:linear-gradient(180deg,#d62839,#7a0c1f); height:<?= max($h, 3) ?>px;
                      border-radius:4px 4px 0 0;"></div>
          <div style="font-size:11px; color:#888; margin-top:6px;">
            <?= e(date('M', strtotime($m['month'] . '-01'))) ?>
          </div>
          <div style="font-size:10px; color:#bbb;"><?= (int) $m['orders'] ?> ord</div>
        </div>
      <?php endforeach; ?>
    </div>
    <p class="hint" style="margin:14px 0 0;">
      Monthly revenue, cancelled orders excluded. The demand forecast line is not drawn yet —
      that was left until the projection method is settled.
    </p>
  <?php endif; ?>
</div>

<div style="display:flex; gap:20px; flex-wrap:wrap;">
  <!-- ---------------- SEGMENTATION ---------------- -->
  <div style="flex:1; min-width:340px;">
    <h2>Customer segments</h2>
    <div class="card">
      <?php if ($buyerCount === 0): ?>
        <p style="color:#888;">Nobody has bought anything yet.</p>
      <?php else: ?>
        <?php foreach ($segments as $name => $s):
            $pct = $buyerCount > 0 ? round($s['count'] / $buyerCount * 100) : 0;
            $bar = $segRevenueMax > 0 ? round($s['revenue'] / $segRevenueMax * 100) : 0;
        ?>
          <div style="margin-bottom:16px;">
            <div style="display:flex; justify-content:space-between; font-size:14px; margin-bottom:5px;">
              <strong style="color:<?= $segColour[$name] ?>;"><?= e($name) ?></strong>
              <span><?= $s['count'] ?> customer<?= $s['count'] === 1 ? '' : 's' ?> (<?= $pct ?>%)
                &middot; <?= e(money($s['revenue'])) ?></span>
            </div>
            <div style="background:#eef0f3; border-radius:4px; height:16px;">
              <div style="background:<?= $segColour[$name] ?>; width:<?= max($bar, 1) ?>%; height:16px; border-radius:4px;"></div>
            </div>
          </div>
        <?php endforeach; ?>
        <p class="hint" style="margin:0;">
          Bar length is revenue. Customers are grouped by what they actually buy:
          office equipment means <strong>Corporate</strong>; a small total spend on budget parts means
          <strong>Student</strong>; otherwise <strong>Gamer / Enthusiast</strong>.
        </p>
      <?php endif; ?>
    </div>
  </div>

  <!-- ---------------- CATEGORY REVENUE ---------------- -->
  <div style="flex:1; min-width:340px;">
    <h2>Revenue by category</h2>
    <div class="card">
      <?php if (count($byCategory) === 0): ?>
        <p style="color:#888;">No sales yet.</p>
      <?php else: ?>
        <?php foreach ($byCategory as $c):
            $bar = $catMax > 0 ? round((float) $c['revenue'] / $catMax * 100) : 0; ?>
          <div style="margin-bottom:11px;">
            <div style="display:flex; justify-content:space-between; font-size:13px; margin-bottom:3px;">
              <span><?= e($c['category']) ?></span>
              <span style="color:#888;"><?= e(money($c['revenue'])) ?> &middot; <?= (int) $c['units'] ?> items</span>
            </div>
            <div style="background:#eef0f3; border-radius:3px; height:11px;">
              <div style="background:#7a0c1f; width:<?= max($bar, 1) ?>%; height:11px; border-radius:3px;"></div>
            </div>
          </div>
        <?php endforeach; ?>
      <?php endif; ?>
    </div>
  </div>
</div>

<!-- ---------------- WHO'S IN EACH SEGMENT ---------------- -->
<h2>Customers</h2>
<div class="table-wrap">
<table class="data">
  <thead><tr><th>Customer</th><th>Segment</th><th>Why</th><th>Buys most</th><th class="num">Total spend</th></tr></thead>
  <tbody>
  <?php if ($buyerCount === 0): ?>
    <tr><td colspan="5" style="text-align:center; color:#888; padding:24px;">No purchases yet.</td></tr>
  <?php endif; ?>
  <?php
  uasort($people, fn($a, $b) => $b['total'] <=> $a['total']);
  foreach ($people as $p): ?>
    <tr>
      <td><strong><?= e($p['name']) ?></strong><br /><small style="color:#999;"><?= e($p['email']) ?></small></td>
      <td><span class="badge" style="background:<?= $segColour[$p['segment']] ?>22; color:<?= $segColour[$p['segment']] ?>;">
        <?= e($p['segment']) ?></span></td>
      <td><small style="color:#777;"><?= e($p['why']) ?></small></td>
      <td><small><?= e($p['top']) ?></small></td>
      <td class="num"><?= e(money($p['total'])) ?></td>
    </tr>
  <?php endforeach; ?>
  </tbody>
</table>
</div>

<h2 style="margin-top:26px;">Best sellers</h2>
<div class="table-wrap">
<table class="data">
  <thead><tr><th>Product</th><th class="num">Units sold</th><th class="num">Revenue</th></tr></thead>
  <tbody>
  <?php foreach ($bestSellers as $b): ?>
    <tr>
      <td><?= e(mb_strimwidth($b['product_name'], 0, 50, '…')) ?></td>
      <td class="num"><?= (int) $b['units'] ?></td>
      <td class="num"><?= e(money($b['revenue'])) ?></td>
    </tr>
  <?php endforeach; ?>
  </tbody>
</table>
</div>

<?php adminFooter(); ?>
