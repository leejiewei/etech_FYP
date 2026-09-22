// ============================================================
// Dashboard. An at-a-glance summary plus anything needing attention.
//
// admin/index.php opened with eleven separate COUNT queries. A browser
// cannot send a COUNT — PostgREST turns a URL into a SELECT and will not
// take an aggregate written by the client — so those eleven became one
// row of one view, admin_dashboard, and this page makes one request for
// the lot. The sums are the same sums; they just live in the database
// now, where the shape of a report is fixed rather than being whatever
// the page happens to ask for.
// ============================================================

adminPage("Dashboard", "dashboard", async (content) => {
  const [summary, recentOrders, activity] = await Promise.all([
    sb.from("admin_dashboard").select("*").single(),
    sb.from("admin_orders")
      .select("order_id,order_date,status,total,customer_name")
      .order("order_date", { ascending: false }).limit(8),
    sb.from("admin_customer_activity")
      .select("customer_id,product_id,product_name,price,views,cart_adds,purchases,in_wishlist,deal_price"),
  ]);

  if (summary.error) throw summary.error;
  const s = summary.data;
  const orders = recentOrders.data || [];
  const waiting = waitingForADeal(activity.data || []);

  content.innerHTML = `
    <div class="tiles">
      <div class="tile">
        <div class="label">Products</div>
        <div class="value">${count(s.product_count)}</div>
        <div class="sub">${count(s.low_stock)} low · ${count(s.out_of_stock)} out of stock</div>
      </div>
      <div class="tile">
        <div class="label">Orders</div>
        <div class="value">${count(s.order_count)}</div>
        <div class="sub">${count(s.pending_orders)} waiting to be processed</div>
      </div>
      <div class="tile">
        <div class="label">Revenue</div>
        <div class="value">${e(money(s.revenue))}</div>
        <div class="sub">All orders not cancelled</div>
      </div>
      <div class="tile">
        <div class="label">Customers</div>
        <div class="value">${count(s.customer_count)}</div>
        <div class="sub">${count(s.live_coupons)} promotions running</div>
      </div>
    </div>

    ${waitingOnData(s)}

    <div style="display:flex; gap:20px; flex-wrap:wrap;">
      <div style="flex:1; min-width:300px;">
        <h2>Latest orders</h2>
        <div class="table-wrap">
          <table class="data">
            <thead><tr><th>#</th><th>Customer</th><th>Status</th><th class="num">Total</th></tr></thead>
            <tbody>
            ${orders.length === 0
              ? `<tr><td colspan="4" style="text-align:center; color:#888; padding:20px;">No orders yet.</td></tr>`
              : orders.map((o) => `
              <tr>
                <td><a href="orders.html">#${o.order_id}</a></td>
                <td>${e(o.customer_name)}</td>
                <td><span class="badge status-${e(o.status)}">${e(o.status)}</span></td>
                <td class="num">${e(money(o.total))}</td>
              </tr>`).join("")}
            </tbody>
          </table>
        </div>
      </div>

      <div style="flex:1; min-width:300px;">
        <h2>Customers waiting for a deal</h2>
        <p class="hint">
          Signed-in customers who saved, carted or keep viewing a product that is not
          on offer. Put one on offer and each of them is messaged straight away.
          <a href="behaviour.html" style="color:#d62839;">See Customer Behaviour</a>.
        </p>
        <div class="table-wrap">
          <table class="data">
            <thead><tr><th>Product</th><th class="num">Saved</th><th class="num">In cart</th>
                <th class="num">Viewed</th><th class="num">Told</th><th></th></tr></thead>
            <tbody>
            ${waiting.length === 0
              ? `<tr><td colspan="6" style="text-align:center; color:#888; padding:20px;">
                   Nobody is waiting on a product yet.</td></tr>`
              : waiting.map((p) => `
              <tr>
                <td>${e(shorten(p.name, 34))}</td>
                <td class="num">${p.saved || ""}</td>
                <td class="num">${p.carted || ""}</td>
                <td class="num">${p.viewed || ""}</td>
                <td class="num"><strong>${p.total}</strong></td>
                <td><a href="deals.html?product=${p.id}" class="btn small">Put on offer</a></td>
              </tr>`).join("")}
            </tbody>
          </table>
        </div>
      </div>
    </div>`;
});

// Products with somebody waiting on a price drop and no live deal, most
// waited-on first. "Told" is how many customers a deal on it would
// message today -- admin_create_deal() counts the same people.
function waitingForADeal(rows) {
  const byProduct = new Map();
  rows.forEach((r) => {
    const reason = watchReason(r);
    if (!reason || r.deal_price !== null) return;
    let p = byProduct.get(r.product_id);
    if (!p) {
      p = { id: r.product_id, name: r.product_name, saved: 0, carted: 0, viewed: 0, total: 0 };
      byProduct.set(r.product_id, p);
    }
    p[reason]++;
    p.total++;
  });
  return [...byProduct.values()]
    .sort((a, b) => b.total - a.total || b.saved - a.saved || b.carted - a.carted)
    .slice(0, 8);
}

// Two fields were never recorded in the supplier notes, and part of the
// dashboard is waiting on them. Saying so plainly beats showing a zero
// and letting somebody read it as a fact.
function waitingOnData(s) {
  if (!s.missing_cost && !s.missing_qty) return "";

  return `
    <div class="card" style="border-top-color:#b8860b;">
      <h2 style="margin-top:0;">Waiting on data</h2>
      <p class="hint" style="margin-bottom:8px;">
        Two fields were never recorded in the supplier notes, and some of the
        dashboard is waiting on them:
      </p>
      <ul style="font-size:14px; margin-left:20px;">
        ${s.missing_cost ? `<li><strong>${count(s.missing_cost)}</strong> products have no cost price —
          needed for profit margins and for spotting expensive stock that isn't selling.</li>` : ""}
        ${s.missing_qty ? `<li><strong>${count(s.missing_qty)}</strong> products have no stock count —
          the In Stock / Low Stock badges are set by hand until these are entered.</li>` : ""}
      </ul>
      <p style="margin-top:10px;"><a href="products.html" class="btn small">Go to products</a></p>
    </div>`;
}
