<?php
// ============================================================
// Add a new product, or edit an existing one — including uploading a
// photo, which replaces the drawn illustration on the shop.
// ============================================================

require_once 'inc/auth.php';
require_once 'inc/layout.php';
requireAdmin();

$id      = (int) (isset($_GET['id']) ? $_GET['id'] : 0);
$isNew   = ($id === 0);
$errors  = [];

$product = null;
if (!$isNew) {
    $product = fetchOne("SELECT * FROM products WHERE product_id = ?", [$id], 'i');
    if (!$product) { flash('That product no longer exists.'); header('Location: products.php'); exit; }
}

$brands     = fetchAll("SELECT brand_id, name FROM brands ORDER BY name");
$categories = fetchAll(
    "SELECT c.category_id, c.name, parent.name AS parent
     FROM categories c LEFT JOIN categories parent ON parent.category_id = c.parent_id
     ORDER BY COALESCE(parent.name, c.name), c.parent_id IS NOT NULL, c.name");

// ------------------------------------------------------------
// Saving a photo.
//
// Three checks before anything is written: it must really be an image
// (getimagesize, not just the file name), under 5MB, and of a type we
// accept. Then it is redrawn at a sensible size and saved as JPEG —
// which also strips anything hidden inside the original file.
// ------------------------------------------------------------
function saveUploadedImage($file, $productId, &$errors) {
    if (!isset($file) || $file['error'] === UPLOAD_ERR_NO_FILE) return null;

    if ($file['error'] !== UPLOAD_ERR_OK) { $errors[] = 'The photo did not upload properly.'; return null; }
    if ($file['size'] > 5 * 1024 * 1024)  { $errors[] = 'Photo must be under 5MB.'; return null; }

    $info = @getimagesize($file['tmp_name']);
    if ($info === false) { $errors[] = 'That file is not an image.'; return null; }

    $allowed = [IMAGETYPE_JPEG => 'jpg', IMAGETYPE_PNG => 'png', IMAGETYPE_WEBP => 'webp'];
    if (!isset($allowed[$info[2]])) { $errors[] = 'Photo must be a JPG, PNG or WEBP.'; return null; }

    if (!extension_loaded('gd')) {
        $errors[] = 'Image support (GD) is switched off in PHP. Restart Apache in the XAMPP Control Panel.';
        return null;
    }

    switch ($info[2]) {
        case IMAGETYPE_JPEG: $src = @imagecreatefromjpeg($file['tmp_name']); break;
        case IMAGETYPE_PNG:  $src = @imagecreatefrompng($file['tmp_name']);  break;
        default:             $src = @imagecreatefromwebp($file['tmp_name']); break;
    }
    if (!$src) { $errors[] = 'Could not read that image.'; return null; }

    // Scale down so the shop stays quick to load. Never scales up.
    $maxW = 800; $maxH = 800;
    $w = imagesx($src); $h = imagesy($src);
    $scale = min($maxW / $w, $maxH / $h, 1);
    $newW = (int) round($w * $scale);
    $newH = (int) round($h * $scale);

    $out = imagecreatetruecolor($newW, $newH);
    imagefill($out, 0, 0, imagecolorallocate($out, 255, 255, 255)); // flatten transparency
    imagecopyresampled($out, $src, 0, 0, 0, 0, $newW, $newH, $w, $h);

    $dir = __DIR__ . '/../uploads';
    if (!is_dir($dir)) mkdir($dir, 0777, true);

    $filename = 'p' . $productId . '_' . time() . '.jpg';
    imagejpeg($out, $dir . '/' . $filename, 85);
    imagedestroy($src);
    imagedestroy($out);

    return 'uploads/' . $filename;
}

// ------------------------------------------------------------
// Save
// ------------------------------------------------------------
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    checkCsrf();

    $name        = trim($_POST['name']);
    $brandId     = (int) $_POST['brand_id'];
    $categoryId  = (int) $_POST['category_id'];
    $price       = (float) $_POST['price'];
    $costRaw     = trim($_POST['cost_price']);
    $cost        = ($costRaw === '') ? null : (float) $costRaw;
    $qtyRaw      = trim($_POST['stock_qty']);
    $qty         = ($qtyRaw === '') ? null : (int) $qtyRaw;
    $reorder     = (int) $_POST['reorder_level'];
    $status      = $_POST['stock_status'];
    $description = trim($_POST['description']);
    $imgSlug     = trim($_POST['img_slug']);
    $excludeBuild= isset($_POST['exclude_from_builder']) ? 1 : 0;

    if ($name === '')   $errors[] = 'Name is required.';
    if ($price <= 0)    $errors[] = 'Price must be more than zero.';
    if ($cost !== null && $cost < 0) $errors[] = 'Cost cannot be negative.';
    if (!in_array($status, ['in', 'low', 'out'], true)) $status = 'in';

    // A real count beats the dropdown
    if ($qty !== null) {
        if ($qty <= 0)            $status = 'out';
        elseif ($qty <= $reorder) $status = 'low';
        else                      $status = 'in';
    }

    if (count($errors) === 0) {
        if ($isNew) {
            // Ids are not auto-increment (they match the picture files),
            // so take the next one above the highest in use.
            $newId = (int) fetchValue("SELECT COALESCE(MAX(product_id), 0) + 1 FROM products");
            query(
                "INSERT INTO products
                   (product_id, name, brand_id, category_id, price, cost_price,
                    stock_qty, reorder_level, stock_status, description, img_slug, exclude_from_builder)
                 VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
                [$newId, $name, $brandId, $categoryId, $price, $cost,
                 $qty, $reorder, $status, $description, ($imgSlug ?: 'default'), $excludeBuild],
                'isiiddiisssi');
            $id = $newId;
        } else {
            query(
                "UPDATE products SET name=?, brand_id=?, category_id=?, price=?, cost_price=?,
                        stock_qty=?, reorder_level=?, stock_status=?, description=?,
                        img_slug=?, exclude_from_builder=?
                 WHERE product_id=?",
                [$name, $brandId, $categoryId, $price, $cost, $qty, $reorder, $status,
                 $description, ($imgSlug ?: 'default'), $excludeBuild, $id],
                'siiddiissssi');
        }

        // Photo last, because it needs the id for its file name.
        $path = saveUploadedImage(isset($_FILES['photo']) ? $_FILES['photo'] : null, $id, $errors);
        if ($path !== null) {
            query("UPDATE products SET image_path = ? WHERE product_id = ?", [$path, $id], 'si');
        }

        if (count($errors) === 0) {
            flash($isNew ? 'Product added.' : 'Product saved.');
            header('Location: products.php');
            exit;
        }
    }

    // Something failed — keep what was typed so nothing is lost
    $product = array_merge((array) $product, [
        'product_id' => $id, 'name' => $name, 'brand_id' => $brandId, 'category_id' => $categoryId,
        'price' => $price, 'cost_price' => $cost, 'stock_qty' => $qty, 'reorder_level' => $reorder,
        'stock_status' => $status, 'description' => $description, 'img_slug' => $imgSlug,
        'exclude_from_builder' => $excludeBuild,
    ]);
}

function val($product, $key, $default = '') {
    return ($product !== null && isset($product[$key]) && $product[$key] !== null) ? $product[$key] : $default;
}

adminHeader($isNew ? 'Add Product' : 'Edit Product', 'products');
?>

<?php if (count($errors) > 0): ?>
  <div class="error-box"><?= implode('<br />', array_map('e', $errors)) ?></div>
<?php endif; ?>

<form method="post" enctype="multipart/form-data">
  <input type="hidden" name="csrf" value="<?= e(csrfToken()) ?>" />

  <div class="card">
    <h2 style="margin-top:0;">Details</h2>

    <div class="field">
      <label for="name">Product name</label>
      <input type="text" id="name" name="name" required value="<?= e(val($product, 'name')) ?>" />
      <small>Start with the brand, e.g. "Asus ROG Astral RTX 5090 OC White".</small>
    </div>

    <div class="form-row">
      <div class="field">
        <label for="brand_id">Brand</label>
        <select id="brand_id" name="brand_id" required>
          <?php foreach ($brands as $b): ?>
            <option value="<?= (int) $b['brand_id'] ?>"
              <?= (int) val($product, 'brand_id') === (int) $b['brand_id'] ? 'selected' : '' ?>>
              <?= e($b['name']) ?>
            </option>
          <?php endforeach; ?>
        </select>
      </div>
      <div class="field">
        <label for="category_id">Category</label>
        <select id="category_id" name="category_id" required>
          <?php foreach ($categories as $c): ?>
            <option value="<?= (int) $c['category_id'] ?>"
              <?= (int) val($product, 'category_id') === (int) $c['category_id'] ? 'selected' : '' ?>>
              <?= e($c['parent'] ? $c['parent'] . ' > ' . $c['name'] : $c['name']) ?>
            </option>
          <?php endforeach; ?>
        </select>
      </div>
    </div>

    <div class="field">
      <label for="description">Description</label>
      <textarea id="description" name="description" rows="3"><?= e(val($product, 'description')) ?></textarea>
    </div>
  </div>

  <div class="card">
    <h2 style="margin-top:0;">Price and stock</h2>
    <div class="form-row">
      <div class="field">
        <label for="price">Selling price (RM)</label>
        <input type="number" id="price" name="price" step="0.01" min="0" required
               value="<?= e(number_format((float) val($product, 'price', 0), 2, '.', '')) ?>" />
      </div>
      <div class="field">
        <label for="cost_price">Cost price (RM)</label>
        <input type="number" id="cost_price" name="cost_price" step="0.01" min="0"
               value="<?= $product && $product['cost_price'] !== null
                          ? e(number_format((float) $product['cost_price'], 2, '.', '')) : '' ?>" />
        <small>What you pay the supplier. Used for margin and dead-stock alerts. Leave blank if unknown.</small>
      </div>
    </div>

    <div class="form-row">
      <div class="field">
        <label for="stock_qty">Quantity in stock</label>
        <input type="number" id="stock_qty" name="stock_qty" min="0"
               value="<?= $product && $product['stock_qty'] !== null ? (int) $product['stock_qty'] : '' ?>" />
        <small>Leave blank if not counted yet.</small>
      </div>
      <div class="field">
        <label for="reorder_level">Low-stock level</label>
        <input type="number" id="reorder_level" name="reorder_level" min="0"
               value="<?= (int) val($product, 'reorder_level', 5) ?>" />
        <small>At or below this many, the shop shows "Low Stock".</small>
      </div>
      <div class="field">
        <label for="stock_status">Status shown in the shop</label>
        <select id="stock_status" name="stock_status">
          <option value="in"  <?= val($product, 'stock_status') === 'in'  ? 'selected' : '' ?>>In Stock</option>
          <option value="low" <?= val($product, 'stock_status') === 'low' ? 'selected' : '' ?>>Low Stock</option>
          <option value="out" <?= val($product, 'stock_status') === 'out' ? 'selected' : '' ?>>Out of Stock</option>
        </select>
        <small>Worked out from the quantity when one is entered.</small>
      </div>
    </div>
  </div>

  <div class="card">
    <h2 style="margin-top:0;">Picture</h2>
    <?php $current = val($product, 'image_path'); ?>
    <div style="display:flex; gap:20px; align-items:flex-start; flex-wrap:wrap;">
      <div style="text-align:center;">
        <img src="<?= $current ? '../' . e($current) : '../images/' . e(val($product, 'img_slug', 'default')) . '.svg' ?>"
             style="width:140px; height:110px; object-fit:contain; background:#fafbfc; border:1px solid #e3e6ea; border-radius:6px;" />
        <div style="font-size:12px; color:#999; margin-top:5px;">
          <?= $current ? 'Uploaded photo' : 'Drawn illustration' ?>
        </div>
      </div>
      <div style="flex:1; min-width:240px;">
        <div class="field">
          <label for="photo">Upload a photo</label>
          <input type="file" id="photo" name="photo" accept="image/jpeg,image/png,image/webp" />
          <small>JPG, PNG or WEBP, under 5MB. Resized to 800px and saved as JPEG.</small>
        </div>
        <div class="field">
          <label for="img_slug">Fallback drawing</label>
          <input type="text" id="img_slug" name="img_slug" value="<?= e(val($product, 'img_slug', 'default')) ?>" />
          <small>Used when there's no photo: cpu, gpu, ram, motherboard, psu, case, cooler,
                 ssd, hdd, monitor, laptop, printer, paper, projector, projectorscreen,
                 monitorarm, keyboard, mouse, headset, mousepad, router, wifi, switch, cable, default.</small>
        </div>
      </div>
    </div>
  </div>

  <div class="card">
    <label style="font-weight:normal;">
      <input type="checkbox" name="exclude_from_builder" value="1"
             <?= (int) val($product, 'exclude_from_builder', 0) === 1 ? 'checked' : '' ?> />
      Hide from the PC Builder
    </label>
    <small style="display:block; color:#999; margin-top:4px;">
      For things sold in the shop that don't belong in a desktop build —
      laptop memory, surveillance drives, legacy repair boards.
    </small>
  </div>

  <button type="submit" class="btn"><?= $isNew ? 'Add product' : 'Save changes' ?></button>
  <a href="products.php" class="btn grey">Cancel</a>
</form>

<?php adminFooter(); ?>
