<?php
// ============================================================
// Demand forecast.
//
// METHOD — least-squares linear regression.
//
// This fits a straight line through the monthly sales figures by
// choosing the slope and intercept that make the total squared error
// as small as possible. The coefficients are learned from the data
// rather than set by hand, which is what makes it a (very simple)
// supervised machine-learning model — it is the one every course starts
// with, before anything more elaborate.
//
//     revenue = intercept + (slope x month number)
//
// A neural network or similar would need thousands of examples to beat
// this. With a handful of months, a straight line plus an honest
// confidence figure is the defensible choice.
//
// R-squared says how much of the month-to-month movement the line
// actually explains, from 0 (none — the line is guessing) to 1 (perfect).
// It is shown on the page so nobody mistakes a weak fit for a firm
// prediction.
//
// A three-month moving average is calculated alongside it as a sanity
// check: if the two disagree wildly, the trend is not stable.
// ============================================================

require_once 'inc/auth.php';
require_once 'inc/layout.php';
requireAdmin();

$aheadOptions = [3, 6];
$ahead = (int) (isset($_GET['ahead']) ? $_GET['ahead'] : 3);
if (!in_array($ahead, $aheadOptions, true)) $ahead = 3;

$metric = isset($_GET['metric']) && $_GET['metric'] === 'units' ? 'units' : 'revenue';

// ------------------------------------------------------------
// History — every month that has sales, oldest first
// ------------------------------------------------------------
$history = fetchAll(
    "SELECT to_char(o.order_date, 'YYYY-MM') AS month,
            COUNT(DISTINCT o.order_id) AS orders,
            SUM(oi.quantity)           AS units,
            SUM(oi.line_total)         AS revenue
     FROM orders o
     JOIN order_items oi ON oi.order_id = o.order_id
     WHERE o.status <> 'Cancelled'
     GROUP BY to_char(o.order_date, 'YYYY-MM')
     ORDER BY month");

$n = count($history);

// ------------------------------------------------------------
// Fit the line
// ------------------------------------------------------------
function fitLine($points) {
    $n = count($points);
    if ($n < 2) return null;

    $sumX = 0; $sumY = 0; $sumXY = 0; $sumXX = 0;
    foreach ($points as $i => $y) {
        $sumX += $i; $sumY += $y; $sumXY += $i * $y; $sumXX += $i * $i;
    }
    $denominator = ($n * $sumXX) - ($sumX * $sumX);
    if ($denominator == 0) return null;

    $slope     = (($n * $sumXY) - ($sumX * $sumY)) / $denominator;
    $intercept = ($sumY - ($slope * $sumX)) / $n;

    // R-squared: how much of the variation the line accounts for
    $mean = $sumY / $n;
    $ssTot = 0; $ssRes = 0;
    foreach ($points as $i => $y) {
        $predicted = $intercept + ($slope * $i);
        $ssTot += ($y - $mean) ** 2;
        $ssRes += ($y - $predicted) ** 2;
    }
    $r2 = $ssTot > 0 ? 1 - ($ssRes / $ssTot) : 0;

    return ['slope' => $slope, 'intercept' => $intercept, 'r2' => max(0, $r2), 'mean' => $mean];
}

$series = array_map(fn($m) => (float) $m[$metric], $history);
$fit = fitLine($series);

// Three-month moving average, as a second opinion
$movingAvg = null;
if ($n >= 3) {
    $last3 = array_slice($series, -3);
    $movingAvg = array_sum($last3) / 3;
}

// ------------------------------------------------------------
// Project forward
// ------------------------------------------------------------
$projection = [];
if ($fit !== null) {
    $lastMonth = new DateTime($history[$n - 1]['month'] . '-01');
    for ($k = 1; $k <= $ahead; $k++) {
        $x = $n - 1 + $k;
        $value = $fit['intercept'] + ($fit['slope'] * $x);
        if ($value < 0) $value = 0;               // sales cannot go negative
        $future = clone $lastMonth;
        $future->modify("+$k month");
        $projection[] = ['month' => $future->format('Y-m'), 'value' => $value];
    }
}

// ------------------------------------------------------------
// How much to trust it
// ------------------------------------------------------------
$confidence = 'none';
$confidenceNote = '';
if ($fit === null) {
    $confidenceNote = 'Not enough months of sales to draw a line through yet.';
} elseif ($n < 6) {
    $confidence = 'low';
    $confidenceNote = "Only $n months of sales. That is enough to compute a line but not enough to trust it — " .
                      "treat this as a rough direction, not a number to order stock against.";
} elseif ($fit['r2'] < 0.3) {
    $confidence = 'low';
    $confidenceNote = 'The months vary too much for a straight line to describe them. ' .
                      'The projection is shown, but the trend is weak.';
} elseif ($fit['r2'] < 0.6) {
    $confidence = 'moderate';
    $confidenceNote = 'There is a visible trend, but a fair amount of month-to-month movement around it.';
} else {
    $confidence = 'good';
    $confidenceNote = 'The months follow the trend line closely, so the projection is reasonably firm.';
}

$confColour = ['none' => '#98a0aa', 'low' => '#c0392b', 'moderate' => '#b8860b', 'good' => '#1e8e3e'][$confidence];

// ------------------------------------------------------------
// Which categories are growing or shrinking
// ------------------------------------------------------------
$catTrends = [];
$catRows = fetchAll(
    "SELECT COALESCE(parent.name, c.name) AS category,
            to_char(o.order_date, 'YYYY-MM') AS month,
            SUM(oi.line_total) AS revenue
     FROM order_items oi
     JOIN orders o     ON o.order_id = oi.order_id
     JOIN products p   ON p.product_id = oi.product_id
     JOIN categories c ON c.category_id = p.category_id
     LEFT JOIN categories parent ON parent.category_id = c.parent_id
     WHERE o.status <> 'Cancelled'
     GROUP BY COALESCE(parent.name, c.name), to_char(o.order_date, 'YYYY-MM')
     ORDER BY category, month");

$grouped = [];
foreach ($catRows as $r) $grouped[$r['category']][$r['month']] = (float) $r['revenue'];

$allMonths = array_map(fn($m) => $m['month'], $history);
foreach ($grouped as $category => $months) {
    // Fill missing months with 0 so a gap counts as a bad month
    $points = [];
    foreach ($allMonths as $m) $points[] = isset($months[$m]) ? $months[$m] : 0;
    $f = fitLine($points);
    if ($f === null) continue;
    $catTrends[] = [
        'category' => $category,
        'slope'    => $f['slope'],
        'total'    => array_sum($points),
        'r2'       => $f['r2'],
    ];
}
usort($catTrends, fn($a, $b) => $b['slope'] <=> $a['slope']);

$unit = $metric === 'revenue' ? 'RM' : 'items';
function showValue($v, $metric) {
    return $metric === 'revenue' ? money($v) : number_format($v, 0) . ' items';
}

$chartMax = 0;
foreach ($series as $v) $chartMax = max($chartMax, $v);
foreach ($projection as $p) $chartMax = max($chartMax, $p['value']);

adminHeader('Sales Forecast', 'forecast');
?>

<div class="card" style="border-top-color:#2c5d8f;">
  <h2 style="margin-top:0;">How this is worked out</h2>
  <p style="font-size:14px;">
    The forecast fits a straight line through past monthly sales using
    <strong>least-squares linear regression</strong> &mdash; it picks the slope and starting point
    that leave the smallest total error against the real figures. The coefficients are learned
    from the data rather than chosen by hand, which is what makes it a supervised
    machine-learning model, albeit the simplest one there is.
  </p>
  <p style="font-family:monospace; background:#f4f6f8; padding:12px 16px; border-radius:6px; font-size:15px;">
    <?= $metric === 'revenue' ? 'revenue' : 'units' ?> = intercept + (slope &times; month number)
  </p>
  <p class="hint" style="margin-bottom:0;">
    Something heavier &mdash; a neural network, say &mdash; would need thousands of months to beat a
    straight line here. What matters more than the model is being honest about the fit, so
    <strong>R&sup2;</strong> is shown below: it says how much of the month-to-month movement the line
    actually explains, from 0 (guessing) to 1 (perfect).
  </p>
</div>

<form method="get" class="filters">
  <div class="field">
    <label>Forecast</label>
    <select name="metric" onchange="this.form.submit()">
      <option value="revenue" <?= $metric === 'revenue' ? 'selected' : '' ?>>Revenue</option>
      <option value="units"   <?= $metric === 'units'   ? 'selected' : '' ?>>Units sold (demand)</option>
    </select>
  </div>
  <div class="field">
    <label>Months ahead</label>
    <select name="ahead" onchange="this.form.submit()">
      <?php foreach ($aheadOptions as $a): ?>
        <option value="<?= $a ?>" <?= $ahead === $a ? 'selected' : '' ?>><?= $a ?> months</option>
      <?php endforeach; ?>
    </select>
  </div>
</form>

<?php if ($fit === null): ?>
  <div class="card" style="border-top-color:#c0392b;">
    <strong>Not enough sales history yet.</strong>
    <p style="font-size:14px; margin-top:6px;">
      A forecast needs at least two months with sales in them. There <?= $n === 1 ? 'is' : 'are' ?>
      currently <?= $n ?>. The page will start working on its own as orders come in.
    </p>
  </div>
<?php else: ?>

<div class="tiles">
  <div class="tile">
    <div class="label">Next month (<?= e(date('M Y', strtotime($projection[0]['month'] . '-01'))) ?>)</div>
    <div class="value"><?= e(showValue($projection[0]['value'], $metric)) ?></div>
    <div class="sub">Projected from the trend line</div>
  </div>
  <div class="tile" style="border-top-color:<?= $fit['slope'] >= 0 ? '#1e8e3e' : '#c0392b' ?>;">
    <div class="label">Direction</div>
    <div class="value" style="color:<?= $fit['slope'] >= 0 ? '#1e8e3e' : '#c0392b' ?>;">
      <?= $fit['slope'] >= 0 ? '&#9650;' : '&#9660;' ?>
      <?= e(showValue(abs($fit['slope']), $metric)) ?>
    </div>
    <div class="sub">Change per month<?= $fit['slope'] >= 0 ? ', growing' : ', falling' ?></div>
  </div>
  <div class="tile" style="border-top-color:<?= $confColour ?>;">
    <div class="label">Confidence (R&sup2;)</div>
    <div class="value" style="color:<?= $confColour ?>;"><?= number_format($fit['r2'], 2) ?></div>
    <div class="sub"><?= ucfirst($confidence) ?> &mdash; based on <?= $n ?> months</div>
  </div>
  <?php if ($movingAvg !== null): ?>
  <div class="tile" style="border-top-color:#6c7581;">
    <div class="label">3-month average</div>
    <div class="value"><?= e(showValue($movingAvg, $metric)) ?></div>
    <div class="sub">Second opinion, ignoring the trend</div>
  </div>
  <?php endif; ?>
</div>

<div class="card" style="border-top-color:<?= $confColour ?>;">
  <strong style="color:<?= $confColour ?>;">How much to trust this:</strong>
  <span style="font-size:14px;"><?= e($confidenceNote) ?></span>
  <?php if ($movingAvg !== null && $projection[0]['value'] > 0):
      $gap = abs($projection[0]['value'] - $movingAvg) / max($movingAvg, 1) * 100; ?>
    <?php if ($gap > 40): ?>
      <p style="font-size:14px; margin-top:8px; color:#c0392b;">
        The line and the three-month average disagree by <?= round($gap) ?>%, which means recent
        months are not following the longer trend. Treat the projection with extra care.
      </p>
    <?php endif; ?>
  <?php endif; ?>
</div>

<!-- ---------------- CHART ---------------- -->
<h2>History and projection</h2>
<div class="card">
  <div style="display:flex; align-items:flex-end; gap:10px; height:250px; padding-top:10px;">
    <?php foreach ($history as $i => $m):
        $v = (float) $m[$metric];
        $h = $chartMax > 0 ? round($v / $chartMax * 190) : 0; ?>
      <div style="flex:1; text-align:center; display:flex; flex-direction:column; justify-content:flex-end; height:100%;">
        <div style="font-size:10px; color:#666; margin-bottom:4px;">
          <?= $metric === 'revenue' ? number_format($v / 1000, 1) . 'k' : (int) $v ?>
        </div>
        <div title="Actual: <?= e(showValue($v, $metric)) ?>"
             style="background:linear-gradient(180deg,#d62839,#7a0c1f); height:<?= max($h, 3) ?>px; border-radius:4px 4px 0 0;"></div>
        <div style="font-size:10px; color:#888; margin-top:5px;"><?= e(date('M', strtotime($m['month'] . '-01'))) ?></div>
      </div>
    <?php endforeach; ?>

    <?php foreach ($projection as $p):
        $h = $chartMax > 0 ? round($p['value'] / $chartMax * 190) : 0; ?>
      <div style="flex:1; text-align:center; display:flex; flex-direction:column; justify-content:flex-end; height:100%;">
        <div style="font-size:10px; color:#2c5d8f; margin-bottom:4px;">
          <?= $metric === 'revenue' ? number_format($p['value'] / 1000, 1) . 'k' : round($p['value']) ?>
        </div>
        <div title="Projected: <?= e(showValue($p['value'], $metric)) ?>"
             style="background:repeating-linear-gradient(45deg,#aec6e0,#aec6e0 5px,#cddcea 5px,#cddcea 10px);
                    border:2px dashed #2c5d8f; border-bottom:none; height:<?= max($h, 3) ?>px; border-radius:4px 4px 0 0;"></div>
        <div style="font-size:10px; color:#2c5d8f; margin-top:5px;"><?= e(date('M', strtotime($p['month'] . '-01'))) ?></div>
      </div>
    <?php endforeach; ?>
  </div>
  <p class="hint" style="margin:14px 0 0;">
    Solid red is what actually happened. Hatched blue is the projection.
  </p>
</div>

<!-- ---------------- THE WORKING ---------------- -->
<h2>The working</h2>
<p class="hint">Every number above comes from these figures, so the calculation can be checked by hand.</p>
<div class="table-wrap">
<table class="data">
  <thead><tr><th>Month</th><th>#</th><th class="num">Actual</th><th class="num">Line says</th>
             <th class="num">Difference</th><th></th></tr></thead>
  <tbody>
  <?php foreach ($history as $i => $m):
      $actual = (float) $m[$metric];
      $predicted = $fit['intercept'] + ($fit['slope'] * $i);
      $diff = $actual - $predicted; ?>
    <tr>
      <td><?= e(date('M Y', strtotime($m['month'] . '-01'))) ?></td>
      <td><?= $i ?></td>
      <td class="num"><?= e(showValue($actual, $metric)) ?></td>
      <td class="num" style="color:#888;"><?= e(showValue(max($predicted, 0), $metric)) ?></td>
      <td class="num" style="color:<?= $diff >= 0 ? '#1e8e3e' : '#c0392b' ?>;">
        <?= $diff >= 0 ? '+' : '&minus;' ?><?= e(showValue(abs($diff), $metric)) ?>
      </td>
      <td><span class="badge grey">actual</span></td>
    </tr>
  <?php endforeach; ?>
  <?php foreach ($projection as $k => $p): ?>
    <tr style="background:#f7fafd;">
      <td><strong><?= e(date('M Y', strtotime($p['month'] . '-01'))) ?></strong></td>
      <td><?= $n + $k ?></td>
      <td class="num" style="color:#bbb;">&mdash;</td>
      <td class="num"><strong><?= e(showValue($p['value'], $metric)) ?></strong></td>
      <td class="num" style="color:#bbb;">&mdash;</td>
      <td><span class="badge" style="background:#eaf2fb; color:#2c5d8f;">forecast</span></td>
    </tr>
  <?php endforeach; ?>
  </tbody>
</table>
</div>

<p class="hint" style="margin-top:12px;">
  Fitted line: <code><?= $metric ?> = <?= number_format($fit['intercept'], 2) ?>
  <?= $fit['slope'] >= 0 ? '+' : '&minus;' ?> <?= number_format(abs($fit['slope']), 2) ?> &times; month</code>
  &nbsp;·&nbsp; R&sup2; = <?= number_format($fit['r2'], 4) ?>
</p>

<!-- ---------------- CATEGORY OUTLOOK ---------------- -->
<h2 style="margin-top:26px;">Which categories are moving</h2>
<p class="hint">
  The same line fitted separately to each category, so you can see what is picking up and what is
  falling away. Sorted by change per month.
</p>
<div class="table-wrap">
<table class="data">
  <thead><tr><th>Category</th><th class="num">Total sold</th><th class="num">Change / month</th>
             <th style="width:190px;">Direction</th><th class="num">R&sup2;</th></tr></thead>
  <tbody>
  <?php if (count($catTrends) === 0): ?>
    <tr><td colspan="5" style="text-align:center; color:#888; padding:22px;">No category has enough sales yet.</td></tr>
  <?php endif; ?>
  <?php
  $biggest = 0;
  foreach ($catTrends as $t) $biggest = max($biggest, abs($t['slope']));
  foreach ($catTrends as $t):
      $width = $biggest > 0 ? round(abs($t['slope']) / $biggest * 50) : 0;
      $up = $t['slope'] >= 0; ?>
    <tr>
      <td><?= e($t['category']) ?></td>
      <td class="num"><?= e(money($t['total'])) ?></td>
      <td class="num" style="color:<?= $up ? '#1e8e3e' : '#c0392b' ?>;">
        <?= $up ? '+' : '&minus;' ?><?= e(money(abs($t['slope']))) ?>
      </td>
      <td>
        <div style="display:flex; align-items:center; height:12px;">
          <div style="width:50%; display:flex; justify-content:flex-end;">
            <?php if (!$up): ?><div style="background:#c0392b; width:<?= $width ?>%; height:12px; border-radius:3px 0 0 3px;"></div><?php endif; ?>
          </div>
          <div style="width:1px; height:16px; background:#ccd1d7;"></div>
          <div style="width:50%;">
            <?php if ($up): ?><div style="background:#1e8e3e; width:<?= $width ?>%; height:12px; border-radius:0 3px 3px 0;"></div><?php endif; ?>
          </div>
        </div>
      </td>
      <td class="num" style="color:#999;"><?= number_format($t['r2'], 2) ?></td>
    </tr>
  <?php endforeach; ?>
  </tbody>
</table>
</div>

<?php endif; ?>

<?php adminFooter(); ?>
