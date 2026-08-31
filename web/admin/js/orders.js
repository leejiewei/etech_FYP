// ============================================================
// Orders, and moving them along the stages:
//   Pending -> Processing -> Shipped -> Delivered
//
// Every change is written to order_status_history, so there is a record
// of when each order moved and which member of staff moved it. Those two
// writes belong together — a status that changed with nothing recording
// who changed it is the one thing the history table exists to prevent —
// so they are one call to admin_set_order_status(), a database function,
// rather than two statements from this page hoping both land.
//
// That function also works out which admin is calling it. The old PHP
// passed adminId() from the session; a browser cannot be trusted to say
// which member of staff it is, so the function reads it from the token
// instead.
// ============================================================

const STAGES = ["Pending", "Processing", "Shipped", "Delivered", "Cancelled"];

// The next step along for each stage.
const NEXT = { Pending: "Processing", Processing: "Shipped", Shipped: "Delivered" };

adminPage("Orders", "orders", async (content) => {
  const filter = STAGES.includes(params().status) ? params().status : "";

  let query = sb.from("admin_orders")
    .select("order_id,order_date,status,subtotal,discount,total,coupon_code," +
            "shipping_name,shipping_phone,shipping_address,customer_name,customer_email")
    .order("order_date", { ascending: false })
    .limit(60);
  if (filter !== "") query = query.eq("status", filter);

  const [ordersResult, countsResult] = await Promise.all([
    query,
    sb.from("admin_order_status_counts").select("status,orders"),
  ]);
  if (ordersResult.error) throw ordersResult.error;

  const orders = ordersResult.data;
  const counts = Object.fromEntries((countsResult.data || []).map((r) => [r.status, r.orders]));
  const allCount = Object.values(counts).reduce((sum, n) => sum + Number(n), 0);

  // The lines and the history for every order on screen, in two requests
  // rather than two per order. admin/orders.php ran a query per order
  // inside its display loop, which was fine at 35 orders and would not
  // have been at 3,500.
  const ids = orders.map((o) => o.order_id);
  const [lines, history] = await Promise.all([
    ids.length === 0 ? [] : loadLines(ids),
    ids.length === 0 ? [] : loadHistory(ids),
  ]);

  const linesFor = groupBy(lines, "order_id");
  const historyFor = groupBy(history, "order_id");

  content.innerHTML = `
    <div class="filters">
      <a href="orders.html" class="btn ${filter === "" ? "" : "grey"}">All (${allCount})</a>
      ${STAGES.map((s) => `
        <a href="orders.html?status=${encodeURIComponent(s)}" class="btn ${filter === s ? "" : "grey"}">
          ${e(s)} (${counts[s] || 0})
        </a>`).join("")}
    </div>

    ${orders.length === 0
      ? `<div class="card" style="text-align:center; color:#888;">No orders here yet.</div>`
      : orders.map((o) => orderCard(o, linesFor[o.order_id] || [], historyFor[o.order_id] || [])).join("")}`;

  wireOrderActions();
});

async function loadLines(ids) {
  const { data, error } = await sb.from("order_items")
    .select("order_id,product_name,unit_price,quantity,line_total")
    .in("order_id", ids).order("order_item_id");
  if (error) throw error;
  return data;
}

async function loadHistory(ids) {
  const { data, error } = await sb.from("admin_order_history")
    .select("order_id,status,changed_at,note,staff")
    .in("order_id", ids).order("changed_at");
  if (error) throw error;
  return data;
}

function groupBy(rows, key) {
  const grouped = {};
  rows.forEach((row) => (grouped[row[key]] ||= []).push(row));
  return grouped;
}

function orderCard(o, items, history) {
  const discount = num(o.discount);

  return `
    <div class="card" data-order="${o.order_id}">
      <div style="display:flex; justify-content:space-between; flex-wrap:wrap; gap:12px;">
        <div>
          <h2 style="margin:0;">Order #${o.order_id}
            <span class="badge status-${e(o.status)}">${e(o.status)}</span>
          </h2>
          <div style="font-size:13px; color:#888;">
            ${e(when(o.order_date))}
            &nbsp;·&nbsp; ${e(o.customer_name)} (${e(o.customer_email)})
          </div>
        </div>
        <div style="text-align:right;">
          <div style="font-size:20px; font-weight:bold;">${e(money(o.total))}</div>
          ${discount > 0 ? `
            <div style="font-size:12px; color:#1e8e3e;">
              ${e(o.coupon_code)} −${e(money(discount))}
            </div>` : ""}
        </div>
      </div>

      <div style="display:flex; gap:26px; flex-wrap:wrap; margin-top:14px;">
        <div style="flex:2; min-width:260px;">
          <table class="data" style="font-size:13px;">
            ${items.map((i) => `
              <tr>
                <td>${i.quantity} ×</td>
                <td>${e(i.product_name)}</td>
                <td class="num">${e(money(i.line_total))}</td>
              </tr>`).join("")}
          </table>
        </div>
        <div style="flex:1; min-width:200px; font-size:13px;">
          <strong>Deliver to</strong><br />
          ${e(o.shipping_name)}<br />
          ${e(o.shipping_phone)}<br />
          ${e(o.shipping_address).replace(/\n/g, "<br />")}
        </div>
      </div>

      ${history.length === 0 ? "" : `
        <div style="margin-top:12px; font-size:12px; color:#999;">
          <strong>History:</strong>
          ${history.map((h) =>
            `${e(h.status)} (${e(when(h.changed_at))}${h.staff ? ", " + e(h.staff) : ""})`
          ).join(" → ")}
        </div>`}

      <div style="margin-top:14px; display:flex; gap:8px; align-items:center; flex-wrap:wrap;">
        <input type="text" data-field="note" placeholder="Note (optional)"
               style="flex:1; min-width:160px; padding:8px 10px; border:1px solid #ccd1d7; border-radius:6px;" />

        ${NEXT[o.status] ? `
          <button type="button" data-act="advance" data-to="${e(NEXT[o.status])}" class="btn small">
            Move to ${e(NEXT[o.status])}
          </button>` : ""}

        <select data-field="status" style="padding:7px 10px; border:1px solid #ccd1d7; border-radius:6px;">
          ${STAGES.map((s) =>
            `<option value="${e(s)}" ${o.status === s ? "selected" : ""}>${e(s)}</option>`).join("")}
        </select>
        <button type="button" data-act="set" class="btn small grey">Set</button>
      </div>
    </div>`;
}

function wireOrderActions() {
  document.querySelectorAll("[data-order] button[data-act]").forEach((button) => {
    button.onclick = async () => {
      const card = button.closest("[data-order]");
      const orderId = Number(card.dataset.order);
      const note = card.querySelector('[data-field="note"]').value.trim();
      const status = button.dataset.act === "advance"
        ? button.dataset.to
        : card.querySelector('[data-field="status"]').value;

      if (!STAGES.includes(status)) return;
      button.disabled = true;

      const { error } = await sb.rpc("admin_set_order_status", {
        p_order_id: orderId,
        p_status: status,
        p_note: note,
      });

      if (error) {
        button.disabled = false;
        alert("Could not update that order: " + error.message);
        return;
      }
      reloadWith(`Order #${orderId} moved to ${status}.`);
    };
  });
}
