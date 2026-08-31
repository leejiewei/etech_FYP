<?php
// ============================================================
// Staff sign-in.
//
// The password in the database is a bcrypt hash, so we never compare
// text. password_verify() re-hashes what was typed with the same salt
// and checks it matches.
// ============================================================

require_once 'inc/auth.php';

// Already signed in? go straight through.
if (adminId() !== null) { header('Location: index.php'); exit; }

$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = trim(isset($_POST['username']) ? $_POST['username'] : '');
    $password = isset($_POST['password']) ? $_POST['password'] : '';
    $ip       = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : '0.0.0.0';

    // Tidy up: attempts older than a day are of no further interest.
    query("DELETE FROM login_attempts WHERE attempted_at < ?",
          [date('Y-m-d H:i:s', time() - 86400)]);

    // Count the recent failures for this username. Working the cut-off
    // out in PHP rather than in SQL keeps the query easy to read.
    $cutoff = date('Y-m-d H:i:s', time() - (LOGIN_LOCK_MINUTES * 60));
    $recentFails = (int) fetchValue(
        "SELECT COUNT(*) FROM login_attempts WHERE username = ? AND attempted_at > ?",
        [$username, $cutoff]);

    if ($recentFails >= LOGIN_MAX_TRIES) {
        // Locked. Notice the password is not even checked here - there
        // is nothing an attacker can learn by guessing during this window.
        $error = 'Too many failed attempts. Please wait '
               . LOGIN_LOCK_MINUTES . ' minutes and try again.';
    } else {
        $admin = fetchOne("SELECT admin_id, username, password_hash, name FROM admins WHERE username = ?",
                          [$username]);

        if ($admin && password_verify($password, $admin['password_hash'])) {
            // Signed in, so the failure history for this account is cleared.
            query("DELETE FROM login_attempts WHERE username = ?", [$username]);

            // A fresh session id on sign-in, so a session id someone already
            // knew cannot be reused afterwards.
            session_regenerate_id(true);
            $_SESSION['admin_id']   = (int) $admin['admin_id'];
            $_SESSION['admin_name'] = $admin['name'];
            header('Location: index.php');
            exit;
        }

        // Record the failure, then answer. Deliberately vague: it doesn't
        // reveal whether the username exists.
        query("INSERT INTO login_attempts (username, ip_address, attempted_at) VALUES (?, ?, ?)",
              [$username, $ip, date('Y-m-d H:i:s')]);

        $left = LOGIN_MAX_TRIES - ($recentFails + 1);
        $error = 'Incorrect username or password.'
               . ($left <= 2 && $left > 0 ? ' ' . $left . ' attempt(s) left.' : '');
    }
}
?><!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>Admin Login - eTech</title>
  <link rel="stylesheet" href="assets/admin.css" />
</head>
<body>

<div class="login-page">
  <h1>eTech Admin</h1>
  <p class="sub">Staff sign-in</p>

  <?php if ($error !== ''): ?>
    <div class="error-box"><?= e($error) ?></div>
  <?php endif; ?>

  <form method="post">
    <div class="field">
      <label for="username">Username</label>
      <input type="text" id="username" name="username" required autofocus
             value="<?= e(isset($_POST['username']) ? $_POST['username'] : '') ?>" />
    </div>
    <div class="field">
      <label for="password">Password</label>
      <input type="password" id="password" name="password" required />
    </div>
    <button type="submit" class="btn">Sign in</button>
  </form>
</div>

</body>
</html>
