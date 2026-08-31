<?php
// Ends the admin session and returns to the sign-in page.
require_once 'inc/auth.php';

unset($_SESSION['admin_id'], $_SESSION['admin_name'], $_SESSION['csrf']);
header('Location: login.php');
exit;
