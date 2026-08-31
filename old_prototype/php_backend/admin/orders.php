<?php
// ============================================================
// Orders, and moving them along the stages:
//   Pending -> Processing -> Shipped -> Delivered
// Every change is written to order_status_history, so there is a record
// of when each order moved and which member of staff moved it.
// ============================================================

require_once 'inc/auth.php';
require_once 'inc/layout.php';
requireAdmin();

$STAGES = ['Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled'];

// The next step along for each stage
$NEXT = ['Pending' => 'Processing', 'Processing' => 'Shipped', 'Shipped' => 'Delivered'];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    checkCsrf();
    $orderId = (int) $_POST['order_id'];
    $note    = trim(isset($_POST['note']) ? $_POST['note'] : '');

    // The "Move to X" button and the dropdown are separate fields on
    // purpose. If they shared a name the browser would send both and the
    // dropdown's value would quietly win, so the button would do nothing.
    $status = isset($_POST['advance']) && $_POST['advance'] !== ''
        ? $_POST['advance']
        : (isset($_POST['status']) ? $_POST['status'] : '');

    if (!in_array($status, $STAGES, true)) { flash('Unknown status.'); header('Location: orders.php'); exit; }

    // Both writes belong together, so they go in one transaction.
    dbBegin();
    try {
        query("UPDATE orders SET status = ? WHERE order_id = ?", [$status, $orderId], 'si');
        query("INSERT INTO order_status_history (order_id, status, changed_by, note)
               VALUES (?, ?, ?, ?)",
              [$orderId, $status, adminId(), $note], 'isis');
        dbCommit();
        flash("Order #$orderId moved to $status.");
    } catch (Exception $ex) {
        dbRollback();
        flash('Could not update that order.');
    }
    header('Location: ' . $_SERVER['REQUEST_URI']);
    exit;
}

$filter = isset($_GET['status']) ? $_GET['status'] : '';
$where  = '';
$params = []; $types = '';
if (in_array($filter, $STAGES, true)) {
    $where = 'WHERE o.status = ?';
    $params[] = $filter; $types = 's';
}

$orders = fetchAll(
    "SELECT o.order_id, o.order_date, o.status, o.subtotal, o.discount, o.total,
            o.coupon_code, o.shipping_name, o.shipping_phone, o.shipping_address,
            c.name AS customer_name, c.email AS customer_email
     FROM orders o JOIN customers c ON c.customer_id = o.customer_id
     $where
     ORDER BY o.order_date DESC
     LIMIT 200", $params, $types);

// Counts for the filter buttons
$counts = [];
foreach (fetchAll("SELECT status, COUNT(*) AS n FROM orders GROUP BY status") as $r) {
    $counts[$r['status']] = (int) $r['n'];
}
$allCount = array_sum($counts);

adminHeader('Orders', 'orders');
?>

<div class="filters">
  <a href="orders.php" class="btn <?= $filter === '' ? '' : 'grey' ?>">All (<?= $allCount ?>)</a>
  <?php foreach ($STAGES as $s): ?>
    <a href="orders.php?status=<?= urlencode($s) ?>" class="btn <?= $filter === $s ? '' : 'grey' ?>">
      <?= e($s) ?> (<?= isset($counts[$s]) ? $counts[$s] : 0 ?>)
    </a>
  <?php endforeach; ?>
</div>

<?php if (count($orders) === 0): ?>
  <div class="card" style="text-align:center; color:#888;">No orders here yet.</div>
<?php endif; ?>

<?php foreach ($orders as $o):
    $items = fetchAll("SELECT product_name, unit_price, quantity, line_total
                       FROM order_items WHERE order_id = ?", [(int) $o['order_id']], 'i');
    $history = fetchAll("SELECT h.status, h.changed_at, h.note, a.name AS staff
                         FROM order_status_history h
                         LEFT JOIN admins a ON a.admin_id = h.changed_by
                         WHERE h.order_id = ? ORDER BY h.changed_at", [(int) $o['order_id']], 'i');
?>
<div class="card">
  <div style="display:flex; justify-content:space-between; flex-wrap:wrap; gap:12px;">
    <div>
      <h2 style="margin:0;">Order #<?= (int) $o['order_id'] ?>
        <span class="badge status-<?= e($o['status']) ?>"><?= e($o['status']) ?></span>
      </h2>
      <div style="font-size:13px; color:#888;">
        <?= e(date('j M Y, g:ia', strtotime($o['order_date']))) ?>
        &nbsp;·&nbsp; <?= e($o['customer_name']) ?> (<?= e($o['customer_email']) ?>)
      </div>
    </div>
    <div style="text-align:right;">
      <div style="font-size:20px; font-weight:bold;"><?= e(money($o['total'])) ?></div>
      <?php if ((float) $o['discount'] > 0): ?>
        <div style="font-size:12px; color:#1e8e3e;">
          <?= e($o['coupon_code']) ?> −<?= e(money($o['discount'])) ?>
        </div>
      <?php endif; ?>
    </div>
  </div>

  <div style="display:flex; gap:26px; flex-wrap:wrap; margin-top:14px;">
    <div style="flex:2; min-width:260px;">
      <table class="data" style="font-size:13px;">
        <?php foreach ($items as $i): ?>
          <tr>
            <td><?= (int) $i['quantity'] ?> ×</td>
            <td><?= e($i['product_name']) ?></td>
            <td class="num"><?= e(money($i['line_total'])) ?></td>
          </tr>
        <?php endforeach; ?>
      </table>
    </div>
    <div style="flex:1; min-width:200px; font-size:13px;">
      <strong>Deliver to</strong><br />
      <?= e($o['shipping_name']) ?><br />
      <?= e($o['shipping_phone']) ?><br />
      <?= nl2br(e($o['shipping_address'])) ?>
    </div>
  </div>

  <?php if (count($history) > 0): ?>
    <div style="margin-top:12px; font-size:12px; color:#999;">
      <strong>History:</strong>
      <?php foreach ($history as $h): ?>
        <?= e($h['status']) ?> (<?= e(date('j M g:ia', strtotime($h['changed_at']))) ?><?php
          if ($h['staff']) echo ', ' . e($h['staff']); ?>)<?= $h === end($history) ? '' : ' →' ?>
      <?php endforeach; ?>
    </div>
  <?php endif; ?>

  <form method="post" style="margin-top:14px; display:flex; gap:8px; align-items:center; flex-wrap:wrap;">
    <input type="hidden" name="csrf" value="<?= e(csrfToken()) ?>" />
    <input type="hidden" name="order_id" value="<?= (int) $o['order_id'] ?>" />
    <input type="text" name="note" placeholder="Note (optional)" style="flex:1; min-width:160px; padding:8px 10px; border:1px solid #ccd1d7; border-radius:6px;" />

    <?php if (isset($NEXT[$o['status']])): ?>
      <button type="submit" name="advance" value="<?= e($NEXT[$o['status']]) ?>" class="btn small">
        Move to <?= e($NEXT[$o['status']]) ?>
      </button>
    <?php endif; ?>

    <select name="status" style="padding:7px 10px; border:1px solid #ccd1d7; border-radius:6px;">
      <?php foreach ($STAGES as $s): ?>
        <option value="<?= e($s) ?>" <?= $o['status'] === $s ? 'selected' : '' ?>><?= e($s) ?></option>
      <?php endforeach; ?>
    </select>
    <button type="submit" class="btn small grey">Set</button>
  </form>
</div>
<?php endforeach; ?>

<?php adminFooter(); ?>
