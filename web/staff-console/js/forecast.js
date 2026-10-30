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
// Charts are plain HTML and inline SVG, like the rest of the console -- no charting
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
//
// Two different "next months" (28 Oct). The model's first month is the
// one after its data ends -- September 2026, as the receipts stop in
// August -- which is not the next month on the calendar once time has
// moved on. Every month on the card now says both: how far it is past
// the data, and where it sits against today. "Next calendar month" jumps
// straight to the month after this one. No prediction is changed.
function thisCalendarMonth() {
  return new Date().toLocaleDateString("en-CA", { timeZone: "Asia/Kuala_Lumpur" }).slice(0, 7);
}

function nextCalendarMonth() {
  const [y, m] = thisCalendarMonth().split("-").map(Number);
  return m === 12 ? `${y + 1}-01` : `${y}-${String(m + 1).padStart(2, "0")}`;
}

// "Month 3 after the data · this calendar month"
function monthPlace(months, i) {
  const n = months[i];
  const now = thisCalendarMonth();
  const when = n.month < now ? "already past, so it can be checked against the receipts"
    : n.month === now ? "this calendar month"
    : n.month === nextCalendarMonth() ? "next calendar month"
    : "a later month";
  return `Month ${i + 1} after the data (which ends ${n.fittedTo}) · ${when}`;
}

function predictionCard(months, shown) {
  if (months.length === 0) return "";
  const calendarNext = months.findIndex((m) => m.month === nextCalendarMonth());

  const header = `
    <div style="display:flex; justify-content:space-between; align-items:center; gap:10px; flex-wrap:wrap;">
      <div style="font-size:13px; color:#888; text-transform:uppercase; letter-spacing:.04em;">
        ${shown < 0 ? "Sales prediction" : `Predicted sales &mdash; ${e(months[shown].label)}`}
      </div>
      <div style="display:flex; gap:8px;">
        ${shown > 0 ? `<button type="button" class="btn small grey" id="predict-prev">&#9664; Previous month</button>` : ""}
        ${shown < months.length - 1
          ? `<button type="button" class="btn small" id="predict-next">
               ${shown < 0 ? `Predict ${e(months[0].label)} (first month after the data)` : "Predict the month after &#9654;"}</button>`
          : ""}
        ${calendarNext >= 0 && calendarNext !== shown
          ? `<button type="button" class="btn small grey" id="predict-calendar" data-at="${calendarNext}">
               Next calendar month: ${e(months[calendarNext].label)}</button>`
          : ""}
      </div>
    </div>`;

  if (shown < 0) {
    return `
      <div class="card" style="border-left:4px solid ${COLOUR_FORECAST};">
        ${header}
        <p class="hint" style="margin:10px 0 0;">
          The sales receipts run to ${e(months[0].fittedTo)}, so the model's first month is
          ${e(months[0].label)}, the first month after the data. That is not the next month on the
          calendar: today it is ${e(monthLabel(thisCalendarMonth(), true))}. Step through up to
          ${months.length} months, or jump to the next calendar month.
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
      <div style="font-size:13px; color:var(--ink-3); margin-top:6px;">${e(monthPlace(months, shown))}</div>
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
  const jump = slot.querySelector("#predict-calendar");
  jump?.addEventListener("click", () => showPrediction(slot, months, Number(jump.dataset.at)));
}


// Months the boss has sent since the forecast was frozen, written by
// tools/check_forecast_months.py. Optional: the page works without it.
const FORECAST_CHECKS = "data/forecast_checks.json";

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
  const monthName = (month) => (coming.find((m) => m.month === month) || {}).label || monthLabel(month, true);

  let checks = [];
  let calendar = {};
  try {
    const response = await fetch(FORECAST_CHECKS, { cache: "no-store" });
    if (response.ok) ({ checks = [], calendarMonths: calendar = {} } = await response.json());
  } catch (error) {
    // No checked months yet; the chart simply stops at the backtest.
  }

  const monthRows = monthlyRows(monthly, checks, coming, calendar);
  const weekRows = weekly.map((w, i) => ({
    // A label at each new month, but not on a lone first week that would
    // print on top of the next month's.
    label: (i === 0 ? weekly[3] && weekly[3].week.slice(5, 7) === w.week.slice(5, 7)
                    : w.week.slice(5, 7) !== weekly[i - 1].week.slice(5, 7))
      ? monthLabel(w.week.slice(0, 7), true) : "",
    tip: `week of ${w.week}`,
    actual: w.actual,
    forecast: w.forecast,
  }));
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
        ${lineChart(monthRows, { height: 300, errors: true })}
        ${legend(coming.length > 0)}
        <p class="hint" style="margin:12px 0 0;">
          ${e(monthLabel(monthly[0].month, true))} to ${e(monthLabel(monthly[monthly.length - 1].month, true))}
          are months the model had never seen; the shaded part is the six months it predicts
          ahead, with its usual error as the band; hollow dots are forecasts, with no sales to check them
          against yet. August 2026 is left out because its last week runs into September. A percentage
          under a month is how far the prediction was off; positive means it said more than the shop took.
          Point at a month to see its actual sales, the prediction, the difference and the shop's
          calendar-month total.
        </p>
        ${checks.map((c) => checkNote({ ...c, label: monthName(c.month) })).join("")}`}
    </div>

    <h2>The same forecast, week by week</h2>
    <div class="card">
      ${weekly.length === 0
        ? `<p style="color:#888;">No weekly rows in the forecast file.</p>`
        : `
        ${lineChart(weekRows, { height: 220, dots: false })}
        ${legend(false)}
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



// A month sent after the forecast was frozen, checked against it. The
// numbers are like for like (see tools/check_forecast_months.py), and the
// calendar-month total is on the note so nobody has to take the scaling
// on trust.
function checkNote(c) {
  return `
    <div style="margin-top:14px; padding:12px 14px; background:#f4f5f7; border-radius:4px; font-size:13px;">
      <strong>${e(c.label)} checked against the shop's own figure.</strong>
      The shop took ${e(money(c.calendarTotal))} in products over ${e(c.days)} days
      (services left out, as in training), which is ${e(money(c.actual))} over the ${e(c.forecastDays)} days
      the forecast covers. The model said ${e(money(c.forecast))}:
      <strong style="color:${c.inRange ? "#1e8e3e" : COLOUR_FORECAST};">
        ${c.errorPct >= 0 ? "+" : ""}${e(c.errorPct)}%, ${c.inRange ? "inside" : "outside"} its range
      </strong>
      of ${e(money(c.low))} to ${e(money(c.high))}.
      ${c.linesGenerated ? `
      <br />Only the month's total is the shop's own figure${c.reportedTotal != null ? ` (${e(money(c.reportedTotal))}, services included)` : ""}:
      the receipt lines in ${e(c.source)} were generated to add up to it, so the services taken out and
      the day-by-day split are estimates. The prediction itself was not changed.` : ""}
    </div>`;
}


function pct(value) {
  return value === null || value === undefined ? "--" : `${value}%`;
}
