<?php
// ============================================================
// Database connection for the admin panel.
//
// Same Supabase database the shop front reads, reached the same way -
// PDO over the Postgres connection string in config/etech_config.php.
//
// It used to be a second MySQL login, etech_admin, with full rights,
// while the shop connected as etech_client and physically could not
// change a price or read cost_price. Supabase issues one Postgres login,
// so that split is gone at the database and lives here instead: this
// file is only ever loaded by pages behind inc/auth.php, and every one
// of those starts with requireAdmin(). See sql/supabase/README.md.
//
// The customer-facing shop has its own connection file (../../api/db.php).
// ============================================================

// Settings live outside the website folder - see config/etech_config.php
require_once __DIR__ . '/../../../config/etech_config.php';

function db() {
    static $conn = null;
    if ($conn !== null) return $conn;

    $settings = dbSettings();

    try {
        $conn = new PDO(dbDsn(), $settings['user'], $settings['pass'], [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            // Real prepared statements: the values never reach Postgres
            // as part of the SQL text.
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]);
    } catch (PDOException $e) {
        error_log('eTech admin cannot reach Supabase: ' . $e->getMessage());
        die(IS_LIVE
            ? 'Cannot reach the database.'
            : 'Cannot reach Supabase. Check the connection string in '
            . 'config/etech_config.php, and that this machine is online.<br />'
            . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8'));
    }

    // The reports count "the last 30 days" in Malaysian time, the same
    // zone the dates were stored in.
    $conn->exec("SET TIME ZONE '" . DB_TIME_ZONE . "'");

    return $conn;
}

// Values are always bound separately from the SQL, so nothing a user
// types can ever be run as SQL.
//
// $types is ignored - mysqli had to be told which values were numbers,
// Postgres reads that off the column - but it is still accepted so the
// call sites did not all have to change.
function query($sql, $params = [], $types = '') {
    try {
        $stmt = db()->prepare($sql);
        $stmt->execute(array_values($params));
        return $stmt;
    } catch (PDOException $e) {
        if (db()->inTransaction()) db()->rollBack();
        error_log('eTech admin query failed: ' . $e->getMessage() . ' -- SQL: ' . $sql);
        die(IS_LIVE ? 'Something went wrong.' : 'Bad query: ' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8'));
    }
}

function fetchAll($sql, $params = [], $types = '') {
    $stmt = query($sql, $params, $types);
    $rows = $stmt->fetchAll();
    $stmt->closeCursor();

    foreach ($rows as $i => $row) $rows[$i] = tidyTimestamps($row);
    return $rows;
}

function fetchOne($sql, $params = [], $types = '') {
    $rows = fetchAll($sql, $params, $types);
    return count($rows) > 0 ? $rows[0] : null;
}

function fetchValue($sql, $params = [], $types = '') {
    $row = fetchOne($sql, $params, $types);
    return $row === null ? null : reset($row);
}

// Two writes that belong together go between these, so a half-done job
// is never left behind - see orders.php, which moves an order along and
// records who moved it.
function dbBegin()    { db()->beginTransaction(); }
function dbCommit()   { db()->commit(); }
function dbRollback() { if (db()->inTransaction()) db()->rollBack(); }

// Postgres writes a stored date as  2026-08-26 11:07:00+08  where MySQL
// wrote  2026-08-26 11:07:00 . The connection has already asked for
// Malaysian time, so the clock is right; the offset is trimmed off so
// every date('j M Y', strtotime(...)) on these pages prints what it
// always printed.
function tidyTimestamps(array $row) {
    foreach ($row as $key => $value) {
        if (!is_string($value)) continue;
        if (preg_match('/^(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)(?:\.\d+)?[+-]\d\d(?::?\d\d)?$/', $value, $m)) {
            $row[$key] = $m[1];
        }
    }
    return $row;
}

// Escapes anything before it goes into a page, so a product name
// containing < or " can't break the HTML or inject a script.
function e($text) {
    return htmlspecialchars((string) $text, ENT_QUOTES, 'UTF-8');
}

function money($amount) {
    return 'RM ' . number_format((float) $amount, 2);
}
