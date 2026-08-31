// Prebuilt PC bundles grouped by use case, with optional upgrade add-ons
// that recalculate the price live.

const prebuilts = [
  {
    id: "gaming",
    name: "Gaming Rig",
    useCase: "Gaming",
    icon: "🎮",
    basePrice: 4499,
    specs: ["Ryzen 5 5600X", "RTX 4060 8GB", "16GB DDR4 RAM", "1TB NVMe SSD", "650W Gold PSU"],
    addons: [
      { name: "Upgrade to 32GB RAM", price: 160 },
      { name: "Upgrade to 2TB SSD", price: 230 },
      { name: "Add Mechanical Keyboard + Mouse", price: 250 },
    ],
  },
  {
    id: "office",
    name: "Office Desktop",
    useCase: "Office",
    icon: "🖥️",
    basePrice: 2199,
    specs: ["Core i5-12400F", "16GB DDR4 RAM", "500GB NVMe SSD", "550W PSU", "Compact Case"],
    addons: [
      { name: "Upgrade to 1TB SSD", price: 110 },
      { name: "Add 24\" Monitor", price: 449 },
      { name: "Add Wireless Keyboard + Mouse", price: 99 },
    ],
  },
  {
    id: "student",
    name: "Student Essentials",
    useCase: "Student",
    icon: "🎓",
    basePrice: 1799,
    specs: ["Ryzen 5 5600X", "16GB DDR4 RAM", "500GB NVMe SSD", "550W PSU", "Compact Case"],
    addons: [
      { name: "Add 24\" Monitor", price: 449 },
      { name: "Upgrade to 32GB RAM", price: 160 },
      { name: "Add WiFi Card", price: 99 },
    ],
  },
];

function calcPrebuiltTotal(prebuilt, cardEl) {
  let total = prebuilt.basePrice;
  cardEl.querySelectorAll(".addon-check:checked").forEach((box) => {
    total += Number(box.dataset.price);
  });
  return total;
}

function updatePrebuiltPrice(prebuiltId) {
  const prebuilt = prebuilts.find((p) => p.id === prebuiltId);
  const card = document.getElementById("prebuilt-" + prebuiltId);
  const total = calcPrebuiltTotal(prebuilt, card);
  card.querySelector(".prebuilt-price").textContent = "RM " + total.toFixed(2);
}

function addPrebuiltToCart(prebuiltId) {
  const prebuilt = prebuilts.find((p) => p.id === prebuiltId);
  const card = document.getElementById("prebuilt-" + prebuiltId);
  const total = calcPrebuiltTotal(prebuilt, card);

  const chosenAddons = Array.from(card.querySelectorAll(".addon-check:checked")).map((box) => box.dataset.name);
  const label = prebuilt.name + " (Prebuilt)" + (chosenAddons.length ? " + " + chosenAddons.join(", ") : "");

  const cart = getCart();
  cart.push({
    id: "bundle-" + prebuilt.id + "-" + Date.now(),
    name: label,
    price: total,
    icon: prebuilt.icon,
    img: "prebuilt",
    qty: 1,
  });
  saveCart(cart);
  updateCartCount();
  alert(prebuilt.name + " added to cart for RM " + total.toFixed(2));
}

let currentUseCaseFilter = "All";

function renderUseCaseFilter() {
  const container = document.getElementById("usecase-filter");
  if (!container) return;

  const useCases = ["All", ...new Set(prebuilts.map((p) => p.useCase))];

  container.innerHTML = "";
  useCases.forEach((useCase) => {
    const btn = document.createElement("button");
    btn.textContent = useCase;
    btn.className = "filter-btn" + (useCase === currentUseCaseFilter ? " active" : "");
    btn.onclick = () => {
      currentUseCaseFilter = useCase;
      renderUseCaseFilter();
      renderPrebuilts();
    };
    container.appendChild(btn);
  });
}

function renderPrebuilts() {
  const grid = document.getElementById("prebuilt-grid");
  if (!grid) return;

  const list = currentUseCaseFilter === "All"
    ? prebuilts
    : prebuilts.filter((p) => p.useCase === currentUseCaseFilter);

  grid.innerHTML = list.map((p) => `
    <div class="prebuilt-card" id="prebuilt-${p.id}">
      <div class="product-img-wrap">
        <img class="product-img" src="images/prebuilt.svg" alt="${p.name}" />
      </div>
      <span class="prebuilt-usecase">${p.useCase}</span>
      <h3>${p.name}</h3>
      <ul class="prebuilt-specs">
        ${p.specs.map((s) => `<li>• ${s}</li>`).join("")}
      </ul>
      <div class="addon-list">
        <strong>Optional Add-ons:</strong>
        ${p.addons.map((a) => `
          <label>
            <input type="checkbox" class="addon-check" data-name="${a.name}" data-price="${a.price}"
              onchange="updatePrebuiltPrice('${p.id}')" />
            ${a.name} (+RM ${a.price.toFixed(2)})
          </label>
        `).join("")}
      </div>
      <p class="prebuilt-price">RM ${p.basePrice.toFixed(2)}</p>
      <button class="add-btn" onclick="addPrebuiltToCart('${p.id}')">Add to Cart</button>
    </div>
  `).join("");
}

document.addEventListener("DOMContentLoaded", () => {
  renderUseCaseFilter();
  renderPrebuilts();
});
