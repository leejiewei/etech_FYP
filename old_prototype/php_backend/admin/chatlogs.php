<?php
// ============================================================
// What customers have been asking the AI hardware consultant.
//
// Useful for two things: seeing which questions come up often enough
// to deserve a proper answer, and spotting the ones the advisor
// couldn't handle.
// ============================================================

require_once 'inc/auth.php';
require_once 'inc/layout.php';
requireAdmin();

$only    = isset($_GET['only']) ? $_GET['only'] : '';
$page    = max(1, (int) (isset($_GET['page']) ? $_GET['page'] : 1));
$perPage = 30;

$where = '';
if ($only === 'builds')  $where = 'WHERE l.was_build_request = 1';
if ($only === 'general') $where = 'WHERE l.was_build_request = 0';

$total  = (int) fetchValue("SELECT COUNT(*) FROM chatbot_logs l $where");
$pages  = max(1, (int) ceil($total / $perPage));
$page   = min($page, $pages);
$offset = ($page - 1) * $perPage;

$logs = fetchAll(
    "SELECT l.log_id, l.question, l.answer, l.was_build_request, l.created_at,
            c.name AS customer
     FROM chatbot_logs l
     LEFT JOIN customers c ON c.customer_id = l.customer_id
     $where
     ORDER BY l.created_at DESC
     LIMIT $perPage OFFSET $offset");

$buildCount = (int) fetchValue("SELECT COUNT(*) FROM chatbot_logs WHERE was_build_request = 1");
$allCount   = (int) fetchValue("SELECT COUNT(*) FROM chatbot_logs");

adminHeader('Chatbot Logs', 'chatlogs');
?>

<div class="tiles">
  <div class="tile">
    <div class="label">Questions asked</div>
    <div class="value"><?= number_format($allCount) ?></div>
  </div>
  <div class="tile">
    <div class="label">Asked for a full build</div>
    <div class="value"><?= number_format($buildCount) ?></div>
    <div class="sub"><?= $allCount > 0 ? round($buildCount / $allCount * 100) : 0 ?>% of all questions</div>
  </div>
</div>

<div class="filters">
  <a href="chatlogs.php" class="btn <?= $only === '' ? '' : 'grey' ?>">All</a>
  <a href="chatlogs.php?only=builds"  class="btn <?= $only === 'builds'  ? '' : 'grey' ?>">Build requests</a>
  <a href="chatlogs.php?only=general" class="btn <?= $only === 'general' ? '' : 'grey' ?>">General questions</a>
</div>

<div class="table-wrap">
<table class="data">
  <thead>
    <tr><th>When</th><th>Customer</th><th>Question &amp; answer</th><th></th></tr>
  </thead>
  <tbody>
  <?php if (count($logs) === 0): ?>
    <tr><td colspan="4" style="text-align:center; color:#888; padding:26px;">
      Nothing logged yet. Questions appear here as customers use the chatbot on the shop.
    </td></tr>
  <?php endif; ?>
  <?php foreach ($logs as $l): ?>
    <tr>
      <td style="white-space:nowrap;"><small><?= e(date('j M, g:ia', strtotime($l['created_at']))) ?></small></td>
      <td><small><?= e($l['customer'] ?: 'Not signed in') ?></small></td>
      <td>
        <div class="chat-q"><?= e($l['question']) ?></div>
        <div class="chat-a"><?= e(mb_strimwidth($l['answer'], 0, 260, '…')) ?></div>
      </td>
      <td>
        <?php if ((int) $l['was_build_request'] === 1): ?>
          <span class="badge in">Build</span>
        <?php else: ?>
          <span class="badge grey">Question</span>
        <?php endif; ?>
      </td>
    </tr>
  <?php endforeach; ?>
  </tbody>
</table>
</div>

<?php if ($pages > 1): ?>
<div class="pager">
  <?php if ($page > 1): ?>
    <a href="?<?= e(http_build_query(array_merge($_GET, ['page' => $page - 1]))) ?>">&laquo; Prev</a>
  <?php endif; ?>
  <span class="current"><?= $page ?> of <?= $pages ?></span>
  <?php if ($page < $pages): ?>
    <a href="?<?= e(http_build_query(array_merge($_GET, ['page' => $page + 1]))) ?>">Next &raquo;</a>
  <?php endif; ?>
</div>
<?php endif; ?>

<?php adminFooter(); ?>
