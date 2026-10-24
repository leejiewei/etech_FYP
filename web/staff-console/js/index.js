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
//
// The page draws its frame straight away and fills each section as its
// own request comes back, so a slow or failed one shows "Loading" or an
// error in its own card instead of holding up -- or blanking -- the rest.
//
// Every figure is read from Supabase (the online shop) except the Sales
// Forecast card, which is the ML model fitted on the shop's own sales
// receipts (data/ml_forecast.json, as on the Sales Forecast page). The
// two are labelled apart because they are very different sizes: the
// receipts are the whole shop, the orders are the website alone.
// ============================================================

// Revenue counts every order not cancelled, the same rule admin_dashboard
// uses for its revenue figure.
const COUNTS_AS_SALE = (o) => o.status !== "Cancelled";

// The ring's colours are the Orders page's own status badges.
const STATUS_COLOUR = {
  Pending: "#855600",
  Processing: "#2c5d8f",
  Ready: "#6a3fb5",
  Collected: "#1d6b3a",
  Cancelled: "#b3261e",
};

adminPage("Dashboard", "dashboard", async (content) => {
  content.innerHTML = `
    <div class="dash-cards" id="dash-cards">
      ${["Total Revenue", "Total Orders", "Total Customers", "Total Products"].map((label) => `
        <div class="card stat"><div><div class="label">${label}</div>
          <div class="value loading">…</div></div></div>`).join("")}
    </div>

    <div class="dash-row">
      <div class="card" id="sales-card">
        <div class="card-head">
          <h2>Sales Overview</h2>
          <div class="seg" role="group" aria-label="Group sales by">
            ${["day", "week", "month", "year"].map((g) =>
              `<button type="button" data-group="${g}">${{ day: "Daily", week: "Weekly", month: "Monthly", year: "Yearly" }[g]}</button>`).join("")}
          </div>
        </div>
        <div class="range" style="margin-bottom:12px;">
          <label for="sales-from">From</label><input type="date" id="sales-from" />
          <label for="sales-to">to</label><input type="date" id="sales-to" />
        </div>
        <div id="sales-chart"><p class="empty-state loading">Loading sales…</p></div>
      </div>

      <div class="card" id="status-card">
        <div class="card-head"><h2>Order Status</h2><a href="orders.html" class="more">View all</a></div>
        <div id="status-body"><p class="empty-state loading">Loading…</p></div>
      </div>
    </div>

    <div class="dash-row">
      <div class="card">
        <div class="card-head"><h2>Sales Forecast</h2><a href="forecast.html" class="more">Open Sales Forecast</a></div>
        <div id="forecast-chart"><p class="empty-state loading">Loading forecast…</p></div>
      </div>
      <div class="card" id="prediction-card">
        <div class="card-head"><h2>Predicted sales</h2></div>
        <div id="prediction-body"><p class="empty-state loading">Loading…</p></div>
      </div>
    </div>

    <div class="dash-row">
      <div class="card">
        <div class="card-head"><h2>Recent Orders</h2><a href="orders.html" class="more">View all</a></div>
        <div id="recent-body"><p class="empty-state loading">Loading…</p></div>
      </div>
      <div class="card">
        <div class="card-head"><h2>Top Products</h2><a href="reports.html" class="more">View all</a></div>
        <div id="top-body"><p class="empty-state loading">Loading…</p></div>
      </div>
    </div>

    <div id="waiting-data"></div>

    <h2>Customers waiting for a deal</h2>
    <p class="hint">
      Signed-in customers who saved, carted or keep viewing a product that is not
      on offer. Put one on offer and each of them is messaged straight away.
      <a href="behaviour.html" style="color:var(--brand);">See Customer Behaviour</a>.
    </p>
    <div id="waiting-deal"><p class="hint loading">Loading…</p></div>`;

  // Each section is drawn by its own promise; one failing does not stop
  // the others.
  const fail = (slot, what) => (error) => {
    console.error(error);
    document.getElementById(slot).innerHTML =
      `<p class="empty-state" style="color:var(--danger);">${e(what)} could not be loaded. ${e(error.message || "")}</p>`;
  };

  const summary = select(sb.from("admin_dashboard").select("*").single());
  const orders = select(sb.from("admin_orders")
    .select("order_id,order_date,status,total,customer_name")
    .order("order_date", { ascending: false }));

  Promise.all([summary, orders, select(sb.from("customers").select("created_at"))])
    .then(([s, list, customers]) => {
      drawCards(s, list, customers);
      document.getElementById("waiting-data").innerHTML = waitingOnData(s);
    })
    .catch(fail("dash-cards", "The summary"));

  orders.then((list) => salesOverview(list)).catch(fail("sales-chart", "Sales"));
  orders.then((list) => drawRecent(list.slice(0, 5))).catch(fail("recent-body", "Recent orders"));

  select(sb.from("admin_order_status_counts").select("status,orders"))
    .then(drawStatus).catch(fail("status-body", "Order status"));

  loadTopProducts().then(drawTop).catch(fail("top-body", "Top products"));
  loadForecast().catch(fail("forecast-chart", "The forecast"));

  select(sb.from("admin_customer_activity")
    .select("customer_id,product_id,product_name,price,views,cart_adds,purchases,in_wishlist,deal_price"))
    .then((rows) => { document.getElementById("waiting-deal").innerHTML = waitingTable(waitingForADeal(rows)); })
    .catch(fail("waiting-deal", "Customer activity"));
});

// ------------------------------------------------------------
// Dates, in Malaysian time -- the zone the shop trades in.
// ------------------------------------------------------------
function mytDay(timestamp) {
  return new Date(timestamp).toLocaleDateString("en-CA", { timeZone: "Asia/Kuala_Lumpur" });
}
function today() { return mytDay(Date.now()); }

// Day arithmetic on "YYYY-MM-DD" strings, done in UTC so no clock change
// or timezone can move a date into the one next door.
function addDays(day, n) {
  const [y, m, d] = day.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d + n)).toISOString().slice(0, 10);
}
function mondayOf(day) {
  const [y, m, d] = day.split("-").map(Number);
  const weekday = (new Date(Date.UTC(y, m - 1, d)).getUTCDay() + 6) % 7;
  return addDays(day, -weekday);
}
function dayLabel(day) {
  return `${Number(day.slice(8, 10))} ${monthLabel(day.slice(0, 7))}`;
}

// ------------------------------------------------------------
// Summary cards
// ------------------------------------------------------------
function drawCards(s, orders, customers) {
  const now = today();
  const start = addDays(now, -29);
  const before = addDays(now, -59);
  const inLast = (day) => day >= start && day <= now;
  const inPrevious = (day) => day >= before && day < start;

  const sales = orders.filter(COUNTS_AS_SALE);
  const sum = (rows) => rows.reduce((total, o) => total + num(o.total), 0);
  const revenueNow = sum(sales.filter((o) => inLast(mytDay(o.order_date))));
  const revenueThen = sum(sales.filter((o) => inPrevious(mytDay(o.order_date))));
  const ordersNow = orders.filter((o) => inLast(mytDay(o.order_date))).length;
  const ordersThen = orders.filter((o) => inPrevious(mytDay(o.order_date))).length;
  const joinedNow = customers.filter((c) => c.created_at && inLast(mytDay(c.created_at))).length;
  const joinedThen = customers.filter((c) => c.created_at && inPrevious(mytDay(c.created_at))).length;

  const card = (glyph, label, value, sub) => `
    <div class="card stat">
      <span class="chip">${icon(glyph)}</span>
      <div><div class="label">${label}</div><div class="value">${value}</div><div class="change">${sub}</div></div>
    </div>`;

  document.getElementById("dash-cards").innerHTML =
    card("money", "Total Revenue", e(money(s.revenue)), change(revenueNow, revenueThen, "sales")) +
    card("cart", "Total Orders", count(s.order_count), change(ordersNow, ordersThen, "orders")) +
    card("users", "Total Customers", count(s.customer_count), change(joinedNow, joinedThen, "sign-ups")) +
    card("package", "Total Products", count(s.product_count),
      `${count(s.low_stock)} low · ${count(s.out_of_stock)} out of stock`);
}

// The last 30 days against the 30 before. A percentage of nothing is not
// a number, so when the earlier period is empty the card says so in words.
function change(now, then, noun) {
  if (then === 0) {
    return now === 0 ? `No ${noun} in the last 60 days` : `New: none in the 30 days before`;
  }
  const pctChange = ((now - then) / then) * 100;
  const up = pctChange >= 0;
  return `<span class="${up ? "up" : "down"}" title="Last 30 days against the 30 days before">
            ${up ? "▲" : "▼"} ${Math.abs(pctChange).toFixed(1)}%</span> vs previous 30 days`;
}

// ------------------------------------------------------------
// Sales overview: revenue by day, week, month or year
// ------------------------------------------------------------
const DEFAULT_SPAN = { day: 29, week: 7 * 11, month: 365, year: 365 * 4 };

function salesOverview(orders) {
  const sales = orders.filter(COUNTS_AS_SALE).map((o) => ({ day: mytDay(o.order_date), total: num(o.total) }));
  const first = sales.length ? sales[sales.length - 1].day : today();
  const from = document.getElementById("sales-from");
  const to = document.getElementById("sales-to");
  let group = "month";

  const setDefaults = () => {
    to.value = today();
    from.value = group === "year"
      ? `${first.slice(0, 4)}-01-01`
      : addDays(today(), -DEFAULT_SPAN[group]);
  };

  const draw = () => {
    document.querySelectorAll("#sales-card .seg button").forEach((b) =>
      b.classList.toggle("on", b.dataset.group === group));
    document.getElementById("sales-chart").innerHTML = salesChart(sales, group, from.value, to.value);
  };

  document.querySelectorAll("#sales-card .seg button").forEach((b) => {
    b.onclick = () => { group = b.dataset.group; setDefaults(); draw(); };
  });
  from.onchange = draw;
  to.onchange = draw;
  setDefaults();
  draw();
}

function bucketOf(day, group) {
  if (group === "day") return day;
  if (group === "week") return mondayOf(day);
  if (group === "month") return day.slice(0, 7);
  return day.slice(0, 4);
}

function bucketLabel(key, group) {
  if (group === "day") return dayLabel(key);
  if (group === "week") return dayLabel(key);
  if (group === "month") return monthLabel(key, true);
  return key;
}

function salesChart(sales, group, from, to) {
  if (!from || !to || from > to) {
    return `<p class="empty-state">Choose a start date before the end date.</p>`;
  }

  // Every bucket in the range, empty ones included, so a quiet week shows
  // as zero rather than the line skipping over it.
  const keys = [];
  for (let day = from; day <= to && keys.length < 400; day = addDays(day, 1)) {
    const key = bucketOf(day, group);
    if (keys[keys.length - 1] !== key) keys.push(key);
  }
  if (keys.length >= 400) {
    return `<p class="empty-state">That is too many days to draw one by one. Try Weekly or Monthly.</p>`;
  }

  const totals = Object.fromEntries(keys.map((k) => [k, { revenue: 0, orders: 0 }]));
  let revenue = 0, orderCount = 0;
  sales.forEach((s) => {
    if (s.day < from || s.day > to) return;
    const bucket = totals[bucketOf(s.day, group)];
    if (!bucket) return;
    bucket.revenue += s.total;
    bucket.orders += 1;
    revenue += s.total;
    orderCount += 1;
  });

  if (orderCount === 0) {
    return `<p class="empty-state">No online sales between ${e(dayLabel(from))} ${e(from.slice(0, 4))}
      and ${e(dayLabel(to))} ${e(to.slice(0, 4))}.</p>`;
  }

  const rows = keys.map((k) => ({
    label: bucketLabel(k, group),
    tip: `${bucketLabel(k, group)} (${totals[k].orders} order${totals[k].orders === 1 ? "" : "s"})`,
    actual: Math.round(totals[k].revenue * 100) / 100,
  }));

  return `
    <p class="chart-total"><strong>${e(money(revenue))}</strong> from ${count(orderCount)} order${orderCount === 1 ? "" : "s"}
      (cancelled orders left out)</p>
    ${lineChart(rows, {
      height: 240, area: true, colour: COLOUR_FORECAST, minWidth: 480, name: "sales",
      dots: rows.length <= 40, labelEvery: Math.max(1, Math.ceil(rows.length / 8)),
    })}`;
}

// ------------------------------------------------------------
// Order status
// ------------------------------------------------------------
function drawStatus(rows) {
  const byStatus = Object.fromEntries(rows.map((r) => [r.status, Number(r.orders)]));
  const slices = Object.keys(STATUS_COLOUR).map((status) => ({
    label: status, value: byStatus[status] || 0, colour: STATUS_COLOUR[status],
  }));
  const total = slices.reduce((sum, s) => sum + s.value, 0);

  document.getElementById("status-body").innerHTML = total === 0
    ? `<p class="empty-state">No orders yet.</p>`
    : `
      <div class="status-wrap">
        ${doughnut(slices, count(total), total === 1 ? "order" : "orders")}
        <ul class="status-legend">
          ${slices.map((s) => `
            <li><span class="dot" style="background:${s.colour};"></span>
              <a href="orders.html?status=${encodeURIComponent(s.label)}">${e(s.label)}</a>
              <span class="n">${s.value} · ${Math.round((s.value / total) * 100)}%</span></li>`).join("")}
        </ul>
      </div>`;
}

// ------------------------------------------------------------
// Sales forecast, from the ML model (the Sales Forecast page's file)
// ------------------------------------------------------------
async function loadForecast() {
  const response = await fetch("data/ml_forecast.json", { cache: "no-store" });
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  const data = await response.json();
  let checks = [];
  try {
    const checked = await fetch("data/forecast_checks.json", { cache: "no-store" });
    if (checked.ok) checks = (await checked.json()).checks || [];
  } catch (error) {
    // Optional, as on the Sales Forecast page.
  }

  const coming = data.nextMonths || (data.nextMonth ? [data.nextMonth] : []);
  // The last year of the backtest, then the months ahead.
  const rows = monthlyRows(data.monthly || [], checks, coming).slice(-18);

  document.getElementById("forecast-chart").innerHTML = rows.length === 0
    ? `<p class="empty-state">The forecast file has no months in it.</p>`
    : `${lineChart(rows, { height: 240, minWidth: 480 })}
       ${legend(coming.length > 0)}
       <p class="hint" style="margin:10px 0 0;">
         From the shop's own sales receipts, which cover far more than the website's orders above.
         Monthly accuracy ${e(data.metrics && data.metrics.monthlyAccuracy)}% on months the model had never seen.
       </p>`;

  // This month if the model covers it, otherwise the next one it does.
  const thisMonth = today().slice(0, 7);
  const at = Math.max(0, coming.findIndex((m) => m.month >= thisMonth));
  const shown = coming.slice(at, at + 2);
  document.getElementById("prediction-body").innerHTML = shown.length === 0
    ? `<p class="empty-state">No months ahead in the forecast file.</p>`
    : shown.map((m, i) => `
        <div style="${i ? "border-top:1px solid var(--line); padding-top:14px; margin-top:14px;" : ""}">
          <div class="label" style="font-size:13px; color:var(--ink-3);">${e(m.label)}${m.month === thisMonth ? " (this month)" : ""}</div>
          <div class="forecast-figure">${e(money(m.revenue))}</div>
          <div style="font-size:13px; color:var(--ink-3);">likely ${e(money(m.low))} to ${e(money(m.high))}</div>
        </div>`).join("") + `
      <p class="hint" style="margin:14px 0 0;">Model fitted on receipts up to ${e(shown[0].fittedTo)}.</p>`;
}

// ------------------------------------------------------------
// Recent orders
// ------------------------------------------------------------
async function drawRecent(orders) {
  const slot = document.getElementById("recent-body");
  if (orders.length === 0) {
    slot.innerHTML = `<p class="empty-state">No orders yet.</p>`;
    return;
  }

  const lines = await select(sb.from("order_items")
    .select("order_id,product_name,quantity")
    .in("order_id", orders.map((o) => o.order_id)).order("order_item_id"));
  const linesFor = {};
  lines.forEach((l) => (linesFor[l.order_id] ||= []).push(l));

  slot.innerHTML = `
    <div style="overflow-x:auto;">
      <table class="data" style="min-width:560px;">
        <thead><tr><th>Order ID</th><th>Customer</th><th>Product</th><th>Status</th>
          <th class="num">Amount</th><th></th></tr></thead>
        <tbody>
        ${orders.map((o) => {
          const items = linesFor[o.order_id] || [];
          const product = items.length === 0 ? "—"
            : shorten(items[0].product_name, 28) + (items.length > 1 ? ` +${items.length - 1} more` : "");
          return `
          <tr>
            <td><a href="orders.html?order=${o.order_id}" style="color:var(--brand); font-weight:600;">#${o.order_id}</a></td>
            <td>${e(o.customer_name)}</td>
            <td>${e(product)}</td>
            <td><span class="badge status-${e(o.status)}">${e(o.status)}</span></td>
            <td class="num">${e(money(o.total))}</td>
            <td><a href="orders.html?order=${o.order_id}" class="btn small ghost">View</a></td>
          </tr>`;
        }).join("")}
        </tbody>
      </table>
    </div>`;
}

// ------------------------------------------------------------
// Top products: most units sold, cancelled orders left out
// ------------------------------------------------------------
async function loadTopProducts() {
  const lines = await select(sb.from("order_items")
    .select("product_id,product_name,quantity,line_total,orders!inner(status),products(image_path,img_slug)")
    .neq("orders.status", "Cancelled"));
  const byProduct = new Map();
  lines.forEach((l) => {
    let p = byProduct.get(l.product_id);
    if (!p) {
      p = { id: l.product_id, name: l.product_name, units: 0, revenue: 0,
            image: (l.products && l.products.image_path) ||
                   `../images/${(l.products && l.products.img_slug) || "default"}.svg` };
      byProduct.set(l.product_id, p);
    }
    p.units += Number(l.quantity);
    p.revenue += num(l.line_total);
  });
  return [...byProduct.values()].sort((a, b) => b.units - a.units || b.revenue - a.revenue).slice(0, 5);
}

function drawTop(products) {
  const slot = document.getElementById("top-body");
  if (products.length === 0) {
    slot.innerHTML = `<p class="empty-state">Nothing sold yet.</p>`;
    return;
  }
  const most = products[0].units;
  slot.innerHTML = `
    <ul class="top-list">
      ${products.map((p) => `
        <li>
          <img src="${e(p.image)}" alt="" loading="lazy" onerror="this.src='../images/default.svg'" />
          <div class="body">
            <div class="name" title="${e(p.name)}">${e(p.name)}</div>
            <div class="bar"><span style="width:${Math.max(4, Math.round((p.units / most) * 100))}%;"></span></div>
          </div>
          <div class="sold"><strong>${count(p.units)}</strong> sold<br />${e(money(p.revenue))}</div>
        </li>`).join("")}
    </ul>`;
}

// ------------------------------------------------------------
// Customers waiting for a deal
// ------------------------------------------------------------

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

function waitingTable(waiting) {
  return `
    <div class="table-wrap">
      <table class="data">
        <thead><tr><th>Product</th><th class="num">Saved</th><th class="num">In cart</th>
            <th class="num">Viewed</th><th class="num">Told</th><th></th></tr></thead>
        <tbody>
        ${waiting.length === 0
          ? `<tr><td colspan="6" style="text-align:center; color:var(--ink-3); padding:20px;">
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
    </div>`;
}

// Two fields were never recorded in the supplier notes, and part of the
// dashboard is waiting on them. Saying so plainly beats showing a zero
// and letting somebody read it as a fact.
function waitingOnData(s) {
  if (!s.missing_cost && !s.missing_qty) return "";

  return `
    <div class="card">
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
