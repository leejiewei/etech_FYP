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
// the children of the "Desktops" category, gathered into the four ranges
// the shop actually sells against:
//
//   Gaming    5   Prebuilt Gaming PCs -- the E-Tech gaming builds
//   Office    6   Office PC Series + Custom Office CO1
//   Branded   4   Branded Desktops -- Asus and Lenovo towers
//   AIO PC    4   AIO Desktops -- the HP all-in-ones
//
// The two office ranges are one chip rather than two. They are the same
// kind of machine to a customer -- an E-Tech office tower -- and the
// difference between the series and the CO1 variants is in the model
// name, which is on every card anyway. All nineteen machines are still
// on the page; this changes how they are grouped, not which of them the
// shop sells.
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

// The four ranges, and which catalogue sub-categories feed each. Written
// out rather than derived from the data so the order on the page is the
// order the shop thinks in, and so a sub-category added under Desktops
// later does not silently appear as a fifth chip -- it has to be named
// here first.
const PREBUILT_GROUPS = [
  { label: "Gaming",  subcategories: ["Prebuilt Gaming PCs"] },
  { label: "Office",  subcategories: ["Office PC Series", "Custom Office CO1"] },
  { label: "Branded", subcategories: ["Branded Desktops"] },
  { label: "AIO PC",  subcategories: ["AIO Desktops"] },
];

let currentUseCaseFilter = "All";

// Which of the four a machine belongs to, or null if it belongs to none
// -- in which case it is not a machine this page shows.
function prebuiltGroup(product) {
  const group = PREBUILT_GROUPS.find((g) =>
    g.subcategories.includes(product.subcategory));
  return group ? group.label : null;
}

function getPrebuilts() {
  return products
    .filter((p) => p.category === PREBUILT_PARENT_CATEGORY && prebuiltGroup(p))
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

  // Fixed order, and only ranges that have something in them -- an empty
  // chip that finds nothing when tapped is worse than no chip.
  const stocked = new Set(getPrebuilts().map(prebuiltGroup));
  const useCases = ["All", ...PREBUILT_GROUPS
    .map((g) => g.label)
    .filter((label) => stocked.has(label))];

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
    : all.filter((p) => prebuiltGroup(p) === currentUseCaseFilter);

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
      <span class="prebuilt-usecase">${prebuiltGroup(p)}</span>
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
      openProductModal(id);
    });
  });
}

onAppReady(() => {
  renderUseCaseFilter();
  renderPrebuilts();
});
