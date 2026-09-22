// Builds the navbar, footer, floating WhatsApp button, chatbot widget and
// the "deal for you" notification toast, and drops them into every page.
// Each page just needs empty <div id="site-header"></div> and
// <div id="site-footer"></div> placeholders — this file fills them in,
// so the navbar only has to be edited in one place.

function injectHeader() {
  const header = document.getElementById("site-header");
  if (!header) return;

  const user = typeof getCurrentUser === "function" ? getCurrentUser() : null;
  const cartCount = typeof getCart === "function" ? getCart().reduce((s, i) => s + i.qty, 0) : 0;
  const wishlistCount = typeof getWishlist === "function" ? getWishlist().length : 0;

  const accountMenu = user
    ? `<div class="account-menu">
         <span>Hi, ${escapeHtml(user.name.split(" ")[0])}</span>
         <div class="account-dropdown">
           <a href="profile.html">Profile</a>
           <a href="orders.html">Order History</a>
           <a href="#" onclick="logoutUser(); return false;">Logout</a>
         </div>
       </div>`
    : `<a href="login.html">Login</a> / <a href="register.html">Register</a>`;

  // Messages about the customer's orders -- see js/notifications.js,
  // which fills the list and the count once the header is on the page.
  // Only drawn where that file is loaded, so a page without it never
  // shows a bell that does nothing.
  const notificationBell = user && typeof startNotifications === "function"
    ? `<li class="notif-menu" id="notif-menu">
         <button type="button" class="notif-bell" id="notif-bell"
                 aria-label="Notifications" aria-haspopup="true" aria-expanded="false">
           🔔<span class="badge" id="notif-count" hidden>0</span>
         </button>
         <div class="notif-panel" id="notif-panel" hidden>
           <div class="notif-head">Notifications</div>
           <div class="notif-list" id="notif-list"></div>
         </div>
       </li>`
    : "";

  header.innerHTML = `
    <nav class="navbar">
      <a href="index.html" class="logo">e<span>Tech</span> <small>Computer Accessories</small></a>

      <input type="text" id="global-search" class="search-box" placeholder="Search products or brands..."
        onkeyup="if(event.key==='Enter'){ window.location.href='shop.html?search=' + encodeURIComponent(this.value); }" />

      <ul class="nav-links">
        <li><a href="build.html">Build PC</a></li>
        <li><a href="prebuilt.html">Prebuilt</a></li>
        <li><a href="deals.html">Deals</a></li>
        <li><a href="rigs.html">Rigs</a></li>
        <li><a href="wishlist.html">Wishlist <span class="badge" id="wishlist-count">${wishlistCount}</span></a></li>
        <li><a href="cart.html">Cart <span class="badge" id="cart-count">${cartCount}</span></a></li>
        ${notificationBell}
        <li>${accountMenu}</li>
      </ul>
    </nav>

    <!-- Second bar: the two mega-menu buttons (Brands / Categories) -->
    <div class="mega-bar">
      <button class="mega-tab" id="tab-brands" onclick="toggleMegaMenu('brands')">&#9776; BRANDS</button>
      <button class="mega-tab" id="tab-categories" onclick="toggleMegaMenu('categories')">&#9776; CATEGORIES</button>
    </div>

    <div class="mega-menu" id="mega-brands">${buildBrandsMenu()}</div>
    <div class="mega-menu" id="mega-categories">${buildCategoriesMenu()}</div>
  `;

  // If the page loaded with ?search=..., push it into the search box.
  const params = new URLSearchParams(window.location.search);
  const searchBox = document.getElementById("global-search");
  if (searchBox && params.get("search")) {
    searchBox.value = params.get("search");
  }

  wireMegaItems(header);
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
  root.querySelectorAll(".mega-item[data-mega-kind]").forEach((item) => {
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

// One name per tile. There used to be a second span beneath it repeating
// the same brand in capitals -- a caption that had lost its picture. The
// stylesheet already uppercases .mega-logo, so nothing was lost with it.
function buildBrandsMenu() {
  const brands = getAllBrands();

  return `
    <div class="mega-inner">
      <div class="mega-left">
        <h3>BRANDS</h3>
        <p>We will never stop exploring and expanding the brands we carry.
           Stay tuned with us for more exciting updates.</p>
        <hr />
        <span class="mega-tagline">PASSION DRIVEN</span>
      </div>
      <div class="mega-grid">
        ${brands.map((brand) => `
          <a class="mega-item" href="shop.html?brand=${encodeURIComponent(brand)}"
             data-mega-kind="brand" data-mega-value="${escapeHtml(brand)}">
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
      <div class="mega-left">
        <h3>CATEGORIES</h3>
        <p>You want it, we have it.</p>
        <hr />
        <span class="mega-tagline">PASSION CREATES</span>
      </div>
      <div class="mega-grid">
        ${mainCategories.map((c) => `
          <a class="mega-item" href="shop.html?category=${encodeURIComponent(c.name)}"
             data-mega-kind="category" data-mega-value="${escapeHtml(c.name)}">
            <span class="mega-icon">${categoryIcon(c.icon)}</span>
            <span class="mega-label">${escapeHtml(c.name.toUpperCase())}</span>
          </a>
        `).join("")}
        ${subCategories.map((c) => `
          <a class="mega-item" href="shop.html?subcategory=${encodeURIComponent(c.name)}"
             data-mega-kind="subcategory" data-mega-value="${escapeHtml(c.name)}">
            <span class="mega-icon">${categoryIcon(c.icon)}</span>
            <span class="mega-label">${escapeHtml(c.name.toUpperCase())}</span>
          </a>
        `).join("")}
      </div>
    </div>
  `;
}

// Opens the clicked menu and closes the other one. Clicking the same tab
// again closes it.
function toggleMegaMenu(which) {
  const panel = document.getElementById("mega-" + which);
  const tab = document.getElementById("tab-" + which);
  const other = which === "brands" ? "categories" : "brands";

  document.getElementById("mega-" + other).classList.remove("open");
  document.getElementById("tab-" + other).classList.remove("active");

  panel.classList.toggle("open");
  tab.classList.toggle("active");
}

function closeMegaMenus() {
  document.querySelectorAll(".mega-menu.open").forEach((m) => m.classList.remove("open"));
  document.querySelectorAll(".mega-tab.active").forEach((t) => t.classList.remove("active"));
}

// Clicking anywhere outside the menus closes them.
document.addEventListener("click", (e) => {
  if (!e.target || !e.target.closest) return;
  if (e.target.closest(".mega-bar") || e.target.closest(".mega-menu")) return;
  closeMegaMenus();
});

function injectFooter() {
  const footer = document.getElementById("site-footer");
  if (!footer) return;

  footer.innerHTML = `
    <footer>
      <div class="footer-links">
        <a href="info.html">Information</a>
        <a href="service.html">Service</a>
        <a href="contact.html">Contact</a>
        <a href="privacy.html">Privacy</a>
      </div>
      <p>&copy; 2026 eTech Computer Accessories.</p>
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
      <a href="privacy.html">Read the privacy notice</a>.
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

// The number itself moved to js/whatsapp.js when the staff console
// needed it too. This is still the only place the floating button is
// built; it just no longer owns the number.
function injectWhatsApp() {
  const btn = document.createElement("a");
  btn.className = "whatsapp-btn";
  btn.href = whatsappShopLink("Hi, I have a question about a product on eTech.");
  btn.target = "_blank";
  btn.rel = "noopener";
  btn.title = "Chat with us on WhatsApp";
  btn.textContent = "💬";
  document.body.appendChild(btn);
}

function injectChatbot() {
  const wrapper = document.createElement("div");
  wrapper.className = "chatbot-wrapper";
  wrapper.innerHTML = `
    <button class="chatbot-toggle" onclick="document.getElementById('chatbot-panel').classList.toggle('open')">🤖</button>
    <div class="chatbot-panel" id="chatbot-panel">
      <div class="chatbot-header">AI Hardware Consultant</div>
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
  toast.innerHTML = `🎉 ${deal.discountPercent}% off ${escapeHtml(deal.category)} right now! Code <strong>${escapeHtml(deal.code)}</strong>
    <a href="deals.html">View deal</a>`;
  document.body.appendChild(toast);

  setTimeout(() => toast.classList.add("show"), 100);
  setTimeout(() => toast.remove(), 8000);
}

onAppReady(() => {
  injectHeader();
  injectFooter();
  injectWhatsApp();
  injectChatbot();
  injectPrivacyNotice();
  // The deal notification is fired by deals.js once the promotions have
  // been fetched — it can't run until we know what's on offer.
});
