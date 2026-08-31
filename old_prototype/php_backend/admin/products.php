<?php
// ============================================================
// Product list: search, filter, and quick edits to price and stock.
// Adding and full editing happen on product_edit.php.
// ============================================================

require_once 'inc/auth.php';
require_once 'inc/layout.php';
requireAdmin();

// ---------------- quick actions ----------------
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    checkCsrf();

    // Change price / stock straight from the list
    if (isset($_POST['quick_save'])) {
        $id     = (int) $_POST['product_id'];
        $price  = (float) $_POST['price'];
        $status = $_POST['stock_status'];
        $qtyRaw = trim($_POST['stock_qty']);
        $qty    = ($qtyRaw === '') ? null : (int) $qtyRaw;

        if (!in_array($status, ['in', 'low', 'out'], true)) $status = 'in';

        // If a real count is given, work the badge out from it rather than
        // trusting the dropdown — the number is the better source.
        if ($qty !== null) {
            $reorder = (int) fetchValue("SELECT reorder_level FROM products WHERE product_id = ?", [$id], 'i');
            if ($qty <= 0)              $status = 'out';
            elseif ($qty <= $reorder)   $status = 'low';
            else                        $status = 'in';
        }

        query("UPDATE products SET price = ?, stock_qty = ?, stock_status = ? WHERE product_id = ?",
              [$price, $qty, $status, $id], 'disi');
        flash('Saved.');
        header('Location: ' . $_SERVER['REQUEST_URI']);
        exit;
    }

    // Remove from the shop. This is a soft delete: the row stays so old
    // orders still point at a real product, it just stops being listed.
    if (isset($_POST['remove'])) {
        $id = (int) $_POST['product_id'];
        query("UPDATE products SET is_active = 0 WHERE product_id = ?", [$id], 'i');
        flash('Product removed from the shop. Past orders are unaffected.');
        header('Location: ' . $_SERVER['REQUEST_URI']);
        exit;
    }

    if (isset($_POST['restore'])) {
        $id = (int) $_POST['product_id'];
        query("UPDATE products SET is_active = 1 WHERE product_id = ?", [$id], 'i');
        flash('Product put back in the shop.');
        header('Location: ' . $_SERVER['REQUEST_URI']);
        exit;
    }
}

// ---------------- filters ----------------
$search   = trim(isset($_GET['q']) ? $_GET['q'] : '');
$catId    = (int) (isset($_GET['cat']) ? $_GET['cat'] : 0);
$stock    = isset($_GET['stock']) ? $_GET['stock'] : '';
$showGone = isset($_GET['inactive']) && $_GET['inactive'] === '1';
$page     = max(1, (int) (isset($_GET['page']) ? $_GET['page'] : 1));
$perPage  = 25;

$where  = [$showGone ? 'p.is_active = 0' : 'p.is_active = 1'];
$params = [];
$types  = '';

if ($search !== '') {
    // ILIKE is LIKE that ignores case. MySQL's LIKE already did, so
    // searching "asus" had always found "ASUS"; in Postgres that has to
    // be asked for, or the search box quietly stops finding things.
    $where[]  = '(p.name ILIKE ? OR b.name ILIKE ?)';
    $like     = '%' . $search . '%';
    $params[] = $like; $params[] = $like; $types .= 'ss';
}
if ($catId > 0) {
    // Matches the category itself or anything under it
    $where[]  = '(p.category_id = ? OR c.parent_id = ?)';
    $params[] = $catId; $params[] = $catId; $types .= 'ii';
}
if (in_array($stock, ['in', 'low', 'out'], true)) {
    $where[]  = 'p.stock_status = ?';
    $params[] = $stock; $types .= 's';
}
$whereSql = 'WHERE ' . implode(' AND ', $where);

$total = (int) fetchValue(
    "SELECT COUNT(*) FROM products p
     JOIN brands b ON b.brand_id = p.brand_id
     JOIN categories c ON c.category_id = p.category_id $whereSql",
    $params, $types);

$pages  = max(1, (int) ceil($total / $perPage));
$page   = min($page, $pages);
$offset = ($page - 1) * $perPage;

$rows = fetchAll(
    "SELECT p.product_id, p.name, p.price, p.cost_price, p.stock_qty, p.stock_status,
            p.img_slug, p.image_path, p.is_active,
            b.name AS brand,
            c.name AS category, parent.name AS parent
     FROM products p
     JOIN brands b ON b.brand_id = p.brand_id
     JOIN categories c ON c.category_id = p.category_id
     LEFT JOIN categories parent ON parent.category_id = c.parent_id
     $whereSql
     ORDER BY p.product_id
     LIMIT $perPage OFFSET $offset",
    $params, $types);

$categories = fetchAll(
    "SELECT c.category_id, c.name, parent.name AS parent
     FROM categories c LEFT JOIN categories parent ON parent.category_id = c.parent_id
     ORDER BY COALESCE(parent.name, c.name), c.parent_id IS NOT NULL, c.name");

// Keeps the current filters when building links
function keepQuery($extra = []) {
    $q = array_merge($_GET, $extra);
    return '?' . http_build_query($q);
}

adminHeader('Products', 'products');
?>

<p class="hint">
  <?= number_format($total) ?> product<?= $total === 1 ? '' : 's' ?><?= $showGone ? ' removed from the shop' : ' in the shop' ?>.
  Price and stock can be changed here; use Edit for everything else.
</p>

<form method="get" class="filters">
  <?php if ($showGone): ?><input type="hidden" name="inactive" value="1" /><?php endif; ?>
  <div class="field">
    <label>Search</label>
    <input type="text" name="q" value="<?= e($search) ?>" placeholder="Name or brand" />
  </div>
  <div class="field">
    <label>Category</label>
    <select name="cat">
      <option value="0">All categories</option>
      <?php foreach ($categories as $c): ?>
        <option value="<?= (int) $c['category_id'] ?>" <?= $catId === (int) $c['category_id'] ? 'selected' : '' ?>>
          <?= e($c['parent'] ? $c['parent'] . ' > ' . $c['name'] : $c['name']) ?>
        </option>
      <?php endforeach; ?>
    </select>
  </div>
  <div class="field">
    <label>Stock</label>
    <select name="stock">
      <option value="">Any</option>
      <option value="in"  <?= $stock === 'in'  ? 'selected' : '' ?>>In stock</option>
      <option value="low" <?= $stock === 'low' ? 'selected' : '' ?>>Low stock</option>
      <option value="out" <?= $stock === 'out' ? 'selected' : '' ?>>Out of stock</option>
    </select>
  </div>
  <button type="submit" class="btn">Filter</button>
  <a href="products.php" class="btn grey">Clear</a>
  <a href="product_edit.php" class="btn">+ Add product</a>
  <a href="<?= $showGone ? 'products.php' : 'products.php?inactive=1' ?>" class="btn grey">
    <?= $showGone ? 'Back to live products' : 'View removed' ?>
  </a>
</form>

<div class="table-wrap">
<table class="data">
  <thead>
    <tr>
      <th>ID</th><th></th><th>Product</th><th>Category</th>
      <th class="num">Price (RM)</th><th class="num">Cost</th>
      <th class="num">Qty</th><th>Status</th><th></th>
    </tr>
  </thead>
  <tbody>
  <?php if (count($rows) === 0): ?>
    <tr><td colspan="9" style="text-align:center; color:#888; padding:26px;">Nothing matches those filters.</td></tr>
  <?php endif; ?>
  <?php foreach ($rows as $r):
      $img = $r['image_path'] ? '../' . $r['image_path'] : '../images/' . ($r['img_slug'] ?: 'default') . '.svg';
      // A <form> cannot wrap table rows — the browser moves it out and the
      // inputs stop working. Instead each input carries form="qsID" and the
      // matching <form> sits below the table.
      $f = 'qs' . (int) $r['product_id'];
  ?>
    <tr>
      <td><?= (int) $r['product_id'] ?></td>
      <td><img class="thumb" src="<?= e($img) ?>" alt="" /></td>
      <td>
        <strong><?= e($r['name']) ?></strong><br />
        <small style="color:#999;"><?= e($r['brand']) ?></small>
      </td>
      <td><small><?= e($r['parent'] ? $r['parent'] . ' > ' . $r['category'] : $r['category']) ?></small></td>
      <td class="num">
        <input form="<?= $f ?>" type="number" step="0.01" min="0" name="price"
               style="width:100px; text-align:right;"
               value="<?= e(number_format((float) $r['price'], 2, '.', '')) ?>" />
      </td>
      <td class="num">
        <?= $r['cost_price'] === null
            ? '<small style="color:#bbb;">not set</small>'
            : e(money($r['cost_price'])) ?>
      </td>
      <td class="num">
        <input form="<?= $f ?>" type="number" min="0" name="stock_qty"
               style="width:70px; text-align:right;"
               placeholder="&mdash;" value="<?= $r['stock_qty'] === null ? '' : (int) $r['stock_qty'] ?>" />
      </td>
      <td>
        <select form="<?= $f ?>" name="stock_status" style="width:105px;">
          <option value="in"  <?= $r['stock_status'] === 'in'  ? 'selected' : '' ?>>In stock</option>
          <option value="low" <?= $r['stock_status'] === 'low' ? 'selected' : '' ?>>Low</option>
          <option value="out" <?= $r['stock_status'] === 'out' ? 'selected' : '' ?>>Out</option>
        </select>
      </td>
      <td style="white-space:nowrap;">
        <button form="<?= $f ?>" type="submit" name="quick_save" value="1" class="btn small">Save</button>
        <a href="product_edit.php?id=<?= (int) $r['product_id'] ?>" class="btn small grey">Edit</a>
        <?php if ($r['is_active']): ?>
          <button form="<?= $f ?>" type="submit" name="remove" value="1" class="btn small danger"
                  onclick="return confirm('Remove this product from the shop? Past orders keep it.');">Remove</button>
        <?php else: ?>
          <button form="<?= $f ?>" type="submit" name="restore" value="1" class="btn small">Restore</button>
        <?php endif; ?>
      </td>
    </tr>
  <?php endforeach; ?>
  </tbody>
</table>
</div>

<?php // One form per row, sitting outside the table where it is valid.
foreach ($rows as $r): ?>
  <form id="qs<?= (int) $r['product_id'] ?>" method="post" style="display:none;">
    <input type="hidden" name="csrf" value="<?= e(csrfToken()) ?>" />
    <input type="hidden" name="product_id" value="<?= (int) $r['product_id'] ?>" />
  </form>
<?php endforeach; ?>

<?php if ($pages > 1): ?>
<div class="pager">
  <?php if ($page > 1): ?><a href="<?= e(keepQuery(['page' => $page - 1])) ?>">&laquo; Prev</a><?php endif; ?>
  <span class="current"><?= $page ?> of <?= $pages ?></span>
  <?php if ($page < $pages): ?><a href="<?= e(keepQuery(['page' => $page + 1])) ?>">Next &raquo;</a><?php endif; ?>
</div>
<?php endif; ?>

<?php adminFooter(); ?>
