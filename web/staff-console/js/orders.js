// ============================================================
// Orders, and moving them along the stages:
//   Pending -> Processing -> Ready -> Collected
//
// Four rungs, and the top two are called different things depending on
// how the customer asked to get their order. For a collection, Ready
// means it is on the counter with their name on it and Collected means
// they walked out with it. For a delivery the same two rungs read
// Shipped and Delivered. The words come from ../js/fulfilment.js; the
// button below and the dropdown both use them, so staff never see a
// stage described in the wrong language for the order in front of them.
//
// Pressing the Ready button is what messages the customer either way,
// and the database picks which of the two messages to send.
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
//
// ------------------------------------------------------------
// The payment is a second, separate track.
//
// There is no gateway: customers pay from their own banking app and
// upload a photograph of the receipt, and somebody here decides whether
// it matches. So each card carries two states -- where the goods are,
// and whether the money arrived -- and two sets of buttons. Approving a
// payment on a Pending order moves it to Processing as well, which is
// what Pending means once the money is in.
//
// The receipts live in a private bucket. This page holds no key to it:
// it asks Storage for a link signed for a few minutes, and Storage
// decides whether to issue one by asking the same is_admin() every other
// policy asks. A member of staff who lost their access would find the
// picture would not load.
// ------------------------------------------------------------
// ============================================================

const STAGES = ["Pending", "Processing", "Ready", "Collected", "Cancelled"];

// The next step along for each stage.
const NEXT = { Pending: "Processing", Processing: "Ready", Ready: "Collected" };

// What the button says, as an instruction rather than a noun. "Move to
// Ready" is ambiguous about who does what; the phrasing below is the
// thing the member of staff is actually asserting, and for Ready it is
// the press that messages the customer.
const STAGE_ACTION = {
  PICKUP: {
    Processing: "Start preparing",
    Ready:      "Mark ready to collect",
    Collected:  "Mark collected",
  },
  DELIVERY: {
    Processing: "Start preparing",
    Ready:      "Mark shipped",
    Collected:  "Mark delivered",
  },
};

function stageAction(stage, method) {
  const words = STAGE_ACTION[method] || STAGE_ACTION.PICKUP;
  return words[stage] || "Move to " + stageLabel(stage, method);
}

const PAYMENT_STATES = ["PENDING", "APPROVED", "REJECTED"];

const PAYMENT_LABELS = {
  PENDING:  "Payment not checked",
  APPROVED: "Payment approved",
  REJECTED: "Payment rejected",
};

const PAYMENT_METHOD_LABELS = {
  QR_CODE:       "DuitNow QR",
  BANK_TRANSFER: "Bank transfer",
};

// Long enough to look at the picture, short enough that a link copied
// out of the page is worthless by the time it leaves the building.
const RECEIPT_LINK_SECONDS = 300;

adminPage("Orders", "orders", async (content) => {
  const filter = STAGES.includes(params().status) ? params().status : "";
  // A second filter, on the money rather than the goods. ?pay=PENDING is
  // the queue somebody works through in the morning.
  const payFilter = PAYMENT_STATES.includes(params().pay) ? params().pay : "";

  let query = sb.from("admin_orders")
    .select("order_id,order_date,status,subtotal,discount,total,coupon_code," +
            "shipping_name,shipping_phone,shipping_address,fulfilment_method," +
            "customer_name,customer_email," +
            "payment_method,payment_status,receipt_image_path")
    .order("order_date", { ascending: false })
    .limit(60);
  if (filter !== "") query = query.eq("status", filter);
  if (payFilter !== "") query = query.eq("payment_status", payFilter);

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
      <a href="orders.html" class="btn ${filter === "" && payFilter === "" ? "" : "grey"}">All (${allCount})</a>
      ${STAGES.map((s) => `
        <a href="orders.html?status=${encodeURIComponent(s)}" class="btn ${filter === s ? "" : "grey"}">
          ${e(s)} (${counts[s] || 0})
        </a>`).join("")}
    </div>

    <div class="filters" style="margin-top:-6px;">
      ${PAYMENT_STATES.map((s) => `
        <a href="orders.html?pay=${encodeURIComponent(s)}" class="btn small ${payFilter === s ? "" : "grey"}">
          ${e(PAYMENT_LABELS[s])}
        </a>`).join("")}
    </div>

    ${orders.length === 0
      ? `<div class="card" style="text-align:center; color:#888;">No orders here yet.</div>`
      : orders.map((o) => orderCard(o, linesFor[o.order_id] || [], historyFor[o.order_id] || [])).join("")}`;

  wireOrderActions();
  wirePaymentActions();
  wireReceiptLinks();
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
            <span class="badge status-${e(o.status)}">${
              e(stageLabel(o.status, o.fulfilment_method))}</span>
            <span class="badge ${isDelivery(o.fulfilment_method) ? "low" : "in"}"
                  style="font-weight:normal;">${
              e(FULFILMENT_LABELS[o.fulfilment_method] || "Collection")}</span>
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
          <strong>${isDelivery(o.fulfilment_method) ? "Deliver to" : "Collected by"}</strong><br />
          ${e(o.shipping_name)}<br />
          ${e(o.shipping_phone)}
          ${isDelivery(o.fulfilment_method) && o.shipping_address
            ? "<br />" + e(o.shipping_address).replace(/\n/g, "<br />")
            : ""}
        </div>
      </div>

      ${history.length === 0 ? "" : `
        <div style="margin-top:12px; font-size:12px; color:#999;">
          <strong>History:</strong>
          ${history.map((h) =>
            `${e(stageLabel(h.status, o.fulfilment_method))} (${e(when(h.changed_at))}${
              h.staff ? ", " + e(h.staff) : ""})`
          ).join(" → ")}
        </div>`}

      <div style="margin-top:14px; display:flex; gap:8px; align-items:center; flex-wrap:wrap;">
        <input type="text" data-field="note" placeholder="Note (optional)"
               style="flex:1; min-width:160px; padding:8px 10px; border:1px solid #ccd1d7; border-radius:6px;" />

        ${NEXT[o.status] ? `
          <button type="button" data-act="advance" data-to="${e(NEXT[o.status])}" class="btn small">
            ${e(stageAction(NEXT[o.status], o.fulfilment_method))}
          </button>` : ""}

        <select data-field="status" style="padding:7px 10px; border:1px solid #ccd1d7; border-radius:6px;">
          ${STAGES.map((s) =>
            `<option value="${e(s)}" ${o.status === s ? "selected" : ""}>${
              e(stageLabel(s, o.fulfilment_method))}</option>`).join("")}
        </select>
        <button type="button" data-act="set" class="btn small grey">Set</button>
      </div>

      ${paymentBlock(o)}
    </div>`;
}

// The money half of the card: how they said they would pay, whether it
// has been checked, the receipt itself, and the two buttons.
//
// payment_method is NULL on the orders placed through the old card
// sandbox, before the shop could take a payment at all. Those get a line
// saying so rather than an approval queue entry for money that was never
// asked for.
function paymentBlock(o) {
  if (!o.payment_method) {
    return `
      <div style="margin-top:12px; font-size:12px; color:#999;">
        Placed through the card sandbox, before online payment existed.
      </div>`;
  }

  const state = o.payment_status;
  const badge = state === "APPROVED" ? "in" : state === "REJECTED" ? "out" : "low";

  // Built from the order's current payment status, so the message says
  // whatever is true at the moment somebody looks at the card. Empty when
  // the customer left an unusable phone number, and then no button is
  // drawn -- one that opened a chat with nobody would have staff
  // believing they had told somebody.
  const waLink = whatsappLink(o.shipping_phone, paymentMessage(o));

  return `
    <div style="margin-top:14px; border-top:1px solid #eef0f3; padding-top:12px;">
      <div style="display:flex; gap:10px; align-items:center; flex-wrap:wrap;">
        <span class="badge ${badge}">${e(PAYMENT_LABELS[state] || state)}</span>
        <span style="font-size:13px; color:#777;">
          ${e(PAYMENT_METHOD_LABELS[o.payment_method] || o.payment_method)}
        </span>

        ${o.receipt_image_path
          ? `<button type="button" class="btn small grey" data-receipt="${e(o.receipt_image_path)}">
               View receipt
             </button>`
          : `<span style="font-size:13px; color:#c0392b;">No receipt sent yet</span>`}

        <span style="flex:1;"></span>

        ${waLink ? `
          <a class="btn small grey" href="${e(waLink)}" target="_blank" rel="noopener"
             title="Opens WhatsApp with a message ready to send. You still have to send it.">
            WhatsApp customer
          </a>` : ""}

        ${state !== "APPROVED" && o.receipt_image_path ? `
          <button type="button" data-pay="APPROVED" class="btn small">Approve payment</button>` : ""}
        ${state !== "REJECTED" && o.receipt_image_path ? `
          <button type="button" data-pay="REJECTED" class="btn small danger">Reject payment</button>` : ""}
      </div>
      <div class="receipt-view" style="margin-top:10px;"></div>
    </div>`;
}

// The bucket is private, so there is no URL to put in the page. Storage
// is asked for one signed for a few minutes at the moment somebody
// clicks, and it decides whether to issue it by asking is_admin().
function wireReceiptLinks() {
  document.querySelectorAll("[data-receipt]").forEach((button) => {
    button.onclick = async () => {
      const view = button.closest("[data-order]").querySelector(".receipt-view");
      button.disabled = true;

      const { data, error } = await sb.storage
        .from("payment-receipts")
        .createSignedUrl(button.dataset.receipt, RECEIPT_LINK_SECONDS);

      button.disabled = false;

      if (error || !data) {
        view.innerHTML =
          `<div class="error-box">Could not open that receipt: ${e((error && error.message) || "unknown error")}</div>`;
        return;
      }

      view.innerHTML = `
        <a href="${e(data.signedUrl)}" target="_blank" rel="noopener">
          <img src="${e(data.signedUrl)}" alt="Payment receipt"
               style="max-width:340px; border:1px solid #e6e8ec; border-radius:6px;" />
        </a>
        <div style="font-size:12px; color:#999; margin-top:4px;">
          Click to open full size. This link expires in five minutes.
        </div>`;
    };
  });
}

function wirePaymentActions() {
  document.querySelectorAll("[data-order] button[data-pay]").forEach((button) => {
    button.onclick = async () => {
      const card = button.closest("[data-order]");
      const orderId = Number(card.dataset.order);
      const note = card.querySelector('[data-field="note"]').value.trim();
      const status = button.dataset.pay;

      if (status === "REJECTED" &&
          !confirm("Reject this payment? The customer will be asked to send another receipt.")) {
        return;
      }

      button.disabled = true;

      const { error } = await sb.rpc("admin_set_payment_status", {
        p_order_id: orderId,
        p_status: status,
        p_note: note,
      });

      if (error) {
        button.disabled = false;
        alert("Could not update that payment: " + error.message);
        return;
      }

      reloadWith(status === "APPROVED"
        ? `Payment approved for order #${orderId}.`
        : `Payment rejected for order #${orderId}.`);
    };
  });
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
