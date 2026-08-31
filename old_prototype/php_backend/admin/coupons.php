<?php
// ============================================================
// Promotions and coupon codes.
//
// Creating one here is what triggers the customer notification: the
// shop reads the live coupons, and when a shopper's most-viewed
// category is on offer, the pop-up appears for them.
// ============================================================

require_once 'inc/auth.php';
require_once 'inc/layout.php';
requireAdmin();

$errors = [];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    checkCsrf();

    if (isset($_POST['toggle'])) {
        $couponId = (int) $_POST['coupon_id'];
        query("UPDATE coupons SET is_active = 1 - is_active WHERE coupon_id = ?", [$couponId], 'i');
        flash('Promotion updated.');
        header('Location: coupons.php'); exit;
    }

    if (isset($_POST['delete'])) {
        $couponId = (int) $_POST['coupon_id'];
        query("DELETE FROM coupons WHERE coupon_id = ?", [$couponId], 'i');
        flash('Promotion deleted.');
        header('Location: coupons.php'); exit;
    }

    if (isset($_POST['create'])) {
        $code        = strtoupper(trim($_POST['code']));
        $description = trim($_POST['description']);
        $categoryId  = (int) $_POST['category_id'];
        $percent     = (float) $_POST['discount_percent'];
        $days        = (int) $_POST['days'];

        if ($code === '')                     $errors[] = 'A code is required.';
        if (!preg_match('/^[A-Z0-9]{3,30}$/', $code)) $errors[] = 'Code should be 3-30 letters and numbers, no spaces.';
        if ($percent <= 0 || $percent > 90)   $errors[] = 'Discount must be between 1% and 90%.';
        if (fetchOne("SELECT coupon_id FROM coupons WHERE code = ?", [$code])) $errors[] = 'That code already exists.';

        if (count($errors) === 0) {
            $endsAt = $days > 0 ? date('Y-m-d H:i:s', strtotime("+$days days")) : null;
            $catForDb = $categoryId > 0 ? $categoryId : null;
            if ($description === '') {
                $catName = $catForDb
                    ? fetchValue("SELECT name FROM categories WHERE category_id = ?", [$catForDb], 'i')
                    : 'everything';
                $description = rtrim($percent, '0.') . '% off ' . strtolower($catName);
            }
            query("INSERT INTO coupons (code, description, category_id, discount_percent, ends_at)
                   VALUES (?, ?, ?, ?, ?)",
                  [$code, $description, $catForDb, $percent, $endsAt], 'ssids');
            flash('Promotion created. Customers browsing that category will be notified.');
            header('Location: coupons.php'); exit;
        }
    }
}

$categories = fetchAll(
    "SELECT c.category_id, c.name, parent.name AS parent
     FROM categories c LEFT JOIN categories parent ON parent.category_id = c.parent_id
     ORDER BY COALESCE(parent.name, c.name), c.parent_id IS NOT NULL, c.name");

$coupons = fetchAll(
    "SELECT c.*, cat.name AS category,
            (SELECT COUNT(*) FROM orders o WHERE o.coupon_code = c.code) AS times_used
     FROM coupons c LEFT JOIN categories cat ON cat.category_id = c.category_id
     ORDER BY c.is_active DESC, c.created_at DESC");

adminHeader('Promotions', 'coupons');
?>

<?php if (count($errors) > 0): ?>
  <div class="error-box"><?= implode('<br />', array_map('e', $errors)) ?></div>
<?php endif; ?>

<div class="card">
  <h2 style="margin-top:0;">New promotion</h2>
  <p class="hint">
    Switching a promotion on is what sends the customer notification —
    shoppers who have been browsing that category see it on their next visit.
  </p>
  <form method="post">
    <input type="hidden" name="csrf" value="<?= e(csrfToken()) ?>" />
    <div class="form-row">
      <div class="field">
        <label for="code">Coupon code</label>
        <input type="text" id="code" name="code" placeholder="SAVE15" required style="text-transform:uppercase;" />
      </div>
      <div class="field">
        <label for="discount_percent">Discount %</label>
        <input type="number" id="discount_percent" name="discount_percent" min="1" max="90" step="0.5" value="10" required />
      </div>
      <div class="field">
        <label for="category_id">Applies to</label>
        <select id="category_id" name="category_id">
          <option value="0">Everything in the shop</option>
          <?php foreach ($categories as $c): ?>
            <option value="<?= (int) $c['category_id'] ?>">
              <?= e($c['parent'] ? $c['parent'] . ' > ' . $c['name'] : $c['name']) ?>
            </option>
          <?php endforeach; ?>
        </select>
      </div>
      <div class="field">
        <label for="days">Runs for (days)</label>
        <input type="number" id="days" name="days" min="0" value="30" />
        <small>0 means no end date.</small>
      </div>
    </div>
    <div class="field">
      <label for="description">Description shown to customers</label>
      <input type="text" id="description" name="description" placeholder="Left blank, one is written for you" />
    </div>
    <button type="submit" name="create" value="1" class="btn">Create promotion</button>
  </form>
</div>

<div class="table-wrap">
<table class="data">
  <thead>
    <tr><th>Code</th><th>Description</th><th>Applies to</th><th class="num">Discount</th>
        <th>Ends</th><th class="num">Used</th><th>Status</th><th></th></tr>
  </thead>
  <tbody>
  <?php foreach ($coupons as $c):
      $expired = $c['ends_at'] !== null && strtotime($c['ends_at']) < time();
      $live    = (int) $c['is_active'] === 1 && !$expired;
  ?>
    <tr>
      <td><strong><?= e($c['code']) ?></strong></td>
      <td><?= e($c['description']) ?></td>
      <td><?= e($c['category'] ?: 'Everything') ?></td>
      <td class="num"><?= e(rtrim(rtrim(number_format((float) $c['discount_percent'], 2), '0'), '.')) ?>%</td>
      <td><small><?= $c['ends_at'] ? e(date('j M Y', strtotime($c['ends_at']))) : 'No end date' ?></small></td>
      <td class="num"><?= (int) $c['times_used'] ?></td>
      <td>
        <?php if ($expired): ?>
          <span class="badge grey">Expired</span>
        <?php elseif ($live): ?>
          <span class="badge in">Live</span>
        <?php else: ?>
          <span class="badge out">Off</span>
        <?php endif; ?>
      </td>
      <td style="white-space:nowrap;">
        <form method="post" style="display:inline;">
          <input type="hidden" name="csrf" value="<?= e(csrfToken()) ?>" />
          <input type="hidden" name="coupon_id" value="<?= (int) $c['coupon_id'] ?>" />
          <button type="submit" name="toggle" value="1" class="btn small grey">
            <?= (int) $c['is_active'] === 1 ? 'Switch off' : 'Switch on' ?>
          </button>
          <button type="submit" name="delete" value="1" class="btn small danger"
                  onclick="return confirm('Delete this promotion?');">Delete</button>
        </form>
      </td>
    </tr>
  <?php endforeach; ?>
  </tbody>
</table>
</div>

<?php adminFooter(); ?>
