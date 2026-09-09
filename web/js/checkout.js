// ============================================================
// Checkout.
//
// The browser sends only the delivery details and an optional coupon.
// Every price, the discount and the total are worked out inside the
// database from the basket rows — so editing this page cannot change
// what anything costs.
//
// The card sandbox that used to sit at the bottom of this page is gone.
// It took sixteen digits, sent them nowhere and said so. In its place is
// what a small shop without a payment gateway actually does: show a
// DuitNow QR or a bank account, take a photograph of the receipt, and
// have a member of staff check it against the amount before anything is
// packed. See js/payment.js for the details themselves.
//
// The order is written before the receipt is asked for, and that order
// is worth explaining. The receipt has to be filed against something,
// and the customer has to know the exact amount before they can pay it.
// So the order is placed, its payment_status starts at PENDING, and the
// confirmation screen is where the money is actually sent. An order with
// no receipt against it is not a failure -- it is a customer who has not
// paid yet, which the shop can see and chase.
// ============================================================

// Set once the order exists, so the receipt upload knows what it is a
// receipt for.
let placedOrderId = null;

function renderCheckoutSummary() {
  const listEl = document.getElementById("checkout-items");
  const totalEl = document.getElementById("checkout-total");
  const formSection = document.getElementById("checkout-form-section");
  const emptyEl = document.getElementById("checkout-empty");

  if (!isLoggedIn()) {
    formSection.style.display = "none";
    emptyEl.style.display = "block";
    emptyEl.innerHTML = 'Please <a href="login.html">log in</a> to check out.';
    return;
  }

  const items = getCart();
  if (items.length === 0) {
    formSection.style.display = "none";
    emptyEl.style.display = "block";
    emptyEl.innerHTML = 'Your cart is empty. <a href="shop.html">Go shopping</a>';
    return;
  }

  listEl.innerHTML = items.map((item) =>
    `<li>${item.qty} x ${escapeHtml(item.name)} — RM ${item.lineTotal.toFixed(2)}</li>`).join("");
  totalEl.textContent = "RM " + items.reduce((s, i) => s + i.lineTotal, 0).toFixed(2);
}

function prefillFromProfile() {
  const user = getCurrentUser();
  if (!user) return;
  document.getElementById("checkout-name").value = user.name || "";
  document.getElementById("checkout-address").value = user.address || "";
  document.getElementById("checkout-phone").value = user.phone || "";
}

function placeOrder(event) {
  event.preventDefault();
  const errorEl = document.getElementById("checkout-error");
  errorEl.textContent = "";

  const couponField = document.getElementById("checkout-coupon");
  const method = chosenPaymentMethod();

  // place_order() is a function inside the database. It reads the
  // basket, prices it, writes the order and its lines, records a
  // purchase against each product and empties the basket — all as one
  // indivisible step, so a failure halfway cannot leave an order with
  // no items in it.
  //
  // Only the delivery details, the coupon code and how they intend to
  // pay are sent. Every price, the discount and the total are worked out
  // down there from the basket rows, so editing this page cannot change
  // what anything costs. Nor can it change whether the payment has been
  // checked: payment_status starts at PENDING on that side and only a
  // member of staff can move it.
  sb.rpc("place_order", {
    p_name:    document.getElementById("checkout-name").value.trim(),
    p_phone:   document.getElementById("checkout-phone").value.trim(),
    p_address: document.getElementById("checkout-address").value.trim(),
    p_coupon:  couponField ? couponField.value.trim() : "",
    p_payment_method: method,
  }).then(({ data, error }) => {
    if (error) {
      errorEl.textContent = dbMessage(error, "Could not place the order. Nothing was charged.");
      return;
    }

    const discount = Number(data.discount);
    placedOrderId = data.orderId;

    document.getElementById("checkout-form-section").style.display = "none";
    document.getElementById("checkout-confirmation").style.display = "block";
    document.getElementById("confirm-order-id").textContent = data.orderId;
    document.getElementById("confirm-total").textContent = "RM " + Number(data.total).toFixed(2);

    // The same instructions again, because this is the screen somebody
    // is looking at while their banking app is open.
    document.getElementById("confirm-pay-details").innerHTML = paymentPanelHtml(method);

    // Sending the receipt over WhatsApp instead of uploading it. Written
    // here rather than in the markup because the message has to name this
    // order and its amount, and neither exists until the order is placed.
    //
    // wa.me cannot carry an attachment, so this opens the chat with the
    // words ready and the customer adds the photo. That is one tap more
    // than the uploader above and is still how most people would rather
    // do it, so both are offered rather than one replacing the other.
    const waButton = document.getElementById("receipt-whatsapp");
    if (waButton) {
      waButton.href = whatsappShopLink(
        "Hi eTech, this is my payment receipt for order #" + data.orderId +
        ", RM " + Number(data.total).toFixed(2) + "."
      );
    }

    const savedEl = document.getElementById("confirm-discount");
    if (savedEl) {
      savedEl.style.display = discount > 0 ? "block" : "none";
      savedEl.textContent = discount > 0
        ? `Coupon ${data.coupon} saved you RM ${discount.toFixed(2)}.` : "";
    }

    // The basket was emptied down in the database, so refresh our copy.
    loadCart();
  });
}

// ------------------------------------------------------------
// Sending the receipt.
//
// The file is shrunk and re-encoded in the browser by photo.js before it
// goes anywhere -- a 4MB phone photo becomes a legible JPEG a fraction
// of the size, and drawing it through a canvas strips whatever else was
// in the original file.
//
// It lands in a private bucket, in a folder named after the customer,
// and the path is then handed to attach_payment_receipt(). That function
// checks the order is theirs, that the payment has not already been
// approved, and that the path is inside their own folder before it
// records anything -- so none of the three facts this page is asserting
// are taken on the page's word.
// ------------------------------------------------------------
function sendReceipt() {
  const fileInput = document.getElementById("receipt-file");
  const errorEl = document.getElementById("receipt-error");
  const doneEl = document.getElementById("receipt-done");
  const button = document.getElementById("receipt-send");

  errorEl.textContent = "";
  doneEl.style.display = "none";

  const file = fileInput.files[0];
  if (!file) {
    errorEl.textContent = "Choose the receipt photo first.";
    return;
  }

  const problem = checkPhoto(file);
  if (problem) { errorEl.textContent = problem; return; }

  const user = getCurrentUser();
  if (!user || placedOrderId === null) {
    errorEl.textContent = "Please sign in and place the order first.";
    return;
  }

  button.disabled = true;
  button.textContent = "Uploading…";

  uploadReceipt(file, user.id, placedOrderId)
    .then((path) => sb.rpc("attach_payment_receipt", {
      p_order_id: placedOrderId,
      p_path: path,
    }))
    .then((result) => {
      if (result && result.error) throw result.error;
      fileInput.value = "";
      doneEl.style.display = "block";
      doneEl.textContent =
        "Receipt received. We will check it and move your order on — you can " +
        "follow it in your order history.";
      button.textContent = "Send another";
      button.disabled = false;
    })
    .catch((error) => {
      button.disabled = false;
      button.textContent = "Upload receipt";
      errorEl.textContent = dbMessage(error, "Could not upload that receipt.");
    });
}

onAppReady(() => {
  renderCheckoutSummary();
  prefillFromProfile();
  // Before the panel is chosen, not after: this may move the selection off
  // DuitNow, and the panel that ends up on screen has to be the one the
  // radio actually says.
  applyPaymentAvailability();
  showPaymentPanel(chosenPaymentMethod());
});
