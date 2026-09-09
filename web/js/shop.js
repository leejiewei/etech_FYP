// Renders the product grid on shop.html: category buttons, technical
// attribute filters, real-time search, and stock badges (via buildProductCard).

let currentCategory = "All";
let currentSearch = "";
let currentAttrFilters = {}; // e.g. { socket: "AM4", ramGen: "DDR4" }
let currentSort = "default";
let currentBrand = "All";        // set by the BRANDS mega menu
let currentSubcategory = "All";  // set by the CATEGORIES mega menu (CPU, GPU, ...)
let currentStock = "all";        // all | in_stock | out_of_stock

function getCategories() {
  const categories = ["All"];
  products.forEach((p) => {
    if (!categories.includes(p.category)) categories.push(p.category);
  });
  return categories;
}

// Figures out which attribute keys are relevant for the products currently
// shown (after category filtering), so the filter dropdowns only show
// options that actually apply, e.g. "socket" only appears for Components.
function getAvailableAttrOptions(list) {
  const options = {}; // { socket: Set, ramGen: Set, screenSize: Set, storageSize: Set }

  list.forEach((p) => {
    Object.keys(p.attrs || {}).forEach((key) => {
      const value = p.attrs[key];
      if (typeof value !== "string") return; // skip numeric attrs like wattage
      if (!options[key]) options[key] = new Set();
      options[key].add(value);
    });
  });

  return options;
}

function renderCategoryButtons() {
  const container = document.getElementById("category-buttons");
  if (!container) return;

  container.innerHTML = "";

  getCategories().forEach((category) => {
    const btn = document.createElement("button");
    btn.textContent = category;
    btn.className = "filter-btn" + (category === currentCategory ? " active" : "");
    btn.onclick = () => {
      currentCategory = category;
      currentAttrFilters = {}; // reset attribute filters when category changes
      syncFilterUrl();
      renderCategoryButtons();
      renderAttrFilters();
      renderProductGrid();
      // The buttons sit above the grid, and choosing one of them used to
      // change something the shopper could not see -- on a phone the whole
      // answer was below the fold. Now the answer comes to them.
      scrollToProducts();
    };
    container.appendChild(btn);
  });
}

function renderAttrFilters() {
  const container = document.getElementById("attr-filters");
  if (!container) return;

  container.innerHTML = "";

  // With every category showing at once we'd list every technical filter in
  // the shop (socket, paper size, VESA mount...), which is just noise. So the
  // technical filters only appear once a category has been chosen.
  if (currentCategory === "All") {
    container.innerHTML =
      `<p class="filter-hint">Pick a category above to filter by technical details.</p>`;
    return;
  }

  const categoryList = products.filter((p) => p.category === currentCategory);
  const options = getAvailableAttrOptions(categoryList);

  Object.keys(options).forEach((key) => {
    const select = document.createElement("select");
    select.className = "attr-select";

    const defaultOption = document.createElement("option");
    defaultOption.value = "";
    defaultOption.textContent = attrLabel(key) + ": Any";
    select.appendChild(defaultOption);

    Array.from(options[key]).sort().forEach((value) => {
      const opt = document.createElement("option");
      opt.value = value;
      opt.textContent = value;
      if (currentAttrFilters[key] === value) opt.selected = true;
      select.appendChild(opt);
    });

    select.onchange = () => {
      if (select.value === "") {
        delete currentAttrFilters[key];
      } else {
        currentAttrFilters[key] = select.value;
      }
      renderProductGrid();
    };

    container.appendChild(select);
  });
}

// "In stock" means there is at least one to sell, so it takes the low
// ones with it -- a shopper filtering for what they can buy today wants
// the last two in the box, not only the full shelves.
//
// This asks stockOf() rather than product.stock for the same reason the
// card does: the shop's own eleven builds have no stock of their own,
// they have however many their scarcest part allows. Reading the column
// would show every one of them as available regardless of its parts.
function matchesStockFilter(product) {
  if (currentStock === "all") return true;
  const inStock = stockOf(product) !== "out";
  return currentStock === "in_stock" ? inStock : !inStock;
}

function matchesFilters(product) {
  if (currentCategory !== "All" && product.category !== currentCategory) return false;
  if (currentBrand !== "All" && product.brand !== currentBrand) return false;
  if (currentSubcategory !== "All" && product.subcategory !== currentSubcategory) return false;
  if (!matchesStockFilter(product)) return false;

  for (const key in currentAttrFilters) {
    if ((product.attrs || {})[key] !== currentAttrFilters[key]) return false;
  }

  if (currentSearch.trim() !== "") {
    const term = currentSearch.trim().toLowerCase();
    const haystack = (product.name + " " + product.brand).toLowerCase();
    if (!haystack.includes(term)) return false;
  }

  return true;
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

  const filtered = sortProducts(products.filter(matchesFilters));

  // This is the one place that knows both what was searched for and how
  // many products came back, so the search is recorded from here rather
  // than from the input handler. trackSearch decides whether this
  // particular call is worth a row — most are not.
  if (currentSearch.trim() !== "" && typeof trackSearch === "function") {
    trackSearch(currentSearch, filtered.length);
  }

  grid.innerHTML = "";
  noResults.style.display = filtered.length === 0 ? "block" : "none";

  filtered.forEach((product) => {
    grid.appendChild(buildProductCard(product));
  });
}

function handleSearchInput(value) {
  currentSearch = value;
  renderProductGrid();
}

function handleSortChange(value) {
  currentSort = value;
  renderProductGrid();
}

function handleStockChange(value) {
  currentStock = value;
  syncFilterUrl();
  renderProductGrid();
}

// Shows a little "Brand: Razer  x" chip when you arrive from a mega menu link,
// so it's obvious why only some products are showing.
function renderActiveFilterNotice() {
  const el = document.getElementById("active-filter");
  if (!el) return;

  let label = "";
  if (currentBrand !== "All") label = "Brand: " + currentBrand;
  if (currentSubcategory !== "All") label = "Type: " + currentSubcategory;

  if (label === "") {
    el.style.display = "none";
    return;
  }

  el.style.display = "block";
  el.innerHTML = `<span class="active-filter-chip">${escapeHtml(label)}
    <button onclick="clearMegaFilter()" title="Clear filter">&times;</button></span>`;
}

function clearMegaFilter() {
  currentBrand = "All";
  currentSubcategory = "All";
  syncFilterUrl();
  renderActiveFilterNotice();
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
function syncFilterUrl() {
  if (!window.history || !window.history.replaceState) return;

  const params = new URLSearchParams();
  if (currentCategory !== "All") params.set("category", currentCategory);
  if (currentBrand !== "All") params.set("brand", currentBrand);
  if (currentSubcategory !== "All") params.set("subcategory", currentSubcategory);
  if (currentStock !== "all") params.set("stock", currentStock);
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
// already open. kind is "brand", "category" or "subcategory".
function applyMegaFilter(kind, value) {
  if (kind === "brand") {
    currentBrand = value;
  } else if (kind === "subcategory") {
    currentSubcategory = value;
  } else if (kind === "category") {
    currentCategory = value;
    currentAttrFilters = {}; // the old category's filters mean nothing here
  } else {
    return;
  }

  syncFilterUrl();
  renderCategoryButtons();
  renderAttrFilters();
  renderActiveFilterNotice();
  renderProductGrid();
  scrollToProducts();
}

onAppReady(() => {
  // Allow shop.html?category=Laptops, ?brand=Razer, ?subcategory=CPU or
  // ?search=... links from the home page, nav search box and mega menus.
  const params = new URLSearchParams(window.location.search);
  if (params.get("category")) {
    currentCategory = params.get("category");
  }
  if (params.get("brand")) {
    currentBrand = params.get("brand");
  }
  if (params.get("subcategory")) {
    currentSubcategory = params.get("subcategory");
  }
  if (params.get("search")) {
    currentSearch = params.get("search");
    const searchInput = document.getElementById("shop-search");
    if (searchInput) searchInput.value = currentSearch;
  }
  // ?stock=in_stock, ?stock=out_of_stock. Anything else is ignored and
  // the page shows everything, which is what a mistyped filter should do.
  if (params.get("stock") === "in_stock" || params.get("stock") === "out_of_stock") {
    currentStock = params.get("stock");
    const stockSelect = document.getElementById("stock-select");
    if (stockSelect) stockSelect.value = currentStock;
  }

  renderCategoryButtons();
  renderAttrFilters();
  renderActiveFilterNotice();
  renderProductGrid();
});
