// Deals page. Two different things share it, and they are worth keeping
// apart in your head:
//
//   Timed deals    a price on one product until a stated moment. Nothing
//                  is typed in; the shopper sees RM1,499 struck through
//                  and RM1,249 beside it, and that is what the till
//                  charges. They come from the deals table and are drawn
//                  as ordinary product cards, because that is what they
//                  are -- products, at a different price, for a while.
//
//   Promotions     a coupon code for a whole category. The shopper types
//                  it at the checkout and a percentage comes off the
//                  order. These come from the coupons table.
//
// Neither one filters out the expired or switched-off ones here, and
// that is on purpose: the policies on both tables only ever return what
// is running. The page cannot see a dead deal to show it by mistake,
// which is a stronger guarantee than remembering to filter.

let deals = [];

function loadDeals() {
  return sb.from("coupons")
    .select("code,description,discount_percent,ends_at,categories(name)")
    .order("discount_percent", { ascending: false })
    .then(({ data, error }) => {
      if (error) { console.error("Loading promotions:", error); deals = []; return; }
      deals = data.map((row) => ({
        code:            row.code,
        description:     row.description,
        discountPercent: Number(row.discount_percent),
        // null means the promotion applies to everything
        category:        row.categories ? row.categories.name : null,
        endsAt:          row.ends_at,
      }));
    })
    .catch(() => { deals = []; });
}

function getDealForCategory(category) {
  return deals.find((d) => d.category === category);
}

// ------------------------------------------------------------
// The clock.
//
// This used to be six hours from whenever you first opened the page,
// remembered in localStorage. It counted down convincingly and meant
// nothing: the sale ended at a different moment for every visitor, at no
// moment at all for one who cleared their browser, and no price ever
// changed when it reached zero.
//
// It now counts down to a real end_time, and when it gets there the
// prices on the page really do go back up -- because the deal is a row
// with a window on it and the till reads the same window.
// ------------------------------------------------------------

// HH:MM:SS, with the days broken out in front once there is more than
// one. A three-week deal reading "504:00:00" is arithmetic, not an
// answer to "how long have I got".
function formatCountdown(msLeft) {
  if (msLeft <= 0) return "Ended";

  const totalSeconds = Math.floor(msLeft / 1000);
  const days = Math.floor(totalSeconds / 86400);
  const hours = Math.floor((totalSeconds % 86400) / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  const pad = (n) => String(n).padStart(2, "0");
  const clock = `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
  return days > 0 ? `${days}d ${clock}` : clock;
}

// The deal that ends first, since that is the one the banner is telling
// people to hurry for.
function soonestDealEnd() {
  let soonest = null;
  products.forEach((product) => {
    const deal = dealFor(product);
    if (!deal) return;
    const ends = new Date(deal.endsAt).getTime();
    if (soonest === null || ends < soonest) soonest = ends;
  });
  return soonest;
}

// One interval at a time. Without clearing the old one, every expiry
// would leave its timer running and the banner would be written to by
// two of them.
let countdownTimer = null;

function startCountdown() {
  const el = document.getElementById("countdown");
  const banner = document.querySelector(".countdown-banner");
  if (!el || !banner) return;

  const endTime = soonestDealEnd();

  // No deals running, so there is nothing to count down to. Saying so is
  // better than a banner sitting at 00:00:00 forever.
  if (endTime === null) {
    banner.style.display = "none";
    return;
  }

  function tick() {
    const left = endTime - Date.now();
    el.textContent = formatCountdown(left);

    // The first deal has run out. The cards correct themselves from
    // ui.js; the grid is redrawn here so an expired one leaves it, and
    // the banner moves on to whichever deal is now closest.
    if (left <= 0) {
      renderTimedDeals();
      startCountdownAgain();
    }
  }

  tick();
  countdownTimer = setInterval(tick, 1000);
}

function startCountdownAgain() {
  if (countdownTimer) clearInterval(countdownTimer);
  countdownTimer = null;
  startCountdown();
}

function copyCoupon(code) {
  navigator.clipboard.writeText(code).then(() => {
    alert("Coupon code \"" + code + "\" copied!");
  }).catch(() => {
    alert("Coupon code: " + code);
  });
}

let currentDealCategory = "All";

function renderDealChips() {
  const container = document.getElementById("deal-chips");
  if (!container) return;

  const categories = ["All", ...new Set(deals.map((d) => d.category))];
  container.innerHTML = "";

  categories.forEach((category) => {
    const chip = document.createElement("button");
    chip.className = "filter-btn" + (category === currentDealCategory ? " active" : "");
    chip.textContent = category;
    chip.onclick = () => {
      currentDealCategory = category;
      renderDealChips();
      renderDealCards();
    };
    container.appendChild(chip);
  });
}

function renderDealCards() {
  const grid = document.getElementById("deal-grid");
  if (!grid) return;

  const list = currentDealCategory === "All" ? deals : deals.filter((d) => d.category === currentDealCategory);

  grid.innerHTML = "";
  list.forEach((deal) => {
    const card = document.createElement("div");
    card.className = "deal-card";
    card.innerHTML = `
      <h3>${escapeHtml(deal.description)}</h3>
      <p class="product-category">${escapeHtml(deal.category)}</p>
      <p class="deal-percent">${deal.discountPercent}% OFF</p>
      <button class="add-btn" onclick="copyCoupon('${escapeHtml(deal.code)}')">Copy Code: ${escapeHtml(deal.code)}</button>
      <a class="deal-link" href="shop.html?category=${encodeURIComponent(deal.category)}">Shop ${escapeHtml(deal.category)} &rarr;</a>
    `;
    grid.appendChild(card);
  });
}

// ------------------------------------------------------------
// The timed deals themselves.
//
// Drawn with buildProductCard, the same renderer the shop grid and the
// home page use. That is the whole point of putting the deal price into
// the catalogue rather than into this page: a product on offer looks
// like a product on offer wherever it is shown, and this page has no
// special knowledge the rest of the site lacks.
// ------------------------------------------------------------
function dealProducts() {
  return products
    .filter((product) => dealFor(product))
    .sort((a, b) => {
      // Biggest saving first -- as a proportion, so a RM50 saving on a
      // RM200 keyboard is not buried under RM50 off a RM4,000 machine.
      const cut = (p) => (p.price - priceOf(p)) / p.price;
      return cut(b) - cut(a);
    });
}

function renderTimedDeals() {
  const grid = document.getElementById("timed-deal-grid");
  const empty = document.getElementById("no-timed-deals");
  if (!grid) return;

  const list = dealProducts();

  grid.innerHTML = "";
  if (empty) empty.style.display = list.length === 0 ? "block" : "none";

  list.forEach((product) => grid.appendChild(buildProductCard(product)));
}

// The promotions have to arrive before anything can be drawn, and the
// notification toast in layout.js needs them too. The timed deals came
// with the catalogue, so they are already here.
onAppReady(() => {
  renderTimedDeals();
  startCountdown();

  loadDeals().then(() => {
    renderDealChips();
    renderDealCards();
    if (typeof maybeShowDealToast === "function") maybeShowDealToast();
  });
});
