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
         <span>Hi, ${user.name.split(" ")[0]}</span>
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
          <a class="mega-item" href="shop.html?brand=${encodeURIComponent(brand)}">
            <span class="mega-logo">${brand}</span>
            <span class="mega-label">${brand.toUpperCase()}</span>
          </a>
        `).join("")}
      </div>
    </div>
  `;
}

function buildCategoriesMenu() {
  // Main categories, then the component sub-types, each with a small icon.
  const mainCategories = [
    { name: "Components", icon: "&#129513;" },
    { name: "Case Fans", icon: "&#127788;" },
    { name: "Accessories", icon: "&#128268;" },
    { name: "Printers", icon: "&#128424;" },
    { name: "Monitors", icon: "&#128421;" },
    { name: "Projectors", icon: "&#128253;" },
    { name: "Monitor Arms", icon: "&#129470;" },
    { name: "Networking", icon: "&#128246;" },
    { name: "Consumables", icon: "&#128196;" },
    { name: "Laptops", icon: "&#128187;" },
    { name: "Gaming Gear", icon: "&#127918;" },
  ];

  const subCategories = [
    { name: "CPU", icon: "&#129504;" },
    { name: "Cooler", icon: "&#127744;" },
    { name: "Motherboard", icon: "&#128268;" },
    { name: "RAM", icon: "&#128190;" },
    { name: "GPU", icon: "&#127918;" },
    { name: "Storage", icon: "&#128189;" },
    { name: "PSU", icon: "&#128267;" },
    { name: "Case", icon: "&#128421;" },
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
          <a class="mega-item" href="shop.html?category=${encodeURIComponent(c.name)}">
            <span class="mega-icon">${c.icon}</span>
            <span class="mega-label">${c.name.toUpperCase()}</span>
          </a>
        `).join("")}
        ${subCategories.map((c) => `
          <a class="mega-item" href="shop.html?subcategory=${encodeURIComponent(c.name)}">
            <span class="mega-icon">${c.icon}</span>
            <span class="mega-label">${c.name.toUpperCase()}</span>
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

// Clicking anywhere outside the menus closes them.
document.addEventListener("click", (e) => {
  if (!e.target || !e.target.closest) return;
  if (e.target.closest(".mega-bar") || e.target.closest(".mega-menu")) return;
  document.querySelectorAll(".mega-menu.open").forEach((m) => m.classList.remove("open"));
  document.querySelectorAll(".mega-tab.active").forEach((t) => t.classList.remove("active"));
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
      </div>
      <p>&copy; 2026 eTech Computer Accessories.</p>
    </footer>
  `;
}

// Our WhatsApp number. wa.me needs the international format with no
// "+", no dashes and no leading zero, so 011-1074 3634 becomes 601110743634
// (60 = Malaysia, then 11 10743634).
const WHATSAPP_NUMBER = "601110743634";

function injectWhatsApp() {
  const btn = document.createElement("a");
  btn.className = "whatsapp-btn";
  btn.href = "https://wa.me/" + WHATSAPP_NUMBER + "?text=" +
    encodeURIComponent("Hi, I have a question about a product on eTech.");
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
  toast.innerHTML = `🎉 ${deal.discountPercent}% off ${deal.category} right now! Code <strong>${deal.code}</strong>
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
  // The deal notification is fired by deals.js once the promotions have
  // been fetched — it can't run until we know what's on offer.
});
