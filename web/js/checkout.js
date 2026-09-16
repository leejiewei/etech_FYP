// ============================================================
// Checkout.
//
// The browser sends a name, a phone number, how the customer wants to
// get their things, and an optional coupon. The address goes with it only
// when they asked for delivery -- a collection has nowhere to send
// anything, and the database drops any address sent with one anyway. See
// js/fulfilment.js for the two vocabularies and js/pickup.js for where
// the shop is.
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
  document.getElementById("checkout-phone").value = user.phone || "";
  // Only useful if they pick delivery, but filled in now rather than at
  // the moment they switch: the profile is already loaded here, and a
  // field that populates itself as you click a radio button looks like a
  // glitch.
  document.getElementById("checkout-address").value = user.address || "";
}

// Which way they want it. Defaults to collection if the radios are
// somehow absent, which matches the database's own reading.
function chosenFulfilment() {
  const picked = document.querySelector("input[name='fulfilment']:checked");
  return picked ? picked.value : "PICKUP";
}

// Swap the half of the form that the choice implies.
//
// `required` moves with the field rather than living in the markup. A
// hidden input carrying required blocks submission with a validation
// bubble pointing at something nobody can see, which is a page that
// simply stops working with no explanation.
function showFulfilment(method) {
  const delivery = isDelivery(method);
  const addressBlock = document.getElementById("address-block");
  const address = document.getElementById("checkout-address");
  const pickup = document.getElementById("pickup-notice");
  const phoneNote = document.getElementById("phone-note");

  addressBlock.style.display = delivery ? "block" : "none";
  address.required = delivery;

  pickup.style.display = delivery ? "none" : "block";
  pickup.innerHTML = delivery ? "" : pickupNoticeHtml();

  phoneNote.textContent = delivery
    ? "We message this number about your delivery."
    : "We message this number when your order is ready to collect.";
}

function placeOrder(event) {
  event.preventDefault();
  const errorEl = document.getElementById("checkout-error");
  errorEl.textContent = "";

  const couponField = document.getElementById("checkout-coupon");
  const method = chosenPaymentMethod();
  const fulfilment = chosenFulfilment();

  // place_order() is a function inside the database. It reads the
  // basket, prices it, writes the order and its lines, records a
  // purchase against each product and empties the basket — all as one
  // indivisible step, so a failure halfway cannot leave an order with
  // no items in it.
  //
  // Only the details, the coupon code, how they intend to pay and how
  // they want it are sent. p_address goes up empty for a collection and
  // is dropped on that side regardless, so a stray address cannot ride
  // along on an order nobody is delivering.
  //
  // Every price, the discount and the total are worked out
  // down there from the basket rows, so editing this page cannot change
  // what anything costs. Nor can it change whether the payment has been
  // checked: payment_status starts at PENDING on that side and only a
  // member of staff can move it.
  sb.rpc("place_order", {
    p_name:    document.getElementById("checkout-name").value.trim(),
    p_phone:   document.getElementById("checkout-phone").value.trim(),
    p_address: fulfilment === "DELIVERY"
      ? document.getElementById("checkout-address").value.trim() : "",
    p_coupon:  couponField ? couponField.value.trim() : "",
    p_payment_method: method,
    p_fulfilment: fulfilment,
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

    // Where to come and get it, said again on the screen people keep --
    // or, for a delivery, what happens next instead. The confirmation is
    // the screen somebody screenshots, so it has to answer the question
    // they will have tomorrow.
    const confirmPickup = document.getElementById("confirm-pickup-notice");
    if (confirmPickup) {
      confirmPickup.innerHTML = fulfilment === "DELIVERY"
        ? `<div class="pickup-note">
             <strong>Delivery</strong>
             <p>
               We will send this to the address you gave us once your
               payment has been checked, and message you when it is on
               its way.
             </p>
           </div>`
        : pickupNoticeHtml();
    }
    document.getElementById("receipt-limits").textContent = `Accepted: ${PHOTO_LIMITS_TEXT}`;
    // Say what is wrong with a file as soon as it is chosen, not only
    // after Upload is pressed.
    document.getElementById("receipt-file").onchange = (e) => {
      document.getElementById("receipt-error").textContent = checkPhoto(e.target.files[0]) || "";
    };

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

// Waiting for the basket, not just for the catalogue and the session.
//
// This page paints its form immediately -- #checkout-form-section has no
// display:none -- and then renderCheckoutSummary() decides whether to keep
// it. Reading the basket synchronously here found it empty every time, so
// a customer with a full cart watched their order details appear and be
// replaced, about a second later, by "Your cart is empty". The order was
// fine; nothing had gone wrong with it. This page simply asked before the
// answer existed.
//
// whenCartLoaded() returns the request onAppReady already started in
// cart.js, so this waits rather than asking again.
onAppReady(() => {
  whenCartLoaded().then(() => {
    renderCheckoutSummary();
    prefillFromProfile();
    // Painted before the form is used, not after it is submitted: where
    // to collect is something to read while deciding, not afterwards.
    // This also puts the form into the state its checked radio claims.
    showFulfilment(chosenFulfilment());
    // Before the panel is chosen, not after: this may move the selection
    // off DuitNow, and the panel that ends up on screen has to be the one
    // the radio actually says.
    applyPaymentAvailability();
    showPaymentPanel(chosenPaymentMethod());
  });
});
