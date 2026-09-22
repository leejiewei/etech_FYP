// ============================================================
// The frame every admin page sits inside, and the small helpers they
// all use. This replaces three PHP files at once:
//
//   inc/db.php      the Postgres connection  ->  the sb client below
//   inc/auth.php    requireAdmin(), CSRF     ->  requireAdmin() below
//   inc/layout.php  the top bar and menu     ->  buildChrome() below
//
// Two of those three shrink to almost nothing, and it is worth being
// clear about why, because it is the whole point of the change.
//
//   The connection. inc/db.php opened Postgres with the owner's
//   password. An owner is not subject to Row Level Security, so the only
//   thing standing between a visitor and every table in the database was
//   the requireAdmin() call at the top of each page — a line of PHP that
//   somebody could forget to write. The client below holds the same
//   publishable key the shop front holds. It is the staff member's own
//   login that grants the access, and the database checks it on every
//   single statement.
//
//   The CSRF token. inc/auth.php put a hidden token in every form,
//   because a form post carried a session cookie and the browser would
//   attach that cookie to a request another site had triggered. Nothing
//   here is a form post and there is no cookie: the session is a token
//   this page holds and puts in an Authorization header, which another
//   site cannot make the browser send. The class of attack the token
//   existed to stop cannot happen, so the token is gone rather than
//   reimplemented.
// ============================================================

const sb = supabase.createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    // A different key from the shop front's, so signing in as staff in
    // one tab does not sign a customer out in another.
    storageKey: "etech-admin-auth",
  },
});

// ------------------------------------------------------------
// Small helpers, same names and behaviour as the PHP ones
// ------------------------------------------------------------

// Escapes anything before it goes into a page, so a product name
// containing < or " cannot break the HTML or inject a script. Every
// value below that came out of the database goes through this.
function e(text) {
  return String(text === null || text === undefined ? "" : text)
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}

function money(amount) {
  return "RM " + Number(amount || 0).toLocaleString("en-MY", {
    minimumFractionDigits: 2, maximumFractionDigits: 2,
  });
}

function count(n) {
  return Number(n || 0).toLocaleString("en-MY");
}

// Postgres numeric arrives as a string, because a double cannot hold
// every value it can. Anything arithmetic is read through here.
function num(value) {
  return Number(value ?? 0);
}

// "2026-04" -> "Apr", or "Apr 26" with the year. Built from the string
// rather than from a Date, so no timezone can shift it into the month
// next door.
function monthLabel(month, withYear = false) {
  const names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                 "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  const text = String(month);
  const name = names[Number(text.slice(5, 7)) - 1];
  if (!name) return text;
  return withYear ? `${name} ${text.slice(2, 4)}` : name;
}

// Runs a Supabase query and hands back its rows, or throws its error.
async function select(query) {
  const { data, error } = await query;
  if (error) throw error;
  return data;
}

// Every product's scores over the last `days` days, optionally for one
// category (null means all). Read by the Alerts and Velocity pages.
async function loadScores(days, categoryId = null) {
  const { data, error } = await sb.rpc("admin_product_scores", {
    p_days: days,
    p_category: categoryId,
  });
  if (error) throw error;
  return data;
}

// Who a deal would message, read off one admin_customer_activity row:
// saved it, carted it without buying, or viewed it WATCHING_VIEWS times.
// The same three groups, in the same order, as admin_create_deal() --
// so the Dashboard and Customer Behaviour count what a deal sends.
const WATCHING_VIEWS = 3;

function watchReason(r) {
  if (r.in_wishlist) return "saved";
  if (Number(r.cart_adds) > 0 && Number(r.purchases) === 0) return "carted";
  if (Number(r.views) >= WATCHING_VIEWS) return "viewed";
  return null;
}

// A stored date read back in Malaysian time, which is the zone the
// dates were recorded in and the zone the shop trades in.
function when(timestamp, withTime = true) {
  if (!timestamp) return "";
  const options = withTime
    ? { day: "numeric", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" }
    : { day: "numeric", month: "short", year: "numeric" };
  return new Date(timestamp).toLocaleString("en-GB", { ...options, timeZone: "Asia/Kuala_Lumpur" });
}

function shorten(text, limit) {
  text = String(text || "");
  return text.length > limit ? text.slice(0, limit - 1) + "…" : text;
}

// Short message shown once on the next page, e.g. "Product saved".
// Was $_SESSION['flash']; sessionStorage does the same job and, like the
// session, is this browser tab's own.
function flash(message) {
  if (message !== undefined) { sessionStorage.setItem("admin-flash", message); return null; }
  const stored = sessionStorage.getItem("admin-flash");
  sessionStorage.removeItem("admin-flash");
  return stored;
}

// The current filters, as an object, and a way to build a link that
// keeps them. Replaces PHP's $_GET and keepQuery().
function params() {
  return Object.fromEntries(new URLSearchParams(window.location.search));
}

function keepQuery(extra) {
  const merged = new URLSearchParams({ ...params(), ...extra });
  for (const [key, value] of [...merged]) {
    if (value === "" || value === "0") merged.delete(key);
  }
  const query = merged.toString();
  return query ? "?" + query : window.location.pathname.split("/").pop();
}

// ------------------------------------------------------------
// The frame
// ------------------------------------------------------------
const ADMIN_MENU = [
  ["dashboard",  "index.html",        "Dashboard"],
  ["products",   "products.html",     "Products"],
  ["prebuilts",  "prebuilts.html",    "Prebuilt Parts"],
  ["deals",      "deals.html",        "Timed Deals"],
  ["coupons",    "coupons.html",      "Promotions"],
  ["orders",     "orders.html",       "Orders"],
  ["showcases",  "showcases.html",    "Rig Showcase"],
  ["chatlogs",   "chatlogs.html",     "Chatbot Logs"],
  [null,         null,                "Analytics"],
  ["velocity",   "velocity.html",     "Inventory Velocity"],
  ["alerts",     "alerts.html",       "Stock Alerts"],
  ["reports",    "reports.html",      "Sales &amp; Customers"],
  ["behaviour",  "behaviour.html",    "Customer Behaviour"],
  ["forecast",   "forecast.html",     "Sales Forecast"],
];

function buildChrome(title, active, staffName) {
  const menu = ADMIN_MENU.map(([key, href, label]) =>
    href === null
      ? `<div class="side-heading">${label}</div>`
      : `<a href="${href}"${key === active ? ' class="active"' : ""}>${label}</a>`
  ).join("");

  const message = flash();

  document.title = title + " - eTech Admin";
  // Into the shell div rather than into body, so the script tags that
  // are still running are not pulled out from under themselves.
  document.getElementById("admin-shell").innerHTML = `
    <div class="admin-top">
      <div class="admin-logo">e<span>Tech</span> <small>Admin</small></div>
      <div class="admin-user">
        <a href="../index.html" target="_blank" class="view-shop">View shop &#8599;</a>
        ${e(staffName)}
        <a href="#" id="admin-logout" class="logout">Log out</a>
      </div>
    </div>

    <div class="admin-body">
      <nav class="admin-side">${menu}</nav>
      <main class="admin-main">
        <h1>${e(title)}</h1>
        ${message ? `<p class="flash">${e(message)}</p>` : ""}
        <div id="admin-content"></div>
      </main>
    </div>`;

  document.getElementById("admin-logout").onclick = (event) => {
    event.preventDefault();
    sb.auth.signOut().finally(() => { window.location.href = "login.html"; });
  };

  return document.getElementById("admin-content");
}

// ------------------------------------------------------------
// The guard.
//
// requireAdmin() in PHP checked $_SESSION['admin_id'] and redirected if
// it was missing. This checks two things instead, and the second one is
// the one that matters:
//
//   1. is there a Supabase session at all, and
//   2. does the admins table have a row pointing at it.
//
// The second is asked of the database, not answered here, and every
// query the page then makes is checked against the same test by the
// policies. A page that forgot to call this would simply come back
// empty rather than leaking anything — which is the difference between
// a guard and a lock.
// ------------------------------------------------------------
async function requireAdmin() {
  const { data } = await sb.auth.getSession();
  if (!data.session) { window.location.href = "login.html"; return null; }

  // This used to read the admins table. That worked only by accident and
  // stopped the day the shop had two members of staff:
  //
  //   * the policy is "staff read staff", so the table returns every
  //     member of staff, and maybeSingle() fails on more than one row;
  //   * narrowing it with .eq("auth_user_id", ...) fails too, because the
  //     grant is column-level -- SELECT (admin_id, username, name,
  //     created_at) -- and filtering on a column needs SELECT on that
  //     column. auth_user_id is not in the list, so Postgres answers
  //     "permission denied for table admins".
  //
  // is_admin() has neither problem. It is SECURITY DEFINER, it answers
  // the one question being asked, and it is the very function every
  // policy behind every admin page calls -- so this gate and those
  // policies can never disagree.
  const { data: isStaff, error } = await sb.rpc("is_admin");

  if (error || isStaff !== true) {
    // A valid login that is not staff. Signing out avoids leaving the
    // browser stuck in a redirect loop on the login page.
    await sb.auth.signOut();
    window.location.href = "login.html";
    return null;
  }

  // The name for the page header. It is on the session already, put there
  // when the account was made, so there is no second round trip for it.
  const account = data.session.user;
  return {
    name: (account.user_metadata && account.user_metadata.name) ||
          account.email.split("@")[0],
    email: account.email,
  };
}

// Every admin page is one call to this: check the login, draw the
// frame, then hand the content area to the page's own code.
async function adminPage(title, active, render) {
  const staff = await requireAdmin();
  if (!staff) return;

  const content = buildChrome(title, active, staff.name);
  try {
    await render(content, staff);
  } catch (error) {
    console.error(error);
    content.innerHTML =
      `<div class="error-box">Could not load this page. ${e(error.message || error)}</div>`;
  }
}

// A page that has just written something reloads to show the result,
// exactly as the PHP did with a redirect after a POST.
function reloadWith(message) {
  if (message) flash(message);
  window.location.reload();
}

// supabase-js hands errors back rather than throwing them, so a write
// whose result nobody looks at fails in silence. Every write in the
// panel goes through here instead.
async function write(query) {
  const { error } = await query;
  if (error) throw error;
}

// ------------------------------------------------------------
// Pieces several pages share
// ------------------------------------------------------------

// Parents first, each followed by its own children, which is the order
// every dropdown in the panel wants. The view says as much, but a view's
// ORDER BY is not a promise once PostgREST has wrapped it, so the sort
// is done here, where it definitely happens.
async function loadCategories() {
  const { data, error } = await sb.from("category_options")
    .select("category_id,name,parent");
  if (error) throw error;

  return data.sort((a, b) =>
    (a.parent || a.name).localeCompare(b.parent || b.name) ||
    (a.parent ? 1 : 0) - (b.parent ? 1 : 0) ||
    a.name.localeCompare(b.name));
}

function categoryOptions(categories, selectedId) {
  return categories.map((c) => `
    <option value="${c.category_id}" ${Number(selectedId) === c.category_id ? "selected" : ""}>
      ${e(c.parent ? c.parent + " > " + c.name : c.name)}
    </option>`).join("");
}

function pager(page, pages) {
  if (pages <= 1) return "";
  return `
    <div class="pager">
      ${page > 1 ? `<a href="${e(keepQuery({ page: page - 1 }))}">&laquo; Prev</a>` : ""}
      <span class="current">${page} of ${pages}</span>
      ${page < pages ? `<a href="${e(keepQuery({ page: page + 1 }))}">Next &raquo;</a>` : ""}
    </div>`;
}

// A bar in one of the hand-drawn charts. The panel has never pulled in a
// charting library — it works with no internet connection and there is
// nothing to explain that is not in the file you are reading.
function barWidth(value, max) {
  return max > 0 ? Math.max(2, Math.round((num(value) / num(max)) * 100)) : 0;
}
