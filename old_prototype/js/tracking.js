// Very simple behaviour tracking engine.
// Logs events into localStorage so the homepage can build a basic
// "recommended for you" carousel out of what the user actually looked at.
// This is a simplified demo version of a real analytics/recommendation
// pipeline (which would normally run on a server, not in the browser).

function getEvents() {
  const text = localStorage.getItem("events");
  if (text === null) return [];
  return JSON.parse(text);
}

function saveEvents(events) {
  // Keep only the most recent 200 events so localStorage doesn't grow forever.
  const trimmed = events.slice(-200);
  localStorage.setItem("events", JSON.stringify(trimmed));
}

// type examples: "view_click", "view_duration", "wishlist_add", "cart_add"
function logEvent(type, productId) {
  const product = getProductById(productId);
  if (!product) return;

  const events = getEvents();
  events.push({
    type: type,
    productId: productId,
    category: product.category,
    time: Date.now(),
  });
  saveEvents(events);
}

// Looks at recent events and returns the category the user has shown the
// most interest in (most logged events). Returns null if we have no data yet.
function getTopCategory() {
  const events = getEvents();
  if (events.length === 0) return null;

  const counts = {};
  events.forEach((e) => {
    counts[e.category] = (counts[e.category] || 0) + 1;
  });

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

// Call this when the user opens/clicks a product card.
function trackProductClick(productId) {
  logEvent("view_click", productId);
}
