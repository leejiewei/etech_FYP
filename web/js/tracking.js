// ============================================================
// Behaviour tracking.
//
// Every product a shopper opens is recorded in the database. Those rows
// are what the admin dashboard turns into the Inventory Velocity score:
//
//     score = (views x 1) + (cart adds x 3) + (purchases x 5)
//
// Cart adds and purchases are recorded inside the database, by the
// functions that do the adding and the buying. Views are the one kind
// this file sends, because a view is not a database write of its own —
// it is somebody clicking a card.
//
// This used to say that cart adds and purchases "cannot be faked from
// the browser", which was half right and worth correcting. They cannot
// be faked *through* cart_add() or place_order(), which check the caller
// and do the work themselves. But until
// 20260905090000_protect_behaviour_capture.sql the events table itself
// would accept anything: the INSERT policy only checked customer_id, so
// anyone holding the publishable key — which ships in js/config.js by
// design — could post event_type: "purchase" straight into the table,
// for any product, dated to any moment. Since the velocity score weights
// a purchase five times a view, and since this table *is* the Objective
// 1 dataset, that was worth closing.
//
// The policy now permits event_type = 'view' from a client and nothing
// else, and created_at is no longer a column any client may set. The
// other three kinds still arrive, from the SECURITY DEFINER functions,
// which are not subject to the policy at all.
//
// A copy of the recent activity is also kept in this browser, purely so
// the home page can suggest things without another round trip.
//
// Every row this file writes also carries an anon_id — see getAnonId()
// below for what that is and why a shopper who is not signed in is
// worth nothing to a recommender without one.
// ============================================================

// ------------------------------------------------------------
// The id of this browser, as distinct from the person using it.
//
// customer_id answers "who is this?" and is null for anyone not signed
// in. That leaves an anonymous visitor's rows as a heap of unrelated
// facts: two views a minute apart from this browser cannot be told from
// two views by two strangers. anon_id answers the weaker question "was
// this the same browser?", which is all that is needed to group a
// visit into a session.
//
// It is made once and kept for good. It is not a login and proves
// nothing — the database does not check it, and it is not tied to a
// person, only to this browser's storage. Clearing site data starts a
// new one, which is correct: that is a new anonymous visitor as far as
// anyone can tell.
// ------------------------------------------------------------
const ANON_ID_KEY = "etech_anon_id";

function getAnonId() {
  try {
    let id = localStorage.getItem(ANON_ID_KEY);
    if (id) return id;

    // randomUUID needs a secure context. Opening the site as file:// or
    // over plain http on a phone during testing is exactly when it is
    // missing, so there is a fallback rather than a thrown error.
    id = (window.crypto && crypto.randomUUID)
      ? crypto.randomUUID()
      : "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
          const r = (Math.random() * 16) | 0;
          return (c === "x" ? r : (r & 0x3) | 0x8).toString(16);
        });

    localStorage.setItem(ANON_ID_KEY, id);
    return id;
  } catch (e) {
    // Private mode with storage blocked. Tracking must never break the
    // shop, so this visitor is simply untrackable.
    return null;
  }
}

// ------------------------------------------------------------
// Joining a visitor's browsing to the account they end up creating.
//
// Called from auth.js the moment a sign-in or sign-up succeeds. Until
// then everything this browser did is filed under anon_id and belongs
// to nobody; afterwards it belongs to them, which is what makes "they
// looked at these four things and then bought this one" a sentence the
// data can say.
//
// The database function does the work and will only ever hand rows that
// belong to nobody to whoever is calling. It cannot be made to take
// somebody else's.
// ------------------------------------------------------------
function claimAnonActivity() {
  const anonId = getAnonId();
  if (!anonId) return Promise.resolve(0);

  return sb.rpc("claim_anon_activity", { p_anon_id: anonId })
    .then(({ data, error }) => {
      if (error) { console.error("Claiming earlier activity:", error); return 0; }
      return data || 0;
    });
}

function getEvents() {
  const text = localStorage.getItem("events");
  return text === null ? [] : JSON.parse(text);
}

function saveEvents(events) {
  // Keep only the most recent 200 so this doesn't grow forever.
  localStorage.setItem("events", JSON.stringify(events.slice(-200)));
}

// Records locally (for recommendations) and on the server (for the dashboard).
function logEvent(type, productId) {
  const product = getProductById(productId);
  if (!product) return;

  const events = getEvents();
  events.push({ type, productId, category: product.category, time: Date.now() });
  saveEvents(events);

  if (type === "view_click") {
    // Written straight to the events table. The policy on it allows an
    // insert and nothing else — no client can read back what other
    // people have been looking at, and a signed-in browser may only
    // stamp its own customer id on the row, so nobody can pad somebody
    // else's history.
    //
    // No .select() afterwards, deliberately: reading these rows is for
    // staff, and asking for the row back would be refused.
    const user = getCurrentUser();
    sb.from("events").insert({
      customer_id: user ? user.id : null,   // null = browsing signed out
      anon_id: getAnonId(),                 // ...but still the same browser
      source: "web",
      product_id: productId,
      event_type: "view",
    }).then(({ error }) => {
      // Tracking must never break the shop.
      if (error) console.error("Recording a view:", error);
    });
  }
}

// The category this shopper has shown the most interest in, used by the
// home page carousel and the "there's a deal on" notification.
function getTopCategory() {
  const events = getEvents();
  if (events.length === 0) return null;

  const counts = {};
  events.forEach((e) => { counts[e.category] = (counts[e.category] || 0) + 1; });

  let topCategory = null;
  let topCount = 0;
  for (const category in counts) {
    if (counts[category] > topCount) {
      topCount = counts[category];
      topCategory = category;
    }
  }
  return topCategory;
}

// Called when a shopper clicks a product card.
function trackProductClick(productId) {
  logEvent("view_click", productId);
  recordRecentView(productId);
}

// ------------------------------------------------------------
// Recently viewed.
//
// Two lists, never mixed:
//
//   * Signed in: the account's list, in the recently_viewed table
//     (supabase/migrations/…_recently_viewed.sql). record_recent_view()
//     files the view under whoever the session says is signed in, so it
//     follows the customer to any browser or phone, and nobody else on
//     this browser can read it.
//   * Signed out: this browser's list, in localStorage under
//     RECENT_GUEST_KEY. It stays on this device and is never sent
//     anywhere until its owner signs in, when mergeGuestRecent() hands
//     it to their account and clears it here.
//
// Either way a product appears once, newest first, at most 20.
// ------------------------------------------------------------
const RECENT_GUEST_KEY = "etech_recent_guest";
const RECENT_LIMIT = 20;

function getGuestRecent() {
  try {
    const list = JSON.parse(localStorage.getItem(RECENT_GUEST_KEY) || "[]");
    return Array.isArray(list) ? list.filter((r) => r && Number.isInteger(r.id)) : [];
  } catch (e) {
    return [];
  }
}

function saveGuestRecent(list) {
  try {
    if (list.length === 0) localStorage.removeItem(RECENT_GUEST_KEY);
    else localStorage.setItem(RECENT_GUEST_KEY, JSON.stringify(list.slice(0, RECENT_LIMIT)));
  } catch (e) {
    // Storage blocked: a guest simply has no list.
  }
}

function recordRecentView(productId) {
  if (!Number.isInteger(productId)) return;
  if (getCurrentUser()) {
    sb.rpc("record_recent_view", { p_product_id: productId }).then(({ error }) => {
      if (error) console.error("Recording a recent view:", error);
      else announceRecentViews();
    });
    return;
  }
  const list = getGuestRecent().filter((r) => r.id !== productId);
  list.unshift({ id: productId, t: Date.now() });
  saveGuestRecent(list);
  announceRecentViews();
}

// The home page redraws its rows when this fires.
function announceRecentViews() {
  document.dispatchEvent(new CustomEvent("recentviewschange"));
}

// The product ids to show, newest first.
function loadRecentViews() {
  if (!getCurrentUser()) return Promise.resolve(getGuestRecent().map((r) => r.id));
  return mergeGuestRecent().then(() => sb.from("recently_viewed")
    .select("product_id")
    .order("viewed_at", { ascending: false })
    .limit(RECENT_LIMIT)
    .then(({ data, error }) => {
      if (error) { console.error("Loading recently viewed:", error); return []; }
      return (data || []).map((row) => row.product_id);
    }));
}

// What a guest looked at before signing in, added to their account.
// Cleared here only once the database has it, so a failed request
// leaves the list to try again on the next page.
function mergeGuestRecent() {
  const list = getGuestRecent();
  if (!getCurrentUser() || list.length === 0) return Promise.resolve(0);
  const items = list.map((r) => ({ product_id: r.id, viewed_at: new Date(r.t || Date.now()).toISOString() }));
  return sb.rpc("merge_recent_views", { p_items: items }).then(({ data, error }) => {
    if (error) { console.error("Merging recently viewed:", error); return 0; }
    saveGuestRecent([]);
    return data || 0;
  });
}

// ------------------------------------------------------------
// Searches.
//
// A typed search says more about what somebody wants than a handful of
// clicks does, and it is the only signal here that can describe a thing
// the shop does not sell. That is why result_count is recorded too: a
// search returning nothing is the most useful row in the table.
//
// The shop's search filters as you type, so the naive thing — log every
// keystroke — would write "r", "rt", "rtx" and call the first two
// searches that found nothing. Two rules prevent that:
//
//   * wait until the typing stops (three quarters of a second), and
//   * ignore a query that repeats the one just recorded, so arriving at
//     shop.html?search=… and then touching a filter does not log twice.
//
// searchTimer is deliberately module-level: a second keystroke cancels
// the first one's pending write rather than racing it.
// ------------------------------------------------------------
let searchTimer = null;
let lastLoggedSearch = "";

function trackSearch(query, resultCount) {
  const text = (query || "").trim();

  // One or two characters is somebody mid-word, not a question.
  if (text.length < 3) return;
  if (text.toLowerCase() === lastLoggedSearch) return;

  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    lastLoggedSearch = text.toLowerCase();

    const user = getCurrentUser();
    sb.from("search_logs").insert({
      customer_id: user ? user.id : null,
      anon_id: getAnonId(),
      source: "web",
      query: text,
      result_count: resultCount,
    }).then(({ error }) => {
      if (error) console.error("Recording a search:", error);
    });
  }, 750);
}
