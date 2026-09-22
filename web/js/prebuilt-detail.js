// One prebuilt machine, on a page of its own: prebuilt-detail.html?id=5201
//
// Opened by clicking a card on the Prebuilt page. A red band carries the
// name, stock and price; below it the picture sits beside a table of the
// parts, then one numbered step per kind of upgrade, and a "Your PC"
// receipt down the side lists every upgrade chosen and the total.
//
// Each option shows an icon for its kind (a graphics card, a RAM stick)
// rather than a photo of the exact part. The shop has no photos of the
// upgrade parts yet; the icon is there until it does.
//
// Nothing here prices anything for real. As on the card before it, only
// the chosen upgrade ids go to the basket, and place_order reads what
// each one costs from prebuilt_upgrades on the server.

// What each slot is called on the page, and its icon from CATEGORY_ICONS
// in layout.js. A slot missing from here still shows, under its own name.
const UPGRADE_SLOTS = {
  cpu:         { title: "Upgrade Processor",       icon: "cpu" },
  gpu:         { title: "Upgrade Graphics Card",   icon: "gpu" },
  ram:         { title: "Upgrade RAM",             icon: "ram" },
  ssd:         { title: "Upgrade Storage",         icon: "storage" },
  cooler:      { title: "Upgrade CPU Cooler",      icon: "cooler" },
  extras:      { title: "Add-on Fans",             icon: "fan" },
  monitor:     { title: "Add-on Monitor",          icon: "monitor" },
  peripherals: { title: "Add-on Keyboard & Mouse", icon: "keyboard" },
  audio:       { title: "Add-on Speakers",         icon: "speaker" },
};

function slotInfo(slot) {
  return UPGRADE_SLOTS[slot] || {
    title: "Upgrade " + slot.charAt(0).toUpperCase() + slot.slice(1),
    icon: "puzzle",
  };
}

// The ids chosen so far. One per slot: a machine has one graphics card,
// so choosing a second replaces the first rather than charging for both.
const detailChosen = new Set();
let detailProduct = null;

function detailOptions() {
  return detailProduct ? upgradesFor(detailProduct.id) : [];
}

function detailExtra() {
  return detailOptions()
    .filter((u) => detailChosen.has(u.id))
    .reduce((sum, u) => sum + u.priceDelta, 0);
}

// Upgrades to the machine first, then the things sold beside it, each
// kept in the order the shop listed them.
function slotGroups(options) {
  const groups = [];
  ["upgrade", "accessory"].forEach((kind) => {
    options.filter((u) => (u.kind === "accessory" ? "accessory" : "upgrade") === kind)
      .forEach((u) => {
        let group = groups.find((g) => g.slot === u.slot);
        if (!group) groups.push(group = { slot: u.slot, options: [] });
        group.options.push(u);
      });
  });
  return groups;
}

// The machine's parts as rows of a table, in the same order the Prebuilt
// page's cards list them.
function detailSpecRows(product) {
  const attrs = product.attrs || {};
  const keys = Object.keys(attrs);
  const ordered = [
    ...PREBUILT_SPEC_ORDER.filter((key) => keys.includes(key)),
    ...keys.filter((key) => !PREBUILT_SPEC_ORDER.includes(key)),
  ];
  return ordered.map((key) => {
    const value = Array.isArray(attrs[key]) ? attrs[key].join(", ") : attrs[key];
    return `<tr><th>${escapeHtml(attrLabel(key))}</th><td>${escapeHtml(value)}</td></tr>`;
  }).join("");
}

function renderPrebuiltDetail() {
  const root = document.getElementById("prebuilt-detail");
  const p = detailProduct;

  const stock = stockOf(p);
  const outOfStock = stock === "out";
  const waiting = blockedBy(p.id);
  const options = detailOptions();
  const note = options.length ? null : upgradeNote(p);
  const group = prebuiltGroup(p);
  const base = priceOf(p);
  const saving = hasDeal(p) ? p.price - base : 0;

  root.innerHTML = `
    <div class="pd-hero">
      <div class="pd-hero-text">
        <p class="pd-crumbs">
          <a href="prebuilt.html">Prebuilt PCs</a> / ${escapeHtml(group || "")}
        </p>
        <h1 class="pd-title">${escapeHtml(p.name)}</h1>
        <span class="stock-badge stock-${stock}">${stockLabel(stock)}</span>
      </div>
      <div class="pd-hero-price">
        ${saving > 0 ? `<span class="pd-save">Save ${money(saving)}</span>` : ""}
        <span class="pd-price-now">${money(base)}</span>
        ${saving > 0 ? `<span class="pd-was">was ${money(p.price)}</span>` : ""}
        ${saving > 0 ? `<span class="pd-deal-ends">Deal ends ${escapeHtml(dealEndsText(p))}</span>` : ""}
      </div>
    </div>

    <div class="pd-body">
      <div class="pd-main">
        <div class="pd-showcase">
          <div class="pd-image">${productImageTag(p, "pd-img")}</div>
          <table class="pd-spec">
            <caption>What's inside</caption>
            ${detailSpecRows(p)}
          </table>
        </div>
        ${waiting ? `<p class="prebuilt-waiting">Waiting on: ${escapeHtml(waiting)}</p>` : ""}

        ${options.length ? `<h2 class="pd-steps-title">Make it yours</h2>
          <p class="pd-steps-hint">Everything is optional. Pick one in a step to swap it in; pick it again to go back to standard.</p>` : ""}
        ${slotGroups(options).map((g, i) => upgradeSection(g, i, outOfStock)).join("")}

        ${note ? `
        <div class="pd-step">
          <h2 class="pd-step-title">Available upgrades</h2>
          <p class="prebuilt-upgrades">${escapeHtml(note)}
            <br /><small>Ask us in store or on WhatsApp to add one.</small></p>
        </div>` : ""}

        ${p.description ? `
        <div class="pd-description">
          <h2>About this PC</h2>
          <p>${escapeHtml(p.description)}</p>
        </div>` : ""}
      </div>

      <aside class="pd-receipt">
        <h2>Your PC</h2>
        <div id="pd-summary">${summaryHtml()}</div>
        <button class="add-btn pd-add" ${outOfStock ? "disabled" : ""} id="pd-add">
          ${outOfStock ? "Out of Stock" : "Add to Cart"}
        </button>
      </aside>
    </div>`;

  wireDetail(outOfStock);
}

// One numbered step per kind of upgrade. Each option is a row with a round
// marker, its icon, its name and what it adds.
function upgradeSection(group, index, outOfStock) {
  const info = slotInfo(group.slot);
  const number = String(index + 1).padStart(2, "0");
  return `
    <section class="pd-step">
      <h2 class="pd-step-title"><span class="pd-step-no">${number}</span>${escapeHtml(info.title)}</h2>
      <div class="pd-tiles">
        ${group.options.map((u) => `
          <button type="button" class="pd-tile${detailChosen.has(u.id) ? " chosen" : ""}"
                  data-upgrade="${u.id}" data-slot="${escapeHtml(u.slot)}"
                  aria-pressed="${detailChosen.has(u.id)}" ${outOfStock ? "disabled" : ""}>
            <span class="pd-tile-mark" aria-hidden="true"></span>
            <span class="pd-tile-icon">${categoryIcon(info.icon)}</span>
            <span class="pd-tile-name">${escapeHtml(u.label)}</span>
            <span class="pd-tile-price">+${money(u.priceDelta)}</span>
          </button>`).join("")}
      </div>
    </section>`;
}

// The receipt: the machine, then each upgrade chosen on its own line.
function summaryHtml() {
  const base = priceOf(detailProduct);
  const chosen = detailOptions().filter((u) => detailChosen.has(u.id));
  const extra = detailExtra();
  return `
    <div class="pd-line"><span>${escapeHtml(detailProduct.name)}</span><span>${money(base)}</span></div>
    ${chosen.length
      ? chosen.map((u) => `
        <div class="pd-line pd-line-up"><span>+ ${escapeHtml(u.label)}</span><span>${money(u.priceDelta)}</span></div>`).join("")
      : `<p class="pd-line-none">Standard build, no upgrades</p>`}
    <div class="pd-line pd-total"><span>Total</span><span>${money(base + extra)}</span></div>`;
}

function wireDetail(outOfStock) {
  document.querySelectorAll(".pd-tile").forEach((tile) => {
    tile.onclick = () => {
      const id = Number(tile.dataset.upgrade);

      if (detailChosen.has(id)) {
        detailChosen.delete(id);
      } else {
        detailOptions()
          .filter((u) => u.slot === tile.dataset.slot)
          .forEach((u) => detailChosen.delete(u.id));
        detailChosen.add(id);
      }

      // Redraw only the tiles and the total, so the page does not jump.
      document.querySelectorAll(".pd-tile").forEach((t) => {
        const on = detailChosen.has(Number(t.dataset.upgrade));
        t.classList.toggle("chosen", on);
        t.setAttribute("aria-pressed", on);
      });
      document.getElementById("pd-summary").innerHTML = summaryHtml();
    };
  });

  const add = document.getElementById("pd-add");
  if (add && !outOfStock) {
    add.onclick = () => addToCart(detailProduct.id, Array.from(detailChosen));
  }
}

onAppReady(() => {
  const root = document.getElementById("prebuilt-detail");
  if (!root) return;

  const id = Number(new URLSearchParams(window.location.search).get("id"));
  const product = getProductById(id);

  if (!product || !prebuiltGroup(product)) {
    root.innerHTML = `
      <p style="text-align:center; color:#666;">
        That PC could not be found. <a href="prebuilt.html">See all prebuilt PCs</a>.
      </p>`;
    return;
  }

  detailProduct = product;
  document.title = product.name + " - eTech Computer Accessories";

  // Opening a machine's page is a view, the same as opening a product's
  // window anywhere else on the site. See tracking.js.
  if (typeof trackProductClick === "function") trackProductClick(product.id);

  renderPrebuiltDetail();
});
