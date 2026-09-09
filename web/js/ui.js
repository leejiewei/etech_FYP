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
function money(amount) {
  return "RM " + Number(amount).toFixed(2);
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

function buildProductCard(product) {
  const card = document.createElement("div");
  card.className = "product-card";

  // stockOf, not product.stock: one of the shop's own builds is only
  // available when its parts are, and it must read the same here as it
  // does on the Prebuilt page. For everything else this is product.stock.
  const stock = stockOf(product);
  const stockClass = "stock-" + stock; // stock-in / stock-low / stock-out
  const heartFilled = typeof isInWishlist === "function" && isInWishlist(product.id);
  const comparing = typeof isInCompare === "function" && isInCompare(product.id);
  const outOfStock = stock === "out";

  card.innerHTML = `
    <button class="wishlist-btn ${heartFilled ? "active" : ""}" onclick="toggleWishlist(${product.id})" title="Add to wishlist">
      ${heartFilled ? "❤️" : "🤍"}
    </button>
    <div class="product-img-wrap">
      ${productImageTag(product, "product-img")}
    </div>
    <h3>${escapeHtml(product.name)}</h3>
    <p class="product-category">${escapeHtml(product.category)}${product.subcategory ? " · " + escapeHtml(product.subcategory) : ""}</p>
    <p class="stock-badge ${stockClass}">${stockLabel(stock)}</p>
    ${priceBlockHtml(product, "product-price")}
    <button class="add-btn" ${outOfStock ? "disabled" : ""} onclick="addToCart(${product.id})">
      ${outOfStock ? "Out of Stock" : "Add to Cart"}
    </button>
    <label class="compare-check">
      <input type="checkbox" ${comparing ? "checked" : ""} onchange="toggleCompare(${product.id})" />
      Compare
    </label>
  `;

  // The picture and the name both open the detail modal. The picture has
  // always looked clickable; until the modal existed, clicking it only
  // recorded a view and left the shopper exactly where they were.
  card.querySelector(".product-img-wrap").addEventListener("click", () => {
    openProductModal(product.id);
  });
  const heading = card.querySelector("h3");
  heading.style.cursor = "pointer";
  heading.addEventListener("click", () => openProductModal(product.id));

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

  // The same specs the compare table shows, through the same label
  // function, so a spec is never named one thing here and another there.
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
      <button class="product-modal-close" title="Close" aria-label="Close">&times;</button>
    </div>
    <div class="product-modal-body">
      <div class="product-modal-figure">
        ${productImageTag(product, "")}
      </div>
      <div class="product-modal-facts">
        <p class="product-modal-meta">${escapeHtml(product.brand)} · ${escapeHtml(product.category)}${
          product.subcategory ? " · " + escapeHtml(product.subcategory) : ""
        }</p>
        <p class="stock-badge stock-${stock}">${stockLabel(stock)}</p>
        ${priceBlockHtml(product, "product-modal-price")}
        ${product.description
          ? `<p class="product-modal-desc">${escapeHtml(product.description)}</p>`
          : ""}
        ${specRows
          ? `<table class="product-modal-specs">${specRows}</table>`
          : ""}
        <div class="product-modal-actions">
          <button class="add-btn product-modal-add" ${outOfStock ? "disabled" : ""}>
            ${outOfStock ? "Out of Stock" : "Add to Cart"}
          </button>
          <button class="product-modal-wish" title="Add to wishlist">
            ${saved ? "❤️" : "🤍"}
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

  const add = root.querySelector(".product-modal-add");
  if (!add.disabled) {
    add.addEventListener("click", () => {
      addToCart(product.id);
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
      heart.textContent =
        (typeof isInWishlist === "function" && isInWishlist(product.id)) ? "❤️" : "🤍";
    });
  });
}

// The clock starts once the catalogue has arrived, which is when the
// first card can exist. It goes on running for the life of the page and
// picks up cards drawn later -- a re-filtered grid, a reopened modal --
// because it looks the countdowns up on each tick rather than holding a
// list of them.
onAppReady(startDealTicker);
