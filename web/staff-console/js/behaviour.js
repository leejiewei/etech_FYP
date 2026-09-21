// ============================================================
// What shoppers are circling.
//
// Sales & Customers next door groups people by what they bought, which
// is the end of the story and the smallest part of it: of the events
// recorded so far, roughly one in eleven is a purchase. The rest are
// people looking, and looking again, and this page is the only thing
// that reads them.
//
// The question it answers is the one a shop can act on: who keeps coming
// back to what, and is that product on offer yet. Somebody on their
// third visit to the same graphics card is the person a deal is for, and
// creating one on the Timed Deals page now messages exactly these people
// -- wishlist first, then anyone at or above the view threshold below.
// The number in the "Watching" tile is what that deal would reach.
//
// Everything comes from admin_customer_activity, one row per customer
// per product. Signed-out browsing is not in it: events.customer_id is
// NULL for a visitor with no account, and a uuid is not somebody staff
// can act on. When that visitor signs in, claim_anon_activity stitches
// the history onto the account and it appears here.
//
// Nothing on this page writes, and nothing here scores or labels a
// person. It is counting, and the counts are the customer's own actions.
// ============================================================

// Three views of one product is the line between a second look and a
// decision. Kept the same as admin_create_deal()'s p_min_views default,
// so the "Watching" figure here is the number that function would message.
const WATCHING_VIEWS = 3;

// Long enough to hold a shopping decision, short enough that a card
// somebody abandoned in April is not called interest in September.
const RECENT_DAYS = 60;

adminPage("Customer Behaviour", "behaviour", async (content) => {
  const rows = await select(sb.from("admin_customer_activity")
    .select("customer_id,customer_name,customer_email,product_id,product_name,category," +
            "price,views,cart_adds,purchases,first_view,last_seen,in_wishlist,wishlisted_at,deal_price")
    .order("last_seen", { ascending: false }));

  const since = Date.now() - RECENT_DAYS * 86400000;
  const recent = rows.filter((r) => new Date(r.last_seen).getTime() >= since);

  // The rows a deal would reach: saved, or looked at enough times.
  const watching = rows.filter((r) => r.in_wishlist || Number(r.views) >= WATCHING_VIEWS);
  const unserved = watching.filter((r) => r.deal_price === null && Number(r.purchases) === 0);

  const customers = new Set(rows.map((r) => r.customer_id)).size;
  const totalViews = rows.reduce((t, r) => t + Number(r.views), 0);

  // Most-wanted products: the watchers, grouped by product.
  const byProduct = new Map();
  watching.forEach((r) => {
    let p = byProduct.get(r.product_id);
    if (!p) {
      p = { name: r.product_name, category: r.category, price: r.price,
            deal: r.deal_price, saved: 0, viewers: 0, views: 0 };
      byProduct.set(r.product_id, p);
    }
    if (r.in_wishlist) p.saved++; else p.viewers++;
    p.views += Number(r.views);
  });
  const wanted = [...byProduct.entries()]
    .map(([id, p]) => ({ id, ...p, watchers: p.saved + p.viewers }))
    .sort((a, b) => b.watchers - a.watchers || b.views - a.views)
    .slice(0, 12);
  const wantedMax = Math.max(0, ...wanted.map((p) => p.watchers));

  content.innerHTML = `
    <div class="tiles">
      <div class="tile">
        <div class="label">Watching right now</div>
        <div class="value">${watching.length}</div>
        <div class="sub">Saved, or viewed ${WATCHING_VIEWS}+ times</div>
      </div>
      <div class="tile">
        <div class="label">Watching with no deal</div>
        <div class="value">${unserved.length}</div>
        <div class="sub">Not on offer, not yet bought</div>
      </div>
      <div class="tile">
        <div class="label">Views recorded</div>
        <div class="value">${count(totalViews)}</div>
        <div class="sub">${customers} customer${customers === 1 ? "" : "s"}, ${byProduct.size} product${byProduct.size === 1 ? "" : "s"} watched</div>
      </div>
      <div class="tile">
        <div class="label">Active in ${RECENT_DAYS} days</div>
        <div class="value">${recent.length}</div>
        <div class="sub">Customer-product pairs touched</div>
      </div>
    </div>

    <h2>Most wanted, and whether it is on offer</h2>
    <div class="card">
      ${wanted.length === 0
        ? `<p style="color:#888;">Nobody is watching anything closely enough yet.
             A product needs a wishlist save or ${WATCHING_VIEWS} views from one customer.</p>`
        : wanted.map((p) => `
        <div style="margin-bottom:14px;">
          <div style="display:flex; justify-content:space-between; font-size:13px; margin-bottom:4px; gap:12px;">
            <span><strong>${e(shorten(p.name, 46))}</strong>
              <small style="color:#999;"> ${e(p.category || "")}</small></span>
            <span style="white-space:nowrap;">
              ${p.saved > 0 ? `<span class="badge" style="background:#d6283922; color:#d62839;">${p.saved} saved</span> ` : ""}
              ${p.viewers > 0 ? `<span style="color:#888;">${p.viewers} watching</span>` : ""}
              ${p.deal !== null
                ? ` &middot; <strong style="color:#1e8e3e;">on offer ${e(money(p.deal))}</strong>`
                : ` &middot; <span style="color:#b4642a;">${e(money(p.price))}, no deal</span>`}
            </span>
          </div>
          <div style="background:#eef0f3; border-radius:3px; height:12px;">
            <div style="background:${p.deal !== null ? "#1e8e3e" : "#b4642a"};
                        width:${barWidth(p.watchers, wantedMax)}%; height:12px; border-radius:3px;"></div>
          </div>
        </div>`).join("") + `
        <p class="hint" style="margin:0;">
          Bar length is how many customers are watching. Amber means nobody has put it on
          offer yet &mdash; creating a deal on the Timed Deals page messages every customer
          counted here.
        </p>`}
    </div>

    <h2>Who is watching what</h2>
    <div class="table-wrap">
      <table class="data">
        <thead><tr>
          <th>Customer</th><th>Product</th><th class="num">Views</th>
          <th>Signals</th><th>Last seen</th><th class="num">Price</th>
        </tr></thead>
        <tbody>
        ${watching.length === 0
          ? `<tr><td colspan="6" style="text-align:center; color:#888; padding:24px;">
               Nothing watched closely yet.</td></tr>`
          : watching
              .sort((a, b) => new Date(b.last_seen) - new Date(a.last_seen))
              .slice(0, 100)
              .map((r) => `
          <tr>
            <td><strong>${e(r.customer_name)}</strong><br />
                <small style="color:#999;">${e(r.customer_email)}</small></td>
            <td>${e(shorten(r.product_name, 40))}<br />
                <small style="color:#999;">${e(r.category || "")}</small></td>
            <td class="num">${r.views}</td>
            <td>
              ${r.in_wishlist ? `<span class="badge" style="background:#d6283922; color:#d62839;">saved</span> ` : ""}
              ${Number(r.cart_adds) > 0 ? `<span class="badge" style="background:#2c5d8f22; color:#2c5d8f;">carted</span> ` : ""}
              ${Number(r.purchases) > 0 ? `<span class="badge" style="background:#1e8e3e22; color:#1e8e3e;">bought</span>` : ""}
            </td>
            <td><small>${e(when(r.last_seen, false))}</small></td>
            <td class="num">
              ${r.deal_price !== null
                ? `<strong style="color:#1e8e3e;">${e(money(r.deal_price))}</strong>`
                : e(money(r.price))}
            </td>
          </tr>`).join("")}
        </tbody>
      </table>
    </div>
    ${watching.length > 100
      ? `<p class="hint">Showing the 100 most recent of ${watching.length}.</p>`
      : ""}

    <p class="hint" style="margin-top:20px;">
      Signed-out browsing is not counted here. It is recorded against a random id and joins
      the customer's history when they next sign in.
    </p>`;
});

