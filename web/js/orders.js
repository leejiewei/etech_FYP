// ============================================================
// Order history.
//
// This lived inline in orders.html and has moved out here, because the
// page now has behaviour rather than only markup: a customer who closed
// the checkout tab before sending their receipt has to be able to send
// it from somewhere, and this is that somewhere.
//
// The two states an order is in are shown separately and deliberately:
//
//   status          where the goods are
//   payment_status  whether the money has been checked
//
// An order can be Pending with the payment approved (paid, not yet
// packed) or Processing with the payment rejected (a blurred receipt on
// an order somebody has already started). Folding those into one line
// would hide exactly the case the customer needs to act on.
// ============================================================

// Colour the status so the current stage stands out.
const ORDER_STATUS_COLOUR = {
  Pending: "#b8860b", Processing: "#2c5d8f",
  Shipped: "#6a3fb5", Delivered: "#1e8e3e", Cancelled: "#c0392b",
};

function renderOrders() {
  const list = document.getElementById("orders-list");
  list.innerHTML = "<p style='text-align:center; color:#777;'>Loading your orders...</p>";

  // Straight from the database, with each order's lines joined on.
  // There is no "and only mine" filter here and there does not need to
  // be one: the policy on orders returns the signed-in customer's own
  // rows and nothing else, so asking for all of them is asking for all
  // of theirs.
  sb.from("orders")
    .select("order_id,order_date,status,subtotal,discount,total,coupon_code," +
            "shipping_name,shipping_phone,shipping_address," +
            "payment_method,payment_status,receipt_image_path," +
            "order_items(product_id,product_name,unit_price,quantity,line_total)")
    .order("order_date", { ascending: false })
    .then(({ data: orders, error }) => {
      if (error) {
        console.error("Loading orders:", error);
        list.innerHTML =
          `<p style="text-align:center; color:#c0392b;">Could not load your orders.</p>`;
        return;
      }
      if (orders.length === 0) {
        list.innerHTML =
          `<p style="text-align:center; color:#777;">No orders yet. <a href="shop.html">Start shopping</a></p>`;
        return;
      }

      list.innerHTML = orders.map(orderCard).join("");
      orders.forEach(wireReceiptUpload);
    });
}

function orderCard(order) {
  const status = escapeHtml(order.status);
  const colour = ORDER_STATUS_COLOUR[order.status] || "#555";

  return `
    <div class="prebuilt-card" style="margin-bottom: 16px;" data-order="${order.order_id}">
      <h3>Order #${order.order_id}</h3>
      <p class="product-category">${escapeHtml(new Date(order.order_date).toLocaleString())}</p>
      <p style="font-weight:bold; color:${colour};">${status}</p>
      <ul class="prebuilt-specs">
        ${order.order_items.map((item) =>
          `<li>${item.quantity} x ${escapeHtml(item.product_name)} - RM ${Number(item.line_total).toFixed(2)}</li>`
        ).join("")}
      </ul>
      ${Number(order.discount) > 0
        ? `<p class="product-category">Coupon ${escapeHtml(order.coupon_code)}: -RM ${Number(order.discount).toFixed(2)}</p>`
        : ""}
      <p class="prebuilt-price">Total: RM ${Number(order.total).toFixed(2)}</p>
      <p class="product-category">Shipping to: ${escapeHtml(order.shipping_address)}</p>
      ${paymentSection(order)}
    </div>`;
}

// What the customer needs to know, and to do, about the money.
//
// payment_method is NULL on the orders placed before the shop could be
// paid at all -- they went through the old card sandbox. Those are shown
// as they are rather than being dressed up as a bank transfer that never
// happened.
function paymentSection(order) {
  if (!order.payment_method) {
    return `<p class="product-category">Placed before online payment was available.</p>`;
  }

  const state = order.payment_status;
  const badgeClass = state.toLowerCase();
  const label = PAYMENT_STATUS_LABELS[state] || state;
  const method = PAYMENT_METHOD_LABELS[order.payment_method] || order.payment_method;

  // Approved is the end of it: there is nothing for the customer to do
  // and nothing they are allowed to change.
  if (state === "APPROVED") {
    return `
      <p style="margin-top:10px;">
        <span class="pay-badge approved">${escapeHtml(label)}</span>
        <span class="product-category"> · ${escapeHtml(method)}</span>
      </p>`;
  }

  const chased = state === "REJECTED"
    ? `<p class="form-note" style="color:#c0392b;">
         We could not match that receipt to this order. Please send another —
         a clear photo showing the amount and the date.
       </p>`
    : order.receipt_image_path
      ? `<p class="form-note">Your receipt is with us. We will confirm it shortly.</p>`
      : `<p class="form-note">We have not received a receipt for this order yet.</p>`;

  return `
    <div style="margin-top:12px;">
      <p>
        <span class="pay-badge ${badgeClass}">${escapeHtml(label)}</span>
        <span class="product-category"> · ${escapeHtml(method)}</span>
      </p>
      ${chased}
      <div class="pay-panel">${paymentPanelHtml(order.payment_method)}</div>
      <input type="file" class="receipt-file" accept="image/jpeg,image/png,image/webp" />
      <div class="form-error receipt-error"></div>
      <p class="receipt-done" style="display:none; color:#1e8e3e;"></p>
      <button type="button" class="receipt-send">
        ${order.receipt_image_path ? "Send another receipt" : "Upload receipt"}
      </button>
    </div>`;
}

// Same upload as the checkout page's, and the same three checks in the
// database behind it. Wired per card rather than inline, because the id
// is already on the card and does not need carrying through a string.
function wireReceiptUpload(order) {
  const card = document.querySelector(`[data-order="${order.order_id}"]`);
  if (!card) return;

  const button = card.querySelector(".receipt-send");
  if (!button) return;

  const fileInput = card.querySelector(".receipt-file");
  const errorEl = card.querySelector(".receipt-error");
  const doneEl = card.querySelector(".receipt-done");

  button.onclick = () => {
    errorEl.textContent = "";
    doneEl.style.display = "none";

    const file = fileInput.files[0];
    if (!file) { errorEl.textContent = "Choose the receipt photo first."; return; }

    const problem = checkPhoto(file);
    if (problem) { errorEl.textContent = problem; return; }

    const user = getCurrentUser();
    if (!user) { errorEl.textContent = "Please sign in again."; return; }

    button.disabled = true;
    button.textContent = "Uploading…";

    uploadReceipt(file, user.id, order.order_id)
      .then((path) => sb.rpc("attach_payment_receipt", {
        p_order_id: order.order_id,
        p_path: path,
      }))
      .then((result) => {
        if (result && result.error) throw result.error;
        fileInput.value = "";
        doneEl.style.display = "block";
        doneEl.textContent = "Receipt received. We will check it shortly.";
        button.textContent = "Send another receipt";
        button.disabled = false;
      })
      .catch((error) => {
        button.disabled = false;
        button.textContent = "Upload receipt";
        errorEl.textContent = dbMessage(error, "Could not upload that receipt.");
      });
  };
}

onAppReady(() => {
  if (!isLoggedIn()) {
    window.location.href = "login.html";
    return;
  }
  renderOrders();
});
