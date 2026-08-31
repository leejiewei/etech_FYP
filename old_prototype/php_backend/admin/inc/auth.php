<?php
// ============================================================
// Admin sign-in guard.
//
// Every admin page starts with require_once 'inc/auth.php', which sends
// anyone who isn't signed in back to the login screen. Staff accounts
// live in their own table, so a customer can never turn themselves into
// an admin by editing their own record.
// ============================================================

// db.php first, because it loads the settings file that
// startSecureSession() below comes from.
require_once __DIR__ . '/db.php';
startSecureSession();

function adminId() {
    return isset($_SESSION['admin_id']) ? (int) $_SESSION['admin_id'] : null;
}

function adminName() {
    return isset($_SESSION['admin_name']) ? $_SESSION['admin_name'] : '';
}

function requireAdmin() {
    if (adminId() === null) {
        header('Location: login.php');
        exit;
    }
}

// A hidden token on every form. A page on another site can copy our form
// but cannot read this value, so a request without it is rejected — that
// is what stops a cross-site request forgery.
function csrfToken() {
    if (!isset($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(16));
    }
    return $_SESSION['csrf'];
}

function checkCsrf() {
    $sent = isset($_POST['csrf']) ? $_POST['csrf'] : '';
    if (!isset($_SESSION['csrf']) || !hash_equals($_SESSION['csrf'], $sent)) {
        die('This form has expired. Please go back and try again.');
    }
}

// Short message shown once on the next page, e.g. "Product saved".
function flash($message = null) {
    if ($message !== null) { $_SESSION['flash'] = $message; return; }
    if (!isset($_SESSION['flash'])) return null;
    $m = $_SESSION['flash'];
    unset($_SESSION['flash']);
    return $m;
}
