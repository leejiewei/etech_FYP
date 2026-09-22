// Renders the product grid on shop.html: tick-box filters down the side
// (availability, category, type, brand and technical details, each with
// a count), real-time search, sorting, and stock badges (via
// buildProductCard).
//
// The side panel follows suncycle.com.my's category pages. Unlike theirs
// there is no Apply button: a tick redraws the grid straight away.

let currentSearch = "";
let currentSort = "default";

// What is ticked, one Set per group. An empty Set means "any". Ticking
// two brands shows either brand; ticking a brand and a category shows
// products that are both.
const selected = {
  stock: new Set(),        // "in", "out"
  category: new Set(),
  subcategory: new Set(),  // CPU, GPU, ... -- set by the CATEGORIES mega menu too
  brand: new Set(),        // set by the BRANDS mega menu too
};
let currentAttrFilters = {}; // e.g. { socket: Set["AM5"], ramGen: Set["DDR5"] }

// Brand lists run long; this many show before "Show all".
const BRANDS_SHOWN = 8;
let showAllBrands = false;

// "In stock" means there is at least one to sell, so it takes the low
// ones with it -- a shopper filtering for what they can buy today wants
// the last two in the box, not only the full shelves.
//
// This asks stockOf() rather than product.stock for the same reason the
// card does: the shop's own eleven builds have no stock of their own,
// they have however many their scarcest part allows. Reading the column
// would show every one of them as available regardless of its parts.
function stockKey(product) {
  return stockOf(product) === "out" ? "out" : "in";
}

// What a product is, for each tick-box group.
const FACET_VALUE = {
  stock: stockKey,
  category: (p) => p.category,
  subcategory: (p) => p.subcategory,
  brand: (p) => p.brand,
};

// The technical filters only make sense inside one category -- with every
// category at once they would list socket, paper size and VESA mount side
// by side. So they show once exactly one category is ticked.
function attrCategory() {
  return selected.category.size === 1 ? Array.from(selected.category)[0] : null;
}

// skip names a group to leave out, so each group's counts say how many
// products ticking that box would show, given everything else ticked.
function matchesFilters(product, skip) {
  for (const facet in selected) {
    if (facet === skip || selected[facet].size === 0) continue;
    if (!selected[facet].has(FACET_VALUE[facet](product))) return false;
  }

  for (const key in currentAttrFilters) {
    if ("attr:" + key === skip || currentAttrFilters[key].size === 0) continue;
    if (!currentAttrFilters[key].has((product.attrs || {})[key])) return false;
  }

  if (currentSearch.trim() !== "") {
    const term = currentSearch.trim().toLowerCase();
    const haystack = (product.name + " " + product.brand).toLowerCase();
    if (!haystack.includes(term)) return false;
  }

  return true;
}

// { value: count } for one group, over the products the other groups allow.
function facetCounts(skip, valueOf) {
  const counts = {};
  products.forEach((p) => {
    const value = valueOf(p);
    if (value === undefined || value === null || value === "") return;
    if (!matchesFilters(p, skip)) return;
    counts[value] = (counts[value] || 0) + 1;
  });
  return counts;
}

// One group of tick boxes. A ticked value stays listed even when its count
// drops to nothing, so it can always be unticked.
function facetGroup(title, groupId, counts, isChecked, opts) {
  opts = opts || {};
  let values = Object.keys(counts);
  if (opts.keep) opts.keep.forEach((v) => { if (!(v in counts)) { counts[v] = 0; values.push(v); } });
  if (opts.order) values = opts.order.filter((v) => values.includes(v));
  else values.sort((a, b) => a.localeCompare(b));
  if (values.length === 0) return "";

  let hiddenCount = 0;
  if (opts.limit && values.length > opts.limit && !showAllBrands) {
    const shown = values.filter((v, i) => i < opts.limit || isChecked(v));
    hiddenCount = values.length - shown.length;
    values = shown;
  }

  const label = opts.label || ((v) => v);
  return `
    <details class="shop-facet" ${opts.closed ? "" : "open"}>
      <summary>${escapeHtml(title)}</summary>
      ${values.map((v) => `
        <label class="shop-tick${counts[v] === 0 ? " empty" : ""}">
          <input type="checkbox" data-group="${escapeHtml(groupId)}" value="${escapeHtml(v)}"
                 ${isChecked(v) ? "checked" : ""} />
          <span>${escapeHtml(label(v))}</span>
          <em>${counts[v]}</em>
        </label>`).join("")}
      ${hiddenCount ? `<button type="button" class="shop-more" data-more>Show all ${values.length + hiddenCount}</button>` : ""}
      ${opts.limit && showAllBrands && values.length > opts.limit
        ? `<button type="button" class="shop-more" data-less>Show fewer</button>` : ""}
    </details>`;
}

function renderFacets() {
  const container = document.getElementById("shop-facets");
  if (!container) return;

  // Keep whichever groups the shopper folded shut folded after a redraw.
  const closed = new Set(Array.from(container.querySelectorAll("details.shop-facet:not([open]) summary"))
    .map((s) => s.textContent));

  const has = (facet) => (v) => selected[facet].has(v);
  let html = "";

  html += facetGroup("Availability", "stock", facetCounts("stock", stockKey), has("stock"),
    { order: ["in", "out"], keep: Array.from(selected.stock),
      label: (v) => (v === "in" ? "In stock" : "Out of stock") });

  html += facetGroup("Categories", "category", facetCounts("category", FACET_VALUE.category),
    has("category"), { keep: Array.from(selected.category) });

  // Types appear once there is something to narrow: a category ticked, or
  // a type already chosen from the mega menu.
  if (selected.category.size || selected.subcategory.size) {
    html += facetGroup("Type", "subcategory", facetCounts("subcategory", FACET_VALUE.subcategory),
      has("subcategory"), { keep: Array.from(selected.subcategory) });
  }

  html += facetGroup("Brands", "brand", facetCounts("brand", FACET_VALUE.brand), has("brand"),
    { keep: Array.from(selected.brand), limit: BRANDS_SHOWN });

  // Technical details for the products in view: one category, and inside
  // a category split into types (Components: CPU, GPU, ...), only once a
  // type is ticked -- otherwise the CPU's socket, the case's board size and
  // the PSU's 80+ rating would all be listed at once.
  const category = attrCategory();
  const inView = (p) => p.category === category &&
    (selected.subcategory.size === 0 || selected.subcategory.has(p.subcategory));
  const hasTypes = category && products.some((p) => p.category === category && p.subcategory);
  if (category && hasTypes && selected.subcategory.size === 0) {
    html += `<p class="filter-hint shop-hint">Tick a type above to filter by technical details.</p>`;
  } else if (category) {
    const keys = new Set();
    products.forEach((p) => {
      if (!inView(p)) return;
      Object.keys(p.attrs || {}).forEach((k) => {
        if (typeof p.attrs[k] === "string") keys.add(k); // skip numeric attrs like wattage
      });
    });
    Array.from(keys).sort((a, b) => attrLabel(a).localeCompare(attrLabel(b))).forEach((key) => {
      const ticked = currentAttrFilters[key] || new Set();
      html += facetGroup(attrLabel(key), "attr:" + key,
        facetCounts("attr:" + key, (p) => (inView(p) && typeof (p.attrs || {})[key] === "string")
          ? p.attrs[key] : null),
        (v) => ticked.has(v), { keep: Array.from(ticked), closed: ticked.size === 0 });
    });
  }

  container.innerHTML = html;

  container.querySelectorAll("details.shop-facet summary").forEach((s) => {
    if (closed.has(s.textContent)) s.parentElement.open = false;
  });

  container.querySelectorAll("input[data-group]").forEach((box) => {
    box.onchange = () => toggleFilter(box.dataset.group, box.value, box.checked);
  });
  container.querySelectorAll("[data-more]").forEach((b) => {
    b.onclick = () => { showAllBrands = true; renderFacets(); };
  });
  container.querySelectorAll("[data-less]").forEach((b) => {
    b.onclick = () => { showAllBrands = false; renderFacets(); };
  });
}

function toggleFilter(group, value, on) {
  let set;
  if (group.indexOf("attr:") === 0) {
    const key = group.slice(5);
    set = currentAttrFilters[key] || (currentAttrFilters[key] = new Set());
  } else {
    set = selected[group];
  }
  on ? set.add(value) : set.delete(value);

  // A category change leaves the old category's technical filters meaning
  // nothing, and its types too.
  if (group === "category") {
    currentAttrFilters = {};
    pruneSubcategories();
  }
  if (group === "subcategory") pruneAttrFilters();
  refreshShop();
}

// Drops ticked technical values that no product in view has any more,
// e.g. a CPU socket left ticked after switching the type to GPU.
function pruneAttrFilters() {
  const category = attrCategory();
  Object.keys(currentAttrFilters).forEach((key) => {
    currentAttrFilters[key].forEach((v) => {
      const fits = products.some((p) => p.category === category &&
        (selected.subcategory.size === 0 || selected.subcategory.has(p.subcategory)) &&
        (p.attrs || {})[key] === v);
      if (!fits) currentAttrFilters[key].delete(v);
    });
  });
}

// Drops ticked types that no longer belong to any ticked category.
function pruneSubcategories() {
  if (selected.category.size === 0) return;
  Array.from(selected.subcategory).forEach((sub) => {
    const fits = products.some((p) => p.subcategory === sub && selected.category.has(p.category));
    if (!fits) selected.subcategory.delete(sub);
  });
}

function refreshShop() {
  syncFilterUrl();
  renderFacets();
  renderShopHead();
  renderProductGrid();
}

// The heading, the crumb and a chip for each thing ticked, so it is always
// plain why only some products are showing.
function renderShopHead() {
  const one = (set) => (set.size === 1 ? Array.from(set)[0] : null);
  const title = one(selected.subcategory) || one(selected.category) || one(selected.brand) || "All Products";
  document.getElementById("shop-title").textContent = title;
  document.getElementById("shop-crumb").textContent = title;

  const chips = [];
  const chip = (group, value, label) => chips.push(`
    <span class="active-filter-chip">${escapeHtml(label)}
      <button type="button" data-chip-group="${escapeHtml(group)}" data-chip-value="${escapeHtml(value)}"
              title="Remove this filter">&times;</button></span>`);

  selected.stock.forEach((v) => chip("stock", v, v === "in" ? "In stock" : "Out of stock"));
  selected.category.forEach((v) => chip("category", v, v));
  selected.subcategory.forEach((v) => chip("subcategory", v, "Type: " + v));
  selected.brand.forEach((v) => chip("brand", v, "Brand: " + v));
  Object.keys(currentAttrFilters).forEach((key) =>
    currentAttrFilters[key].forEach((v) => chip("attr:" + key, v, attrLabel(key) + ": " + v)));

  const el = document.getElementById("shop-chips");
  el.innerHTML = chips.length
    ? chips.join("") + `<button type="button" class="shop-clear" id="shop-clear">Clear all</button>`
    : "";
  el.querySelectorAll("[data-chip-group]").forEach((b) => {
    b.onclick = () => toggleFilter(b.dataset.chipGroup, b.dataset.chipValue, false);
  });
  const clear = document.getElementById("shop-clear");
  if (clear) clear.onclick = clearAllFilters;
}

function clearAllFilters() {
  Object.keys(selected).forEach((k) => selected[k].clear());
  currentAttrFilters = {};
  refreshShop();
}

function sortProducts(list) {
  const sorted = list.slice(); // don't shuffle the original products array

  if (currentSort === "brand") {
    sorted.sort((a, b) => a.brand.localeCompare(b.brand));
  } else if (currentSort === "price-low") {
    sorted.sort((a, b) => a.price - b.price);
  } else if (currentSort === "price-high") {
    sorted.sort((a, b) => b.price - a.price);
  }

  return sorted;
}

function renderProductGrid() {
  const grid = document.getElementById("product-grid");
  const noResults = document.getElementById("no-results");
  if (!grid) return;

  const filtered = sortProducts(products.filter((p) => matchesFilters(p)));

  // This is the one place that knows both what was searched for and how
  // many products came back, so the search is recorded from here rather
  // than from the input handler. trackSearch decides whether this
  // particular call is worth a row — most are not.
  if (currentSearch.trim() !== "" && typeof trackSearch === "function") {
    trackSearch(currentSearch, filtered.length);
  }

  document.getElementById("shop-count").textContent =
    filtered.length === 1 ? "1 product" : filtered.length + " products";

  grid.innerHTML = "";
  noResults.style.display = filtered.length === 0 ? "block" : "none";

  filtered.forEach((product) => {
    grid.appendChild(buildProductCard(product));
  });
}

function handleSearchInput(value) {
  currentSearch = value;
  syncFilterUrl();
  renderFacets();
  renderProductGrid();
}

function handleSortChange(value) {
  currentSort = value;
  renderProductGrid();
}

// ------------------------------------------------------------
// Filtering without leaving the page.
//
// Every filter here has always been a link: the mega menus point at
// shop.html?category=Laptops and the page is thrown away and rebuilt to
// answer them. That is a whole page load -- the header, the product
// list, the images -- to change which subset of an array is drawn, and
// on a phone it is a white flash and a jump back to the top.
//
// So when the shop page is the page already open, the menus call in
// here instead and the grid re-renders in place. The links stay real
// links: ctrl-click still opens a new tab, and every other page in the
// site still navigates here the old way, because applyMegaFilter simply
// does not exist there for layout.js to find.
// ------------------------------------------------------------

// Keeps the address bar honest about what is on screen, so a reload or a
// pasted link shows the same products. replaceState rather than
// pushState: these are filters on one page, not places to go Back to.
// Two brands ticked is ?brand=MSI&brand=Asus.
function syncFilterUrl() {
  if (!window.history || !window.history.replaceState) return;

  const params = new URLSearchParams();
  selected.category.forEach((v) => params.append("category", v));
  selected.brand.forEach((v) => params.append("brand", v));
  selected.subcategory.forEach((v) => params.append("subcategory", v));
  selected.stock.forEach((v) => params.append("stock", v === "in" ? "in_stock" : "out_of_stock"));
  if (currentSearch.trim() !== "") params.set("search", currentSearch.trim());

  const query = params.toString();
  window.history.replaceState(null, "", query ? "?" + query : window.location.pathname);
}

// Puts the top of the grid where the eye already is. scrollIntoView is
// asked for smooth here as well as in the stylesheet: the stylesheet
// covers anchors and this covers the ones we scroll ourselves, and one
// of the two is redundant on any given browser rather than either being
// wrong.
function scrollToProducts() {
  const anchor = document.getElementById("product-grid-top");
  if (!anchor || !anchor.scrollIntoView) return;
  anchor.scrollIntoView({ behavior: "smooth", block: "start" });
}

// Called from layout.js when a mega-menu tile is clicked and this page is
// already open. kind is "brand", "category" or "subcategory". A menu
// click means "show me this", so it replaces whatever was ticked in that
// group rather than adding to it -- the same as following the link would.
function applyMegaFilter(kind, value) {
  if (!(kind in selected) || kind === "stock") return;

  selected[kind].clear();
  selected[kind].add(value);
  if (kind === "category") {
    currentAttrFilters = {}; // the old category's filters mean nothing here
    pruneSubcategories();
  }

  refreshShop();
  scrollToProducts();
}

onAppReady(() => {
  // Allow shop.html?category=Laptops, ?brand=Razer, ?subcategory=CPU or
  // ?search=... links from the home page, nav search box and mega menus.
  // Each may repeat: ?brand=MSI&brand=Asus.
  const params = new URLSearchParams(window.location.search);
  params.getAll("category").forEach((v) => selected.category.add(v));
  params.getAll("brand").forEach((v) => selected.brand.add(v));
  params.getAll("subcategory").forEach((v) => selected.subcategory.add(v));

  // ?stock=in_stock, ?stock=out_of_stock. Anything else is ignored and
  // the page shows everything, which is what a mistyped filter should do.
  params.getAll("stock").forEach((v) => {
    if (v === "in_stock") selected.stock.add("in");
    if (v === "out_of_stock") selected.stock.add("out");
  });

  if (params.get("search")) {
    currentSearch = params.get("search");
    const searchInput = document.getElementById("shop-search");
    if (searchInput) searchInput.value = currentSearch;
  }

  // On a phone the panel starts folded, so the products come first.
  if (window.matchMedia && window.matchMedia("(max-width: 900px)").matches) {
    document.getElementById("shop-side").open = false;
  }

  refreshShop();
  openLinkedProduct();
  window.addEventListener("hashchange", openLinkedProduct);
});

// shop.html#product-12 opens that product's card over the grid.
//
// A price-drop message links here, and lands on this: the bell opens the
// card in place on every page that carries it, but not in a new tab, and
// not before the catalogue has arrived. Either way the shopper ends up
// looking at the product the message was about.
//
// A hash naming something no longer in the catalogue does nothing and
// leaves the shopper on the full grid, which is the right place to be
// when the thing they came for has gone.
function openLinkedProduct() {
  const match = /^#product-(\d+)$/.exec(window.location.hash);
  if (!match) return;
  openProductModal(Number(match[1]));
}
