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
// month predicted ahead. A month with nothing (August 2026) keeps its place
// on the axis, so the lines break there instead of joining across it.
function monthlyRows(monthly, checks, coming) {
  const byMonth = {};
  const row = (month) => (byMonth[month] ||= { month });
  monthly.forEach((m) => Object.assign(row(m.month), { actual: m.actual, forecast: m.forecast, errorPct: m.errorPct }));
  coming.forEach((m) => Object.assign(row(m.month), { forecast: m.revenue, low: m.low, high: m.high }));
  checks.forEach((c) => Object.assign(row(c.month), { actual: c.actual, errorPct: c.errorPct }));

  const keys = Object.keys(byMonth).sort();
  if (keys.length === 0) return [];
  const rows = [];
  let [y, m] = keys[0].split("-").map(Number);
  for (let key = keys[0]; key <= keys[keys.length - 1]; ) {
    const r = byMonth[key] || { month: key };
    rows.push({ ...r, label: monthLabel(key, true), tip: monthLabel(key, true) });
    m += 1;
    if (m > 12) { m = 1; y += 1; }
    key = `${y}-${String(m).padStart(2, "0")}`;
  }
  return rows;
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

  const marks = (pick, fill, label) => dots ? rows.map((r, i) => pick(r) == null ? "" : `
    <circle cx="${x(i)}" cy="${y(pick(r))}" r="3.5" fill="${fill}">
      <title>${e(r.tip)}: ${label} ${e(money(pick(r)))}${r.low != null ? ` (range ${e(money(r.low))} to ${e(money(r.high))})` : ""}</title>
    </circle>`).join("") : "";

  // Undotted charts (the weekly one) still get a hover target per row.
  const hovers = dots ? "" : rows.map((r, i) => `
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
        ${hovers}
        ${labels}
      </svg>
    </div>`;
}

function legend(withBand) {
  const swatch = (colour) => `<span style="display:inline-block; width:16px; height:3px; background:${colour};
    vertical-align:middle; margin-right:6px;"></span>`;
  return `
    <div style="display:flex; gap:18px; flex-wrap:wrap; font-size:12px; color:#5c636e; margin-top:12px;">
      <span>${swatch(COLOUR_ACTUAL)}Actual</span>
      <span>${swatch(COLOUR_FORECAST)}Forecast</span>
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
