// One prebuilt machine, on a page of its own: prebuilt-detail.html?id=5201
//
// Opened by clicking a card on the Prebuilt page. Laid out the way PC
// shops in Malaysia sell a build -- picture on the left; name, price,
// the parts and stock on the right; then one section per kind of
// upgrade, each option a tile with what it adds to the price, and a
// running total above the Add to Cart button.
//
// Each tile shows an icon for its kind (a graphics card, a RAM stick)
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
    <div class="pd-top">
      <div class="pd-image">${productImageTag(p, "pd-img")}</div>

      <div class="pd-info">
        <p class="pd-crumbs">
          <a href="prebuilt.html">Prebuilt PCs</a> &rsaquo; ${escapeHtml(group || "")}
        </p>
        <h1 class="pd-title">${escapeHtml(p.name)}</h1>

        <div class="pd-price">
          ${saving > 0 ? `<span class="price-was">${money(p.price)}</span>` : ""}
          <span class="pd-price-now">${money(base)}</span>
          ${saving > 0 ? `<span class="pd-save">SAVE ${money(saving)}</span>` : ""}
        </div>
        ${saving > 0
          ? `<p class="pd-deal-ends">Deal ends ${escapeHtml(dealEndsText(p))}</p>`
          : ""}

        <ul class="pd-parts">${prebuiltSpecList(p)}</ul>

        <p class="stock-badge stock-${stock}">${stockLabel(stock)}</p>
        ${waiting ? `<p class="prebuilt-waiting">Waiting on: ${escapeHtml(waiting)}</p>` : ""}

        ${slotGroups(options).map((g) => upgradeSection(g, outOfStock)).join("")}

        ${note ? `
        <div class="pd-section">
          <h2 class="pd-section-title">Available upgrades</h2>
          <p class="prebuilt-upgrades">${escapeHtml(note)}
            <br /><small>Ask us in store or on WhatsApp to add one.</small></p>
        </div>` : ""}

        <div class="pd-summary" id="pd-summary">${summaryHtml()}</div>

        <button class="add-btn pd-add" ${outOfStock ? "disabled" : ""} id="pd-add">
          ${outOfStock ? "Out of Stock" : "Add to Cart"}
        </button>
      </div>
    </div>

    ${p.description ? `
    <div class="pd-description">
      <h2>About this PC</h2>
      <p>${escapeHtml(p.description)}</p>
    </div>` : ""}`;

  wireDetail(outOfStock);
}

function upgradeSection(group, outOfStock) {
  const info = slotInfo(group.slot);
  return `
    <details class="pd-section" open>
      <summary class="pd-section-title">${escapeHtml(info.title)}</summary>
      <div class="pd-tiles">
        ${group.options.map((u) => `
          <button type="button" class="pd-tile${detailChosen.has(u.id) ? " chosen" : ""}"
                  data-upgrade="${u.id}" data-slot="${escapeHtml(u.slot)}"
                  aria-pressed="${detailChosen.has(u.id)}" ${outOfStock ? "disabled" : ""}>
            <span class="pd-tile-icon">${categoryIcon(info.icon)}</span>
            <span class="pd-tile-name">${escapeHtml(u.label)}</span>
            <span class="pd-tile-price">(+${money(u.priceDelta)})</span>
          </button>`).join("")}
      </div>
    </details>`;
}

function summaryHtml() {
  const base = priceOf(detailProduct);
  const extra = detailExtra();
  return `
    <div><span>Product price</span><span>${money(base)}</span></div>
    <div><span>Total options</span><span>${money(extra)}</span></div>
    <div class="pd-total"><span>Order total</span><span>${money(base + extra)}</span></div>`;
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
