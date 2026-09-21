// ============================================================
// Sales trend and customer segmentation.
//
// Charts are drawn as plain HTML rather than pulled from a charting
// library, so the panel works with no internet connection and there is
// nothing to explain that isn't in this file. That was true when this
// was reports.php and it is still true.
//
// There is deliberately no projected line on this page. There was a
// forecast page beside it once -- a least-squares fit over monthly
// sales -- and it has been removed. Seven months holding 36 orders is
// not enough history for a trend line to mean anything, and a number
// drawn with a straight face is worse than no number at all. What is
// left here is counting, which is true whatever the row count.
//
// Forecast.html is not that page come back. It forecasts from the
// shop's own sales receipts since January 2022 (docs/data/), not from
// the online orders in Supabase, and that longer history is the only
// reason it can carry a projected line at all.
//
// Four aggregates feed this page, and all four are views. A GROUP BY is
// not something a browser can send, and that is a feature rather than an
// obstacle: the shape of each report is fixed in the database, so this
// file can only decide how to draw the numbers, not quietly change what
// they mean.
// ============================================================

// Customers are grouped by WHAT they buy, not by who they say they are.
// Every category is put in one of two baskets; whichever a customer has
// spent more in decides the group. Monitors and Laptops sit in both
// worlds, so they are in neither list and decide nothing.
const GAMING_CATEGORIES = ["Components", "Case Fans", "Accessories", "Gaming Gear"];
const CORPORATE_CATEGORIES = ["Printers", "Consumables", "Monitor Arms", "Projectors", "Networking"];

// The sales trend chart is switched off for now -- flip this back to true
// to bring the "Sales trend" card on this page back. Nothing else on the
// page depends on it; the twelve-month tiles above it keep working.
const SHOW_SALES_TREND = false;

// Somebody whose entire history is under this is treated as a student,
// whatever they bought.
const STUDENT_CEILING = 3000;

const SEGMENT_COLOUR = {
  "Gamer / Enthusiast": "#d62839",
  "Corporate": "#2c5d8f",
  "Student": "#1e8e3e",
};

adminPage("Sales & Customers", "reports", async (content) => {
  const [monthlyAll, bestSellers, byCategory, spend] = await Promise.all([
    select(sb.from("admin_monthly_sales").select("month,orders,units,revenue").order("month")),
    select(sb.from("admin_top_products").select("product_name,units,revenue")
      .order("revenue", { ascending: false }).limit(8)),
    select(sb.from("admin_category_revenue").select("category,revenue,units")
      .order("revenue", { ascending: false })),
    select(sb.from("admin_customer_spend")
      .select("customer_id,customer_name,customer_email,category,spend")),
  ]);

  // The last twelve months. The view returns every month there has ever
  // been a sale; the trim is this page's business.
  const monthly = monthlyAll.slice(-12);

  const totals = monthly.reduce((t, m) => ({
    revenue: t.revenue + num(m.revenue),
    orders:  t.orders + Number(m.orders),
    units:   t.units + Number(m.units),
  }), { revenue: 0, orders: 0, units: 0 });

  const maxRevenue = Math.max(0, ...monthly.map((m) => num(m.revenue)));
  const catMax = Math.max(0, ...byCategory.map((c) => num(c.revenue)));

  const people = segment(spend);
  const buyers = people.length;
  const segments = tally(people);
  const segRevenueMax = Math.max(0, ...Object.values(segments).map((s) => s.revenue));

  content.innerHTML = `
    <div class="tiles">
      <div class="tile">
        <div class="label">Revenue (12 months)</div>
        <div class="value">${e(money(totals.revenue))}</div>
        <div class="sub">${totals.orders} orders, ${totals.units} items</div>
      </div>
      <div class="tile">
        <div class="label">Average order</div>
        <div class="value">${e(money(totals.orders > 0 ? totals.revenue / totals.orders : 0))}</div>
        <div class="sub">Across all orders</div>
      </div>
      <div class="tile">
        <div class="label">Customers who bought</div>
        <div class="value">${buyers}</div>
        <div class="sub">Grouped into ${Object.values(segments).filter((s) => s.count > 0).length} segments</div>
      </div>
    </div>

    ${!SHOW_SALES_TREND ? "" : `
    <h2>Sales trend</h2>
    <div class="card">
      ${monthly.length === 0
        ? `<p style="color:#888;">No sales recorded yet.</p>`
        : `
        <div style="display:flex; align-items:flex-end; gap:14px; height:230px; padding:10px 0 0;">
          ${monthly.map((m) => {
            const height = maxRevenue > 0 ? Math.round(num(m.revenue) / maxRevenue * 180) : 0;
            return `
            <div style="flex:1; text-align:center; display:flex; flex-direction:column; justify-content:flex-end; height:100%;">
              <div style="font-size:11px; color:#666; margin-bottom:4px; white-space:nowrap;">
                ${(num(m.revenue) / 1000).toFixed(1)}k
              </div>
              <div title="${e(money(m.revenue))} from ${m.orders} orders"
                   style="background:linear-gradient(180deg,#d62839,#7a0c1f); height:${Math.max(height, 3)}px;
                          border-radius:4px 4px 0 0;"></div>
              <div style="font-size:11px; color:#888; margin-top:6px;">${e(monthLabel(m.month))}</div>
              <div style="font-size:10px; color:#bbb;">${m.orders} ord</div>
            </div>`;
          }).join("")}
        </div>
        <p class="hint" style="margin:14px 0 0;">
          Monthly revenue, cancelled orders excluded.
        </p>`}
    </div>`}

    <div style="display:flex; gap:20px; flex-wrap:wrap;">
      <div style="flex:1; min-width:340px;">
        <h2>Customer segments</h2>
        <div class="card">
          ${buyers === 0
            ? `<p style="color:#888;">Nobody has bought anything yet.</p>`
            : Object.entries(segments).map(([name, s]) => `
            <div style="margin-bottom:16px;">
              <div style="display:flex; justify-content:space-between; font-size:14px; margin-bottom:5px;">
                <strong style="color:${SEGMENT_COLOUR[name]};">${e(name)}</strong>
                <span>${s.count} customer${s.count === 1 ? "" : "s"} (${Math.round(s.count / buyers * 100)}%)
                  &middot; ${e(money(s.revenue))}</span>
              </div>
              <div style="background:#eef0f3; border-radius:4px; height:16px;">
                <div style="background:${SEGMENT_COLOUR[name]}; width:${barWidth(s.revenue, segRevenueMax)}%;
                            height:16px; border-radius:4px;"></div>
              </div>
            </div>`).join("") + `
            <p class="hint" style="margin:0;">
              Bar length is revenue. Customers are grouped by what they actually buy:
              office equipment means <strong>Corporate</strong>; a small total spend on budget parts means
              <strong>Student</strong>; otherwise <strong>Gamer / Enthusiast</strong>.
            </p>`}
        </div>
      </div>

      <div style="flex:1; min-width:340px;">
        <h2>Revenue by category</h2>
        <div class="card">
          ${byCategory.length === 0
            ? `<p style="color:#888;">No sales yet.</p>`
            : byCategory.map((c) => `
            <div style="margin-bottom:11px;">
              <div style="display:flex; justify-content:space-between; font-size:13px; margin-bottom:3px;">
                <span>${e(c.category)}</span>
                <span style="color:#888;">${e(money(c.revenue))} &middot; ${c.units} items</span>
              </div>
              <div style="background:#eef0f3; border-radius:3px; height:11px;">
                <div style="background:#7a0c1f; width:${barWidth(c.revenue, catMax)}%; height:11px; border-radius:3px;"></div>
              </div>
            </div>`).join("")}
        </div>
      </div>
    </div>

    <h2>Customers</h2>
    <div class="table-wrap">
    <table class="data">
      <thead><tr><th>Customer</th><th>Segment</th><th>Why</th><th>Buys most</th><th class="num">Total spend</th></tr></thead>
      <tbody>
      ${buyers === 0
        ? `<tr><td colspan="5" style="text-align:center; color:#888; padding:24px;">No purchases yet.</td></tr>`
        : people.map((p) => `
        <tr>
          <td><strong>${e(p.name)}</strong><br /><small style="color:#999;">${e(p.email)}</small></td>
          <td><span class="badge" style="background:${SEGMENT_COLOUR[p.segment]}22; color:${SEGMENT_COLOUR[p.segment]};">
            ${e(p.segment)}</span></td>
          <td><small style="color:#777;">${e(p.why)}</small></td>
          <td><small>${e(p.top)}</small></td>
          <td class="num">${e(money(p.total))}</td>
        </tr>`).join("")}
      </tbody>
    </table>
    </div>

    <h2 style="margin-top:26px;">Best sellers</h2>
    <div class="table-wrap">
    <table class="data">
      <thead><tr><th>Product</th><th class="num">Units sold</th><th class="num">Revenue</th></tr></thead>
      <tbody>
      ${bestSellers.map((b) => `
        <tr>
          <td>${e(shorten(b.product_name, 50))}</td>
          <td class="num">${b.units}</td>
          <td class="num">${e(money(b.revenue))}</td>
        </tr>`).join("")}
      </tbody>
    </table>
    </div>`;
});

async function select(query) {
  const { data, error } = await query;
  if (error) throw error;
  return data;
}

// "2026-04" -> "Apr". Built from the string rather than from a Date, so
// no timezone can shift it into the month next door.
function monthLabel(month) {
  const names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                 "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  return names[Number(month.slice(5, 7)) - 1] || month;
}

// ------------------------------------------------------------
// Segmentation.
//
// The view hands back one row per customer per category. Adding those up
// and deciding what each person is happens here, where the rule is
// readable and arguable — which is the right place for a business
// judgement, as opposed to a fact about the data.
// ------------------------------------------------------------
function segment(rows) {
  const people = new Map();

  rows.forEach((row) => {
    let person = people.get(row.customer_id);
    if (!person) {
      person = {
        name: row.customer_name, email: row.customer_email,
        total: 0, gaming: 0, corporate: 0, top: "", topSpend: 0,
      };
      people.set(row.customer_id, person);
    }

    const amount = num(row.spend);
    person.total += amount;
    if (GAMING_CATEGORIES.includes(row.category)) person.gaming += amount;
    if (CORPORATE_CATEGORIES.includes(row.category)) person.corporate += amount;
    if (amount > person.topSpend) { person.topSpend = amount; person.top = row.category; }
  });

  const listed = [...people.values()];

  listed.forEach((p) => {
    if (p.corporate > p.gaming) {
      p.segment = "Corporate";
      p.why = "Most of their spend is on office equipment";
    } else if (p.total < STUDENT_CEILING) {
      p.segment = "Student";
      p.why = "Small total spend on budget parts";
    } else {
      p.segment = "Gamer / Enthusiast";
      p.why = "Mostly PC components, fans and lighting";
    }
  });

  return listed.sort((a, b) => b.total - a.total);
}

function tally(people) {
  const segments = {
    "Gamer / Enthusiast": { count: 0, revenue: 0 },
    "Corporate":          { count: 0, revenue: 0 },
    "Student":            { count: 0, revenue: 0 },
  };
  people.forEach((p) => {
    segments[p.segment].count++;
    segments[p.segment].revenue += p.total;
  });
  return segments;
}
