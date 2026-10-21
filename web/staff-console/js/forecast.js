// ============================================================
// Sales forecast and the four customer groups.
//
// Every other page in this console reads Supabase, which holds the online
// shop: a few dozen orders across a handful of months. This page does
// not, and the reason is the same one that removed the old forecast page
// -- a trend line over that much history is a number with nothing behind
// it.
//
// What it reads instead is web/staff-console/data/ml_forecast.json,
// written by tools/export_ml_to_web.py from the models in ml/. Those are
// fitted on the shop's own sales receipts from January 2022 to August
// 2026 (docs/data/etech_sales_data.xlsx), which reach back far further
// than the online orders do.
//
// Nothing here writes. The page cannot change an order, a price or a
// stock level, so a wrong model costs a misleading chart and nothing more.
//
// Charts are plain HTML, like the rest of the console -- no charting
// library, nothing to fetch, and nothing to explain that is not in this
// file.
// ============================================================

const FORECAST_DATA = "data/ml_forecast.json";

// ------------------------------------------------------------
// The one number somebody came to this page for.
//
// Everything below it on the page is a backtest -- the model predicting
// weeks that already happened, which is how the accuracy figures are
// earned but is not a forecast of anything. This card is the forecast,
// refitted on the whole series and run forward, and it is at the top
// because "what will next month be" is the question, not "how did the
// model do".
//
// The card opens on a button rather than a number. Each press predicts
// one month further on, up to the six the export script writes; the
// previous button steps back. The months are already in the JSON, so a
// press only changes which one is drawn -- nothing is fitted in the
// browser.
//
// It is written to be hard to quote out of context. The band, the week
// count, the date the data stops and the basis of the year-on-year
// comparison are all on the card rather than in a footnote, because a
// single big number lifted into a slide with none of those attached is
// exactly how a forecast stops being honest.
// ------------------------------------------------------------
function predictionCard(months, shown) {
  if (months.length === 0) return "";

  const header = `
    <div style="display:flex; justify-content:space-between; align-items:center; gap:10px; flex-wrap:wrap;">
      <div style="font-size:13px; color:#888; text-transform:uppercase; letter-spacing:.04em;">
        ${shown < 0 ? "Sales prediction" : `Predicted sales &mdash; ${e(months[shown].label)}`}
      </div>
      <div style="display:flex; gap:8px;">
        ${shown > 0 ? `<button type="button" class="btn small grey" id="predict-prev">&#9664; Previous month</button>` : ""}
        ${shown < months.length - 1
          ? `<button type="button" class="btn small" id="predict-next">
               ${shown < 0 ? "Predict next month" : "Predict the month after &#9654;"}</button>`
          : ""}
      </div>
    </div>`;

  if (shown < 0) {
    return `
      <div class="card" style="border-left:4px solid ${COLOUR_FORECAST};">
        ${header}
        <p class="hint" style="margin:10px 0 0;">
          The sales receipts run to ${e(months[0].fittedTo)}. Press the button to predict
          ${e(months[0].label)}, then keep pressing to look up to ${months.length} months ahead.
        </p>
      </div>`;
  }

  const n = months[shown];
  // The same month a year earlier, spelled the way monthLabel expects.
  const lastYear = (Number(n.month.slice(0, 4)) - 1) + n.month.slice(4);

  // Down is not automatically bad news and up is not automatically good,
  // so the arrow is coloured by direction and left to speak for itself.
  const change = n.changePct === null || n.changePct === undefined
    ? ""
    : `<div style="font-size:13px; color:${n.changePct < 0 ? "#c0392b" : "#1e8e3e"}; margin-top:6px;">
         ${n.changePct < 0 ? "▼" : "▲"} ${e(Math.abs(n.changePct))}% ${e(n.changeBasis || "per week")}
         against ${e(monthLabel(lastYear, true))}
         (${e(money(n.priorYearPerWeek))} a week, over ${e(n.priorYearWeeks)} weeks)
       </div>`;

  return `
    <div class="card" style="border-left:4px solid ${COLOUR_FORECAST};">
      ${header}
      <div style="font-size:34px; font-weight:bold; margin:6px 0 2px; color:${COLOUR_FORECAST};">
        ${e(money(n.revenue))}
      </div>
      <div style="font-size:13px; color:#555;">
        somewhere between <strong>${e(money(n.low))}</strong> and
        <strong>${e(money(n.high))}</strong>
        &nbsp;·&nbsp; ${e(money(n.perWeek))} a week across ${e(n.weeks)} weeks
      </div>
      ${change}
      <div class="hint" style="margin:12px 0 0;">
        Month ${shown + 1} of ${months.length} ahead. The range is this model's own monthly
        error on months it had never seen (WAPE ${e(pct(n.bandPct))}), not a confidence
        interval. Fitted on all ${e(n.fittedWeeks)} weeks up to ${e(n.fittedTo)}; a week counts
        towards the month its Monday falls in, which is why ${e(n.label)} is
        ${e(n.weeks)} weeks and not four-and-a-bit.
      </div>
    </div>`;
}

// Draws the card into its slot and wires whichever buttons it has. Called
// again on every press, so the listeners always belong to the buttons on
// screen.
function showPrediction(slot, months, shown) {
  slot.innerHTML = predictionCard(months, shown);
  slot.querySelector("#predict-next")?.addEventListener("click", () => showPrediction(slot, months, shown + 1));
  slot.querySelector("#predict-prev")?.addEventListener("click", () => showPrediction(slot, months, shown - 1));
}

const COLOUR_ACTUAL = "#2c5d8f";
const COLOUR_FORECAST = "#d62839";

// The four customer groups from ml/04_purchase_segmentation.ipynb.
const SEGMENT_COLOUR = {
  "Gaming & performance": "#2c5d8f",
  "Business & office": "#1e8e3e",
  "Everyday computers": "#8a5cf6",
  "Parts & accessories": "#b4642a",
};

adminPage("Sales Forecast", "forecast", async (content) => {
  let data;
  try {
    const response = await fetch(FORECAST_DATA, { cache: "no-store" });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    data = await response.json();
  } catch (error) {
    content.innerHTML = `
      <div class="card">
        <p style="color:#888;">
          The forecast file could not be read (${e(error.message)}).
        </p>
        <p class="hint" style="margin:0;">
          It is written by <code>tools/export_ml_to_web.py</code>. Run that after
          re-executing the notebooks in <code>ml/</code>.
        </p>
      </div>`;
    return;
  }

  const meta = data.meta || {};
  const metrics = data.metrics || {};
  const monthly = data.monthly || [];
  const weekly = data.forecast || [];
  const groups = data.groups || [];
  const slowest = data.slowest || [];
  // nextMonth (one month) is what the export wrote before the button existed.
  const coming = data.nextMonths || (data.nextMonth ? [data.nextMonth] : []);

  const monthMax = Math.max(0, ...monthly.flatMap((m) => [m.actual, m.forecast]));
  const weekMax = Math.max(0, ...weekly.flatMap((w) => [w.actual, w.forecast]));
  const segMax = Math.max(0, ...groups.map((s) => s.revenue));

  content.innerHTML = `
    <div id="prediction"></div>

    <div class="tiles">
      <div class="tile">
        <div class="label">Forecast accuracy (monthly)</div>
        <div class="value">${e(pct(metrics.monthlyAccuracy))}</div>
        <div class="sub">WAPE ${e(pct(metrics.monthlyWAPE))} &middot; R&sup2; ${e(metrics.monthlyR2)}</div>
      </div>
      <div class="tile">
        <div class="label">Forecast accuracy (weekly)</div>
        <div class="value">${e(pct(metrics.weeklyAccuracy))}</div>
        <div class="sub">WAPE ${e(pct(metrics.weeklyWAPE))} &middot; R&sup2; ${e(metrics.r2)}</div>
      </div>
      <div class="tile">
        <div class="label">Average error a week</div>
        <div class="value">${e(money(metrics.mae))}</div>
        <div class="sub">RMSE ${e(money(metrics.rmse))}</div>
      </div>
    </div>

    <h2>Forecast against what happened, by month</h2>
    <div class="card">
      ${monthly.length === 0
        ? `<p style="color:#888;">No monthly rows in the forecast file.</p>`
        : `
        <div style="display:flex; align-items:flex-end; gap:16px; height:250px; padding:10px 0 0;">
          ${monthly.map((m) => `
            <div style="flex:1; text-align:center; display:flex; flex-direction:column; justify-content:flex-end; height:100%;">
              <div style="font-size:10px; color:#888; margin-bottom:4px; white-space:nowrap;">
                ${(m.actual / 1000).toFixed(0)}k
              </div>
              <div style="display:flex; gap:3px; align-items:flex-end; justify-content:center; height:180px;">
                <div title="Actual ${e(money(m.actual))}"
                     style="width:46%; background:${COLOUR_ACTUAL};
                            height:${barHeight(m.actual, monthMax)}px; border-radius:3px 3px 0 0;"></div>
                <div title="Forecast ${e(money(m.forecast))}"
                     style="width:46%; background:${COLOUR_FORECAST}; opacity:.85;
                            height:${barHeight(m.forecast, monthMax)}px; border-radius:3px 3px 0 0;"></div>
              </div>
              <div style="font-size:11px; color:#888; margin-top:6px;">${e(monthLabel(m.month, true))}</div>
              <div style="font-size:10px; color:${m.errorPct >= 0 ? "#b4642a" : "#2c5d8f"};">
                ${m.errorPct >= 0 ? "+" : ""}${e(m.errorPct)}%
              </div>
            </div>`).join("")}
        </div>
        ${legend()}
        <p class="hint" style="margin:12px 0 0;">
          Months only part-covered by whole weeks are left out at each end.
          A positive percentage means the model forecast more than the shop took.
        </p>`}
    </div>

    <h2>The same forecast, week by week</h2>
    <div class="card">
      ${weekly.length === 0
        ? `<p style="color:#888;">No weekly rows in the forecast file.</p>`
        : `
        <div style="display:flex; align-items:flex-end; gap:2px; height:170px; padding:6px 0 0; overflow-x:auto;">
          ${weekly.map((w) => `
            <div title="${e(w.week)} &#10;actual ${e(money(w.actual))} &#10;forecast ${e(money(w.forecast))}"
                 style="flex:1 0 9px; display:flex; gap:1px; align-items:flex-end; height:100%;">
              <div style="width:50%; background:${COLOUR_ACTUAL};
                          height:${barHeight(w.actual, weekMax, 130)}px;"></div>
              <div style="width:50%; background:${COLOUR_FORECAST}; opacity:.8;
                          height:${barHeight(w.forecast, weekMax, 130)}px;"></div>
            </div>`).join("")}
        </div>
        ${legend()}
        <p class="hint" style="margin:12px 0 0;">
          ${weekly.length} weeks, ${e(meta.testFrom)} to ${e(meta.testTo)}. Weekly takings for a shop
          this size swing hard &mdash; one build moves a week by a fifth &mdash; which is why the
          monthly view above is the fairer read of the same forecast.
        </p>`}
    </div>

    <h2>Customer groups</h2>
    <div class="card">
      ${groups.length === 0
        ? `<p style="color:#888;">No customer groups in the forecast file. Run <code>ml/04_purchase_segmentation.ipynb</code>, then <code>tools/export_ml_to_web.py</code>.</p>`
        : groups.map((s) => `
        <div style="margin-bottom:16px;">
          <div style="display:flex; justify-content:space-between; font-size:14px; margin-bottom:5px;">
            <strong style="color:${SEGMENT_COLOUR[s.segment] || "#555"};">${e(s.segment)}</strong>
            <span>${e(s.purchases.toLocaleString())} purchases (${e(s.share)}%) &middot;
              ${e(money(s.revenue))} (${e(s.revShare)}%)</span>
          </div>
          <div style="background:#eef0f3; border-radius:4px; height:16px;">
            <div style="background:${SEGMENT_COLOUR[s.segment] || "#555"};
                        width:${barWidth(s.revenue, segMax)}%; height:16px; border-radius:4px;"></div>
          </div>
          <div style="font-size:12px; color:#555; margin-top:5px;">
            Best-selling types: ${s.bestSellers.map((b) => `${e(b.name)} (${e(b.purchases)})`).join(", ")}
          </div>
          ${(s.topProducts || []).length === 0 ? "" : `
          <ol style="font-size:12px; color:#555; margin:4px 0 0; padding-left:20px;">
            ${s.topProducts.map((p) => `<li>${e(shorten(p.name, 60))} &mdash; ${e(p.units)} sold</li>`).join("")}
          </ol>`}
          <div style="font-size:11px; color:#888; margin-top:2px;">
            typically ${e(money(s.medPrice))}${s.busiestMonth ? `, busiest in ${e(s.busiestMonth)}` : ""}
          </div>
        </div>`).join("") + `
        <p class="hint" style="margin:0;">
          Every sale since 2022 put into one of four groups by K-Means, using price, quantity,
          graphics card level and whether the item is for gaming, for business or a full computer.
          The receipts do not say who bought, so these are groups of purchases: "a gaming purchase",
          not "a gamer".
        </p>`}
    </div>

    ${slowest.length === 0 ? "" : `
    <h2>Worth a second look</h2>
    <div class="table-wrap">
      <table class="data">
        <thead><tr><th>Product</th><th>Category</th><th class="num">Sold</th>
          <th class="num">Weeks on sale</th><th class="num">A week</th></tr></thead>
        <tbody>
        ${slowest.map((d) => `
          <tr>
            <td>${e(shorten(d.name, 52))}</td>
            <td><small style="color:#777;">${e(d.category)}</small></td>
            <td class="num">${e(d.units)}</td>
            <td class="num">${e(d.weeksOnSale)}</td>
            <td class="num"><strong style="color:#b4642a;">${e(d.unitsPerWk)}</strong></td>
          </tr>`).join("")}
        </tbody>
      </table>
    </div>
    <p class="hint">
      The slowest sellers in the current range: the products that turn over least often since
      they were first sold. Worth checking before they are reordered.
    </p>`}`;

  showPrediction(content.querySelector("#prediction"), coming, -1);
});

function legend() {
  return `
    <div style="display:flex; gap:18px; font-size:12px; color:#666; margin-top:12px;">
      <span><span style="display:inline-block; width:11px; height:11px; background:${COLOUR_ACTUAL};
        border-radius:2px; margin-right:5px;"></span>Actual</span>
      <span><span style="display:inline-block; width:11px; height:11px; background:${COLOUR_FORECAST};
        opacity:.85; border-radius:2px; margin-right:5px;"></span>Forecast</span>
    </div>`;
}

function barHeight(value, max, ceiling = 180) {
  if (!(max > 0)) return 3;
  return Math.max(Math.round(Number(value) / max * ceiling), 3);
}

function pct(value) {
  return value === null || value === undefined ? "--" : `${value}%`;
}
