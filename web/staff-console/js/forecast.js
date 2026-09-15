// ============================================================
// Sales forecast and product segments.
//
// Every other page in this console reads Supabase, which holds the live
// shop: a few dozen real orders across a handful of months. This page
// does not, and the reason is the same one that removed the old forecast
// page -- a trend line over that much history is a number with nothing
// behind it.
//
// What it reads instead is web/staff-console/data/ml_forecast.json,
// written by tools/export_ml_to_web.py from the models in ml/. Those are
// fitted on the five-year sales dataset in docs/data/, which is a
// different body of data from the live shop in every way that matters:
// far longer, and generated rather than traded. That distinction is not
// a footnote, so the banner at the top of the page states it plainly and
// is not dismissible. A forecast whose provenance is unclear is worse
// than no forecast, which is the lesson the deleted page taught.
//
// Nothing here writes. The page cannot change an order, a price or a
// stock level, so a wrong model costs a misleading chart and nothing more.
//
// Charts are plain HTML, like the rest of the console -- no charting
// library, nothing to fetch, and nothing to explain that is not in this
// file.
// ============================================================

const FORECAST_DATA = "data/ml_forecast.json";

const COLOUR_ACTUAL = "#2c5d8f";
const COLOUR_FORECAST = "#d62839";

const SEGMENT_COLOUR = {
  "Core range": "#2c5d8f",
  "Fast-moving, low value": "#1e8e3e",
  "Premium, low volume": "#8a5cf6",
  "Dormant / discontinued": "#b4642a",
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
  const segments = data.segments || [];
  const dormant = data.dormant || [];

  const monthMax = Math.max(0, ...monthly.flatMap((m) => [m.actual, m.forecast]));
  const weekMax = Math.max(0, ...weekly.flatMap((w) => [w.actual, w.forecast]));
  const segMax = Math.max(0, ...segments.map((s) => s.revenue));

  content.innerHTML = `
    ${provenanceBanner(meta)}

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
              <div style="font-size:11px; color:#888; margin-top:6px;">${e(monthLabel(m.month))}</div>
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

    <h2>Product segments</h2>
    <div class="card">
      ${segments.length === 0
        ? `<p style="color:#888;">No segments in the forecast file. Run <code>ml/03_segmentation.ipynb</code>.</p>`
        : segments.map((s) => `
        <div style="margin-bottom:16px;">
          <div style="display:flex; justify-content:space-between; font-size:14px; margin-bottom:5px;">
            <strong style="color:${SEGMENT_COLOUR[s.segment] || "#555"};">${e(s.segment)}</strong>
            <span>${s.skus} product${s.skus === 1 ? "" : "s"} &middot; ${e(money(s.revenue))}
              (${e(s.revShare)}%)</span>
          </div>
          <div style="background:#eef0f3; border-radius:4px; height:16px;">
            <div style="background:${SEGMENT_COLOUR[s.segment] || "#555"};
                        width:${barWidth(s.revenue, segMax)}%; height:16px; border-radius:4px;"></div>
          </div>
          <div style="font-size:11px; color:#888; margin-top:4px;">
            typically ${e(money(s.medPrice))}, ${s.medUnits} sold, last sale ${e(s.medRecency)} weeks ago
          </div>
        </div>`).join("") + `
        <p class="hint" style="margin:0;">
          Products grouped by how they behave &mdash; price, how fast they move, and how long since
          they last sold &mdash; not by category. Grouping is K-Means over the sales dataset.
        </p>`}
    </div>

    ${dormant.length === 0 ? "" : `
    <h2>Worth a second look</h2>
    <div class="table-wrap">
      <table class="data">
        <thead><tr><th>Product</th><th>Category</th><th class="num">Weeks since last sale</th>
          <th class="num">Lifetime revenue</th></tr></thead>
        <tbody>
        ${dormant.map((d) => `
          <tr>
            <td>${e(shorten(d.name, 52))}</td>
            <td><small style="color:#777;">${e(d.category)}</small></td>
            <td class="num"><strong style="color:#b4642a;">${e(d.recencyWk)}</strong></td>
            <td class="num">${e(money(d.revenue))}</td>
          </tr>`).join("")}
        </tbody>
      </table>
    </div>
    <p class="hint">
      The dormant segment, by lifetime revenue. These sold well once and have not sold since,
      which makes them the clearest candidates for clearing &mdash; in the dataset described above,
      not in current stock.
    </p>`}`;
});

// ------------------------------------------------------------
// The banner.
//
// Stated once, at the top, before any number on the page. It is not
// dismissible and it names the file, because somebody reading a chart of
// weekly takings will otherwise assume it is the shop's.
// ------------------------------------------------------------
function provenanceBanner(meta) {
  return `
    <div class="card" style="border-left:4px solid #b4642a; background:#fdf7f0; margin-bottom:22px;">
      <strong style="color:#b4642a;">This page does not describe the live shop.</strong>
      <p style="margin:8px 0 0; font-size:13px; color:#555;">
        These figures come from the five-year sales dataset
        (<code>${e(meta.source || "docs/data")}</code>), which is
        <strong>generated data, not trading records</strong>. The model is
        ${e(meta.model || "a regression")}, fitted on ${e(meta.trainWeeks)} weeks to
        ${e(meta.trainTo)} and measured against the ${e(meta.testWeeks)} weeks after it.
        Orders, customers and stock elsewhere in this console are the live shop and are
        unrelated to anything below.
      </p>
      <p style="margin:6px 0 0; font-size:12px; color:#888;">
        Exported ${e(meta.generated)} by <code>tools/export_ml_to_web.py</code>.
      </p>
    </div>`;
}

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

// "2026-04" -> "Apr 26". Built from the string rather than from a Date, so no
// timezone can shift it into the month next door.
function monthLabel(month) {
  const names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                 "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  const name = names[Number(String(month).slice(5, 7)) - 1];
  return name ? `${name} ${String(month).slice(2, 4)}` : String(month);
}
