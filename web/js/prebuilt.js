// The Prebuilt PCs page.
//
// This page used to render three hardcoded machines -- "Gaming Rig",
// "Office Desktop", "Student Essentials" -- that existed nowhere in the
// database. They were placeholders from before the shop had a real
// catalogue of complete systems, and they outlived their usefulness on
// 12 August 2026 when the RigWorks record brought in nineteen actual
// desktops. The page was still showing the placeholders.
//
// It now reads the catalogue like every other page. The machines here are
// the children of the "Desktops" category:
//
//   Prebuilt Gaming PCs   5   the E-Tech gaming builds
//   Branded Desktops      4   Asus and Lenovo towers
//   AIO Desktops          4   the HP all-in-ones
//   Office PC Series      3   E-Tech office builds
//   Custom Office CO1     3   the CO1 variants
//
// Adding one to the basket goes through addToCart() in cart.js, the same
// path as every other product. The old code here did something different
// and worse: it worked out a price in the browser, invented an id of the
// form "bundle-gaming-1755000000000", and pushed the result straight into
// a localStorage basket. That basket no longer exists -- the cart moved
// into the database, where the price is the shop's to decide and not the
// browser's -- so the old Add to Cart button had been throwing
// "saveCart is not defined" and silently doing nothing at all.

// The order specs are listed in. A machine shows the ones it has and
// skips the rest, so a tower leads with its processor and graphics while
// an all-in-one leads with its processor and screen. Anything not named
// here still appears, after these, rather than being dropped.
const PREBUILT_SPEC_ORDER = [
  "cpu", "gpu", "motherboard", "ram", "ssd", "storageSize",
  "screenSize", "resolution", "touch",
  "psu", "cooler", "chassis", "colour", "sku",
];

const PREBUILT_PARENT_CATEGORY = "Desktops";

let currentUseCaseFilter = "All";

function getPrebuilts() {
  return products
    .filter((p) => p.category === PREBUILT_PARENT_CATEGORY)
    .sort((a, b) => a.id - b.id);
}

// The record writes a machine's upgrade options as prose at the end of its
// description -- "Upgrades: +RM499 to RTX 5050 8GB, +RM380 to 1TB Gen4
// NVMe". Eleven of the nineteen have one.
//
// They are shown as a note, not as the priced checkboxes this page used to
// carry. Those checkboxes added their own numbers to a browser-side total,
// which is exactly the arrangement the database was moved to prevent: an
// upgrade is only real once it is a row the shop can price and stock. The
// text is here because it is what the record says; wiring it up is a
// separate job from putting the machines back on the page.
function upgradeNote(product) {
  const match = /Upgrades?:\s*([^.]+)/i.exec(product.description || "");
  return match ? match[1].trim() : null;
}

function prebuiltSpecList(product) {
  const attrs = product.attrs || {};
  const keys = Object.keys(attrs);

  const ordered = [
    ...PREBUILT_SPEC_ORDER.filter((key) => keys.includes(key)),
    ...keys.filter((key) => !PREBUILT_SPEC_ORDER.includes(key)),
  ];

  return ordered.map((key) => {
    const value = Array.isArray(attrs[key]) ? attrs[key].join(", ") : attrs[key];
    return `<li><span class="spec-key">${attrLabel(key)}:</span> ${value}</li>`;
  }).join("");
}

function renderUseCaseFilter() {
  const container = document.getElementById("usecase-filter");
  if (!container) return;

  const useCases = ["All", ...new Set(getPrebuilts().map((p) => p.subcategory))];

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

  const all = getPrebuilts();
  const list = currentUseCaseFilter === "All"
    ? all
    : all.filter((p) => p.subcategory === currentUseCaseFilter);

  if (!list.length) {
    grid.innerHTML = `<p style="text-align:center; color:#666;">No prebuilt PCs to show.</p>`;
    return;
  }

  grid.innerHTML = list.map((p) => {
    const outOfStock = p.stock === "out";
    const upgrades = upgradeNote(p);

    return `
    <div class="prebuilt-card" id="prebuilt-${p.id}">
      <div class="product-img-wrap">
        ${productImageTag(p, "product-img")}
      </div>
      <span class="prebuilt-usecase">${p.subcategory}</span>
      <h3>${p.name}</h3>
      <p class="stock-badge stock-${p.stock}">${stockLabel(p.stock)}</p>
      <ul class="prebuilt-specs">
        ${prebuiltSpecList(p)}
      </ul>
      ${upgrades ? `
      <div class="addon-list">
        <strong>Available upgrades:</strong>
        <p class="prebuilt-upgrades">${upgrades}</p>
      </div>` : ""}
      <p class="prebuilt-price">RM ${p.price.toFixed(2)}</p>
      <button class="add-btn" ${outOfStock ? "disabled" : ""} onclick="addToCart(${p.id})">
        ${outOfStock ? "Out of Stock" : "Add to Cart"}
      </button>
    </div>`;
  }).join("");

  grid.querySelectorAll(".prebuilt-card").forEach((card) => {
    const id = Number(card.id.replace("prebuilt-", ""));
    card.querySelector(".product-img-wrap").addEventListener("click", () => {
      if (typeof trackProductClick === "function") trackProductClick(id);
    });
  });
}

onAppReady(() => {
  renderUseCaseFilter();
  renderPrebuilts();
});
