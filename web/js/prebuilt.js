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

// The upgrades ticked on each machine's card, by machine id. Held here
// rather than in the basket, because nothing has been bought yet -- they
// travel to the basket with the Add button, and the cart page is where
// they become real.
const chosenUpgrades = {};

function chosenFor(productId) {
  return (chosenUpgrades[productId] ||= new Set());
}

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
// For a long time that sentence was all this page showed, because the
// checkboxes it replaced added their own numbers to a browser-side total
// -- exactly what moving the cart into the database was meant to stop.
// An upgrade is only real once it is a row the shop can price and stock.
// The eleven DIY machines now have those rows, in prebuilt_upgrades, so
// they get real checkboxes and this note is the fallback for the eight
// branded and all-in-one machines that do not.
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
    return `<li><span class="spec-key">${escapeHtml(attrLabel(key))}:</span> ${escapeHtml(value)}</li>`;
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

  grid.innerHTML = list.map(prebuiltCard).join("");

  grid.querySelectorAll(".prebuilt-card").forEach((card) => {
    const id = Number(card.id.replace("prebuilt-", ""));
    card.querySelector(".product-img-wrap").addEventListener("click", () => {
      openProductModal(id);
    });
  });

  // Here rather than only at start-up, so the boxes are live again after
  // a range chip redraws the grid.
  wireUpgradeBoxes();
}

function prebuiltCard(p) {
  // stockOf, not p.stock. For the shop's own builds this is the answer
  // the parts give -- one component out and the machine is out -- and
  // for everything else it is p.stock unchanged. See products.js.
  const stock = stockOf(p);
  const outOfStock = stock === "out";
  const waiting = blockedBy(p.id);

  const options = upgradesFor(p.id);
  const chosen = chosenFor(p.id);
  const extra = options
    .filter((u) => chosen.has(u.id))
    .reduce((sum, u) => sum + u.priceDelta, 0);

  // Only fall back to the prose when there is nothing better. A machine
  // with real options should not also show the sentence they came from.
  const note = options.length ? null : upgradeNote(p);

  return `
    <div class="prebuilt-card" id="prebuilt-${p.id}">
      <div class="product-img-wrap">
        ${productImageTag(p, "product-img")}
      </div>
      <span class="prebuilt-usecase">${escapeHtml(prebuiltGroup(p))}</span>
      <h3>${escapeHtml(p.name)}</h3>
      <p class="stock-badge stock-${stock}">${stockLabel(stock)}</p>
      ${waiting
        ? `<p class="prebuilt-waiting">Waiting on: ${escapeHtml(waiting)}</p>`
        : ""}
      <ul class="prebuilt-specs">
        ${prebuiltSpecList(p)}
      </ul>
      ${optionBlock(p, machineUpgrades(p.id), chosen, outOfStock,
                    "Add on at build time",
                    "Ticked here, confirmed in your cart.")}
      ${optionBlock(p, machineAccessories(p.id), chosen, outOfStock,
                    "Buy with this machine",
                    "Shop prices for buying alongside a PC.")}
      ${note ? `
      <div class="addon-list">
        <strong>Available upgrades:</strong>
        <p class="prebuilt-upgrades">${escapeHtml(note)}</p>
      </div>` : ""}
      ${/* A deal is on the machine, not on the options bolted to it --
            the till works the same way -- so the deal price replaces the
            base and the upgrades are added to it as before. */ ""}
      <p class="prebuilt-price">RM ${(priceOf(p) + extra).toFixed(2)}</p>
      ${hasDeal(p)
        ? `<p class="prebuilt-price-basis">
             <span class="price-was">RM ${(p.price + extra).toFixed(2)}</span>
             on deal until ${escapeHtml(dealEndsText(p))}</p>`
        : ""}
      ${extra > 0
        ? `<p class="prebuilt-price-basis">RM ${priceOf(p).toFixed(2)}
             + RM ${extra.toFixed(2)} upgrades</p>`
        : ""}
      <button class="add-btn" ${outOfStock ? "disabled" : ""}
              onclick="addPrebuiltToCart(${p.id})">
        ${outOfStock ? "Out of Stock" : "Add to Cart"}
      </button>
    </div>`;
}

// One tickable list. An upgrade changes the machine itself; an accessory
// is sold beside it at a with-purchase price. Same tick box to a
// customer, different fact about the shop, so they get separate
// headings rather than one mixed list.
function optionBlock(product, options, chosen, outOfStock, title, hint) {
  if (!options.length) return "";

  return `
    <div class="addon-list">
      <strong>${escapeHtml(title)}</strong>
      <p class="addon-hint">${escapeHtml(hint)}</p>
      ${options.map((u) => `
        <label class="addon-option${outOfStock ? " disabled" : ""}">
          <input type="checkbox" value="${u.id}" data-machine="${product.id}"
                 data-slot="${escapeHtml(u.slot)}"
                 ${chosen.has(u.id) ? "checked" : ""}
                 ${outOfStock ? "disabled" : ""} />
          <span>${escapeHtml(u.label)}</span>
          <em>+RM ${u.priceDelta.toFixed(2)}</em>
        </label>`).join("")}
    </div>`;
}

// Ticking a box redraws only its own card, so the running price updates
// without the page losing the other cards' scroll position.
function wireUpgradeBoxes() {
  const grid = document.getElementById("prebuilt-grid");
  if (!grid) return;

  grid.querySelectorAll(".addon-option input").forEach((box) => {
    box.onchange = () => {
      const machineId = Number(box.dataset.machine);
      const upgradeId = Number(box.value);
      const chosen = chosenFor(machineId);

      if (box.checked) {
        // One swap per slot: a machine has one graphics card, so ticking
        // a second graphics upgrade replaces the first rather than
        // charging for both.
        upgradesFor(machineId)
          .filter((u) => u.slot === box.dataset.slot)
          .forEach((u) => chosen.delete(u.id));
        chosen.add(upgradeId);
      } else {
        chosen.delete(upgradeId);
      }

      redrawCard(machineId);
    };
  });
}

function redrawCard(productId) {
  const card = document.getElementById("prebuilt-" + productId);
  const product = getProductById(productId);
  if (!card || !product) return;

  card.outerHTML = prebuiltCard(product);
  const fresh = document.getElementById("prebuilt-" + productId);
  fresh.querySelector(".product-img-wrap").addEventListener("click", () => {
    openProductModal(productId);
  });
  wireUpgradeBoxes();
}

// Only the ids travel to the basket. What each one costs is read from
// prebuilt_upgrades by place_order, on the server.
function addPrebuiltToCart(productId) {
  addToCart(productId, Array.from(chosenFor(productId)));
}

onAppReady(() => {
  renderUseCaseFilter();
  renderPrebuilts();
});
