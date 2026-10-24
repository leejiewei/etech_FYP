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
// category (null means all). Read by the Stock Alerts page.
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
  ["dashboard",  "index.html",        "Dashboard",          "dashboard"],
  ["products",   "products.html",     "Products",           "package"],
  ["prebuilts",  "prebuilts.html",    "Prebuilt Parts",     "cpu"],
  ["deals",      "deals.html",        "Timed Deals",        "timer"],
  ["coupons",    "coupons.html",      "Promotions",         "tag"],
  ["orders",     "orders.html",       "Orders",             "cart"],
  ["showcases",  "showcases.html",    "Rig Showcase",       "monitor"],
  ["chatlogs",   "chatlogs.html",     "Chatbot Logs",       "message"],
  [null,         null,                "Analytics"],
  ["behaviour",  "behaviour.html",    "Customer Behaviour", "users"],
  ["alerts",     "alerts.html",       "Stock Alerts",       "alert"],
  ["reports",    "reports.html",      "Sales &amp; Customers", "bars"],
  ["forecast",   "forecast.html",     "Sales Forecast",     "trend"],
];

// Line icons, drawn on a 24px grid in the style of Lucide. Inline so
// nothing is fetched and each one takes the colour of the text beside it.
const ICONS = {
  dashboard: '<rect x="3" y="3" width="7" height="9" rx="1"/><rect x="14" y="3" width="7" height="5" rx="1"/><rect x="14" y="12" width="7" height="9" rx="1"/><rect x="3" y="16" width="7" height="5" rx="1"/>',
  package:   '<path d="M21 8 12 3 3 8l9 5 9-5z"/><path d="M3 8v8l9 5 9-5V8"/><path d="M12 13v8"/>',
  cpu:       '<rect x="5" y="5" width="14" height="14" rx="2"/><rect x="9" y="9" width="6" height="6"/><path d="M9 2v3M15 2v3M9 19v3M15 19v3M19 9h3M19 15h3M2 9h3M2 15h3"/>',
  timer:     '<circle cx="12" cy="13" r="8"/><path d="M12 9v4l2 2M9 2h6"/>',
  tag:       '<path d="M20.6 13.4 13.4 20.6a2 2 0 0 1-2.8 0L3 13V3h10l7.6 7.6a2 2 0 0 1 0 2.8z"/><circle cx="7.5" cy="7.5" r="1.5"/>',
  cart:      '<circle cx="9" cy="20" r="1.5"/><circle cx="18" cy="20" r="1.5"/><path d="M2 3h3l2.7 12.4a2 2 0 0 0 2 1.6h8.6a2 2 0 0 0 2-1.6L22 7H6"/>',
  monitor:   '<rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8M12 17v4"/>',
  message:   '<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>',
  users:     '<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.9M16 3.1a4 4 0 0 1 0 7.8"/>',
  alert:     '<path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/><path d="M12 9v4M12 17h.01"/>',
  bars:      '<path d="M12 20V10M18 20V4M6 20v-4"/>',
  trend:     '<path d="m23 6-9.5 9.5-5-5L1 18"/><path d="M17 6h6v6"/>',
  search:    '<circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/>',
  bell:      '<path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/>',
  menu:      '<path d="M3 6h18M3 12h18M3 18h18"/>',
  chevron:   '<path d="m6 9 6 6 6-6"/>',
  external:  '<path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><path d="M15 3h6v6M10 14 21 3"/>',
  logout:    '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="m16 17 5-5-5-5M21 12H9"/>',
  money:     '<rect x="2" y="6" width="20" height="12" rx="2"/><circle cx="12" cy="12" r="2.5"/><path d="M6 12h.01M18 12h.01"/>',
};

function icon(name) {
  return `<svg class="i" viewBox="0 0 24 24" aria-hidden="true">${ICONS[name] || ""}</svg>`;
}

// The menu's collapsed-or-not choice, kept per browser. Storage can be
// blocked (private windows), so every read and write is allowed to fail.
const SIDE_KEY = "etech-admin-side";
function sidePreference() {
  try { return localStorage.getItem(SIDE_KEY); } catch (error) { return null; }
}
function rememberSide(value) {
  try { localStorage.setItem(SIDE_KEY, value); } catch (error) { /* not kept, still works */ }
}

function buildChrome(title, active, staff) {
  const menu = ADMIN_MENU.map(([key, href, label, glyph]) =>
    href === null
      ? `<div class="side-heading">${label}</div>`
      : `<a href="${href}" title="${label}"${key === active ? ' class="active" aria-current="page"' : ""}>
           ${icon(glyph)}<span class="label">${label}</span></a>`
  ).join("");

  const message = flash();
  const initials = String(staff.name || "?").trim().split(/\s+/).slice(0, 2)
    .map((word) => word[0]).join("").toUpperCase();
  // Tablets start with the menu as a rail of icons; a desktop starts open
  // unless this browser closed it last time.
  const rail = sidePreference() ? sidePreference() === "rail" : window.innerWidth <= 1024;

  document.title = title + " - eTech Admin";
  // Into the shell div rather than into body, so the script tags that
  // are still running are not pulled out from under themselves.
  document.getElementById("admin-shell").innerHTML = `
    <div class="admin-app${rail ? " rail" : ""}" id="admin-app">
      <aside class="admin-side" id="admin-side" aria-label="Staff menu">
        <a href="index.html" class="side-brand" title="eTech Admin">
          <img src="../images/brand/etech-logo-64.png" alt="" />
          <span class="word">e<span>Tech</span></span><small>Admin</small>
        </a>
        <nav class="side-nav">${menu}</nav>
      </aside>
      <div class="side-scrim" id="side-scrim"></div>

      <div class="admin-frame">
        <header class="admin-top">
          <button type="button" class="icon-btn" id="side-toggle" aria-label="Show or hide the menu"
                  aria-controls="admin-side">${icon("menu")}</button>

          <form class="admin-search" id="admin-search" role="search">
            ${icon("search")}
            <input type="search" id="admin-search-input" placeholder="Search products, or #12 for an order"
                   aria-label="Search products or orders" />
          </form>

          <div class="top-right">
            <div class="drop">
              <button type="button" class="icon-btn" id="bell-button" aria-label="Alerts"
                      aria-haspopup="true" aria-expanded="false">${icon("bell")}</button>
              <div class="drop-menu" id="bell-menu" hidden>
                <h3>Needs attention</h3>
                <div class="empty">Checking…</div>
              </div>
            </div>

            <div class="drop">
              <button type="button" class="profile-btn" id="profile-button" aria-haspopup="true" aria-expanded="false">
                <span class="avatar">${e(initials)}</span>
                <span class="name">${e(staff.name)}</span>${icon("chevron")}
              </button>
              <div class="drop-menu" id="profile-menu" hidden>
                <div class="who"><strong>${e(staff.name)}</strong><small>${e(staff.email)}</small></div>
                <a href="../index.html" target="_blank" rel="noopener">${icon("external")}View shop</a>
                <a href="#" id="admin-logout">${icon("logout")}Log out</a>
              </div>
            </div>
          </div>
        </header>

        <main class="admin-main">
          <h1>${e(title)}</h1>
          ${message ? `<p class="flash">${e(message)}</p>` : ""}
          <div id="admin-content"></div>
        </main>

        <footer class="admin-foot">
          <span>&copy; ${new Date().getFullYear()} eTech. All rights reserved. Staff use only.</span>
          <nav>
            <a href="../index.html" target="_blank" rel="noopener">View shop</a>
            <a href="../privacy.html" target="_blank" rel="noopener">Privacy Policy</a>
            <a href="../contact.html" target="_blank" rel="noopener">Contact</a>
          </nav>
        </footer>
      </div>
    </div>`;

  wireChrome();
  loadAlerts();
  return document.getElementById("admin-content");
}

function wireChrome() {
  const app = document.getElementById("admin-app");
  const phone = () => window.matchMedia("(max-width: 720px)").matches;

  // On a phone the button slides the menu in over the page; anywhere
  // wider it folds the menu to a rail of icons and back.
  document.getElementById("side-toggle").onclick = () => {
    if (phone()) {
      app.classList.toggle("side-open");
    } else {
      app.classList.toggle("rail");
      rememberSide(app.classList.contains("rail") ? "rail" : "open");
    }
  };
  document.getElementById("side-scrim").onclick = () => app.classList.remove("side-open");

  // "#12" or "12" opens that order; anything else searches products,
  // using the Products page's own search.
  document.getElementById("admin-search").onsubmit = (event) => {
    event.preventDefault();
    const term = document.getElementById("admin-search-input").value.trim();
    if (term === "") return;
    const order = term.match(/^#?(\d+)$/);
    window.location.href = order
      ? `orders.html?order=${order[1]}`
      : `products.html?q=${encodeURIComponent(term)}`;
  };

  const menus = [["bell-button", "bell-menu"], ["profile-button", "profile-menu"]];
  const closeAll = () => menus.forEach(([b, m]) => {
    document.getElementById(m).hidden = true;
    document.getElementById(b).setAttribute("aria-expanded", "false");
  });
  menus.forEach(([b, m]) => {
    document.getElementById(b).onclick = (event) => {
      event.stopPropagation();
      const opening = document.getElementById(m).hidden;
      closeAll();
      document.getElementById(m).hidden = !opening;
      document.getElementById(b).setAttribute("aria-expanded", String(opening));
    };
  });
  document.addEventListener("click", (event) => {
    if (!event.target.closest(".drop-menu")) closeAll();
  });
  document.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return;
    closeAll();
    app.classList.remove("side-open");
  });

  document.getElementById("admin-logout").onclick = (event) => {
    event.preventDefault();
    sb.auth.signOut().finally(() => { window.location.href = "login.html"; });
  };
}

// The bell: orders waiting and products running out, from the same
// admin_dashboard row the Dashboard reads. One small request per page;
// if it fails the bell just says so rather than breaking the page.
async function loadAlerts() {
  const menu = document.getElementById("bell-menu");
  const { data, error } = await sb.from("admin_dashboard")
    .select("pending_orders,out_of_stock,low_stock").maybeSingle();
  if (error || !data) {
    menu.innerHTML = `<h3>Needs attention</h3><div class="empty">Alerts could not be loaded.</div>`;
    return;
  }

  const items = [
    [data.pending_orders, "orders waiting to be processed", "orders.html?status=Pending", "cart"],
    [data.out_of_stock,   "products out of stock",          "products.html?stock=out",    "alert"],
    [data.low_stock,      "products low on stock",          "products.html?stock=low",    "package"],
  ].filter(([n]) => Number(n) > 0);

  const total = items.reduce((sum, [n]) => sum + Number(n), 0);
  if (total > 0) {
    document.getElementById("bell-button").insertAdjacentHTML("beforeend",
      `<span class="bell-count">${total > 99 ? "99+" : total}</span>`);
    document.getElementById("bell-button").setAttribute("aria-label", `Alerts: ${total}`);
  }

  menu.innerHTML = `<h3>Needs attention</h3>` + (items.length === 0
    ? `<div class="empty">Nothing needs attention.</div>`
    : items.map(([n, text, href, glyph]) =>
        `<a href="${href}">${icon(glyph)}<span>${e(text)}</span><span class="n">${count(n)}</span></a>`).join("") +
      `<a href="alerts.html">${icon("trend")}<span>Open Stock Alerts</span></a>`);
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

  const content = buildChrome(title, active, staff);
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
