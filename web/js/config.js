// ============================================================
// Where the database is, and the key used to reach it.
//
// This replaces config/etech_config.php, which held a Postgres username
// and password and had to live outside the website folder so that no URL
// could ever reach it. Nothing here needs hiding, and that is the whole
// point of the change:
//
//   * The old file held the database owner's password. Anyone who read
//     it could do anything to any table, which is why it sat one level
//     above the web root and why PHP had to stand between the browser
//     and Supabase at all.
//
//   * The key below is the *publishable* key. It identifies the project
//     and nothing else. It grants no rights of its own — every request
//     it makes arrives at Postgres as the "anon" role, and Row Level
//     Security decides what that role may see. Supabase intends this key
//     to be shipped in the page, and it is in the Flutter app too.
//
// So there is no longer a secret in front of the database; there is a
// set of policies inside it. See supabase/migrations for those.
//
// The one key that must never appear here is the service_role key. It
// ignores every policy.
// ============================================================

const SUPABASE_URL = "https://asawhkjvturznjitsqfk.supabase.co";
const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_hHm6s61BKP01tIR59CoKQg_Jx3NCFDy";
