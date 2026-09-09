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
  const compareCount = typeof getCompareList === "function" ? getCompareList().length : 0;

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

  header.innerHTML = `
    <nav class="navbar">
      <a href="index.html" class="logo">e<span>Tech</span> <small>Computer Accessories</small></a>

      <input type="text" id="global-search" class="search-box" placeholder="Search products or brands..."
        onkeyup="if(event.key==='Enter'){ window.location.href='shop.html?search=' + encodeURIComponent(this.value); }" />

      <ul class="nav-links">
        <li><a href="shop.html">Shop</a></li>
        <li><a href="build.html">Build PC</a></li>
        <li><a href="prebuilt.html">Prebuilt</a></li>
        <li><a href="deals.html">Deals</a></li>
        <li><a href="rigs.html">Rigs</a></li>
        <li><a href="compare.html">Compare <span class="badge">${compareCount}</span></a></li>
        <li><a href="wishlist.html">Wishlist <span class="badge" id="wishlist-count">${wishlistCount}</span></a></li>
        <li><a href="cart.html">Cart <span class="badge" id="cart-count">${cartCount}</span></a></li>
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

// The icons are written as the characters themselves, not as "&#129513;"
// entities. They were entities once and printed on the page as the literal
// code, because everything that goes into a tile is put through
// escapeHtml() on the way -- which is right, and stays -- and escaping an
// entity turns its ampersand into &amp; so the browser has nothing left to
// decode. A character needs no decoding, so escaping it changes nothing and
// the icon survives the trip. This file already writes 💬 and 🤖 the same way.
function buildCategoriesMenu() {
  // Main categories, then the component sub-types, each with a small icon.
  const mainCategories = [
    { name: "Components", icon: "🧩" },
    { name: "Case Fans", icon: "🌬️" },
    { name: "Accessories", icon: "🔌" },
    { name: "Printers", icon: "🖨️" },
    { name: "Monitors", icon: "🖥️" },
    { name: "Projectors", icon: "📽️" },
    { name: "Monitor Arms", icon: "🦾" },
    { name: "Networking", icon: "📶" },
    { name: "Consumables", icon: "📄" },
    { name: "Laptops", icon: "💻" },
    { name: "Gaming Gear", icon: "🎮" },
  ];

  const subCategories = [
    { name: "CPU", icon: "🧠" },
    { name: "Cooler", icon: "🌀" },
    { name: "Motherboard", icon: "🔌" },
    { name: "RAM", icon: "💾" },
    { name: "GPU", icon: "🎮" },
    { name: "Storage", icon: "💽" },
    { name: "PSU", icon: "🔋" },
    { name: "Case", icon: "🖥️" },
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
            <span class="mega-icon">${escapeHtml(c.icon)}</span>
            <span class="mega-label">${escapeHtml(c.name.toUpperCase())}</span>
          </a>
        `).join("")}
        ${subCategories.map((c) => `
          <a class="mega-item" href="shop.html?subcategory=${encodeURIComponent(c.name)}"
             data-mega-kind="subcategory" data-mega-value="${escapeHtml(c.name)}">
            <span class="mega-icon">${escapeHtml(c.icon)}</span>
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
      the project studies. No goods are shipped and there is nothing to pay:
      the payment details at the checkout are placeholders, not a real account.
      <a href="privacy.html">Read the privacy notice</a>.
    </p>
    <button type="button" class="privacy-notice-ok">I understand</button>
  `;

  bar.querySelector(".privacy-notice-ok").addEventListener("click", () => {
    try { localStorage.setItem(PRIVACY_NOTICE_KEY, "1"); } catch (e) { /* fine */ }
    bar.remove();
    document.body.classList.remove("privacy-notice-open");
  });

  document.body.appendChild(bar);
  // The bar is fixed and covers the foot of the page. The class reserves
  // the same height at the end of the body so the last row of whatever
  // is on screen can still be scrolled out from under it.
  document.body.classList.add("privacy-notice-open");
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
      <div class="chatbot-header">AI Hardware Consultant (demo)</div>
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
