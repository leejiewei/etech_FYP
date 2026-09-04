// ============================================================
// Demand forecast.
//
// METHOD — least-squares linear regression.
//
// This fits a straight line through the monthly sales figures by
// choosing the slope and intercept that make the total squared error as
// small as possible. The coefficients are learned from the data rather
// than set by hand, which is what makes it a (very simple) supervised
// machine-learning model — the one every course starts with, before
// anything more elaborate.
//
//     revenue = intercept + (slope x month number)
//
// A neural network or similar would need thousands of examples to beat
// this. With a handful of months, a straight line plus an honest
// confidence figure is the defensible choice.
//
// R-squared says how much of the month-to-month movement the line
// actually explains, from 0 (none — the line is guessing) to 1
// (perfect). It is shown on the page so nobody mistakes a weak fit for a
// firm prediction.
//
// A three-month moving average is calculated alongside it as a sanity
// check: if the two disagree wildly, the trend is not stable.
//
// All of this arithmetic used to be PHP and is now JavaScript, unchanged
// line for line. What moved into the database is only the counting —
// admin_monthly_sales and admin_category_monthly — because a GROUP BY is
// the one thing a browser cannot ask for.
// ============================================================

const AHEAD_OPTIONS = [3, 6];

adminPage("Sales Forecast", "forecast", async (content) => {
  const q = params();
  const ahead = AHEAD_OPTIONS.includes(Number(q.ahead)) ? Number(q.ahead) : 3;
  const metric = q.metric === "units" ? "units" : "revenue";

  const [history, categoryRows] = await Promise.all([
    select(sb.from("admin_monthly_sales").select("month,orders,units,revenue").order("month")),
    select(sb.from("admin_category_monthly").select("category,month,revenue")
      .order("category").order("month")),
  ]);

  const n = history.length;
  const series = history.map((m) => num(m[metric]));
  const fit = fitLine(series);

  // Three-month moving average, as a second opinion.
  const movingAvg = n >= 3
    ? series.slice(-3).reduce((a, b) => a + b, 0) / 3
    : null;

  const projection = project(fit, history, ahead);
  const trust = confidence(fit, n);

  content.innerHTML = `
    <div class="card" style="border-top-color:#2c5d8f;">
      <h2 style="margin-top:0;">How this is worked out</h2>
      <p style="font-size:14px;">
        The forecast fits a straight line through past monthly sales using
        <strong>least-squares linear regression</strong> &mdash; it picks the slope and starting point
        that leave the smallest total error against the real figures. The coefficients are learned
        from the data rather than chosen by hand, which is what makes it a supervised
        machine-learning model, albeit the simplest one there is.
      </p>
      <p style="font-family:monospace; background:#f4f6f8; padding:12px 16px; border-radius:6px; font-size:15px;">
        ${metric} = intercept + (slope &times; month number)
      </p>
      <p class="hint" style="margin-bottom:0;">
        Something heavier &mdash; a neural network, say &mdash; would need thousands of months to beat a
        straight line here. What matters more than the model is being honest about the fit, so
        <strong>R&sup2;</strong> is shown below: it says how much of the month-to-month movement the line
        actually explains, from 0 (guessing) to 1 (perfect).
      </p>
    </div>

    <form class="filters" id="filters">
      <div class="field">
        <label>Forecast</label>
        <select name="metric">
          <option value="revenue" ${metric === "revenue" ? "selected" : ""}>Revenue</option>
          <option value="units"   ${metric === "units"   ? "selected" : ""}>Units sold (demand)</option>
        </select>
      </div>
      <div class="field">
        <label>Months ahead</label>
        <select name="ahead">
          ${AHEAD_OPTIONS.map((a) =>
            `<option value="${a}" ${ahead === a ? "selected" : ""}>${a} months</option>`).join("")}
        </select>
      </div>
    </form>

    ${fit === null ? notEnoughHistory(n) : `
      ${tiles(fit, projection, trust, movingAvg, n, metric)}
      ${trustCard(trust, projection, movingAvg)}
      ${chart(history, projection, metric)}
      ${working(history, projection, fit, n, metric)}
      ${categoryOutlook(categoryRows, history)}
    `}`;

  document.querySelectorAll("#filters select").forEach((select) => {
    select.onchange = () => {
      const form = document.getElementById("filters");
      window.location.search = new URLSearchParams({
        metric: form.metric.value, ahead: form.ahead.value,
      }).toString();
    };
  });
});

async function select(query) {
  const { data, error } = await query;
  if (error) throw error;
  return data;
}

// ------------------------------------------------------------
// The model
// ------------------------------------------------------------
function fitLine(points) {
  const n = points.length;
  if (n < 2) return null;

  let sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
  points.forEach((y, i) => { sumX += i; sumY += y; sumXY += i * y; sumXX += i * i; });

  const denominator = (n * sumXX) - (sumX * sumX);
  if (denominator === 0) return null;

  const slope = ((n * sumXY) - (sumX * sumY)) / denominator;
  const intercept = (sumY - (slope * sumX)) / n;

  // R-squared: how much of the variation the line accounts for.
  const mean = sumY / n;
  let ssTot = 0, ssRes = 0;
  points.forEach((y, i) => {
    const predicted = intercept + (slope * i);
    ssTot += (y - mean) ** 2;
    ssRes += (y - predicted) ** 2;
  });
  const r2 = ssTot > 0 ? 1 - (ssRes / ssTot) : 0;

  return { slope, intercept, r2: Math.max(0, r2), mean };
}

function project(fit, history, ahead) {
  if (fit === null) return [];

  const n = history.length;
  const last = history[n - 1].month;              // "YYYY-MM"
  const projection = [];

  for (let k = 1; k <= ahead; k++) {
    const x = n - 1 + k;
    projection.push({
      month: addMonths(last, k),
      value: Math.max(0, fit.intercept + (fit.slope * x)),   // sales cannot go negative
    });
  }
  return projection;
}

// Month arithmetic on the "YYYY-MM" string, so no timezone can push a
// projection into the month next door.
function addMonths(month, add) {
  const year = Number(month.slice(0, 4));
  const index = Number(month.slice(5, 7)) - 1 + add;
  const shifted = new Date(Date.UTC(year, index, 1));
  return shifted.getUTCFullYear() + "-" + String(shifted.getUTCMonth() + 1).padStart(2, "0");
}

function monthLabel(month, withYear = false) {
  const names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                 "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  const name = names[Number(month.slice(5, 7)) - 1] || month;
  return withYear ? name + " " + month.slice(0, 4) : name;
}

function confidence(fit, n) {
  if (fit === null) {
    return { level: "none", colour: "#98a0aa",
      note: "Not enough months of sales to draw a line through yet." };
  }
  if (n < 6) {
    return { level: "low", colour: "#c0392b",
      note: `Only ${n} months of sales. That is enough to compute a line but not enough to trust it — ` +
            "treat this as a rough direction, not a number to order stock against." };
  }
  if (fit.r2 < 0.3) {
    return { level: "low", colour: "#c0392b",
      note: "The months vary too much for a straight line to describe them. " +
            "The projection is shown, but the trend is weak." };
  }
  if (fit.r2 < 0.6) {
    return { level: "moderate", colour: "#b8860b",
      note: "There is a visible trend, but a fair amount of month-to-month movement around it." };
  }
  return { level: "good", colour: "#1e8e3e",
    note: "The months follow the trend line closely, so the projection is reasonably firm." };
}

// ------------------------------------------------------------
// Drawing it
// ------------------------------------------------------------
function showValue(value, metric) {
  return metric === "revenue" ? money(value) : Math.round(value).toLocaleString("en-MY") + " items";
}

function shortValue(value, metric) {
  return metric === "revenue" ? (value / 1000).toFixed(1) + "k" : String(Math.round(value));
}

function notEnoughHistory(n) {
  return `
    <div class="card" style="border-top-color:#c0392b;">
      <strong>Not enough sales history yet.</strong>
      <p style="font-size:14px; margin-top:6px;">
        A forecast needs at least two months with sales in them. There ${n === 1 ? "is" : "are"}
        currently ${n}. The page will start working on its own as orders come in.
      </p>
    </div>`;
}

function tiles(fit, projection, trust, movingAvg, n, metric) {
  const growing = fit.slope >= 0;

  return `
    <div class="tiles">
      <div class="tile">
        <div class="label">Next month (${e(monthLabel(projection[0].month, true))})</div>
        <div class="value">${e(showValue(projection[0].value, metric))}</div>
        <div class="sub">Projected from the trend line</div>
      </div>
      <div class="tile" style="border-top-color:${growing ? "#1e8e3e" : "#c0392b"};">
        <div class="label">Direction</div>
        <div class="value" style="color:${growing ? "#1e8e3e" : "#c0392b"};">
          ${growing ? "&#9650;" : "&#9660;"}
          ${e(showValue(Math.abs(fit.slope), metric))}
        </div>
        <div class="sub">Change per month${growing ? ", growing" : ", falling"}</div>
      </div>
      <div class="tile" style="border-top-color:${trust.colour};">
        <div class="label">Confidence (R&sup2;)</div>
        <div class="value" style="color:${trust.colour};">${fit.r2.toFixed(2)}</div>
        <div class="sub">${trust.level.charAt(0).toUpperCase() + trust.level.slice(1)} &mdash; based on ${n} months</div>
      </div>
      ${movingAvg === null ? "" : `
      <div class="tile" style="border-top-color:#6c7581;">
        <div class="label">3-month average</div>
        <div class="value">${e(showValue(movingAvg, metric))}</div>
        <div class="sub">Second opinion, ignoring the trend</div>
      </div>`}
    </div>`;
}

function trustCard(trust, projection, movingAvg) {
  let disagreement = "";

  if (movingAvg !== null && projection[0].value > 0) {
    const gap = Math.abs(projection[0].value - movingAvg) / Math.max(movingAvg, 1) * 100;
    if (gap > 40) {
      disagreement = `
        <p style="font-size:14px; margin-top:8px; color:#c0392b;">
          The line and the three-month average disagree by ${Math.round(gap)}%, which means recent
          months are not following the longer trend. Treat the projection with extra care.
        </p>`;
    }
  }

  return `
    <div class="card" style="border-top-color:${trust.colour};">
      <strong style="color:${trust.colour};">How much to trust this:</strong>
      <span style="font-size:14px;">${e(trust.note)}</span>
      ${disagreement}
    </div>`;
}

function chart(history, projection, metric) {
  const chartMax = Math.max(
    0,
    ...history.map((m) => num(m[metric])),
    ...projection.map((p) => p.value));

  const height = (value) => Math.max(chartMax > 0 ? Math.round(value / chartMax * 190) : 0, 3);

  return `
    <h2>History and projection</h2>
    <div class="card">
      <div style="display:flex; align-items:flex-end; gap:10px; height:250px; padding-top:10px;">
        ${history.map((m) => {
          const value = num(m[metric]);
          return `
          <div style="flex:1; text-align:center; display:flex; flex-direction:column; justify-content:flex-end; height:100%;">
            <div style="font-size:10px; color:#666; margin-bottom:4px;">${shortValue(value, metric)}</div>
            <div title="Actual: ${e(showValue(value, metric))}"
                 style="background:linear-gradient(180deg,#d62839,#7a0c1f); height:${height(value)}px; border-radius:4px 4px 0 0;"></div>
            <div style="font-size:10px; color:#888; margin-top:5px;">${e(monthLabel(m.month))}</div>
          </div>`;
        }).join("")}

        ${projection.map((p) => `
          <div style="flex:1; text-align:center; display:flex; flex-direction:column; justify-content:flex-end; height:100%;">
            <div style="font-size:10px; color:#2c5d8f; margin-bottom:4px;">${shortValue(p.value, metric)}</div>
            <div title="Projected: ${e(showValue(p.value, metric))}"
                 style="background:repeating-linear-gradient(45deg,#aec6e0,#aec6e0 5px,#cddcea 5px,#cddcea 10px);
                        border:2px dashed #2c5d8f; border-bottom:none; height:${height(p.value)}px; border-radius:4px 4px 0 0;"></div>
            <div style="font-size:10px; color:#2c5d8f; margin-top:5px;">${e(monthLabel(p.month))}</div>
          </div>`).join("")}
      </div>
      <p class="hint" style="margin:14px 0 0;">
        Solid red is what actually happened. Hatched blue is the projection.
      </p>
    </div>`;
}

function working(history, projection, fit, n, metric) {
  return `
    <h2>The working</h2>
    <p class="hint">Every number above comes from these figures, so the calculation can be checked by hand.</p>
    <div class="table-wrap">
    <table class="data">
      <thead><tr><th>Month</th><th>#</th><th class="num">Actual</th><th class="num">Line says</th>
                 <th class="num">Difference</th><th></th></tr></thead>
      <tbody>
      ${history.map((m, i) => {
        const actual = num(m[metric]);
        const predicted = fit.intercept + (fit.slope * i);
        const diff = actual - predicted;
        return `
        <tr>
          <td>${e(monthLabel(m.month, true))}</td>
          <td>${i}</td>
          <td class="num">${e(showValue(actual, metric))}</td>
          <td class="num" style="color:#888;">${e(showValue(Math.max(predicted, 0), metric))}</td>
          <td class="num" style="color:${diff >= 0 ? "#1e8e3e" : "#c0392b"};">
            ${diff >= 0 ? "+" : "&minus;"}${e(showValue(Math.abs(diff), metric))}
          </td>
          <td><span class="badge grey">actual</span></td>
        </tr>`;
      }).join("")}
      ${projection.map((p, k) => `
        <tr style="background:#f7fafd;">
          <td><strong>${e(monthLabel(p.month, true))}</strong></td>
          <td>${n + k}</td>
          <td class="num" style="color:#bbb;">&mdash;</td>
          <td class="num"><strong>${e(showValue(p.value, metric))}</strong></td>
          <td class="num" style="color:#bbb;">&mdash;</td>
          <td><span class="badge" style="background:#eaf2fb; color:#2c5d8f;">forecast</span></td>
        </tr>`).join("")}
      </tbody>
    </table>
    </div>

    <p class="hint" style="margin-top:12px;">
      Fitted line: <code>${metric} = ${fit.intercept.toFixed(2)}
      ${fit.slope >= 0 ? "+" : "&minus;"} ${Math.abs(fit.slope).toFixed(2)} &times; month</code>
      &nbsp;·&nbsp; R&sup2; = ${fit.r2.toFixed(4)}
    </p>`;
}

// The same line fitted separately to each category. A category with no
// sales in a month gets a zero rather than being skipped, so a gap
// counts as a bad month instead of quietly disappearing.
function categoryOutlook(rows, history) {
  const allMonths = history.map((m) => m.month);
  const grouped = {};
  rows.forEach((r) => {
    (grouped[r.category] ||= {})[r.month] = num(r.revenue);
  });

  const trends = [];
  for (const [category, months] of Object.entries(grouped)) {
    const points = allMonths.map((m) => months[m] || 0);
    const fit = fitLine(points);
    if (fit === null) continue;
    trends.push({
      category,
      slope: fit.slope,
      total: points.reduce((a, b) => a + b, 0),
      r2: fit.r2,
    });
  }
  trends.sort((a, b) => b.slope - a.slope);

  const biggest = Math.max(0, ...trends.map((t) => Math.abs(t.slope)));

  return `
    <h2 style="margin-top:26px;">Which categories are moving</h2>
    <p class="hint">
      The same line fitted separately to each category, so you can see what is picking up and what is
      falling away. Sorted by change per month.
    </p>
    <div class="table-wrap">
    <table class="data">
      <thead><tr><th>Category</th><th class="num">Total sold</th><th class="num">Change / month</th>
                 <th style="width:190px;">Direction</th><th class="num">R&sup2;</th></tr></thead>
      <tbody>
      ${trends.length === 0
        ? `<tr><td colspan="5" style="text-align:center; color:#888; padding:22px;">No category has enough sales yet.</td></tr>`
        : trends.map((t) => {
          const width = biggest > 0 ? Math.round(Math.abs(t.slope) / biggest * 50) : 0;
          const up = t.slope >= 0;
          return `
          <tr>
            <td>${e(t.category)}</td>
            <td class="num">${e(money(t.total))}</td>
            <td class="num" style="color:${up ? "#1e8e3e" : "#c0392b"};">
              ${up ? "+" : "&minus;"}${e(money(Math.abs(t.slope)))}
            </td>
            <td>
              <div style="display:flex; align-items:center; height:12px;">
                <div style="width:50%; display:flex; justify-content:flex-end;">
                  ${!up ? `<div style="background:#c0392b; width:${width}%; height:12px; border-radius:3px 0 0 3px;"></div>` : ""}
                </div>
                <div style="width:1px; height:16px; background:#ccd1d7;"></div>
                <div style="width:50%;">
                  ${up ? `<div style="background:#1e8e3e; width:${width}%; height:12px; border-radius:0 3px 3px 0;"></div>` : ""}
                </div>
              </div>
            </td>
            <td class="num" style="color:#999;">${t.r2.toFixed(2)}</td>
          </tr>`;
        }).join("")}
      </tbody>
    </table>
    </div>`;
}
