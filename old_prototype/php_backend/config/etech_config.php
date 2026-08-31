<?php
// ============================================================
// Settings that must never sit inside the website folder.
//
// This file lives ONE LEVEL ABOVE the web root, so there is no URL
// that reaches it. Even if somebody guesses the file name, Apache
// will not serve it, because it is outside the folder Apache serves.
//
// The same arrangement works on the live cPanel server:
//
//     /home/yourname/config/etech_config.php   <- this file
//     /home/yourname/public_html/              <- the website
//
// On your PC it is:
//
//     D:\eTech_FYP\config\etech_config.php     <- this file
//     D:\eTech_FYP\web\                        <- the website
// ============================================================


// ------------------------------------------------------------
// Is this the real server, or your own PC?
//
// Leave it false while you work in XAMPP. Set it to true on the
// live server, and PHP will stop printing error details to the
// visitor's screen. Error messages are useful to you and useful
// to an attacker, so the public should never see them.
// ------------------------------------------------------------
define('IS_LIVE', false);


// ------------------------------------------------------------
// Database  ->  Supabase (Postgres)
//
// The shop no longer talks to MySQL. On 26 August 2026 the whole
// database moved to Supabase, which is hosted Postgres, and both the
// website and the mobile app now read that copy. Nothing else about the
// arrangement changed: the browser and the phone still call the PHP API
// in web/api/, and the PHP is what holds the connection to the database.
//
// The old MySQL scripts are kept in sql/ as the history of how the data
// was built. sql/supabase/ holds the Postgres version that is live.
//
// WHERE TO GET THE CONNECTION STRING
//   Supabase dashboard -> Connect -> "Session pooler" (port 5432)
//   and paste it below. It looks like:
//
//   postgresql://postgres.abcdefghijklm:PASSWORD@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres
//
// Use the SESSION pooler (5432), not the transaction pooler (6543):
// the transaction pooler cannot run the prepared statements this code
// relies on, and prepared statements are what keeps SQL injection out.
//
// Better still, do not put the password in this file at all. If the
// environment variable SUPABASE_DB_URL is set, it wins over the constant
// below, so the password can live in the server's configuration instead
// of in a file that gets emailed around and submitted with the report.
// ------------------------------------------------------------
define('SUPABASE_PROJECT_REF', 'asawhkjvturznjitsqfk');

define('SUPABASE_DB_URL',
    'postgresql://postgres.asawhkjvturznjitsqfk:s5A91EoXee4go3Sh'
  . '@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres');

// The host has two parts worth knowing. ap-southeast-1 is the region the
// project lives in (Singapore). aws-0 is which pooler cluster it sits on -
// aws-1 also serves Singapore, and connecting to the wrong one is refused
// with "Tenant or user not found" rather than a timeout, which is a
// friendlier way to be wrong than most.


// Supabase gives one Postgres login, so the two MySQL accounts
// (etech_client and etech_admin) are gone. What replaced them is Row
// Level Security: the anon key that a browser could get hold of can read
// nothing and write nothing, which is stricter than etech_client ever
// was. See sql/supabase/README.md. The split between "shop front" and
// "admin panel" is now enforced by this PHP layer - api/db.php and
// admin/inc/db.php are still separate files, and the admin one is the
// only thing that ever reaches the admin pages.


// ------------------------------------------------------------
// Reading the connection string.
//
// parse_url() does the work. Everything after it is defensive: a missing
// piece here means every page in the site fails with the same confusing
// "cannot reach the database", so it is worth saying plainly what is
// wrong instead.
// ------------------------------------------------------------
function dbSettings() {
    static $parts = null;
    if ($parts !== null) return $parts;

    $url = getenv('SUPABASE_DB_URL');
    if ($url === false || trim($url) === '') $url = SUPABASE_DB_URL;

    $u = parse_url(trim($url));
    if ($u === false || !isset($u['host'], $u['user'])) {
        dbConfigError('The Supabase connection string in config/etech_config.php '
                    . 'is not a valid postgresql:// URL.');
    }
    if (strpos($url, 'PASTE-DB-PASSWORD-HERE') !== false || strpos($url, 'REGION') !== false) {
        dbConfigError('The Supabase connection string has not been filled in yet. '
                    . 'Dashboard -> Connect -> Session pooler, then paste it into '
                    . 'config/etech_config.php (or set SUPABASE_DB_URL).');
    }

    $parts = [
        'host' => $u['host'],
        'port' => isset($u['port']) ? (int) $u['port'] : 5432,
        // The path is "/postgres" - the leading slash is not part of the name.
        'name' => isset($u['path']) ? ltrim($u['path'], '/') : 'postgres',
        'user' => urldecode($u['user']),
        // A password may legally contain @ or /, so it arrives percent-encoded.
        'pass' => isset($u['pass']) ? urldecode($u['pass']) : '',
    ];
    return $parts;
}

// The string PDO wants. sslmode=require is not optional: without it the
// driver is allowed to fall back to an unencrypted connection, and this
// one crosses the public internet.
function dbDsn() {
    $s = dbSettings();
    return 'pgsql:host=' . $s['host']
         . ';port='      . $s['port']
         . ';dbname='    . $s['name']
         . ';sslmode=require';
}

// Shown when the connection string itself is wrong, which is a different
// problem from the database being unreachable. The API answers in JSON,
// the admin panel in plain text, so ask the page which it is.
function dbConfigError($message) {
    error_log('eTech config: ' . $message);
    if (!headers_sent()) http_response_code(500);
    $isApi = strpos($_SERVER['SCRIPT_NAME'] ?? '', '/api/') !== false;
    echo $isApi ? json_encode(['ok' => false, 'error' => IS_LIVE ? 'Server not configured.' : $message])
                : (IS_LIVE ? 'Server not configured.' : $message);
    exit;
}


// ------------------------------------------------------------
// Time.
//
// Every date in the database was moved across carrying a +08 offset, so
// the Malaysian wall clock survived the move exactly. PHP has to agree,
// or "orders in the last 30 days" quietly means something different in
// PHP than it does in Postgres. Both ends are pinned here.
// ------------------------------------------------------------
define('DB_TIME_ZONE', 'Asia/Kuala_Lumpur');
date_default_timezone_set(DB_TIME_ZONE);


// ------------------------------------------------------------
// How many failed sign-ins before an admin account is locked,
// and for how long. See admin/login.php.
// ------------------------------------------------------------
define('LOGIN_MAX_TRIES',   5);
define('LOGIN_LOCK_MINUTES', 15);


// ------------------------------------------------------------
// Error reporting. Always log; only display on your own PC.
// ------------------------------------------------------------
error_reporting(E_ALL);
ini_set('log_errors', '1');
ini_set('display_errors', IS_LIVE ? '0' : '1');


// ------------------------------------------------------------
// Starts the session with safer cookie settings.
//
// Call this instead of session_start(). Three things change:
//
//   httponly  JavaScript cannot read the login cookie, so a script
//             injected into a page cannot steal somebody's session.
//   samesite  the cookie is not sent when another site links into
//             ours, which is a second defence against CSRF.
//   secure    the cookie only travels over https. This must stay
//             OFF on your PC (XAMPP is plain http) or you would be
//             unable to log in - hence it follows IS_LIVE.
// ------------------------------------------------------------
function startSecureSession() {
    if (session_status() === PHP_SESSION_ACTIVE) return;
    session_set_cookie_params([
        'lifetime' => 0,
        'path'     => '/',
        'httponly' => true,
        'samesite' => 'Lax',
        'secure'   => IS_LIVE,
    ]);
    session_start();
}
