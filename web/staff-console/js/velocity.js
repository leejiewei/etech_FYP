// ============================================================
// Inventory Velocity — LFU turned around.
//
// LFU (least-frequently-used) is a caching idea: count how often each
// item is touched, and throw out the ones nobody wants. We keep the
// counting but read it the other way up — instead of finding what to
// evict, we rank what customers engage with most.
//
// Not every touch means the same thing, so each is weighted by how close
// it is to a sale:
//
//     score = (views x 1) + (cart adds x 3) + (purchases x 5)
//
// A view is idle curiosity. Putting something in the basket is real
// intent. Buying it is the thing we actually care about, so it counts
// five times as much as a look.
//
// Products are then split into tiers by where they rank: the top fifth
// are High velocity, the next third Mid, the rest Low. Anything with no
// activity at all is listed separately — that is what feeds the
// dead-stock alerts on the next page.
//
// The counting is a GROUP BY with three FILTER clauses, which a browser
// cannot send, so it is a database function: admin_product_scores(days,
// category). The window and the category used to be pasted into the SQL
// string in PHP; as arguments they cannot be anything but numbers.
//
// The tiering stays here rather than going into the function, because it
// is a judgement about how to read the numbers — where to draw the line
// between High and Mid — and not a fact about them.
// ============================================================

const PERIODS = [
  [30, "Last 30 days"], [90, "Last 90 days"],
  [180, "Last 6 months"], [0, "All time"],
];

adminPage("Inventory Velocity", "velocity", async (content) => {
  const q = params();
  const days = PERIODS.some(([d]) => d === Number(q.days)) ? Number(q.days) : 90;
  const categoryId = Number(q.cat || 0);
  const tierFilter = q.tier || "";

  const [categories, scored] = await Promise.all([
    loadCategories(),
    loadScores(days, categoryId),
  ]);

  const { active, idle, counts, topScore } = applyTiers(scored);

  const shown = tierFilter === "idle" ? idle
    : tierFilter !== "" ? active.filter((r) => r.tier === tierFilter)
    : active;

  const link = (extra) =>
    "?" + new URLSearchParams({ days, cat: categoryId, ...extra }).toString();

  content.innerHTML = `
    <form class="filters" id="filters">
      <div class="field">
        <label>Period</label>
        <select name="days">
          ${PERIODS.map(([d, label]) =>
            `<option value="${d}" ${days === d ? "selected" : ""}>${label}</option>`).join("")}
        </select>
      </div>
      <div class="field">
        <label>Category</label>
        <select name="cat">
          <option value="0">All categories</option>
          ${categoryOptions(categories, categoryId)}
        </select>
      </div>
    </form>

    <div class="tiles">
      ${tierTile("High", counts.High, "Selling and being looked at", "#1e8e3e", link({ tier: "High" }))}
      ${tierTile("Mid",  counts.Mid,  "Steady interest",             "#b8860b", link({ tier: "Mid" }))}
      ${tierTile("Low",  counts.Low,  "Barely moving",               "#98a0aa", link({ tier: "Low" }))}
      <a class="tile" href="${link({ tier: "idle" })}" style="border-top-color:#c0392b;">
        <div class="label">No activity</div>
        <div class="value">${idle.length}</div>
        <div class="sub">Not viewed or bought at all</div>
      </a>
    </div>

    <div class="filters" style="margin-top:4px;">
      <a href="${link({})}" class="btn ${tierFilter === "" ? "" : "grey"}">All ranked</a>
      ${["High", "Mid", "Low"].map((t) =>
        `<a href="${link({ tier: t })}" class="btn ${tierFilter === t ? "" : "grey"}">${t}</a>`).join("")}
      <a href="${link({ tier: "idle" })}" class="btn ${tierFilter === "idle" ? "" : "grey"}">No activity</a>
    </div>

    <div class="table-wrap">
    <table class="data">
      <thead>
        <tr>
          <th>#</th><th>Product</th><th>Category</th>
          <th class="num">Views</th><th class="num">Cart</th><th class="num">Sold</th>
          <th class="num">Score</th><th style="width:150px;">Relative</th>
          <th>Tier</th><th>Stock</th>
        </tr>
      </thead>
      <tbody>
      ${shown.length === 0
        ? `<tr><td colspan="10" style="text-align:center; color:#888; padding:26px;">Nothing here for those filters.</td></tr>`
        : shown.slice(0, 100).map((r, i) => scoreRow(r, i, topScore)).join("")}
      </tbody>
    </table>
    </div>

    ${shown.length > 100
      ? `<p class="hint" style="margin-top:12px;">Showing the first 100 of ${shown.length}.</p>`
      : ""}`;

  // Changing either dropdown reloads with the new filters, the same as
  // the onchange="this.form.submit()" the PHP page used.
  document.querySelectorAll("#filters select").forEach((select) => {
    select.onchange = () => {
      const form = document.getElementById("filters");
      window.location.search = new URLSearchParams({
        days: form.days.value,
        cat: form.cat.value,
        ...(tierFilter ? { tier: tierFilter } : {}),
      }).toString();
    };
  });
});

// ------------------------------------------------------------
// Working out the tiers.
//
// Only products with some activity get ranked; the rest are "no
// activity", which is a different statement from "ranked last" and is
// what the dead-stock page is looking for.
// ------------------------------------------------------------
function applyTiers(rows) {
  const active = rows.filter((r) => Number(r.score) > 0);
  const idle = rows.filter((r) => Number(r.score) === 0);

  const highCut = Math.ceil(active.length * 0.20);   // top 20%
  const midCut = Math.ceil(active.length * 0.50);    // next 30%

  active.forEach((r, i) => {
    r.tier = i < highCut ? "High" : (i < midCut ? "Mid" : "Low");
  });

  const counts = { High: 0, Mid: 0, Low: 0 };
  active.forEach((r) => counts[r.tier]++);

  return {
    active, idle, counts,
    topScore: active.length > 0 ? Number(active[0].score) : 1,
  };
}

function tierTile(tier, tierCount, note, colour, href) {
  return `
    <a class="tile" href="${href}" style="border-top-color:${colour};">
      <div class="label">${tier} velocity</div>
      <div class="value">${tierCount}</div>
      <div class="sub">${note}</div>
    </a>`;
}

function tierColour(tier) {
  return tier === "High" ? "#1e8e3e" : (tier === "Mid" ? "#b8860b" : "#98a0aa");
}

function tierClass(tier) {
  return { High: "in", Mid: "low", Low: "grey" }[tier] || "grey";
}

function stockWord(status) {
  return { in: "In stock", low: "Low", out: "Out" }[status] || status;
}

function scoreRow(r, i, topScore) {
  const score = Number(r.score);
  const categoryPath = r.parent ? r.parent + " > " + r.category : r.category;

  return `
    <tr>
      <td>${i + 1}</td>
      <td>
        <a href="product_edit.html?id=${r.product_id}">${e(shorten(r.name, 44))}</a>
        <br /><small style="color:#999;">${e(money(r.price))}</small>
      </td>
      <td><small>${e(categoryPath)}</small></td>
      <td class="num">${r.views}</td>
      <td class="num">${r.cart_adds}</td>
      <td class="num">${r.purchases}</td>
      <td class="num"><strong>${score}</strong></td>
      <td>
        <div style="background:#eef0f3; border-radius:3px; height:9px; width:100%;">
          <div style="background:${tierColour(r.tier)}; width:${score > 0 ? barWidth(score, topScore) : 0}%;
                      height:9px; border-radius:3px;"></div>
        </div>
      </td>
      <td><span class="badge ${tierClass(r.tier)}">${e(r.tier || "None")}</span></td>
      <td><span class="badge ${e(r.stock_status)}">${e(stockWord(r.stock_status))}</span></td>
    </tr>`;
}
