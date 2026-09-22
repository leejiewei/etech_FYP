// ============================================================
// Stock alerts — the two things the velocity numbers are actually for.
//
//   Restock:    products selling well that are about to run out.
//   Dead stock: money sitting on a shelf that nobody has touched.
//
// Both come from one weighted score, admin_product_scores(). The
// Inventory Velocity page that used to list the whole ranking is gone --
// Customer Behaviour took its place -- and this page is what the score
// is still for.
//
// Everything below the fetch is judgement rather than arithmetic — which
// products count as "selling", what to do about one that isn't — and
// judgement belongs where you can read it, not buried in SQL.
// ============================================================

const ALERT_PERIODS = [30, 90, 180];
const DEAD_STOCK_FLOOR = 300;   // ringgit; below this, standing still costs little

adminPage("Stock Alerts", "alerts", async (content) => {
  const days = ALERT_PERIODS.includes(Number(params().days)) ? Number(params().days) : 90;

  const [all, haveCosts] = await Promise.all([
    loadScores(days),
    countWithCosts(),
  ]);

  // admin_product_scores already sorts by score, so the top of the list
  // is the ranking the tiers are cut from.
  const active = all.filter((r) => Number(r.score) > 0);
  const highCut = Math.ceil(active.length * 0.20);
  const highIds = new Set(active.slice(0, highCut).map((r) => r.product_id));

  const restock = all
    .filter((r) => highIds.has(r.product_id)
      && Number(r.purchases) > 0
      && (r.stock_status === "out" || r.stock_status === "low"))
    .sort((a, b) => Number(b.purchases) - Number(a.purchases));

  const dead = all
    .filter((r) => Number(r.purchases) === 0 && num(r.price) >= DEAD_STOCK_FLOOR)
    .sort((a, b) => shelfValue(b) - shelfValue(a));

  const deadTotal = dead.reduce((sum, r) => sum + num(r.price), 0);

  content.innerHTML = `
    <form class="filters" id="filters">
      <div class="field">
        <label>Judge activity over</label>
        <select name="days">
          <option value="30"  ${days === 30  ? "selected" : ""}>Last 30 days</option>
          <option value="90"  ${days === 90  ? "selected" : ""}>Last 90 days</option>
          <option value="180" ${days === 180 ? "selected" : ""}>Last 6 months</option>
        </select>
      </div>
    </form>

    <h2>Restock these</h2>
    <p class="hint">
      High-velocity products that are low or out of stock. These are selling &mdash; every day
      they are unavailable is a sale going elsewhere.
    </p>
    ${restockTable(restock)}

    <h2 style="margin-top:30px;">Dead stock</h2>
    <p class="hint">
      Nothing sold in the last ${days} days, and priced at RM${DEAD_STOCK_FLOOR} or more &mdash; the items where
      standing still costs the most. ${dead.length} products, ${e(money(deadTotal))} of shelf value.
    </p>
    ${haveCosts === 0 ? costsMissingNote() : ""}
    ${deadTable(dead)}
    ${dead.length > 30
      ? `<p class="hint" style="margin-top:12px;">Showing the 30 costliest of ${dead.length}.</p>`
      : ""}`;

  document.querySelector("#filters select").onchange = (event) => {
    window.location.search = "?days=" + event.target.value;
  };

  wireDiscountButtons();
});

async function countWithCosts() {
  const { count: total, error } = await sb.from("admin_products")
    .select("product_id", { count: "exact", head: true })
    .eq("is_active", 1)
    .not("cost_price", "is", null);
  if (error) throw error;
  return total || 0;
}

// "High-cost" should mean cost price × quantity held. Neither figure is
// recorded yet, so this falls back to the retail price and the page says
// so plainly. Once cost_price and stock_qty are filled in, it becomes a
// real money-at-risk figure with no code change.
function shelfValue(r) {
  return (r.cost_price !== null && r.stock_qty !== null)
    ? num(r.cost_price) * num(r.stock_qty)
    : num(r.price);
}

function restockTable(rows) {
  if (rows.length === 0) {
    return `<div class="card" style="color:#1e8e3e;">Nothing urgent &mdash; everything selling well is in stock.</div>`;
  }

  return `
    <div class="table-wrap">
    <table class="data">
      <thead><tr><th>Product</th><th>Category</th><th class="num">Sold</th>
                 <th class="num">Score</th><th class="num">Qty left</th><th>Status</th><th></th></tr></thead>
      <tbody>
      ${rows.map((r) => `
        <tr>
          <td><strong>${e(shorten(r.name, 42))}</strong><br />
              <small style="color:#999;">${e(money(r.price))}</small></td>
          <td><small>${e(categoryPath(r))}</small></td>
          <td class="num">${r.purchases}</td>
          <td class="num"><strong>${r.score}</strong></td>
          <td class="num">${r.stock_qty === null
            ? '<small style="color:#bbb;">not counted</small>' : r.stock_qty}</td>
          <td><span class="badge ${e(r.stock_status)}">${r.stock_status === "out" ? "Out of stock" : "Low"}</span></td>
          <td><a href="product_edit.html?id=${r.product_id}" class="btn small">Update stock</a></td>
        </tr>`).join("")}
      </tbody>
    </table>
    </div>`;
}

function costsMissingNote() {
  return `
    <div class="card" style="border-top-color:#b8860b; padding:14px 18px;">
      <strong>Ranked by retail price for now.</strong>
      <span style="font-size:14px;">
        This module is meant to rank by <em>money tied up</em> &mdash; cost price &times; quantity held.
        Neither is recorded yet, so it falls back to the shelf price. Fill in cost and quantity on the
        product pages and these figures become real.
      </span>
    </div>`;
}

// What to do depends on WHY it isn't selling. Interest but no sale is a
// pricing problem, which a discount can fix. No interest at all is a
// demand problem, and cutting the price will not create demand.
function suggestion(r) {
  const views = Number(r.views);
  const carts = Number(r.cart_adds);

  if (carts > 0) {
    return { action: "discount",
      why: "Being added to baskets but not bought — price is the likely blocker." };
  }
  if (views >= 3) {
    return { action: "discount",
      why: "Getting looked at but never added to a basket. A discount may convert that interest." };
  }
  if (views > 0) {
    return { action: "halt",
      why: "Barely any interest. Sell through what is here, but do not reorder." };
  }
  return { action: "halt",
    why: "Nobody has even looked at it. A discount will not create demand — stop reordering." };
}

function deadTable(rows) {
  if (rows.length === 0) {
    return `<div class="card" style="color:#1e8e3e;">Nothing stagnant &mdash; every product over RM${DEAD_STOCK_FLOOR} has sold recently.</div>`;
  }

  return `
    <div class="table-wrap">
    <table class="data">
      <thead><tr><th>Product</th><th>Category</th><th class="num">Views</th><th class="num">Cart</th>
                 <th class="num">Value</th><th>Last activity</th><th>Suggested action</th></tr></thead>
      <tbody>
      ${rows.slice(0, 30).map((r) => {
        const { action, why } = suggestion(r);
        return `
        <tr>
          <td><strong>${e(shorten(r.name, 40))}</strong><br />
              <small style="color:#999;">${e(money(r.price))}${
                r.stock_qty !== null ? " &times; " + r.stock_qty + " held" : ""}</small></td>
          <td><small>${e(categoryPath(r))}</small></td>
          <td class="num">${r.views}</td>
          <td class="num">${r.cart_adds}</td>
          <td class="num">${e(money(r.price))}</td>
          <td><small>${r.last_seen
            ? e(when(r.last_seen, false))
            : '<span style="color:#c0392b;">never</span>'}</small></td>
          <td>
            <div style="font-size:12px; color:#777; margin-bottom:5px;">${e(why)}</div>
            ${action === "discount"
              ? `<button type="button" class="btn small" data-discount="${r.product_id}">Discount 15%</button>`
              : '<span class="badge out">Halt restock</span>'}
          </td>
        </tr>`;
      }).join("")}
      </tbody>
    </table>
    </div>`;
}

function categoryPath(r) {
  return r.parent ? r.parent + " > " + r.category : r.category;
}

// ------------------------------------------------------------
// Creating a clearance promotion straight from an alert.
//
// The code is derived from the product id, so pressing the button twice
// does not make two promotions — the second insert hits the unique
// constraint on coupons.code and is refused by the database rather than
// by a check here that could be raced.
// ------------------------------------------------------------
function wireDiscountButtons() {
  document.querySelectorAll("button[data-discount]").forEach((button) => {
    button.onclick = async () => {
      const productId = Number(button.dataset.discount);
      if (!confirm("Create a 15% promotion on this category for 30 days?")) return;
      button.disabled = true;

      try {
        // The alert rows come from a function that does not carry the
        // category id, so it is looked up here.
        const { data: product, error: lookupError } = await sb.from("admin_products")
          .select("category_id,category").eq("product_id", productId).single();
        if (lookupError) throw lookupError;

        const code = "CLEAR" + productId;
        const endsAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

        const { error } = await sb.from("coupons").insert({
          code,
          description: `15% off ${product.category} - clearing slow stock`,
          category_id: product.category_id,
          discount_percent: 15,
          ends_at: endsAt,
        });

        if (error && error.code === "23505") {
          reloadWith(`${code} already exists — see Promotions.`);
          return;
        }
        if (error) throw error;

        reloadWith(`Created ${code} — 15% off ${product.category}. ` +
                   "Customers browsing that category will be notified.");
      } catch (error) {
        button.disabled = false;
        alert("Could not create the promotion: " + (error.message || error));
      }
    };
  });
}
