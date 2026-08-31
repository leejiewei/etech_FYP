<?php
// ============================================================
// Database connection for the customer-facing shop.
//
// This is where the site meets Supabase. The catalogue, the baskets and
// the orders all live in a Postgres database hosted by Supabase, and
// everything the browser or the phone sees has come through here.
//
// It used to be a mysqli connection to MySQL running in XAMPP. Two
// things changed and nothing else:
//
//   * the driver is PDO with the pgsql driver instead of mysqli, and
//   * the address, login and password come from one connection string
//     in config/etech_config.php, outside the website folder.
//
// The four functions below - db(), query(), fetchAll(), fetchOne() -
// still have the same names and still take the same arguments, so every
// page that used them carries on working.
//
// The admin panel has its own connection file (../admin/inc/db.php).
// ============================================================

// The connection string lives one level ABOVE the website folder, where
// no URL can reach it.
require_once __DIR__ . '/../../config/etech_config.php';

function db() {
    // Reuse one connection for the whole request. Opening a connection to
    // Supabase means a TLS handshake across the internet, so doing it
    // twice on one page is a waste nobody would notice until the site is
    // busy.
    static $conn = null;
    if ($conn !== null) return $conn;

    $settings = dbSettings();

    try {
        $conn = new PDO(dbDsn(), $settings['user'], $settings['pass'], [
            // Turn database errors into exceptions so a failure cannot be
            // ignored by accident and half-run.
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            // Real prepared statements, not ones PHP glues together
            // itself. The values then travel to Postgres separately from
            // the SQL and can never be read as SQL.
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]);
    } catch (PDOException $e) {
        // The real reason goes to the log; the visitor gets a plain
        // sentence, because the driver's own wording gives away the host
        // name and the login to anybody probing the site.
        error_log('eTech cannot reach Supabase: ' . $e->getMessage());
        http_response_code(500);
        echo json_encode(['error' => IS_LIVE
            ? 'Cannot reach the database.'
            : 'Cannot reach Supabase: ' . $e->getMessage()]);
        exit;
    }

    // Dates were moved across carrying Malaysian time. Asking for it back
    // in the same zone is what keeps "3pm" reading as 3pm.
    $conn->exec("SET TIME ZONE '" . DB_TIME_ZONE . "'");

    return $conn;
}

// Runs a query with values bound separately from the SQL.
// Doing it this way means a value can never be treated as SQL, which is
// what stops SQL injection - a name like  ' OR 1=1 --  is just text.
//
// $types is left in place so the call sites did not all have to change.
// mysqli needed to be told "this one is a number, this one is a string";
// Postgres works it out from the column, so the argument is ignored.
function query($sql, $params = [], $types = '') {
    try {
        $stmt = db()->prepare($sql);
        $stmt->execute(array_values($params));
        return $stmt;
    } catch (PDOException $e) {
        // A half-finished transaction must not be left holding rows.
        if (db()->inTransaction()) db()->rollBack();

        error_log('eTech query failed: ' . $e->getMessage() . ' -- SQL: ' . $sql);
        http_response_code(500);
        echo json_encode(['error' => IS_LIVE ? 'Something went wrong.' : 'Bad query: ' . $e->getMessage()]);
        exit;
    }
}

// Query that returns rows
function fetchAll($sql, $params = [], $types = '') {
    $stmt = query($sql, $params, $types);
    $rows = $stmt->fetchAll();
    $stmt->closeCursor();

    foreach ($rows as $i => $row) $rows[$i] = tidyTimestamps($row);
    return $rows;
}

// Query that returns a single row (or null)
function fetchOne($sql, $params = [], $types = '') {
    $rows = fetchAll($sql, $params, $types);
    return count($rows) > 0 ? $rows[0] : null;
}

// Query that returns one single value, e.g. a COUNT(*), or the id that an
// INSERT ... RETURNING hands back.
function fetchValue($sql, $params = [], $types = '') {
    $row = fetchOne($sql, $params, $types);
    return $row === null ? null : reset($row);
}

// ------------------------------------------------------------
// Transactions.
//
// Checkout writes to three tables and empties the basket. If one of
// those failed halfway we would be left with a broken half-order, so the
// whole thing runs between dbBegin() and dbCommit(): either every step
// lands, or none of them do.
// ------------------------------------------------------------
function dbBegin()    { db()->beginTransaction(); }
function dbCommit()   { db()->commit(); }
function dbRollback() { if (db()->inTransaction()) db()->rollBack(); }

// ------------------------------------------------------------
// One difference in how the two databases write a date.
//
// MySQL handed back  2026-08-26 11:07:00
// Postgres hands back 2026-08-26 11:07:00+08
//
// Same moment, and the connection above already asked for Malaysian
// time, so the clock part is right either way. The trailing +08 is
// dropped so the JSON going out to the browser and to the Flutter app is
// byte-for-byte what it was before the move, and neither had to change.
// ------------------------------------------------------------
function tidyTimestamps(array $row) {
    foreach ($row as $key => $value) {
        if (!is_string($value)) continue;
        if (preg_match('/^(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)(?:\.\d+)?[+-]\d\d(?::?\d\d)?$/', $value, $m)) {
            $row[$key] = $m[1];
        }
    }
    return $row;
}
