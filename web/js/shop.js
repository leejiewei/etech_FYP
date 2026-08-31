// Renders the product grid on shop.html: category buttons, technical
// attribute filters, real-time search, and stock badges (via buildProductCard).

let currentCategory = "All";
let currentSearch = "";
let currentAttrFilters = {}; // e.g. { socket: "AM4", ramGen: "DDR4" }
let currentSort = "default";
let currentBrand = "All";        // set by the BRANDS mega menu
let currentSubcategory = "All";  // set by the CATEGORIES mega menu (CPU, GPU, ...)

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
      renderCategoryButtons();
      renderAttrFilters();
      renderProductGrid();
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

function matchesFilters(product) {
  if (currentCategory !== "All" && product.category !== currentCategory) return false;
  if (currentBrand !== "All" && product.brand !== currentBrand) return false;
  if (currentSubcategory !== "All" && product.subcategory !== currentSubcategory) return false;

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
  el.innerHTML = `<span class="active-filter-chip">${label}
    <button onclick="clearMegaFilter()" title="Clear filter">&times;</button></span>`;
}

function clearMegaFilter() {
  currentBrand = "All";
  currentSubcategory = "All";
  renderActiveFilterNotice();
  renderProductGrid();
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

  renderCategoryButtons();
  renderAttrFilters();
  renderActiveFilterNotice();
  renderProductGrid();
});
