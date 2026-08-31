<?php
// ============================================================
// Inventory Velocity — LFU turned around.
//
// LFU (least-frequently-used) is a caching idea: count how often each
// item is touched, and throw out the ones nobody wants. We keep the
// counting but read it the other way up — instead of finding what to
// evict, we rank what customers engage with most.
//
// Not every touch means the same thing, so each is weighted by how
// close it is to a sale:
//
//     score = (views x 1) + (cart adds x 3) + (purchases x 5)
//
// A view is idle curiosity. Putting something in the basket is real
// intent. Buying it is the thing we actually care about, so it counts
// five times as much as a look.
//
// Products are then split into tiers by where they rank: the top fifth
// are High velocity, the next third Mid, the rest Low. Anything with no
// activity at all is listed separately — that is what feeds the
// dead-stock alerts on the next page.
// ============================================================

require_once 'inc/auth.php';
require_once 'inc/layout.php';
requireAdmin();

// How far back to look
$days = (int) (isset($_GET['days']) ? $_GET['days'] : 90);
if (!in_array($days, [30, 90, 180, 0], true)) $days = 90;
$dateFilter = $days > 0 ? "AND e.created_at >= NOW() - INTERVAL '$days days'" : "";

$catId = (int) (isset($_GET['cat']) ? $_GET['cat'] : 0);
$catFilter = $catId > 0 ? "AND (p.category_id = $catId OR c.parent_id = $catId)" : "";

// Counting the touches:
//   MySQL was asked to SUM a comparison, because a comparison there is
//   1 when true and 0 when false. Postgres keeps true and false as true
//   and false, so the count is asked for directly instead:
//   COUNT(*) FILTER (WHERE ...) - same three numbers, said properly.

// One row per product, with its weighted score
$rows = fetchAll(
    "SELECT p.product_id, p.name, p.price, p.stock_status, p.stock_qty,
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
     LEFT JOIN events e ON e.product_id = p.product_id $dateFilter
     WHERE p.is_active = 1 $catFilter
     GROUP BY p.product_id, p.name, p.price, p.stock_status, p.stock_qty, c.name, parent.name
     ORDER BY score DESC, p.name");

// ---- work out the tiers ----
// Only products with some activity get ranked; the rest are "no activity".
$active = array_values(array_filter($rows, fn($r) => (int) $r['score'] > 0));
$idle   = array_values(array_filter($rows, fn($r) => (int) $r['score'] == 0));

$activeCount = count($active);
$highCut = (int) ceil($activeCount * 0.20);            // top 20%
$midCut  = (int) ceil($activeCount * 0.50);            // next 30%

foreach ($active as $i => &$r) {
    if ($i < $highCut)      $r['tier'] = 'High';
    elseif ($i < $midCut)   $r['tier'] = 'Mid';
    else                    $r['tier'] = 'Low';
}
unset($r);

$counts = ['High' => 0, 'Mid' => 0, 'Low' => 0];
foreach ($active as $r) $counts[$r['tier']]++;

$topScore = $activeCount > 0 ? (int) $active[0]['score'] : 1;

$categories = fetchAll(
    "SELECT c.category_id, c.name, parent.name AS parent
     FROM categories c LEFT JOIN categories parent ON parent.category_id = c.parent_id
     ORDER BY COALESCE(parent.name, c.name), c.parent_id IS NOT NULL, c.name");

$tierFilter = isset($_GET['tier']) ? $_GET['tier'] : '';
$shown = $tierFilter === 'idle' ? $idle
       : ($tierFilter !== '' ? array_values(array_filter($active, fn($r) => $r['tier'] === $tierFilter))
                             : $active);

function tierClass($tier) {
    return ['High' => 'in', 'Mid' => 'low', 'Low' => 'grey'][$tier] ?? 'grey';
}

adminHeader('Inventory Velocity', 'velocity');
?>

<div class="card" style="border-top-color:#2c5d8f;">
  <h2 style="margin-top:0;">How the score works</h2>
  <p style="font-size:14px; margin-bottom:10px;">
    This is LFU &mdash; the least-frequently-used caching idea &mdash; read the other way up.
    Instead of finding what to throw away, we count every time a customer touches a product
    and rank the ones they engage with most. Each kind of touch is weighted by how close it
    sits to an actual sale:
  </p>
  <p style="font-family:monospace; background:#f4f6f8; padding:12px 16px; border-radius:6px; font-size:15px;">
    score = (views &times; 1) + (cart adds &times; 3) + (purchases &times; 5)
  </p>
  <p class="hint" style="margin-bottom:0;">
    The top 20% by score are <strong>High</strong> velocity, the next 30% <strong>Mid</strong>,
    the rest <strong>Low</strong>. Products nobody touched at all are listed separately &mdash;
    those are the ones the dead-stock alerts pick up.
  </p>
</div>

<form method="get" class="filters">
  <div class="field">
    <label>Period</label>
    <select name="days" onchange="this.form.submit()">
      <option value="30"  <?= $days === 30  ? 'selected' : '' ?>>Last 30 days</option>
      <option value="90"  <?= $days === 90  ? 'selected' : '' ?>>Last 90 days</option>
      <option value="180" <?= $days === 180 ? 'selected' : '' ?>>Last 6 months</option>
      <option value="0"   <?= $days === 0   ? 'selected' : '' ?>>All time</option>
    </select>
  </div>
  <div class="field">
    <label>Category</label>
    <select name="cat" onchange="this.form.submit()">
      <option value="0">All categories</option>
      <?php foreach ($categories as $c): ?>
        <option value="<?= (int) $c['category_id'] ?>" <?= $catId === (int) $c['category_id'] ? 'selected' : '' ?>>
          <?= e($c['parent'] ? $c['parent'] . ' > ' . $c['name'] : $c['name']) ?>
        </option>
      <?php endforeach; ?>
    </select>
  </div>
  <?php if ($tierFilter !== ''): ?><input type="hidden" name="tier" value="<?= e($tierFilter) ?>" /><?php endif; ?>
</form>

<div class="tiles">
  <?php
  $tiles = [
    ['High', $counts['High'], 'Selling and being looked at', 'in'],
    ['Mid',  $counts['Mid'],  'Steady interest', 'low'],
    ['Low',  $counts['Low'],  'Barely moving', 'grey'],
  ];
  foreach ($tiles as $t): ?>
    <a class="tile" href="?days=<?= $days ?>&cat=<?= $catId ?>&tier=<?= $t[0] ?>"
       style="border-top-color:<?= $t[0]==='High' ? '#1e8e3e' : ($t[0]==='Mid' ? '#b8860b' : '#98a0aa') ?>;">
      <div class="label"><?= $t[0] ?> velocity</div>
      <div class="value"><?= $t[1] ?></div>
      <div class="sub"><?= $t[2] ?></div>
    </a>
  <?php endforeach; ?>
  <a class="tile" href="?days=<?= $days ?>&cat=<?= $catId ?>&tier=idle" style="border-top-color:#c0392b;">
    <div class="label">No activity</div>
    <div class="value"><?= count($idle) ?></div>
    <div class="sub">Not viewed or bought at all</div>
  </a>
</div>

<div class="filters" style="margin-top:4px;">
  <a href="?days=<?= $days ?>&cat=<?= $catId ?>" class="btn <?= $tierFilter === '' ? '' : 'grey' ?>">All ranked</a>
  <?php foreach (['High','Mid','Low'] as $t): ?>
    <a href="?days=<?= $days ?>&cat=<?= $catId ?>&tier=<?= $t ?>"
       class="btn <?= $tierFilter === $t ? '' : 'grey' ?>"><?= $t ?></a>
  <?php endforeach; ?>
  <a href="?days=<?= $days ?>&cat=<?= $catId ?>&tier=idle"
     class="btn <?= $tierFilter === 'idle' ? '' : 'grey' ?>">No activity</a>
</div>

<div class="table-wrap">
<table class="data">
  <thead>
    <tr>
      <th>#</th><th>Product</th><th>Category</th>
      <th class="num">Views</th><th class="num">Cart</th><th class="num">Sold</th>
      <th class="num">Score</th><th style="width:150px;">Relative</th>
      <th>Tier</th><th>Stock</th>
    </tr>
  </thead>
  <tbody>
  <?php if (count($shown) === 0): ?>
    <tr><td colspan="10" style="text-align:center; color:#888; padding:26px;">Nothing here for those filters.</td></tr>
  <?php endif; ?>
  <?php foreach (array_slice($shown, 0, 100) as $i => $r):
      $score = (int) $r['score'];
      $bar = $topScore > 0 ? round($score / $topScore * 100) : 0;
  ?>
    <tr>
      <td><?= $i + 1 ?></td>
      <td>
        <a href="product_edit.php?id=<?= (int) $r['product_id'] ?>"><?= e(mb_strimwidth($r['name'], 0, 44, '…')) ?></a>
        <br /><small style="color:#999;"><?= e(money($r['price'])) ?></small>
      </td>
      <td><small><?= e($r['parent'] ? $r['parent'] . ' > ' . $r['category'] : $r['category']) ?></small></td>
      <td class="num"><?= (int) $r['views'] ?></td>
      <td class="num"><?= (int) $r['cart_adds'] ?></td>
      <td class="num"><?= (int) $r['purchases'] ?></td>
      <td class="num"><strong><?= $score ?></strong></td>
      <td>
        <div style="background:#eef0f3; border-radius:3px; height:9px; width:100%;">
          <div style="background:<?= isset($r['tier']) && $r['tier']==='High' ? '#1e8e3e' : (isset($r['tier']) && $r['tier']==='Mid' ? '#b8860b' : '#98a0aa') ?>;
                      width:<?= max($bar, $score > 0 ? 2 : 0) ?>%; height:9px; border-radius:3px;"></div>
        </div>
      </td>
      <td><span class="badge <?= tierClass($r['tier'] ?? '') ?>"><?= e($r['tier'] ?? 'None') ?></span></td>
      <td><span class="badge <?= e($r['stock_status']) ?>"><?= e(stockWord($r['stock_status'])) ?></span></td>
    </tr>
  <?php endforeach; ?>
  </tbody>
</table>
</div>

<?php if (count($shown) > 100): ?>
  <p class="hint" style="margin-top:12px;">Showing the first 100 of <?= count($shown) ?>.</p>
<?php endif; ?>

<?php
function stockWord($s) {
    return ['in' => 'In stock', 'low' => 'Low', 'out' => 'Out'][$s] ?? $s;
}
adminFooter();
?>
