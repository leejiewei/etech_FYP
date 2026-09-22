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
// Signed-in customers come from admin_customer_activity, one row per
// customer per product. Signed-out browsing is read from events as well,
// the way Inventory Velocity counts it, and shown as "Guest shopper":
// one row per browser (anon_id) per product. A guest has no name and
// cannot be messaged, so a deal never reaches one -- but the interest is
// real, and leaving it out hid most of the shop's browsing. When a guest
// signs in, claim_anon_activity moves their rows onto the account and
// they turn into a named customer here.
//
// Nothing on this page writes, and nothing here scores or labels a
// person. It is counting, and the counts are the customer's own actions.
// ============================================================

// Who counts as watching -- saved, carted and not bought, or three views
// -- is watchReason() in admin.js, shared with the Dashboard and kept the
// same as admin_create_deal(), so the "Watching" figure here is the
// number that function would message.

// Long enough to hold a shopping decision, short enough that a card
// somebody abandoned in April is not called interest in September.
const RECENT_DAYS = 60;

adminPage("Customer Behaviour", "behaviour", async (content) => {
  const [named, guestViews, deals] = await Promise.all([
    select(sb.from("admin_customer_activity")
      .select("customer_id,customer_name,customer_email,product_id,product_name,category," +
              "price,views,cart_adds,purchases,first_view,last_seen,in_wishlist,wishlisted_at,deal_price")
      .order("last_seen", { ascending: false })),
    select(sb.from("events")
      .select("anon_id,product_id,created_at,products(name,price,categories(name))")
      .is("customer_id", null)
      .eq("event_type", "view")),
    select(sb.from("deals").select("product_id,discount_price")
      .eq("is_active", 1)
      .lte("start_time", new Date().toISOString())
      .gt("end_time", new Date().toISOString())),
  ]);

  const rows = named.concat(guestRows(guestViews, liveDealPrices(deals)));

  const since = Date.now() - RECENT_DAYS * 86400000;
  const recent = rows.filter((r) => new Date(r.last_seen).getTime() >= since);

  // The rows a deal would reach: saved, carted, or looked at enough times.
  const watching = rows.filter((r) => watchReason(r) !== null);
  const unserved = watching.filter((r) => r.deal_price === null && Number(r.purchases) === 0);

  const customers = new Set(named.map((r) => r.customer_id)).size;
  const guests = new Set(rows.filter((r) => r.guest).map((r) => r.customer_id)).size;
  const totalViews = rows.reduce((t, r) => t + Number(r.views), 0);

  // Most-wanted products: the watchers, grouped by product.
  const byProduct = new Map();
  watching.forEach((r) => {
    let p = byProduct.get(r.product_id);
    if (!p) {
      p = { name: r.product_name, category: r.category, price: r.price,
            deal: r.deal_price, saved: 0, carted: 0, viewers: 0, guests: 0, views: 0 };
      byProduct.set(r.product_id, p);
    }
    const reason = watchReason(r);
    if (r.guest) p.guests++;
    else if (reason === "saved") p.saved++;
    else if (reason === "carted") p.carted++;
    else p.viewers++;
    p.views += Number(r.views);
  });
  const wanted = [...byProduct.entries()]
    .map(([id, p]) => ({ id, ...p, watchers: p.saved + p.carted + p.viewers + p.guests }))
    .sort((a, b) => b.watchers - a.watchers || b.views - a.views)
    .slice(0, 12);
  const wantedMax = Math.max(0, ...wanted.map((p) => p.watchers));

  content.innerHTML = `
    <div class="tiles">
      <div class="tile">
        <div class="label">Watching right now</div>
        <div class="value">${watching.length}</div>
        <div class="sub">Saved, carted, or viewed ${WATCHING_VIEWS}+ times (guests included)</div>
      </div>
      <div class="tile">
        <div class="label">Watching with no deal</div>
        <div class="value">${unserved.length}</div>
        <div class="sub">Not on offer, not yet bought</div>
      </div>
      <div class="tile">
        <div class="label">Views recorded</div>
        <div class="value">${count(totalViews)}</div>
        <div class="sub">${customers} customer${customers === 1 ? "" : "s"}, ${guests} guest${guests === 1 ? "" : "s"}, ${byProduct.size} product${byProduct.size === 1 ? "" : "s"} watched</div>
      </div>
      <div class="tile">
        <div class="label">Active in ${RECENT_DAYS} days</div>
        <div class="value">${recent.length}</div>
        <div class="sub">Shopper-product pairs touched</div>
      </div>
    </div>

    <h2>Most wanted, and whether it is on offer</h2>
    <div class="card">
      ${wanted.length === 0
        ? `<p style="color:#888;">Nobody is watching anything closely enough yet.
             A product needs a wishlist save, a cart add or ${WATCHING_VIEWS} views from one shopper.</p>`
        : wanted.map((p) => `
        <div style="margin-bottom:14px;">
          <div style="display:flex; justify-content:space-between; font-size:13px; margin-bottom:4px; gap:12px;">
            <span><strong>${e(shorten(p.name, 46))}</strong>
              <small style="color:#999;"> ${e(p.category || "")}</small></span>
            <span style="white-space:nowrap;">
              ${p.saved > 0 ? `<span class="badge" style="background:#d6283922; color:#d62839;">${p.saved} saved</span> ` : ""}
              ${p.carted > 0 ? `<span class="badge" style="background:#2c5d8f22; color:#2c5d8f;">${p.carted} in cart</span> ` : ""}
              ${p.viewers > 0 ? `<span style="color:#888;">${p.viewers} watching</span>` : ""}
              ${p.guests > 0 ? `<span style="color:#888;">${p.guests} guest${p.guests === 1 ? "" : "s"}</span>` : ""}
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
          Bar length is how many shoppers are watching, guests included. Amber means nobody
          has put it on offer yet &mdash; creating a deal on the Timed Deals page messages
          every signed-in customer counted here. Guests cannot be messaged.
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
            <td>${r.guest
                  ? `<strong style="color:#888;">Guest shopper</strong><br />
                     <small style="color:#999;">Not signed in &middot; browser ${e(r.customer_id.slice(0, 8))}</small>`
                  : `<strong>${e(r.customer_name)}</strong><br />
                     <small style="color:#999;">${e(r.customer_email)}</small>`}</td>
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
      Guest shoppers are people browsing without signing in, told apart by a random id kept
      in their browser or phone. When one signs in, their history moves onto their account.
    </p>`;
});

// ------------------------------------------------------------
// Signed-out views, shaped like admin_customer_activity rows.
//
// One row per browser per product, so the rest of the page can treat a
// guest exactly like a customer who has only looked. Views with no
// anon_id (storage blocked) cannot be told apart, so they are skipped.
// ------------------------------------------------------------
function guestRows(views, dealPrices) {
  const byKey = new Map();
  views.forEach((v) => {
    if (!v.anon_id || !v.products) return;
    const key = v.anon_id + "|" + v.product_id;
    let r = byKey.get(key);
    if (!r) {
      r = {
        guest: true,
        customer_id: v.anon_id,
        product_id: v.product_id,
        product_name: v.products.name,
        category: v.products.categories ? v.products.categories.name : "",
        price: v.products.price,
        views: 0, cart_adds: 0, purchases: 0,
        first_view: v.created_at, last_seen: v.created_at,
        in_wishlist: false,
        deal_price: dealPrices.has(v.product_id) ? dealPrices.get(v.product_id) : null,
      };
      byKey.set(key, r);
    }
    r.views++;
    if (v.created_at < r.first_view) r.first_view = v.created_at;
    if (v.created_at > r.last_seen) r.last_seen = v.created_at;
  });
  return [...byKey.values()];
}

// The lowest live deal price per product -- the same rule the view uses.
function liveDealPrices(deals) {
  const prices = new Map();
  deals.forEach((d) => {
    const price = Number(d.discount_price);
    if (!prices.has(d.product_id) || price < prices.get(d.product_id)) prices.set(d.product_id, price);
  });
  return prices;
}

