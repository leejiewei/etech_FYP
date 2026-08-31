// Deals page data + logic: flash-sale countdown, category chips, coupon codes.

const deals = [
  { category: "Laptops", code: "LAPTOP15", discountPercent: 15, description: "15% off all laptops" },
  { category: "Components", code: "PARTS10", discountPercent: 10, description: "10% off PC components" },
  { category: "Gaming Gear", code: "GEAR20", discountPercent: 20, description: "20% off gaming gear" },
  { category: "Monitors", code: "SCREEN12", discountPercent: 12, description: "12% off monitors" },
  { category: "Networking", code: "NET10", discountPercent: 10, description: "10% off networking gear" },
];

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
      <h3>${deal.description}</h3>
      <p class="product-category">${deal.category}</p>
      <p class="deal-percent">${deal.discountPercent}% OFF</p>
      <button class="add-btn" onclick="copyCoupon('${deal.code}')">Copy Code: ${deal.code}</button>
      <a class="deal-link" href="shop.html?category=${encodeURIComponent(deal.category)}">Shop ${deal.category} &rarr;</a>
    `;
    grid.appendChild(card);
  });
}

document.addEventListener("DOMContentLoaded", () => {
  startCountdown();
  renderDealChips();
  renderDealCards();
});
