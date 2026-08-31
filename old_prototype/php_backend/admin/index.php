<?php
// ============================================================
// Dashboard. An at-a-glance summary plus anything needing attention.
// The analytics modules (Inventory Velocity, dead-stock alerts,
// restocking, segmentation) come next and will live here too.
// ============================================================

require_once 'inc/auth.php';
require_once 'inc/layout.php';
requireAdmin();

$productCount = (int) fetchValue("SELECT COUNT(*) FROM products WHERE is_active = 1");
$outOfStock   = (int) fetchValue("SELECT COUNT(*) FROM products WHERE is_active = 1 AND stock_status = 'out'");
$lowStock     = (int) fetchValue("SELECT COUNT(*) FROM products WHERE is_active = 1 AND stock_status = 'low'");
$customers    = (int) fetchValue("SELECT COUNT(*) FROM customers");
$orderCount   = (int) fetchValue("SELECT COUNT(*) FROM orders");
$pending      = (int) fetchValue("SELECT COUNT(*) FROM orders WHERE status = 'Pending'");
$revenue      = (float) fetchValue("SELECT COALESCE(SUM(total), 0) FROM orders WHERE status <> 'Cancelled'");
$liveCoupons  = (int) fetchValue("SELECT COUNT(*) FROM coupons WHERE is_active = 1
                                  AND starts_at <= NOW() AND (ends_at IS NULL OR ends_at >= NOW())");

// How much of the catalogue still has no cost price recorded — that's
// what the margin figures and dead-stock alerts are waiting on.
$missingCost = (int) fetchValue("SELECT COUNT(*) FROM products WHERE is_active = 1 AND cost_price IS NULL");
$missingQty  = (int) fetchValue("SELECT COUNT(*) FROM products WHERE is_active = 1 AND stock_qty IS NULL");

$recentOrders = fetchAll(
    "SELECT o.order_id, o.order_date, o.status, o.total, c.name AS customer
     FROM orders o JOIN customers c ON c.customer_id = o.customer_id
     ORDER BY o.order_date DESC LIMIT 8");

$topProducts = fetchAll(
    "SELECT product_id, name, views, cart_adds, purchases, velocity_score
     FROM v_product_velocity
     WHERE velocity_score > 0
     ORDER BY velocity_score DESC, name LIMIT 8");

adminHeader('Dashboard', 'dashboard');
?>

<div class="tiles">
  <div class="tile">
    <div class="label">Products</div>
    <div class="value"><?= number_format($productCount) ?></div>
    <div class="sub"><?= $lowStock ?> low · <?= $outOfStock ?> out of stock</div>
  </div>
  <div class="tile">
    <div class="label">Orders</div>
    <div class="value"><?= number_format($orderCount) ?></div>
    <div class="sub"><?= $pending ?> waiting to be processed</div>
  </div>
  <div class="tile">
    <div class="label">Revenue</div>
    <div class="value"><?= e(money($revenue)) ?></div>
    <div class="sub">All orders not cancelled</div>
  </div>
  <div class="tile">
    <div class="label">Customers</div>
    <div class="value"><?= number_format($customers) ?></div>
    <div class="sub"><?= $liveCoupons ?> promotions running</div>
  </div>
</div>

<?php if ($missingCost > 0 || $missingQty > 0): ?>
<div class="card" style="border-top-color:#b8860b;">
  <h2 style="margin-top:0;">Waiting on data</h2>
  <p class="hint" style="margin-bottom:8px;">
    Two fields were never recorded in the supplier notes, and some of the
    dashboard is waiting on them:
  </p>
  <ul style="font-size:14px; margin-left:20px;">
    <?php if ($missingCost > 0): ?>
      <li><strong><?= number_format($missingCost) ?></strong> products have no cost price —
          needed for profit margins and for spotting expensive stock that isn't selling.</li>
    <?php endif; ?>
    <?php if ($missingQty > 0): ?>
      <li><strong><?= number_format($missingQty) ?></strong> products have no stock count —
          the In Stock / Low Stock badges are set by hand until these are entered.</li>
    <?php endif; ?>
  </ul>
  <p style="margin-top:10px;"><a href="products.php" class="btn small">Go to products</a></p>
</div>
<?php endif; ?>

<div style="display:flex; gap:20px; flex-wrap:wrap;">
  <div style="flex:1; min-width:300px;">
    <h2>Latest orders</h2>
    <div class="table-wrap">
      <table class="data">
        <thead><tr><th>#</th><th>Customer</th><th>Status</th><th class="num">Total</th></tr></thead>
        <tbody>
        <?php if (count($recentOrders) === 0): ?>
          <tr><td colspan="4" style="text-align:center; color:#888; padding:20px;">No orders yet.</td></tr>
        <?php endif; ?>
        <?php foreach ($recentOrders as $o): ?>
          <tr>
            <td><a href="orders.php">#<?= (int) $o['order_id'] ?></a></td>
            <td><?= e($o['customer']) ?></td>
            <td><span class="badge status-<?= e($o['status']) ?>"><?= e($o['status']) ?></span></td>
            <td class="num"><?= e(money($o['total'])) ?></td>
          </tr>
        <?php endforeach; ?>
        </tbody>
      </table>
    </div>
  </div>

  <div style="flex:1; min-width:300px;">
    <h2>Most engaged products</h2>
    <p class="hint">
      Velocity score = views + (cart adds × 3) + (purchases × 5).
      <a href="velocity.php" style="color:#d62839;">See the full ranking</a> or
      <a href="alerts.php" style="color:#d62839;">what needs acting on</a>.
    </p>
    <div class="table-wrap">
      <table class="data">
        <thead><tr><th>Product</th><th class="num">V</th><th class="num">C</th><th class="num">P</th><th class="num">Score</th></tr></thead>
        <tbody>
        <?php if (count($topProducts) === 0): ?>
          <tr><td colspan="5" style="text-align:center; color:#888; padding:20px;">
            No activity recorded yet.</td></tr>
        <?php endif; ?>
        <?php foreach ($topProducts as $p): ?>
          <tr>
            <td><?= e(mb_strimwidth($p['name'], 0, 34, '…')) ?></td>
            <td class="num"><?= (int) $p['views'] ?></td>
            <td class="num"><?= (int) $p['cart_adds'] ?></td>
            <td class="num"><?= (int) $p['purchases'] ?></td>
            <td class="num"><strong><?= (int) $p['velocity_score'] ?></strong></td>
          </tr>
        <?php endforeach; ?>
        </tbody>
      </table>
    </div>
  </div>
</div>

<?php adminFooter(); ?>
