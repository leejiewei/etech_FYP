// Builds the navbar, footer, floating WhatsApp button, chatbot widget and
// the "deal for you" notification toast, and drops them into every page.
// Each page just needs empty <div id="site-header"></div> and
// <div id="site-footer"></div> placeholders — this file fills them in,
// so the navbar only has to be edited in one place.

// ------------------------------------------------------------
// Interface icons. Same rules as CATEGORY_ICONS below: Lucide paths
// (lucide.dev, ISC licence) copied in, 24x24 at a 2px stroke, drawn in
// currentColor. They replaced emoji, which every phone draws differently.
// ------------------------------------------------------------
const UI_ICONS = {
  search: '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
  heart: '<path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/>',
  cart: '<circle cx="8" cy="21" r="1"/><circle cx="19" cy="21" r="1"/><path d="M2.05 2.05h2l2.66 12.42a2 2 0 0 0 2 1.58h9.78a2 2 0 0 0 1.95-1.57l1.65-7.43H5.12"/>',
  bell: '<path d="M10.268 21a2 2 0 0 0 3.464 0"/><path d="M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326"/>',
  user: '<circle cx="12" cy="8" r="5"/><path d="M20 21a8 8 0 0 0-16 0"/>',
  chevron: '<path d="m6 9 6 6 6-6"/>',
  external: '<path d="M15 3h6v6"/><path d="M10 14 21 3"/><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>',
  chat: '<path d="M7.9 20A9 9 0 1 0 4 16.1L2 22Z"/>',
  sparkle: '<path d="M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5.5 0 0 1 0 .964L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z"/>',
  close: '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
  help: '<circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><path d="M12 17h.01"/>',
  star: '<path d="M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z"/>',
  clock: '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
  package: '<path d="M11 21.73a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73z"/><path d="M12 22V12"/><path d="m3.3 7 7.703 4.734a2 2 0 0 0 1.994 0L20.7 7"/><path d="m7.5 4.27 9 5.15"/>',
  shieldCheck: '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9 12 2 2 4-4"/>',
  tag: '<path d="M12.586 2.586A2 2 0 0 0 11.172 2H4a2 2 0 0 0-2 2v7.172a2 2 0 0 0 .586 1.414l8.704 8.704a2.426 2.426 0 0 0 3.42 0l6.58-6.58a2.426 2.426 0 0 0 0-3.42z"/><circle cx="7.5" cy="7.5" r=".5" fill="currentColor"/>',
};

function uiIcon(name, extraClass) {
  return `<svg class="ui-icon${extraClass ? " " + extraClass : ""}" viewBox="0 0 24 24" fill="none"
    stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
    aria-hidden="true">${UI_ICONS[name] || ""}</svg>`;
}

// The aisles shown in the header strip. "All categories" opens the full
// menu for the rest.
const HEADER_AISLES = [
  { label: "Components", href: "shop.html?category=Components" },
  { label: "Laptops", href: "shop.html?category=Laptops" },
  { label: "Gaming Gear", href: "shop.html?category=Gaming%20Gear" },
  { label: "Monitors", href: "shop.html?category=Monitors" },
  { label: "Printers", href: "shop.html?category=Printers" },
  { label: "Networking", href: "shop.html?category=Networking" },
  { label: "Accessories", href: "shop.html?category=Accessories" },
];

function injectHeader() {
  const header = document.getElementById("site-header");
  if (!header) return;

  const user = typeof getCurrentUser === "function" ? getCurrentUser() : null;
  const cartCount = typeof getCart === "function" ? getCart().reduce((s, i) => s + i.qty, 0) : 0;
  const wishlistCount = typeof getWishlist === "function" ? getWishlist().length : 0;
  const here = (location.pathname.split("/").pop() || "index.html").toLowerCase();
  const current = (file) => (here === file ? ' aria-current="page"' : "");

  const accountMenu = user
    ? `<div class="account-menu">
         <button type="button" class="shell-action" aria-haspopup="true">
           ${uiIcon("user")}<span class="shell-action-label">${escapeHtml(user.name.split(" ")[0])}</span>
         </button>
         <div class="account-dropdown">
           <a href="profile.html">Profile</a>
           <a href="orders.html">Order history</a>
           <a href="#" onclick="logoutUser(); return false;">Log out</a>
         </div>
       </div>`
    : `<a class="shell-action" href="login.html">${uiIcon("user")}<span class="shell-action-label">Log in</span></a>`;

  // Messages about the customer's orders -- see js/notifications.js,
  // which fills the list and the count once the header is on the page.
  // Only drawn where that file is loaded, so a page without it never
  // shows a bell that does nothing.
  const notificationBell = user && typeof startNotifications === "function"
    ? `<li class="notif-menu" id="notif-menu">
         <button type="button" class="notif-bell shell-action" id="notif-bell"
                 aria-label="Notifications" aria-haspopup="true" aria-expanded="false">
           ${uiIcon("bell")}<span class="badge" id="notif-count" hidden>0</span>
         </button>
         <div class="notif-panel" id="notif-panel" hidden>
           <div class="notif-head">Notifications</div>
           <div class="notif-list" id="notif-list"></div>
         </div>
       </li>`
    : "";

  header.innerHTML = `
    <div class="shell">
      <nav class="navbar" aria-label="Shop">
        <a href="index.html" class="logo" aria-label="eTech home">
          <img class="logo-img" src="images/brand/etech-logo-96.png" width="44" height="44" alt="" />
          <span class="logo-mark">eTech</span>
          <small>Computer Accessories</small>
        </a>

        <form class="search" role="search" action="shop.html">
          ${uiIcon("search", "search-icon")}
          <input type="search" id="global-search" name="search" class="search-box"
                 placeholder="Search parts, laptops, brands" autocomplete="off"
                 aria-label="Search the shop" />
        </form>

        <ul class="nav-links shell-actions">
          <li><a class="shell-action" href="wishlist.html"${current("wishlist.html")} aria-label="Wishlist">
            ${uiIcon("heart")}<span class="shell-action-label">Wishlist</span>
            <span class="badge" id="wishlist-count">${wishlistCount}</span></a></li>
          ${notificationBell}
          <li>${accountMenu}</li>
          <li><a class="shell-action shell-cart" href="cart.html"${current("cart.html")} aria-label="Cart">
            ${uiIcon("cart")}<span class="shell-action-label">Cart</span>
            <span class="badge" id="cart-count">${cartCount}</span></a></li>
        </ul>
      </nav>

      <div class="mega-bar">
        <nav class="aisles" aria-label="Departments">
          <a class="aisle aisle-tool" href="build.html"${current("build.html")}>Build a PC</a>
          <a class="aisle aisle-tool" href="prebuilt.html"${current("prebuilt.html")}>Prebuilt PCs</a>
          <button class="mega-tab aisle-tool" id="tab-asus" type="button" aria-expanded="false"
                  aria-controls="mega-asus"${["asus.html", "asus-agent.html"].includes(here) ? ' data-current="true"' : ""}
                  onclick="toggleMegaMenu('asus')">Powered by ASUS ${uiIcon("chevron")}</button>
          <a class="aisle aisle-tool aisle-deals" href="deals.html"${current("deals.html")}>${uiIcon("tag")}Deals</a>
          <span class="aisle-rule" aria-hidden="true"></span>
          ${HEADER_AISLES.map((a) => `
            <a class="aisle" href="${a.href}"
               data-mega-kind="category" data-mega-value="${escapeHtml(a.label)}">${escapeHtml(a.label)}</a>`).join("")}
          <button class="mega-tab" id="tab-categories" type="button" aria-expanded="false"
                  onclick="toggleMegaMenu('categories')">All categories ${uiIcon("chevron")}</button>
          <button class="mega-tab" id="tab-brands" type="button" aria-expanded="false"
                  onclick="toggleMegaMenu('brands')">Brands ${uiIcon("chevron")}</button>
        </nav>
      </div>
    </div>

    <div class="mega-menu" id="mega-brands">${buildBrandsMenu()}</div>
    <div class="mega-menu" id="mega-categories">${buildCategoriesMenu()}</div>
    <div class="mega-menu mega-menu-asus" id="mega-asus">${buildAsusMenu()}</div>
  `;

  // If the page loaded with ?search=..., push it into the search box.
  const params = new URLSearchParams(window.location.search);
  const searchBox = document.getElementById("global-search");
  if (searchBox && params.get("search")) {
    searchBox.value = params.get("search");
  }

  // An empty search goes nowhere rather than to an unfiltered shop.
  header.querySelector(".search").addEventListener("submit", (e) => {
    if (!searchBox.value.trim()) e.preventDefault();
  });

  wireMegaItems(header);
  wireMegaHover(header);
}

// The two ASUS pages, which replaced "Workshop rigs" in the strip on
// 27 Oct after an ASUS supplier's review. The rigs page itself still
// works -- customers' submitted builds and the staff showcase queue are
// untouched -- and the Powered by ASUS page links to it.
function buildAsusMenu() {
  const items = [
    { href: "asus.html", icon: "computer", label: "Powered by ASUS",
      note: "Our own PCs built on ASUS boards, cards, power and cooling" },
    { href: "asus-agent.html", icon: "cpu", label: "ASUS Agent Computer",
      note: "PCs for running AI models on your own machine" },
  ];
  return `
    <div class="mega-inner">
      <div class="mega-grid mega-grid-asus">
        ${items.map((i) => `
          <a class="mega-item mega-item-rich" href="${i.href}">
            <span class="mega-icon">${categoryIcon(i.icon)}</span>
            <span class="mega-text">
              <span class="mega-label">${escapeHtml(i.label)}</span>
              <span class="mega-note">${escapeHtml(i.note)}</span>
            </span>
          </a>`).join("")}
      </div>
    </div>`;
}

// On a mouse, the ASUS menu also opens on hover, the way a shop's menu
// is expected to. Touch has no hover, so there it is the tap alone --
// nothing depends on hovering. A short delay on leaving lets the pointer
// cross the gap from the tab into the panel.
function wireMegaHover(root) {
  if (!window.matchMedia || !window.matchMedia("(hover: hover) and (pointer: fine)").matches) return;
  const tab = root.querySelector("#tab-asus");
  const panel = root.querySelector("#mega-asus");
  if (!tab || !panel) return;
  let leaveTimer = null;
  const open = () => {
    clearTimeout(leaveTimer);
    if (panel.classList.contains("open")) return;
    toggleMegaMenu("asus");
    // The click that usually follows a hover must not shut what the
    // hover has just opened.
    panel.dataset.hoverOpenedAt = String(Date.now());
  };
  const leave = () => {
    clearTimeout(leaveTimer);
    leaveTimer = setTimeout(() => {
      if (panel.classList.contains("open") && !panel.contains(document.activeElement)) closeMegaMenus();
    }, 220);
  };
  [tab, panel].forEach((el) => {
    el.addEventListener("mouseenter", open);
    el.addEventListener("mouseleave", leave);
  });
}

// The tiles are ordinary links to shop.html?category=... and they stay
// ordinary links: on the home page, the cart, anywhere that is not the
// shop, clicking one navigates as it always did.
//
// On the shop page itself that navigation was a page load to change
// which subset of an already-loaded array gets drawn. shop.js defines
// applyMegaFilter, nothing else does, so its presence is the test for
// "we are already where this link points" -- and there the click filters
// the grid in place and scrolls to it.
function wireMegaItems(root) {
  root.querySelectorAll(".mega-item[data-mega-kind], .aisle[data-mega-kind]").forEach((item) => {
    item.addEventListener("click", (e) => {
      if (typeof applyMegaFilter !== "function") return;
      // Leave the modified clicks alone -- ctrl/cmd-click and middle-click
      // mean "open this somewhere else", and they still can.
      if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;

      e.preventDefault();
      closeMegaMenus();
      applyMegaFilter(item.dataset.megaKind, item.dataset.megaValue);
    });
  });
}

// ---------- Mega menus (Brands / Categories) ----------

// Every brand we stock, taken straight from the product list so the menu
// updates itself whenever products are added.
function getAllBrands() {
  const brands = [];
  products.forEach((p) => {
    if (!brands.includes(p.brand)) brands.push(p.brand);
  });
  return brands.sort();
}

// One tile per brand: its logo with the name beneath, or the name alone
// for a brand we have no proper logo for.
function buildBrandsMenu() {
  const brands = getAllBrands();

  return `
    <div class="mega-inner">
      <div class="mega-grid">
        ${brands.map((brand) => `
          <a class="mega-item mega-brand${brandLogos[brand] ? " has-logo" : ""}"
             href="shop.html?brand=${encodeURIComponent(brand)}"
             data-mega-kind="brand" data-mega-value="${escapeHtml(brand)}">
            ${brandLogoTag(brand, "mega-brand-logo")}
            <span class="mega-logo">${escapeHtml(brand)}</span>
          </a>
        `).join("")}
      </div>
    </div>
  `;
}

// ------------------------------------------------------------
// Category icons.
//
// Line icons, drawn in currentColor so they take the colour of whatever
// they sit in. Used by the Categories menu and by the upgrade tiles on a
// prebuilt machine's page. They replaced emoji, which every phone and computer
// draws differently. Most are from Lucide (lucide.dev, ISC licence),
// copied in because the site's Content-Security-Policy allows no
// outside files; "monitor-arm" and "all-in-one" are drawn here in the
// same 24x24, 2px-stroke style because Lucide has nothing close.
// ------------------------------------------------------------
const CATEGORY_ICONS = {
  "puzzle": '<path d="M15.39 4.39a1 1 0 0 0 1.68-.474 2.5 2.5 0 1 1 3.014 3.015 1 1 0 0 0-.474 1.68l1.683 1.682a2.414 2.414 0 0 1 0 3.414L19.61 15.39a1 1 0 0 1-1.68-.474 2.5 2.5 0 1 0-3.014 3.015 1 1 0 0 1 .474 1.68l-1.683 1.682a2.414 2.414 0 0 1-3.414 0L8.61 19.61a1 1 0 0 0-1.68.474 2.5 2.5 0 1 1-3.014-3.015 1 1 0 0 0 .474-1.68l-1.683-1.682a2.414 2.414 0 0 1 0-3.414L4.39 8.61a1 1 0 0 1 1.68.474 2.5 2.5 0 1 0 3.014-3.015 1 1 0 0 1-.474-1.68l1.683-1.682a2.414 2.414 0 0 1 3.414 0z"/>',
  "fan": '<path d="M10.827 16.379a6.082 6.082 0 0 1-8.618-7.002l5.412 1.45a6.082 6.082 0 0 1 7.002-8.618l-1.45 5.412a6.082 6.082 0 0 1 8.618 7.002l-5.412-1.45a6.082 6.082 0 0 1-7.002 8.618l1.45-5.412Z"/><path d="M12 12v.01"/>',
  "cable": '<path d="M17 19a1 1 0 0 1-1-1v-2a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2a1 1 0 0 1-1 1z"/><path d="M17 21v-2"/><path d="M19 14V6.5a1 1 0 0 0-7 0v11a1 1 0 0 1-7 0V10"/><path d="M21 21v-2"/><path d="M3 5V3"/><path d="M4 10a2 2 0 0 1-2-2V6a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2a2 2 0 0 1-2 2z"/><path d="M7 5V3"/>',
  "printer": '<path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><path d="M6 9V3a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v6"/><rect x="6" y="14" width="12" height="8" rx="1"/>',
  "monitor": '<rect width="20" height="14" x="2" y="3" rx="2"/><line x1="8" x2="16" y1="21" y2="21"/><line x1="12" x2="12" y1="17" y2="21"/>',
  "projector": '<path d="M5 7 3 5"/><path d="M9 6V3"/><path d="m13 7 2-2"/><circle cx="9" cy="13" r="3"/><path d="M11.83 12H20a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2h2.17"/><path d="M16 16h2"/>',
  "router": '<rect width="20" height="8" x="2" y="14" rx="2"/><path d="M6.01 18H6"/><path d="M10.01 18H10"/><path d="M15 10v4"/><path d="M17.84 7.17a4 4 0 0 0-5.66 0"/><path d="M20.66 4.34a8 8 0 0 0-11.31 0"/>',
  "file-text": '<path d="M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z"/><path d="M14 2v5a1 1 0 0 0 1 1h5"/><path d="M10 9H8"/><path d="M16 13H8"/><path d="M16 17H8"/>',
  "laptop": '<path d="M18 5a2 2 0 0 1 2 2v8.526a2 2 0 0 0 .212.897l1.068 2.127a1 1 0 0 1-.9 1.45H3.62a1 1 0 0 1-.9-1.45l1.068-2.127A2 2 0 0 0 4 15.526V7a2 2 0 0 1 2-2z"/><path d="M20.054 15.987H3.946"/>',
  "computer": '<path d="M12 18h6"/><path d="M6 18h.01"/><path d="M8 6h1"/><rect x="2" y="14" width="20" height="8" rx="2"/><rect x="4" y="2" width="16" height="12" rx="2"/>',
  "gamepad": '<line x1="6" x2="10" y1="11" y2="11"/><line x1="8" x2="8" y1="9" y2="13"/><line x1="15" x2="15.01" y1="12" y2="12"/><line x1="18" x2="18.01" y1="10" y2="10"/><path d="M17.32 5H6.68a4 4 0 0 0-3.978 3.59c-.006.052-.01.101-.017.152C2.604 9.416 2 14.456 2 16a3 3 0 0 0 3 3c1 0 1.5-.5 2-1l1.414-1.414A2 2 0 0 1 9.828 16h4.344a2 2 0 0 1 1.414.586L17 18c.5.5 1 1 2 1a3 3 0 0 0 3-3c0-1.545-.604-6.584-.685-7.258-.007-.05-.011-.1-.017-.151A4 4 0 0 0 17.32 5z"/>',
  "cpu": '<path d="M12 20v2"/><path d="M12 2v2"/><path d="M17 20v2"/><path d="M17 2v2"/><path d="M2 12h2"/><path d="M2 17h2"/><path d="M2 7h2"/><path d="M20 12h2"/><path d="M20 17h2"/><path d="M20 7h2"/><path d="M7 20v2"/><path d="M7 2v2"/><rect x="4" y="4" width="16" height="16" rx="2"/><rect x="8" y="8" width="8" height="8" rx="1"/>',
  "cooler": '<path d="m10 20-1.25-2.5L6 18"/><path d="M10 4 8.75 6.5 6 6"/><path d="M10.585 15H10"/><path d="M2 12h6.5L10 9"/><path d="M20 14.54a4 4 0 1 1-4 0V4a2 2 0 0 1 4 0z"/><path d="m4 10 1.5 2L4 14"/><path d="m7 21 3-6-1.5-3"/><path d="m7 3 3 6h2"/>',
  "motherboard": '<rect width="18" height="18" x="3" y="3" rx="2"/><path d="M11 9h4a2 2 0 0 0 2-2V3"/><circle cx="9" cy="9" r="2"/><path d="M7 21v-4a2 2 0 0 1 2-2h4"/><circle cx="15" cy="15" r="2"/>',
  "ram": '<path d="M12 12v-2"/><path d="M12 18v-2"/><path d="M16 12v-2"/><path d="M16 18v-2"/><path d="M2 11h1.5"/><path d="M20 18v-2"/><path d="M20.5 11H22"/><path d="M4 18v-2"/><path d="M8 12v-2"/><path d="M8 18v-2"/><rect x="2" y="6" width="20" height="10" rx="2"/>',
  "gpu": '<path d="M2 17h18a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2H2"/><path d="M2 21V3"/><path d="M7 17v3a1 1 0 0 0 1 1h5a1 1 0 0 0 1-1v-3"/><circle cx="16" cy="11" r="2"/><circle cx="8" cy="11" r="2"/>',
  "storage": '<path d="M10 16h.01"/><path d="M2.212 11.577a2 2 0 0 0-.212.896V18a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-5.527a2 2 0 0 0-.212-.896L18.55 5.11A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/><path d="M21.946 12.013H2.054"/><path d="M6 16h.01"/>',
  "psu": '<path d="M6.3 20.3a2.4 2.4 0 0 0 3.4 0L12 18l-6-6-2.3 2.3a2.4 2.4 0 0 0 0 3.4Z"/><path d="m2 22 3-3"/><path d="M7.5 13.5 10 11"/><path d="M10.5 16.5 13 14"/><path d="m18 3-4 4h6l-4 4"/>',
  "case": '<rect width="14" height="20" x="5" y="2" rx="2"/><path d="M15 14h.01"/><path d="M9 6h6"/><path d="M9 10h6"/>',
  "keyboard": '<path d="M10 8h.01"/><path d="M12 12h.01"/><path d="M14 8h.01"/><path d="M16 12h.01"/><path d="M18 8h.01"/><path d="M6 8h.01"/><path d="M7 16h10"/><path d="M8 12h.01"/><rect width="20" height="16" x="2" y="4" rx="2"/>',
  "speaker": '<rect width="16" height="20" x="4" y="2" rx="2"/><path d="M12 6h.01"/><circle cx="12" cy="14" r="4"/><path d="M12 14h.01"/>',
  "webcam": '<circle cx="12" cy="10" r="8"/><circle cx="12" cy="10" r="3"/><path d="M7 22h10"/><path d="M12 22v-4"/>',
  "monitor-arm": '<rect x="10" y="3" width="12" height="8" rx="1.5"/><path d="M13 11 6 13l2.5 6"/><circle cx="6" cy="13" r="1"/><path d="M4 21h9"/><path d="M8.5 19v2"/>',
  "all-in-one": '<rect x="2" y="3" width="20" height="14" rx="2"/><path d="M2 13h20"/><path d="M12 17v4"/><path d="M8 21h8"/>',
};

function categoryIcon(key) {
  return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
    stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${CATEGORY_ICONS[key] || ""}</svg>`;
}

function buildCategoriesMenu() {
  // Main categories, then the component sub-types, each with an icon
  // from CATEGORY_ICONS above.
  const mainCategories = [
    { name: "Components", icon: "puzzle" },
    { name: "Case Fans", icon: "fan" },
    { name: "Accessories", icon: "cable" },
    { name: "Printers", icon: "printer" },
    { name: "Monitors", icon: "monitor" },
    { name: "Projectors", icon: "projector" },
    { name: "Monitor Arms", icon: "monitor-arm" },
    { name: "Networking", icon: "router" },
    { name: "Consumables", icon: "file-text" },
    { name: "Laptops", icon: "laptop" },
    { name: "Branded PC", icon: "computer" },
    { name: "All-in-One PC", icon: "all-in-one" },
    { name: "Gaming Gear", icon: "gamepad" },
    { name: "Webcams", icon: "webcam" },
  ];

  const subCategories = [
    { name: "CPU", icon: "cpu" },
    { name: "Cooler", icon: "cooler" },
    { name: "Motherboard", icon: "motherboard" },
    { name: "RAM", icon: "ram" },
    { name: "GPU", icon: "gpu" },
    { name: "Storage", icon: "storage" },
    { name: "PSU", icon: "psu" },
    { name: "Case", icon: "case" },
  ];

  return `
    <div class="mega-inner">
      <div class="mega-grid">
        ${mainCategories.map((c) => `
          <a class="mega-item" href="shop.html?category=${encodeURIComponent(c.name)}"
             data-mega-kind="category" data-mega-value="${escapeHtml(c.name)}">
            <span class="mega-icon">${categoryIcon(c.icon)}</span>
            <span class="mega-label">${escapeHtml(c.name)}</span>
          </a>
        `).join("")}
        ${subCategories.map((c) => `
          <a class="mega-item" href="shop.html?subcategory=${encodeURIComponent(c.name)}"
             data-mega-kind="subcategory" data-mega-value="${escapeHtml(c.name)}">
            <span class="mega-icon">${categoryIcon(c.icon)}</span>
            <span class="mega-label">${escapeHtml(c.name)}</span>
          </a>
        `).join("")}
      </div>
    </div>
  `;
}

// Opens the clicked menu and closes the others. Clicking the same tab
// again closes it.
const MEGA_MENUS = ["brands", "categories", "asus"];

function toggleMegaMenu(which) {
  const panel = document.getElementById("mega-" + which);
  const tab = document.getElementById("tab-" + which);
  if (!panel || !tab) return;
  if (panel.classList.contains("open") &&
      Date.now() - Number(panel.dataset.hoverOpenedAt || 0) < 600) return;

  MEGA_MENUS.filter((m) => m !== which).forEach((other) => {
    document.getElementById("mega-" + other)?.classList.remove("open");
    const otherTab = document.getElementById("tab-" + other);
    if (otherTab) {
      otherTab.classList.remove("active");
      otherTab.setAttribute("aria-expanded", "false");
    }
  });

  panel.classList.toggle("open");
  tab.classList.toggle("active");
  tab.setAttribute("aria-expanded", String(panel.classList.contains("open")));
}

// The keyboard: Escape closes whichever menu is open and puts focus back
// on its tab; the down arrow on an open tab moves into its first item,
// and up/down then walk the items.
document.addEventListener("keydown", (e) => {
  const open = document.querySelector(".mega-menu.open");
  if (!open) return;
  const tab = document.getElementById(open.id.replace("mega-", "tab-"));
  const items = [...open.querySelectorAll("a.mega-item")];

  if (e.key === "Escape") {
    closeMegaMenus();
    tab?.focus();
    return;
  }
  if (e.key !== "ArrowDown" && e.key !== "ArrowUp") return;
  const at = items.indexOf(document.activeElement);
  if (document.activeElement !== tab && at === -1) return;
  e.preventDefault();
  const next = e.key === "ArrowDown"
    ? items[Math.min(at + 1, items.length - 1)]
    : at <= 0 ? tab : items[at - 1];
  next?.focus();
});

function closeMegaMenus() {
  document.querySelectorAll(".mega-menu.open").forEach((m) => m.classList.remove("open"));
  document.querySelectorAll(".mega-tab.active").forEach((t) => {
    t.classList.remove("active");
    t.setAttribute("aria-expanded", "false");
  });
}

// Clicking anywhere outside the menus closes them.
document.addEventListener("click", (e) => {
  if (!e.target || !e.target.closest) return;
  if (e.target.closest(".mega-tab") || e.target.closest(".mega-menu")) return;
  closeMegaMenus();
});

function injectFooter() {
  const footer = document.getElementById("site-footer");
  if (!footer) return;

  footer.innerHTML = `
    <footer class="site-foot">
      <div class="site-foot-inner">
        <div class="site-foot-brand">
          <img class="logo-img" src="images/brand/etech-logo-96.png" width="44" height="44" alt="" />
          <span class="logo-mark">eTech</span>
          <p>Computer Accessories &middot; Malaysia</p>
        </div>
        <nav class="footer-links" aria-label="Shop information">
          <a href="info.html">Information</a>
          <a href="service.html">Service</a>
          <a href="contact.html">Contact</a>
          ${typeof whatsappShopLink === "function"
            ? `<a href="${whatsappShopLink("Hi, I have a question about a product on eTech.")}"
                  target="_blank" rel="noopener">WhatsApp us</a>`
            : ""}
          <a href="privacy.html">Privacy</a>
        </nav>
        <p class="site-foot-note">&copy; 2026 eTech Computer Accessories. Prices in RM.</p>
      </div>
    </footer>
  `;
}

// ------------------------------------------------------------
// Telling people the site is recording what they do.
//
// The shop records every product opened, every search typed and every
// chatbot question, and does so whether or not anyone is signed in --
// that record is the subject of the project, not a side effect of it.
// Collecting it from real testers without telling them is the kind of
// thing that is noticed at the wrong end of a project, and under the
// PDPA notice is owed at the point of collection rather than in a page
// nobody was pointed at.
//
// So this is shown once, on the first page anyone lands on, and
// dismissed for good afterwards. It is a notice and not a wall: the shop
// is usable behind it, because a banner that blocks the page teaches
// people to click it away without reading, which is worse than useless
// for consent.
//
// The acknowledgement is kept in this browser only. It is not a database
// record of consent -- if the project later needs to evidence consent per
// participant, that belongs with the account, not here.
// ------------------------------------------------------------
const PRIVACY_NOTICE_KEY = "etech_privacy_ack";

function injectPrivacyNotice() {
  try {
    if (localStorage.getItem(PRIVACY_NOTICE_KEY)) return;
  } catch (e) {
    // Storage blocked. Showing it every visit is the safe way round.
  }

  const bar = document.createElement("div");
  bar.className = "privacy-notice";
  bar.innerHTML = `
    <p>
      This is a student project, and it records which products you open, what
      you search for and what you ask the chatbot &mdash; that record is what
      the project studies. No order is really fulfilled and there is nothing to pay:
      the payment details at the checkout are placeholders, not a real account.
      <a href="privacy.html">Read the privacy policy</a>.
    </p>
    <button type="button" class="privacy-notice-ok">I understand</button>
  `;

  // Toasts -- "added to cart", and the order messages from
  // notifications.js -- rise from the same edge the bar sits on, and the
  // bar is higher in the stack. They read this to stop above it instead
  // of arriving and leaving unseen behind it. Measured rather than a
  // constant, because the height depends on how the text wraps: on a
  // 400px phone it is 164px, taller than the whole distance a toast rises.
  const measureBar = () =>
    document.body.style.setProperty("--privacy-notice-h", `${bar.offsetHeight}px`);

  bar.querySelector(".privacy-notice-ok").addEventListener("click", () => {
    try { localStorage.setItem(PRIVACY_NOTICE_KEY, "1"); } catch (e) { /* fine */ }
    bar.remove();
    document.body.classList.remove("privacy-notice-open");
    window.removeEventListener("resize", measureBar);
  });

  document.body.appendChild(bar);
  // The bar is fixed and covers the foot of the page. The class reserves
  // the same height at the end of the body so the last row of whatever
  // is on screen can still be scrolled out from under it.
  document.body.classList.add("privacy-notice-open");
  measureBar();
  window.addEventListener("resize", measureBar);
}

// eTech AI, the build consultant, in the bottom-right corner of every
// page. Until 27 Oct that corner held a green "Contact us" WhatsApp
// button and eTech AI sat bottom left; the ASUS supplier's review asked
// for the green block to go and the consultant to move right. WhatsApp
// is still one tap away: the footer, the builder's "Ask us on WhatsApp"
// and the checkout all carry the link (js/whatsapp.js).
function injectChatbot() {
  const wrapper = document.createElement("div");
  wrapper.className = "chatbot-wrapper";
  wrapper.innerHTML = `
    <button type="button" class="chatbot-toggle" aria-controls="chatbot-panel" aria-expanded="false"
      onclick="toggleChatbot()">${uiIcon("sparkle")}<span>eTech AI</span></button>
    <div class="chatbot-panel" id="chatbot-panel" role="dialog" aria-label="eTech AI build consultant">
      <div class="chatbot-header"><span>eTech AI <small>Build consultant</small></span>
        <button type="button" class="chatbot-close" aria-label="Close"
          onclick="toggleChatbot(false)">${uiIcon("close")}</button>
      </div>
      <div class="chat-log" id="chat-log">
        <div class="chat-bubble bot">Hi! Tell me what the PC is for and your budget and I'll spec the whole
          thing out — try <em>"build a pc for CS2, full HD, budget 4k"</em>.</div>
      </div>
      <div class="chat-input-row">
        <input type="text" id="chat-input" placeholder="Ask a question..."
          onkeyup="if(event.key==='Enter') sendChatMessage();" />
        <button onclick="sendChatMessage()">Send</button>
      </div>
    </div>
  `;
  document.body.appendChild(wrapper);
}

// Opens or closes the consultant; with no argument, flips it.
function toggleChatbot(open) {
  const panel = document.getElementById("chatbot-panel");
  if (!panel) return;
  const now = panel.classList.toggle("open", open);
  const toggle = document.querySelector(".chatbot-toggle");
  if (toggle) toggle.setAttribute("aria-expanded", String(now));
  if (now) document.getElementById("chat-input")?.focus();
}

// A short message that rises from the foot of the page and leaves on its
// own. For confirmations ("added to cart") that should not stop the
// customer the way alert() does. Errors still use alert(): those need
// reading.
function showToast(html, ms) {
  document.querySelectorAll(".toast.shop-toast").forEach((t) => t.remove());
  const toast = document.createElement("div");
  toast.className = "toast shop-toast";
  toast.setAttribute("role", "status");
  toast.innerHTML = html;
  document.body.appendChild(toast);
  requestAnimationFrame(() => requestAnimationFrame(() => toast.classList.add("show")));
  setTimeout(() => {
    toast.classList.remove("show");
    setTimeout(() => toast.remove(), 400);
  }, ms || 3800);
}

// Shows a one-off toast if there's a live deal in the category the user has
// been browsing the most (based on tracking.js history).
function maybeShowDealToast() {
  if (typeof getTopCategory !== "function" || typeof getDealForCategory !== "function") return;
  if (sessionStorage.getItem("dealToastShown")) return;

  const category = getTopCategory();
  if (!category) return;

  const deal = getDealForCategory(category);
  if (!deal) return;

  sessionStorage.setItem("dealToastShown", "1");

  const toast = document.createElement("div");
  toast.className = "toast";
  toast.innerHTML = `${uiIcon("tag")} ${deal.discountPercent}% off ${escapeHtml(deal.category)} right now! Code <strong>${escapeHtml(deal.code)}</strong>
    <a href="deals.html">View deal</a>`;
  document.body.appendChild(toast);

  setTimeout(() => toast.classList.add("show"), 100);
  setTimeout(() => toast.remove(), 8000);
}

onAppReady(() => {
  injectHeader();
  injectFooter();
  injectChatbot();
  injectPrivacyNotice();
  // The deal notification is fired by deals.js once the promotions have
  // been fetched — it can't run until we know what's on offer.
});
