// ============================================================
// Charts shared by the Dashboard and the Sales Forecast page.
//
// Plain inline SVG, like the rest of the console -- no charting library,
// nothing to fetch, and every mark is in this file. Moved here from
// forecast.js so the Dashboard can draw the same forecast without
// loading that page's script, which renders a whole page when it runs.
// ============================================================

// Dark for what happened, red for what the model said: the console's own
// --ink and --red.
const COLOUR_ACTUAL = "#16181d";
const COLOUR_FORECAST = "#bc2000";

// One row per calendar month from the first backtest month to the last
// month predicted ahead. A month with nothing keeps its place on the axis,
// so the lines break there instead of joining across it.
//
// calendar is the shop's product sales per calendar month, from
// forecast_checks.json. It is only ever shown in the hover note, never
// drawn: the lines compare the model's week-based months like for like.
//
// weeks is the weekly backtest. The export leaves out the last month
// (August 2026) because its last week, from 31 Aug, has one day of sales;
// the weeks before it are summed here so that month is still drawn.
function monthlyRows(monthly, checks, coming, calendar = {}, weeks = []) {
  const byMonth = {};
  const row = (month) => (byMonth[month] ||= { month });
  monthly.forEach((m) => Object.assign(row(m.month), { actual: m.actual, forecast: m.forecast, errorPct: m.errorPct }));
  const lastMonth = monthly.length ? monthly[monthly.length - 1].month : "";
  weeks.filter((w) => w.week.slice(0, 7) > lastMonth).forEach((w) => {
    const r = row(w.week.slice(0, 7));
    r.actual = (r.actual || 0) + w.actual;
    r.forecast = (r.forecast || 0) + w.forecast;
    (r.partWeeks ||= []).push(w.week);
  });
  Object.values(byMonth).filter((r) => r.partWeeks).forEach((r) => {
    r.errorPct = Math.round((r.forecast - r.actual) / r.actual * 1000) / 10;
  });
  coming.forEach((m) => Object.assign(row(m.month), { forecast: m.revenue, low: m.low, high: m.high, ahead: true }));
  checks.forEach((c) => Object.assign(row(c.month), { actual: c.actual, errorPct: c.errorPct, check: c }));

  const keys = Object.keys(byMonth).sort();
  if (keys.length === 0) return [];
  const rows = [];
  let [y, m] = keys[0].split("-").map(Number);
  for (let key = keys[0]; key <= keys[keys.length - 1]; ) {
    const r = { ...(byMonth[key] || { month: key }), calendar: calendar[key] };
    rows.push({ ...r, label: monthLabel(key, true), tip: fullMonth(key), note: monthNote(r) });
    m += 1;
    if (m > 12) { m = 1; y += 1; }
    key = `${y}-${String(m).padStart(2, "0")}`;
  }
  return rows;
}

// The model's month is the weeks whose Monday falls in it, so September
// 2026 is 7 Sep to 4 Oct. Worked out from the calendar, the same way the
// export script groups the weeks.
function modelWeeks(month, weekStarts) {
  const [y, m] = month.split("-").map(Number);
  const first = new Date(Date.UTC(y, m - 1, 1));
  first.setUTCDate(1 + ((8 - first.getUTCDay()) % 7));
  let mondays = [];
  for (const d = first; d.getUTCMonth() === m - 1; d.setUTCDate(d.getUTCDate() + 7)) mondays.push(new Date(d));
  if (weekStarts) mondays = weekStarts.map((w) => new Date(`${w}T00:00:00Z`));
  const end = new Date(mondays[mondays.length - 1]);
  end.setUTCDate(end.getUTCDate() + 6);
  const day = (d) => `${d.getUTCDate()} ${monthLabel(d.toISOString().slice(0, 7))}`;
  // Dates only: the page reports months, not weeks (3 Nov 2026).
  return `${day(mondays[0])} to ${day(end)}`;
}
const modelSpan = modelWeeks;

function calendarSpan(month) {
  const [y, m] = month.split("-").map(Number);
  const days = new Date(Date.UTC(y, m, 0)).getUTCDate();
  return `1 to ${days} ${monthLabel(month)}`;
}

// What the hover note says about one month, as [label, value] lines. Every
// figure comes from a file; a month with no receipts yet says so in words
// rather than showing a zero, and a forecast is never called sales.
function monthNote(r) {
  const lines = [];
  const has = (v) => v !== null && v !== undefined;

  if (!has(r.forecast) && !has(r.actual)) {
    lines.push(["Model month", "None: it runs into the next month, so the backtest leaves it out"]);
  } else {
    lines.push(["Model month", modelWeeks(r.month, r.partWeeks)
      + (r.partWeeks ? "; 31 Aug is left out, as the sales file ends that day" : "")]);
    if (has(r.actual)) {
      lines.push(["Actual sales", money(r.actual) + (r.check ? ` (calendar month scaled to these ${r.check.forecastDays} days)` : "")]);
    }
    if (has(r.forecast)) lines.push([r.ahead ? "Forecast" : "Predicted sales", money(r.forecast)]);
    if (has(r.low)) lines.push(["Likely range", `${money(r.low)} to ${money(r.high)}`]);
    if (has(r.actual) && has(r.forecast)) {
      const gap = r.actual - r.forecast;
      lines.push(["Difference", gap === 0 ? "None"
        : `${money(Math.abs(gap))} ${gap > 0 ? "more" : "less"} than predicted; the prediction was ${Math.abs(r.errorPct)}% too ${r.errorPct > 0 ? "high" : "low"}`]);
    } else if (r.ahead) {
      lines.push(["Actual sales", "Not available yet"]);
    }
  }

  if (has(r.calendar)) lines.push([`Calendar month (${calendarSpan(r.month)})`, `${money(r.calendar)} in products`]);
  if (r.check) {
    lines.push([`Calendar month (${calendarSpan(r.month)})`, `${money(r.check.calendarTotal)} in products`]);
    if (r.check.reportedTotal != null) lines.push(["Shop's monthly total", `${money(r.check.reportedTotal)} incl. services`]);
    if (r.check.linesGenerated) {
      lines.push(["Note", "The receipt lines in this month's file were generated to add up to the shop's total, so only that total is the shop's figure"]);
    }
  }
  return lines;
}

// "September 2026", for the top line of the hover note.
function fullMonth(month) {
  const [y, m] = month.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, 1)).toLocaleDateString("en-GB", { month: "long", year: "numeric", timeZone: "UTC" });
}

// A line chart as inline SVG: actual in dark, forecast in red, the
// predicted-ahead range as a light red band. Lines break wherever a row
// has no value, rather than drawing across a gap.
//
// The Dashboard's sales chart has one line, so it can recolour "actual"
// and shade under it (area), and it asks for every nth label only so a
// daily axis does not print thirty dates on top of each other.
function lineChart(rows, {
  height = 260, errors = false, dots = true, area = false,
  colour = COLOUR_ACTUAL, minWidth = 560, labelEvery = 1, name = "actual",
} = {}) {
  const W = 760, H = height;
  const left = 52, right = 28, top = 14, bottom = errors ? 44 : 28;
  const values = rows.flatMap((r) => [r.actual, r.forecast, r.high]).filter((v) => v != null);
  const step = niceStep(Math.max(1, ...values) / 4);
  const yMax = Math.ceil(Math.max(1, ...values) / step) * step;

  const slot = (W - left - right) / Math.max(rows.length - 1, 1);
  const x = (i) => rows.length === 1 ? (left + W - right) / 2 : left + i * slot;
  const y = (v) => top + (1 - v / yMax) * (H - top - bottom);

  // Runs of consecutive rows that have the value, as SVG point lists.
  const runs = (pick) => {
    const out = [];
    let run = [];
    rows.forEach((r, i) => {
      const v = pick(r);
      if (v == null) { if (run.length) out.push(run); run = []; }
      else run.push([x(i), y(v)]);
    });
    if (run.length) out.push(run);
    return out;
  };
  const points = (run) => run.map(([px, py]) => `${px.toFixed(1)},${py.toFixed(1)}`).join(" ");

  const grid = [];
  for (let v = 0; v <= yMax; v += step) {
    grid.push(`
      <line x1="${left}" x2="${W - right}" y1="${y(v)}" y2="${y(v)}" stroke="#e2e5e9" />
      <text x="${left - 8}" y="${y(v) + 4}" text-anchor="end" font-size="11" fill="#5c636e">${e(shortMoney(v))}</text>`);
  }

  // The band: upper edge left to right, lower edge back again.
  const bands = [];
  let band = [];
  rows.forEach((r, i) => {
    if (r.low == null) { if (band.length) bands.push(band); band = []; }
    else band.push(i);
  });
  if (band.length) bands.push(band);
  const bandShapes = bands.map((b) => {
    const upper = b.map((i) => `${x(i).toFixed(1)},${y(rows[i].high).toFixed(1)}`);
    const lower = b.slice().reverse().map((i) => `${x(i).toFixed(1)},${y(rows[i].low).toFixed(1)}`);
    return `<polygon points="${upper.concat(lower).join(" ")}" fill="${COLOUR_FORECAST}" opacity=".12" />`;
  });
  const ahead = bands.length
    ? `<line x1="${x(bands[0][0])}" x2="${x(bands[0][0])}" y1="${top}" y2="${H - bottom}" stroke="#c8cdd3" />
       <text x="${x(bands[0][0]) + 6}" y="${top + 10}" font-size="11" fill="#5c636e">Predicted ahead</text>`
    : "";

  const line = (pick, stroke) => runs(pick).map((run) =>
    `<polyline points="${points(run)}" fill="none" stroke="${stroke}" stroke-width="2.25"
       stroke-linejoin="round" stroke-linecap="round" />`).join("");

  // Shading under the actual line, down to the axis.
  const shade = area ? runs((r) => r.actual).filter((run) => run.length > 1).map((run) => {
    const base = y(0).toFixed(1);
    return `<polygon points="${run[0][0].toFixed(1)},${base} ${points(run)} ${run[run.length - 1][0].toFixed(1)},${base}"
      fill="${colour}" opacity=".10" />`;
  }).join("") : "";

  // A month predicted ahead gets a hollow dot, so it never reads as one the
  // model was tested on. Rows with a hover note (the monthly forecast) show
  // that instead of the browser's own title box.
  const marks = (pick, fill, label) => dots ? rows.map((r, i) => pick(r) == null ? "" : `
    <circle cx="${x(i)}" cy="${y(pick(r))}" r="3.5"
      ${label === "forecast" && r.ahead ? `fill="#ffffff" stroke="${fill}" stroke-width="1.75"` : `fill="${fill}"`}>
      ${r.note ? "" : `<title>${e(r.tip)}: ${label} ${e(money(pick(r)))}${r.low != null ? ` (range ${e(money(r.low))} to ${e(money(r.high))})` : ""}</title>`}
    </circle>`).join("") : "";

  // Undotted charts (the weekly one) still get a hover target per row.
  const hovers = rows.some((r) => r.note)
    ? rows.map((r, i) => `
    <rect class="chart-hit" x="${x(i) - slot / 2}" y="${top}" width="${slot}" height="${H - top - bottom}"
      tabindex="0" data-title="${e(r.tip)}" data-note="${e(JSON.stringify(r.note))}"
      aria-label="${e(r.tip)}: ${e(r.note.map(([k, v]) => `${k} ${v}`).join("; "))}" />`).join("")
    : dots ? "" : rows.map((r, i) => `
    <rect x="${x(i) - slot / 2}" y="${top}" width="${slot}" height="${H - top - bottom}" fill="transparent">
      <title>${e(r.tip)}&#10;actual ${e(money(r.actual))}&#10;forecast ${e(money(r.forecast))}</title>
    </rect>`).join("");

  const labels = rows.map((r, i) => `
    ${r.label && i % labelEvery === 0 ? `<text x="${x(i)}" y="${H - bottom + 16}" text-anchor="middle" font-size="11" fill="#5c636e">${e(r.label)}</text>` : ""}
    ${errors && r.errorPct != null && r.actual != null
      ? `<text x="${x(i)}" y="${H - bottom + 31}" text-anchor="middle" font-size="10"
           fill="${Math.abs(r.errorPct) > 15 ? COLOUR_FORECAST : "#5c636e"}">${r.errorPct >= 0 ? "+" : ""}${e(r.errorPct)}%</text>`
      : ""}`).join("");

  return `
    <div class="chart-box">
    <div style="overflow-x:auto;">
      <svg viewBox="0 0 ${W} ${H}" width="100%" style="min-width:${minWidth}px; display:block;"
           role="img" aria-label="Sales chart">
        ${grid.join("")}
        ${bandShapes.join("")}
        ${ahead}
        ${shade}
        ${line((r) => r.forecast, COLOUR_FORECAST)}
        ${line((r) => r.actual, colour)}
        ${marks((r) => r.forecast, COLOUR_FORECAST, "forecast")}
        ${marks((r) => r.actual, colour, name)}
        ${labels}
        ${hovers}
      </svg>
    </div>
    <div class="chart-tip" hidden></div>
    </div>`;
}

// The hover note for a month. One listener for the whole page, because the
// charts are drawn as HTML strings and replaced whenever a page redraws.
// Focus opens it too, so the months can be read from the keyboard.
function showChartNote(hit) {
  const box = hit.closest(".chart-box");
  const tip = box && box.querySelector(".chart-tip");
  if (!tip) return;
  const lines = JSON.parse(hit.dataset.note);
  tip.innerHTML = `<strong>${e(hit.dataset.title)}</strong>
    <dl>${lines.map(([k, v]) => `<dt>${e(k)}</dt><dd>${e(v)}</dd>`).join("")}</dl>`;
  tip.hidden = false;
  const area = box.getBoundingClientRect();
  const spot = hit.getBoundingClientRect();
  const middle = spot.left + spot.width / 2 - area.left;
  // Right of the month when there is room, otherwise left of it.
  const left = middle + 12 + tip.offsetWidth <= area.width ? middle + 12 : Math.max(0, middle - 12 - tip.offsetWidth);
  tip.style.left = `${left}px`;
  tip.style.top = `${Math.max(0, spot.top - area.top)}px`;
}

function hideChartNote(hit) {
  const tip = hit.closest(".chart-box")?.querySelector(".chart-tip");
  if (tip) tip.hidden = true;
}

["pointerover", "focusin"].forEach((type) => document.addEventListener(type, (event) => {
  const hit = event.target.closest && event.target.closest(".chart-hit");
  if (hit) showChartNote(hit);
}));
["pointerout", "focusout"].forEach((type) => document.addEventListener(type, (event) => {
  const hit = event.target.closest && event.target.closest(".chart-hit");
  if (hit) hideChartNote(hit);
}));

// withBand means the chart runs into months predicted ahead, so the legend
// also tells the backtest's solid dots from the hollow ones ahead.
function legend(withBand) {
  const swatch = (colour) => `<span style="display:inline-block; width:16px; height:3px; background:${colour};
    vertical-align:middle; margin-right:6px;"></span>`;
  const dot = (fill) => `<svg width="10" height="10" viewBox="0 0 10 10" style="vertical-align:middle; margin-right:6px;">
    <circle cx="5" cy="5" r="3.5" fill="${fill}" stroke="${COLOUR_FORECAST}" stroke-width="1.75" /></svg>`;
  return `
    <div style="display:flex; gap:18px; flex-wrap:wrap; font-size:12px; color:#5c636e; margin-top:12px;">
      <span>${swatch(COLOUR_ACTUAL)}Actual sales</span>
      ${withBand
        ? `<span>${dot(COLOUR_FORECAST)}Model's prediction for a past month</span>
           <span>${dot("#ffffff")}Forecast ahead</span>`
        : `<span>${swatch(COLOUR_FORECAST)}Forecast</span>`}
      ${withBand ? `<span><span style="display:inline-block; width:16px; height:11px; background:${COLOUR_FORECAST};
        opacity:.15; vertical-align:middle; margin-right:6px;"></span>Likely range</span>` : ""}
    </div>`;
}

// 1, 2 or 5 times a power of ten, so the axis reads 200k, 400k, 600k.
function niceStep(raw) {
  const power = 10 ** Math.floor(Math.log10(raw));
  const unit = raw / power;
  return (unit <= 1 ? 1 : unit <= 2 ? 2 : unit <= 5 ? 5 : 10) * power;
}

function shortMoney(value) {
  return value >= 1000 ? `${Math.round(value / 1000)}k` : String(value);
}

// A doughnut as inline SVG: one arc per slice, the total in the middle.
// Slices of zero are left out of the ring but stay in the legend, so a
// status nobody is in still shows as 0 rather than vanishing.
function doughnut(slices, centreValue, centreLabel) {
  const total = slices.reduce((sum, s) => sum + s.value, 0);
  const R = 60, T = 22, C = 2 * Math.PI * R;
  let offset = 0;
  const arcs = total === 0
    ? `<circle cx="80" cy="80" r="${R}" fill="none" stroke="#eceef1" stroke-width="${T}" />`
    : slices.filter((s) => s.value > 0).map((s) => {
        const length = (s.value / total) * C;
        const arc = `<circle cx="80" cy="80" r="${R}" fill="none" stroke="${s.colour}" stroke-width="${T}"
          stroke-dasharray="${length.toFixed(2)} ${(C - length).toFixed(2)}" stroke-dashoffset="${(-offset).toFixed(2)}"
          transform="rotate(-90 80 80)"><title>${e(s.label)}: ${s.value}</title></circle>`;
        offset += length;
        return arc;
      }).join("");
  return `
    <svg viewBox="0 0 160 160" width="160" height="160" role="img" aria-label="${e(centreLabel)} by status">
      ${arcs}
      <text x="80" y="80" text-anchor="middle" font-size="24" font-weight="700" fill="#16181d">${e(centreValue)}</text>
      <text x="80" y="99" text-anchor="middle" font-size="12" fill="#5c636e">${e(centreLabel)}</text>
    </svg>`;
}
