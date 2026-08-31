<?php
// ============================================================
// Small helpers shared by every API file.
// ============================================================

startSecureSession();
header('Content-Type: application/json; charset=utf-8');

// Send a JSON reply and stop.
function reply($data, $status = 200) {
    http_response_code($status);
    echo json_encode($data);
    exit;
}

function fail($message, $status = 400) {
    reply(['ok' => false, 'error' => $message], $status);
}

// Reads the JSON body a fetch() call sent us.
function body() {
    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    return is_array($data) ? $data : [];
}

// Which action was asked for, e.g. api/cart.php?action=add
function action() {
    return isset($_GET['action']) ? $_GET['action'] : '';
}

// The signed-in customer's id, or null.
function currentCustomerId() {
    return isset($_SESSION['customer_id']) ? (int) $_SESSION['customer_id'] : null;
}

// Use at the top of anything that needs a login.
function requireLogin() {
    $id = currentCustomerId();
    if ($id === null) fail('Please log in first.', 401);
    return $id;
}
