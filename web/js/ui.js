// Shared helper for building a product card. Used by the home page,
// shop page, wishlist page, deals page, and search results so we don't
// repeat the same card HTML in five different files.

// Builds the <img> tag for a product.
// It first tries the real photo (images/101.jpg). If that file isn't there,
// the onerror handler swaps in the drawn illustration (images/cpu.svg).
// Setting this.onerror = null first stops it looping forever if the
// illustration is missing too.
function productImageTag(product, cssClass) {
  // The two URLs go through safeUrl and the name through escapeHtml.
  // image_path is typed into the admin panel, so it is a value from the
  // database sitting in a src attribute -- see js/escape.js.
  return `<img class="${cssClass}" src="${safeUrl(productImage(product))}" alt="${escapeHtml(product.name)}"
    onerror="this.onerror=null; this.src='${safeUrl(productImageFallback(product))}';" />`;
}

// ============================================================
// Prices, and the deal that may be on one.
//
// Every price the shop draws goes through here, so a struck-through
// RM1,499 and the RM1,249 beside it are two halves of one decision made
// in one place. The list price is kept in a data attribute rather than
// being recovered by arithmetic, because when the clock runs out the
// card has to put it back.
// ============================================================
// Thousands grouped (RM 2,899.00), so a column of prices reads at a glance.
function money(amount) {
  return "RM " + Number(amount).toLocaleString("en-MY", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

function priceBlockHtml(product, cssClass) {
  const deal = dealFor(product);

  if (!deal) {
    return `<p class="${cssClass}">${money(product.price)}</p>`;
  }

  return `
    <p class="${cssClass} on-deal" data-list-price="${product.price}">
      <span class="price-was">${money(product.price)}</span>
      <span class="price-now">${money(deal.price)}</span>
    </p>
    <p class="deal-countdown" data-deal-ends="${escapeHtml(deal.endsAt)}">
      <span class="deal-countdown-label">Ends in</span>
      <span class="deal-countdown-clock">${formatCountdown(dealTimeLeft(deal))}</span>
    </p>`;
}

// ------------------------------------------------------------
// One clock for the whole page.
//
// Every countdown on screen is the same second, so they are driven by a
// single interval rather than one per card -- a shop grid with forty
// deals on it would otherwise be forty timers all waking up to write
// the same number.
//
// When a deal runs out the card is corrected in place: the strikethrough
// goes, the list price comes back, and the countdown is removed. That is
// the visible half of "automatic expiration". The half that matters is
// in the database, which stops handing the deal out and stops charging
// it at the same instant, whether or not anybody's browser noticed.
// ------------------------------------------------------------
let dealTickerStarted = false;

function tickDealCountdowns() {
  document.querySelectorAll("[data-deal-ends]").forEach((el) => {
    const left = new Date(el.dataset.dealEnds).getTime() - Date.now();

    if (left > 0) {
      const clock = el.querySelector(".deal-countdown-clock");
      if (clock) clock.textContent = formatCountdown(left);
      return;
    }

    // Over. Put the card back the way it would have been drawn a second
    // later, without a round trip and without a reload.
    const container = el.parentElement;
    if (container) {
      container.querySelectorAll(".on-deal").forEach((priceEl) => {
        priceEl.classList.remove("on-deal");
        priceEl.textContent = money(priceEl.dataset.listPrice);
      });
    }
    el.remove();
  });
}

function startDealTicker() {
  if (dealTickerStarted) return;
  dealTickerStarted = true;
  tickDealCountdowns();
  setInterval(tickDealCountdowns, 1000);
}

// The colours a product can be bought in, when the shop stocks more
// than one side by side. Empty for everything else, which is what keeps
// the picker off every other product.
function colourOptionsOf(product) {
  const options = (product.attrs || {}).colourOption;
  return Array.isArray(options) ? options : [];
}

// What the choice is called. A board sold in one colour with a choice of
// switches (the G512 Carbon, the BlackWidow V3 TKL) asks for a switch.
function optionKindOf(options) {
  return options.length && options.every((o) => / Switch$/.test(o)) ? "Switch" : "Colour";
}

// The photo of one colour, by naming convention: 4504.webp is the main
// photo and 4504-green.webp the green one, side by side on the website.
// Null for a product whose photo is not one of ours, which has nowhere
// to look. A colour with no photo of its own 404s, and the modal falls
// back to the main photo.
function colourImageOf(product, colour) {
  const main = productImage(product);
  if (!colour || !/\/images\/products\/\d+\.webp$/.test(main)) return null;
  const slug = colour.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
  return slug ? main.replace(/\.webp$/, "-" + slug + ".webp") : null;
}

// The product's number in the shop's catalogue. It is the same number on
// the card, in the product view and on the customer's order, so a
// customer reading one out over WhatsApp is understood.
function productCode(product) {
  return "Item " + product.id;
}

// One order line: "2x  AMD Ryzen 5 7500F  Item 2104  RM 1,298.00".
// The till, the cart and the checkout summary all print through this,
// so a line reads the same wherever the customer meets it.
function receiptLineHtml(item, extraClass) {
  return `
    <li class="till-line${extraClass ? " " + extraClass : ""}">
      <span class="till-qty">${item.qty}&times;</span>
      <span class="till-name">${escapeHtml(item.name)}${
        item.colour ? ` <small>${escapeHtml(item.colour)}</small>` : ""}
        <span class="till-code">Item ${escapeHtml(String(item.id))}</span></span>
      <span class="till-leader" aria-hidden="true"></span>
      <span class="till-price${item.onDeal ? " on-deal" : ""}">${money(item.lineTotal)}</span>
    </li>`;
}

function heartIcon() {
  return typeof uiIcon === "function" ? uiIcon("heart") : "&#9825;";
}

function buildProductCard(product) {
  const card = document.createElement("article");
  card.className = "product-card";

  // stockOf, not product.stock: one of the shop's own builds is only
  // available when its parts are, and it must read the same here as it
  // does on the Prebuilt page. For everything else this is product.stock.
  const stock = stockOf(product);
  const stockClass = "stock-" + stock; // stock-in / stock-low / stock-out
  const heartFilled = typeof isInWishlist === "function" && isInWishlist(product.id);
  const outOfStock = stock === "out";
  const options = colourOptionsOf(product);

  // Category, name, item number, stock, then the price over a labelled
  // Add to cart. The whole card opens the product; only the heart and
  // the button do something else.
  card.innerHTML = `
    <button type="button" class="wishlist-btn ${heartFilled ? "active" : ""}"
      onclick="toggleWishlist(${product.id})"
      aria-pressed="${heartFilled}" aria-label="${heartFilled ? "Remove from" : "Save to"} wishlist">
      ${heartIcon()}
    </button>
    <div class="product-img-wrap">
      ${productImageTag(product, "product-img")}
    </div>
    <div class="product-card-body">
      <p class="product-category">${escapeHtml(product.subcategory || product.category || "")}</p>
      <h3><button type="button" class="product-card-open">${escapeHtml(product.name)}</button></h3>
      <p class="product-code">${escapeHtml(productCode(product))}</p>
      <p class="stock-badge ${stockClass}">${stockLabel(stock)}</p>
      <div class="product-card-buy">
        ${priceBlockHtml(product, "product-price")}
        <button type="button" class="card-add" ${outOfStock ? "disabled" : ""}
          aria-label="${outOfStock ? "Out of stock" : (options.length ? "Choose " + optionKindOf(options).toLowerCase() + " for " : "Add to cart: ") + escapeHtml(product.name)}"
          onclick="event.stopPropagation(); ${options.length ? `openProductModal(${product.id})` : `addToCart(${product.id})`}">
          ${outOfStock || typeof uiIcon !== "function" ? "" : uiIcon("cart")}<span>${outOfStock ? "Out of stock" : (options.length ? "Choose " + optionKindOf(options).toLowerCase() : "Add to cart")}</span>
        </button>
      </div>
    </div>
  `;

  card.addEventListener("click", (event) => {
    if (event.target.closest(".wishlist-btn, .card-add")) return;
    openProductModal(product.id);
  });

  return card;
}

// ============================================================
// The product detail view.
//
// The website has no product page and no router to add one to — every
// page is its own static HTML file, and the card has always carried the
// name, price, stock and Add to Cart button that a product page would.
// So the detail view is a modal, built once and reused, opened from any
// card on any page.
//
// It is also what makes a recorded view mean something. The app has
// always recorded a view when the product's own screen opened. The
// website recorded one when somebody clicked a picture that did
// nothing, which is a thing almost nobody had a reason to do — so the
// website's most abundant signal was, in practice, missing. Opening
// this is now the web's equivalent of opening that screen, and the
// event is recorded from here rather than from the card.
// ============================================================

let productModalEl = null;      // built on first open, then reused
let productModalReturnFocus = null;

function openProductModal(productId) {
  const product = getProductById(productId);
  if (!product) return;

  if (typeof trackProductClick === "function") trackProductClick(productId);

  if (!productModalEl) productModalEl = buildProductModalShell();

  productModalEl.querySelector(".product-modal").innerHTML =
    productModalContent(product);
  wireProductModalActions(product);

  // Remember what the shopper was on so Escape or Close puts them back
  // there, rather than at the top of the page.
  productModalReturnFocus = document.activeElement;
  productModalEl.classList.add("open");
  document.body.style.overflow = "hidden";   // don't scroll the page behind
  productModalEl.querySelector(".product-modal-close").focus();
}

function closeProductModal() {
  if (!productModalEl) return;
  productModalEl.classList.remove("open");
  document.body.style.overflow = "";
  if (productModalReturnFocus && productModalReturnFocus.focus) {
    productModalReturnFocus.focus();
  }
  productModalReturnFocus = null;
}

function buildProductModalShell() {
  const backdrop = document.createElement("div");
  backdrop.className = "product-modal-backdrop";
  backdrop.innerHTML = `<div class="product-modal" role="dialog" aria-modal="true"
    aria-label="Product details"></div>`;

  // Clicking the darkened area closes; clicking the card itself must not,
  // which is what the target check is for.
  backdrop.addEventListener("click", (event) => {
    if (event.target === backdrop) closeProductModal();
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") closeProductModal();
  });

  document.body.appendChild(backdrop);
  return backdrop;
}

function productModalContent(product) {
  const stock = stockOf(product);
  const outOfStock = stock === "out";
  const saved = typeof isInWishlist === "function" && isInWishlist(product.id);

  // The same label function the shop filters use, so a spec is never
  // named one thing here and another there.
  const specKeys = Object.keys(product.attrs || {});
  const specRows = specKeys.map((key) => {
    const value = product.attrs[key];
    return `<tr><th>${escapeHtml(attrLabel(key))}</th><td>${
      escapeHtml(Array.isArray(value) ? value.join(", ") : value)
    }</td></tr>`;
  }).join("");

  return `
    <div class="product-modal-head">
      <h2>${escapeHtml(product.name)}</h2>
      <button type="button" class="product-modal-close" title="Close" aria-label="Close">${
        typeof uiIcon === "function" ? uiIcon("close") : "&times;"}</button>
    </div>
    <div class="product-modal-body">
      <div class="product-modal-figure">
        ${productImageTag(product, "")}
      </div>
      <div class="product-modal-facts">
        <p class="product-modal-meta"><span class="product-code">${escapeHtml(productCode(product))}</span>
          ${escapeHtml(product.brand)} · ${escapeHtml(product.category)}${
          product.subcategory ? " · " + escapeHtml(product.subcategory) : ""
        }</p>
        <p class="stock-badge stock-${stock}">${stockLabel(stock)}</p>
        ${priceBlockHtml(product, "product-modal-price")}
        ${product.officialUrl
          ? `<a class="product-modal-official" href="${safeUrl(product.officialUrl)}"
               target="_blank" rel="noopener noreferrer">Full specifications on the maker's site</a>`
          : ""}
        ${product.description
          ? `<p class="product-modal-desc">${escapeHtml(product.description)}</p>`
          : ""}
        ${specRows
          ? `<table class="product-modal-specs">${specRows}</table>`
          : ""}
        ${colourOptionsOf(product).length && !outOfStock
          ? `<label class="product-modal-colour">${optionKindOf(colourOptionsOf(product))}
               <select class="product-modal-colour-pick">
                 <option value="">Choose a ${optionKindOf(colourOptionsOf(product)).toLowerCase()}</option>
                 ${colourOptionsOf(product).map((c) =>
                   `<option value="${escapeHtml(c)}">${escapeHtml(c)}</option>`).join("")}
               </select>
             </label>`
          : ""}
        <div class="product-modal-actions">
          <button class="add-btn product-modal-add" ${outOfStock ? "disabled" : ""}>
            ${outOfStock ? "Out of stock" : "Add to cart"}
          </button>
          <button type="button" class="product-modal-wish wishlist-btn ${saved ? "active" : ""}"
            aria-pressed="${saved}" aria-label="${saved ? "Remove from" : "Save to"} wishlist">
            ${heartIcon()}
          </button>
        </div>
      </div>
    </div>`;
}

// Listeners rather than inline onclick, because the modal's markup is
// rebuilt for each product and inline handlers would have to carry the
// id through a string every time.
function wireProductModalActions(product) {
  const root = productModalEl;

  root.querySelector(".product-modal-close")
      .addEventListener("click", closeProductModal);

  // Choosing a colour shows that colour, when we have its photo.
  const colourPick = root.querySelector(".product-modal-colour-pick");
  const figure = root.querySelector(".product-modal-figure img");
  if (colourPick && figure && optionKindOf(colourOptionsOf(product)) === "Colour") {
    const main = productImage(product);
    colourPick.addEventListener("change", () => {
      const src = colourImageOf(product, colourPick.value) || main;
      figure.onerror = () => { figure.onerror = null; figure.src = safeUrl(main); };
      figure.src = safeUrl(src);
    });
  }

  const add = root.querySelector(".product-modal-add");
  if (!add.disabled) {
    add.addEventListener("click", () => {
      const pick = root.querySelector(".product-modal-colour-pick");
      if (pick && !pick.value) {
        pick.focus();
        alert("Please choose a " + optionKindOf(colourOptionsOf(product)).toLowerCase() + " first.");
        return;
      }
      addToCart(product.id, [], pick ? pick.value : null);
      closeProductModal();
    });
  }

  root.querySelector(".product-modal-wish").addEventListener("click", (event) => {
    const heart = event.currentTarget;
    // toggleWishlist redraws the grid behind the modal but not the modal
    // itself, so this heart is updated by hand — and only once the write
    // has come back, since until then isInWishlist still holds the old
    // answer.
    Promise.resolve(toggleWishlist(product.id)).then(() => {
      const on = typeof isInWishlist === "function" && isInWishlist(product.id);
      heart.classList.toggle("active", on);
      heart.setAttribute("aria-pressed", String(on));
      heart.setAttribute("aria-label", (on ? "Remove from" : "Save to") + " wishlist");
    });
  });
}

// The clock starts once the catalogue has arrived, which is when the
// first card can exist. It goes on running for the life of the page and
// picks up cards drawn later -- a re-filtered grid, a reopened modal --
// because it looks the countdowns up on each tick rather than holding a
// list of them.
onAppReady(startDealTicker);
