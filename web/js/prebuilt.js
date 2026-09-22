// The Prebuilt PCs page.
//
// This page used to render three hardcoded machines -- "Gaming Rig",
// "Office Desktop", "Student Essentials" -- that existed nowhere in the
// database. They were placeholders from before the shop had a real
// catalogue of complete systems, and they outlived their usefulness on
// 12 August 2026 when the RigWorks record brought in nineteen actual
// desktops. The page was still showing the placeholders.
//
// It now reads the catalogue like every other page, gathering the
// machines into the four ranges the shop actually sells against:
//
//   Gaming    5   Desktops > Prebuilt Gaming PCs -- the E-Tech gaming builds
//   Office    6   Desktops > Office PC Series + Custom Office CO1
//   Branded   4   Branded PC -- Asus and Lenovo towers
//   AIO PC    4   All-in-One PC -- the HP all-in-ones
//
// Branded PC and All-in-One PC were sub-categories of Desktops until
// 21 September 2026, when they became categories of their own. A range
// is therefore matched by the machine's most specific category name --
// its sub-category if it has one, otherwise its category.
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

// The four ranges, and which catalogue categories feed each. Written
// out rather than derived from the data so the order on the page is the
// order the shop thinks in, and so a category added later does not
// silently appear as a fifth chip -- it has to be named here first.
// The old names stay listed so the page works on either side of the
// 21 September rename.
const PREBUILT_GROUPS = [
  { label: "Gaming",  categories: ["Prebuilt Gaming PCs"] },
  { label: "Office",  categories: ["Office PC Series", "Custom Office CO1"] },
  { label: "Branded", categories: ["Branded PC", "Branded Desktops"] },
  { label: "AIO PC",  categories: ["All-in-One PC", "AIO Desktops"] },
];

let currentUseCaseFilter = "All";

// Which of the four a machine belongs to, or null if it belongs to none
// -- in which case it is not a machine this page shows.
function prebuiltGroup(product) {
  const name = product.subcategory || product.category;
  const group = PREBUILT_GROUPS.find((g) => g.categories.includes(name));
  return group ? group.label : null;
}

function getPrebuilts() {
  return products
    .filter((p) => prebuiltGroup(p))
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
}

// Where a card leads: the machine's own page, where the upgrades are
// chosen. See prebuilt-detail.js.
function prebuiltDetailUrl(productId) {
  return "prebuilt-detail.html?id=" + encodeURIComponent(productId);
}

function prebuiltCard(p) {
  // stockOf, not p.stock. For the shop's own builds this is the answer
  // the parts give -- one component out and the machine is out -- and
  // for everything else it is p.stock unchanged. See products.js.
  const stock = stockOf(p);
  const outOfStock = stock === "out";
  const waiting = blockedBy(p.id);
  const optionCount = upgradesFor(p.id).length;
  const url = prebuiltDetailUrl(p.id);

  // The upgrades themselves are chosen on the machine's own page; the
  // card only says there are some, so the grid stays easy to scan.
  return `
    <div class="prebuilt-card" id="prebuilt-${p.id}">
      <a class="product-img-wrap" href="${url}">
        ${productImageTag(p, "product-img")}
      </a>
      <span class="prebuilt-usecase">${escapeHtml(prebuiltGroup(p))}</span>
      <h3><a class="prebuilt-name" href="${url}">${escapeHtml(p.name)}</a></h3>
      <p class="stock-badge stock-${stock}">${stockLabel(stock)}</p>
      ${waiting
        ? `<p class="prebuilt-waiting">Waiting on: ${escapeHtml(waiting)}</p>`
        : ""}
      <ul class="prebuilt-specs">
        ${prebuiltSpecList(p)}
      </ul>
      ${priceBlockHtml(p, "prebuilt-price")}
      ${optionCount
        ? `<p class="prebuilt-price-basis">${optionCount} upgrade option${optionCount === 1 ? "" : "s"} available</p>`
        : ""}
      <div class="prebuilt-actions">
        <a class="btn prebuilt-customise" href="${url}">
          ${optionCount ? "Customise" : "View details"}
        </a>
        <button class="add-btn" ${outOfStock ? "disabled" : ""}
                onclick="addToCart(${p.id}, [])">
          ${outOfStock ? "Out of Stock" : "Add to Cart"}
        </button>
      </div>
    </div>`;
}

onAppReady(() => {
  renderUseCaseFilter();
  renderPrebuilts();
});
