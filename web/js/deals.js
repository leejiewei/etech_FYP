// Deals page: flash-sale countdown, category chips, coupon codes.
//
// The promotions are no longer written here — they come from the coupons
// table, which is what the admin panel edits. Switch one on in the admin
// and it appears here, and the matching customers get notified.
//
// Nothing filters out the expired or switched-off ones here, and that is
// on purpose: the policy on the coupons table only ever returns
// promotions that are active and inside their dates. The page cannot see
// a dead coupon to show it by mistake, which is a stronger guarantee
// than remembering to filter.

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

// The flash sale ends 6 hours from the first time this page is opened.
// We store the end time so a page refresh doesn't reset the countdown.
function getFlashSaleEndTime() {
  let endTime = localStorage.getItem("flashSaleEnd");
  if (!endTime || Number(endTime) < Date.now()) {
    endTime = Date.now() + 6 * 60 * 60 * 1000; // 6 hours from now
    localStorage.setItem("flashSaleEnd", String(endTime));
  }
  return Number(endTime);
}

function formatCountdown(msLeft) {
  if (msLeft <= 0) return "Sale ended";
  const totalSeconds = Math.floor(msLeft / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  const pad = (n) => String(n).padStart(2, "0");
  return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
}

function startCountdown() {
  const el = document.getElementById("countdown");
  if (!el) return;

  const endTime = getFlashSaleEndTime();

  function tick() {
    el.textContent = formatCountdown(endTime - Date.now());
  }

  tick();
  setInterval(tick, 1000);
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

// The promotions have to arrive before anything can be drawn, and the
// notification toast in layout.js needs them too.
onAppReady(() => {
  loadDeals().then(() => {
    startCountdown();
    renderDealChips();
    renderDealCards();
    if (typeof maybeShowDealToast === "function") maybeShowDealToast();
  });
});
