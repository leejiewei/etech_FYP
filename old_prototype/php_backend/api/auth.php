<?php
// ============================================================
// Customer accounts: register, log in, log out, and profile edits.
//
// Passwords are hashed with PHP's password_hash() before they touch the
// database, so even someone reading the customers table cannot see them.
// Logging in compares with password_verify(), never by fetching the
// password and matching strings.
// ============================================================

require_once 'db.php';
require_once 'helpers.php';

switch (action()) {

    // ---------------------------------------------------- register
    case 'register': {
        $in    = body();
        $name  = trim(isset($in['name']) ? $in['name'] : '');
        $email = strtolower(trim(isset($in['email']) ? $in['email'] : ''));
        $pass  = isset($in['password']) ? $in['password'] : '';

        if ($name === '' || $email === '' || $pass === '') fail('Please fill in every field.');
        if (!filter_var($email, FILTER_VALIDATE_EMAIL))    fail('That email address does not look right.');
        if (strlen($pass) < 6)                             fail('Password must be at least 6 characters.');

        if (fetchOne("SELECT customer_id FROM customers WHERE email = ?", [$email])) {
            fail('An account with this email already exists.');
        }

        $hash = password_hash($pass, PASSWORD_DEFAULT);
        // RETURNING hands back the id the database has just generated.
        // MySQL needed a second look at insert_id for this; in Postgres the
        // INSERT itself can say what it created.
        $_SESSION['customer_id'] = (int) fetchValue(
            "INSERT INTO customers (name, email, password_hash) VALUES (?, ?, ?)
             RETURNING customer_id",
            [$name, $email, $hash]);   // signed in straight away
        reply(['ok' => true, 'customer' => ['id' => $_SESSION['customer_id'], 'name' => $name, 'email' => $email]]);
    }

    // ---------------------------------------------------- login
    case 'login': {
        $in    = body();
        $email = strtolower(trim(isset($in['email']) ? $in['email'] : ''));
        $pass  = isset($in['password']) ? $in['password'] : '';

        $user = fetchOne("SELECT customer_id, name, email, password_hash FROM customers WHERE email = ?", [$email]);

        // Same message whether the email is unknown or the password is
        // wrong, so nobody can use this to discover who has an account.
        if (!$user || !password_verify($pass, $user['password_hash'])) {
            fail('Incorrect email or password.', 401);
        }

        $_SESSION['customer_id'] = (int) $user['customer_id'];
        reply(['ok' => true, 'customer' => [
            'id' => (int) $user['customer_id'], 'name' => $user['name'], 'email' => $user['email'],
        ]]);
    }

    // ---------------------------------------------------- logout
    case 'logout': {
        session_destroy();
        reply(['ok' => true]);
    }

    // ---------------------------------------------------- who am I
    case 'me': {
        $id = currentCustomerId();
        if ($id === null) reply(['ok' => true, 'customer' => null]);

        $user = fetchOne("SELECT customer_id, name, email, phone, address FROM customers WHERE customer_id = ?",
                         [$id], 'i');
        if (!$user) { session_destroy(); reply(['ok' => true, 'customer' => null]); }

        reply(['ok' => true, 'customer' => [
            'id'      => (int) $user['customer_id'],
            'name'    => $user['name'],
            'email'   => $user['email'],
            'phone'   => $user['phone'],
            'address' => $user['address'],
        ]]);
    }

    // ---------------------------------------------------- save profile
    case 'updateProfile': {
        $id = requireLogin();
        $in = body();

        $name    = trim(isset($in['name'])    ? $in['name']    : '');
        $phone   = trim(isset($in['phone'])   ? $in['phone']   : '');
        $address = trim(isset($in['address']) ? $in['address'] : '');
        if ($name === '') fail('Name cannot be empty.');

        // The WHERE clause pins this to the signed-in customer, so nobody
        // can edit somebody else's details by changing the request.
        query("UPDATE customers SET name = ?, phone = ?, address = ? WHERE customer_id = ?",
              [$name, $phone, $address, $id], 'sssi');
        reply(['ok' => true]);
    }

    default:
        fail('Unknown action.');
}
