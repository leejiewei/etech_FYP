// ============================================================
// The connection to Supabase.
//
// Every other file that needs data goes through the `sb` client made
// here. It is the direct replacement for api/db.php: same job, one
// layer further out. The difference is that db.php opened a Postgres
// connection with the owner's password and could do anything, whereas
// this client can only do what the Row Level Security policies allow
// the anon and authenticated roles to do.
//
// Nothing in this file talks to a server of ours, because there isn't
// one any more. The browser holds a session from Supabase Auth and
// sends it with each request; Postgres reads the identity out of that
// and applies the policies. What used to be
//
//     browser  ->  Apache/PHP  ->  Supabase
//
// is now
//
//     browser  ->  Supabase
// ============================================================

const sb = supabase.createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: {
    // Keep the customer signed in across page loads and refresh the
    // token before it expires. This is what the PHPSESSID cookie was
    // doing, except the browser is now holding a signed token rather
    // than a pointer to a session file on the server.
    persistSession: true,
    autoRefreshToken: true,
    storageKey: "etech-auth",
  },
});

// ------------------------------------------------------------
// Reading more than a thousand rows.
//
// This is the one genuinely new thing to know about talking to Supabase
// from the browser. PostgREST caps a single response at 1000 rows, so
// the catalogue's 1714 specification rows do not arrive in one go — the
// old PHP had no such limit and simply handed over everything the query
// matched.
//
// A silent truncation would be the worst kind of bug: the shop would
// look fine and a handful of products would quietly lose their specs,
// which the PC Builder's compatibility checks depend on. So anything
// that could be long is read through here, a page at a time, until a
// short page says that was the end.
// ------------------------------------------------------------
const DB_PAGE_SIZE = 1000;

async function selectAllRows(buildQuery) {
  const rows = [];
  for (let from = 0; ; from += DB_PAGE_SIZE) {
    const { data, error } = await buildQuery().range(from, from + DB_PAGE_SIZE - 1);
    if (error) throw error;
    rows.push(...data);
    if (data.length < DB_PAGE_SIZE) return rows;
  }
}

// ------------------------------------------------------------
// Turning a database error into something a customer can read.
//
// The functions in the database raise their message deliberately —
// "Your cart is empty.", "Sorry, X is out of stock." — and those should
// be shown as they are. Anything else is a fault rather than a refusal,
// so it gets a plain sentence and the details go to the console for
// whoever is looking after the site.
// ------------------------------------------------------------
function dbMessage(error, fallback) {
  if (!error) return fallback || "Something went wrong.";
  console.error("Supabase:", error);

  // Postgres raise_exception. Everything the shop deliberately refuses
  // arrives with this code and a sentence meant for the customer.
  if (error.code === "P0001" && error.message) return error.message;

  // insufficient_privilege — the policies said no. In practice this
  // means the session has gone stale rather than that anything is wrong.
  if (error.code === "42501") return "Please log in first.";

  return fallback || "Could not reach the shop. Please try again.";
}
