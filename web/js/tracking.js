// ============================================================
// Behaviour tracking.
//
// Every product a shopper opens is recorded in the database. Those rows
// are what the admin dashboard turns into the Inventory Velocity score:
//
//     score = (views x 1) + (cart adds x 3) + (purchases x 5)
//
// Cart adds and purchases are recorded inside the database, by the
// functions that do the adding and the buying, so they cannot be faked
// from the browser. Views are the one kind this file sends, because a
// view is not a database write of its own — it is somebody clicking a
// card.
//
// A copy of the recent activity is also kept in this browser, purely so
// the home page can suggest things without another round trip.
// ============================================================

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
}
