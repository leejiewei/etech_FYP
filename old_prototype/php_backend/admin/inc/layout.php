<?php
// ============================================================
// The frame every admin page sits inside: the top bar and the side
// menu. Each page calls adminHeader('Title') then adminFooter().
// ============================================================

function adminHeader($title, $active = '') {
    $flash = flash();
    ?><!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title><?= e($title) ?> - eTech Admin</title>
  <link rel="stylesheet" href="assets/admin.css" />
</head>
<body>

<div class="admin-top">
  <div class="admin-logo">e<span>Tech</span> <small>Admin</small></div>
  <div class="admin-user">
    <a href="../index.html" target="_blank" class="view-shop">View shop &#8599;</a>
    <?= e(adminName()) ?>
    <a href="logout.php" class="logout">Log out</a>
  </div>
</div>

<div class="admin-body">
  <nav class="admin-side">
    <?php
    $menu = [
      'dashboard' => ['index.php',    'Dashboard'],
      'products'  => ['products.php', 'Products'],
      'coupons'   => ['coupons.php',  'Promotions'],
      'orders'    => ['orders.php',   'Orders'],
      'chatlogs'  => ['chatlogs.php', 'Chatbot Logs'],
      '_analytics' => [null, 'Analytics'],
      'velocity'  => ['velocity.php', 'Inventory Velocity'],
      'alerts'    => ['alerts.php',   'Stock Alerts'],
      'reports'   => ['reports.php',  'Sales &amp; Customers'],
      'forecast'  => ['forecast.php', 'Sales Forecast'],
    ];
    foreach ($menu as $key => $item) {
        // A null link is a heading that separates the menu into groups.
        if ($item[0] === null) {
            echo '<div class="side-heading">' . $item[1] . '</div>';
            continue;
        }
        $cls = ($key === $active) ? ' class="active"' : '';
        echo '<a href="' . $item[0] . '"' . $cls . '>' . $item[1] . '</a>';
    }
    ?>
  </nav>

  <main class="admin-main">
    <h1><?= e($title) ?></h1>
    <?php if ($flash !== null): ?>
      <p class="flash"><?= e($flash) ?></p>
    <?php endif; ?>
<?php
}

function adminFooter() {
    ?>
  </main>
</div>

</body>
</html>
<?php
}
