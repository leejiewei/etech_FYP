// The two pages under "Powered by ASUS" in the department strip:
//
//   asus.html        Powered by ASUS -- the shop's own PCs built on ASUS
//                    parts, read from the real catalogue.
//   asus-agent.html  ASUS Agent Computer -- what a PC needs to run AI
//                    models locally, and the ASUS graphics cards we stock
//                    sorted by how much memory they have.
//
// Both replaced "Workshop rigs" in the strip on 27 Oct 2026, after an
// ASUS supplier's review, and were modelled on the structure of
// mrit.my/powered-by-asus and mrit.my/asus-agent-computer -- not their
// words or pictures.
//
// Nothing on either page is typed in. Which machines appear, their
// prices, their stock and which of their parts are ASUS all come from
// the database, so a machine that is rebuilt on another brand's board
// drops off the page on its own. eTech is a retailer of ASUS parts; the
// pages say so and claim no partnership or certification.

// The ASUS family as the catalogue spells it: "Asus", "Asus TUF",
// "Asus ROG".
function isAsusBrand(brand) {
  return /^asus\b/i.test(brand || "");
}

// The parts of a build that carry a brand worth naming, in the order a
// customer reads a spec sheet. CPU, RAM and drives are left out: ASUS
// does not make them.
const ASUS_SLOTS = [
  { slot: "motherboard", label: "Motherboard" },
  { slot: "gpu",         label: "Graphics card" },
  { slot: "psu",         label: "Power supply" },
  { slot: "cooler",      label: "CPU cooler" },
  { slot: "chassis",     label: "Case" },
];

// ------------------------------------------------------------
// Powered by ASUS
// ------------------------------------------------------------
let asusBuildFilter = "All";
let asusComponents = {};   // prebuilt id -> { slot: component product }

// The bill of materials is public (policy "bill of materials is public"),
// and only this page needs it, so it is read here rather than with the
// catalogue on every page.
function loadAsusComponents() {
  return selectAllRows(() => sb.from("prebuilt_components")
    .select("prebuilt_id,slot,component_id"))
    .then((rows) => {
      asusComponents = {};
      rows.forEach((row) => {
        const part = row.component_id ? getProductById(row.component_id) : null;
        if (!part) return;
        (asusComponents[row.prebuilt_id] ||= {})[row.slot] = part;
      });
    });
}

// Which of a machine's parts are ASUS, as labels. A machine sold under
// the ASUS name is ASUS throughout and is answered by its own brand.
function asusPartsOf(machine) {
  if (isAsusBrand(machine.brand)) return null;
  const parts = asusComponents[machine.id] || {};
  return ASUS_SLOTS
    .filter((s) => parts[s.slot] && isAsusBrand(parts[s.slot].brand))
    .map((s) => s.label);
}

// A machine belongs on the page when ASUS made it, or when its
// motherboard -- the part everything else plugs into -- is ASUS.
function isAsusMachine(machine) {
  if (isAsusBrand(machine.brand)) return true;
  return (asusPartsOf(machine) || []).includes("Motherboard");
}

function asusMachines() {
  return getPrebuilts().filter(isAsusMachine);
}

function asusRange(machine) {
  if (isAsusBrand(machine.brand)) return "ASUS desktops";
  return prebuiltGroup(machine);
}

function renderAsusFilter() {
  const bar = document.getElementById("asus-filter");
  if (!bar) return;
  const ranges = ["All", ...new Set(asusMachines().map(asusRange))];
  bar.innerHTML = ranges.map((r) => `
    <button type="button" class="filter-btn${r === asusBuildFilter ? " active" : ""}"
            data-range="${escapeHtml(r)}" aria-pressed="${r === asusBuildFilter}">${escapeHtml(r)}</button>`).join("");
  bar.querySelectorAll("[data-range]").forEach((btn) => {
    btn.onclick = () => {
      asusBuildFilter = btn.dataset.range;
      renderAsusFilter();
      renderAsusBuilds();
    };
  });
}

function asusCard(machine) {
  const parts = asusPartsOf(machine);
  const line = parts === null
    ? "An ASUS-made desktop"
    : `ASUS ${parts.map((p) => p.toLowerCase()).join(", ")}`;
  // prebuiltCard() from prebuilt.js is the same card the Prebuilt PCs page
  // shows; the ASUS line goes in just under the machine's name.
  return prebuiltCard(machine).replace("</h3>",
    `</h3><p class="asus-parts">${escapeHtml(line)}${parts && parts.length >= 4
      ? ` <span class="asus-full">${parts.length} of ${ASUS_SLOTS.length} ASUS</span>` : ""}</p>`);
}

function renderAsusBuilds() {
  const grid = document.getElementById("asus-grid");
  if (!grid) return;
  const all = asusMachines();
  const list = asusBuildFilter === "All" ? all : all.filter((m) => asusRange(m) === asusBuildFilter);

  if (!list.length) {
    grid.innerHTML = `
      <div class="asus-empty">
        <p><strong>No ASUS-based PCs are listed right now.</strong></p>
        <p>You can still build one on ASUS parts in the PC Builder, or ask us to put one together.</p>
        <a class="btn" href="build.html">Open the PC Builder</a>
      </div>`;
    return;
  }
  // Most ASUS parts first, then by price.
  list.sort((a, b) => ((asusPartsOf(b) || ASUS_SLOTS).length - (asusPartsOf(a) || ASUS_SLOTS).length)
    || priceOf(a) - priceOf(b));
  grid.innerHTML = list.map(asusCard).join("");
}

// The ASUS parts the shop sells on their own, one row per kind, with
// what is in stock and the lowest price -- all counted from the catalogue.
function renderAsusParts() {
  const el = document.getElementById("asus-parts");
  if (!el) return;
  const kinds = [
    { sub: "Motherboard", label: "Motherboards" },
    { sub: "GPU",         label: "Graphics cards" },
    { sub: "PSU",         label: "Power supplies" },
    { sub: "Cooler",      label: "CPU coolers" },
    { sub: "Case",        label: "Cases" },
  ];
  const brands = [...new Set(products.filter((p) => isAsusBrand(p.brand)).map((p) => p.brand))];
  const brandQuery = brands.map((b) => "brand=" + encodeURIComponent(b)).join("&");

  const rows = kinds.map((k) => {
    const items = getProductsBySubcategory(k.sub).filter((p) => isAsusBrand(p.brand));
    if (!items.length) return "";
    const inStock = items.filter((p) => stockOf(p) !== "out").length;
    const from = Math.min(...items.map(priceOf));
    return `
      <a class="asus-part-row" href="shop.html?subcategory=${encodeURIComponent(k.sub)}&${brandQuery}">
        <span class="asus-part-name">${escapeHtml(k.label)}</span>
        <span class="asus-part-count">${items.length} model${items.length === 1 ? "" : "s"}, ${inStock} in stock</span>
        <span class="asus-part-price">from ${money(from)}</span>
      </a>`;
  }).join("");
  el.innerHTML = rows || `<p class="section-sub">No ASUS parts are listed right now.</p>`;
}

// ------------------------------------------------------------
// ASUS Agent Computer
// ------------------------------------------------------------

// Graphics memory in GB from a spec such as "16GB".
function vramOf(product) {
  const m = /(\d+)\s*GB/i.exec(String((product.attrs || {}).vram || ""));
  return m ? Number(m[1]) : 0;
}

// The tiers in the guidance table on the page. A card is filed under the
// highest tier it reaches. Below 8GB is left out: too little for the
// models this page is about.
const AGENT_TIERS = [
  { min: 24, label: "24GB and more" },
  { min: 16, label: "16GB" },
  { min: 12, label: "12GB" },
  { min: 8,  label: "8GB" },
];

function renderAgentGpus() {
  const el = document.getElementById("agent-gpus");
  if (!el) return;
  const cards = getProductsBySubcategory("GPU")
    .filter((p) => isAsusBrand(p.brand) && vramOf(p) >= 8)
    .sort((a, b) => priceOf(a) - priceOf(b));

  if (!cards.length) {
    el.innerHTML = `<p class="section-sub">No ASUS graphics cards with 8GB or more are listed right now.
      <a href="shop.html?subcategory=GPU">See every graphics card</a>.</p>`;
    return;
  }

  // buildProductCard() hands back an element, wired for clicks, so the
  // grids are filled by appending rather than through innerHTML.
  el.innerHTML = "";
  AGENT_TIERS.forEach((tier, i) => {
    const upper = i === 0 ? Infinity : AGENT_TIERS[i - 1].min;
    const inTier = cards.filter((p) => vramOf(p) >= tier.min && vramOf(p) < upper);
    if (!inTier.length) return;
    const title = document.createElement("h3");
    title.className = "agent-tier-title";
    title.textContent = `${tier.label} of graphics memory`;
    const grid = document.createElement("div");
    grid.className = "product-grid";
    inTier.forEach((p) => grid.appendChild(buildProductCard(p)));
    el.append(title, grid);
  });
}

// The shop's own machines, with the graphics memory each one has. A
// machine whose card has under 8GB, or that has no card, is not offered
// here: the page would be promising something it cannot do.
function renderAgentMachines() {
  const el = document.getElementById("agent-machines");
  if (!el) return;
  const rows = getPrebuilts()
    .map((m) => {
      const gpu = (asusComponents[m.id] || {}).gpu;
      return { m, gpu, vram: gpu ? vramOf(gpu) : 0 };
    })
    .filter((r) => r.vram >= 8)
    .sort((a, b) => b.vram - a.vram || priceOf(a.m) - priceOf(b.m));

  if (!rows.length) {
    el.innerHTML = `<p class="section-sub">None of our ready-made PCs has 8GB or more of graphics
      memory at the moment. The PC Builder can put one together from the cards above.</p>`;
    return;
  }

  el.innerHTML = `
    <table class="agent-table">
      <thead><tr><th>Ready-made PC</th><th>Graphics card</th><th>Graphics memory</th><th>System memory</th><th>Price</th><th>Stock</th></tr></thead>
      <tbody>${rows.map(({ m, gpu, vram }) => {
        const stock = stockOf(m);
        return `<tr>
          <td><a href="${prebuiltDetailUrl(m.id)}">${escapeHtml(m.name)}</a></td>
          <td>${escapeHtml(gpu.name)}</td>
          <td>${vram}GB</td>
          <td>${escapeHtml((m.attrs || {}).ram || "See the PC's page")}</td>
          <td class="agent-price">${money(priceOf(m))}</td>
          <td><span class="stock-badge stock-${stock}">${stockLabel(stock)}</span></td>
        </tr>`;
      }).join("")}</tbody>
    </table>
    <p class="agent-note">Graphics memory decides which models fit, so the table is sorted by it.
      For running models locally we suggest 32GB of system memory; each PC's page lists the upgrades
      we offer for it, or ask us on WhatsApp.</p>`;
}

onAppReady(() => {
  const onAsusPage = document.getElementById("asus-grid");
  const onAgentPage = document.getElementById("agent-gpus");
  if (!onAsusPage && !onAgentPage) return;

  renderAgentGpus();
  renderAsusParts();
  loadAsusComponents()
    .catch((error) => {
      // Without the bill of materials only ASUS-made desktops can be
      // shown as ASUS; say nothing more than that.
      console.error("Loading the prebuilt parts list:", error);
      asusComponents = {};
    })
    .finally(() => {
      renderAsusFilter();
      renderAsusBuilds();
      renderAgentMachines();
    });
});
