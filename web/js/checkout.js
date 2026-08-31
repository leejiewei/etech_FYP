// ============================================================
// Checkout.
//
// The browser sends only the delivery details and an optional coupon.
// Every price, the discount and the total are worked out inside the
// database from the basket rows — so editing this page cannot change
// what anything costs.
//
// The card fields are still a mock sandbox: nothing is sent anywhere and
// no card details are stored.
// ============================================================

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
    `<li>${item.qty} x ${item.name} — RM ${item.lineTotal.toFixed(2)}</li>`).join("");
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

  const cardNumber = document.getElementById("card-number").value.replace(/\s/g, "");
  if (!/^\d{16}$/.test(cardNumber)) {
    errorEl.textContent = "Enter a 16-digit mock card number (this is not a real payment).";
    return;
  }

  const couponField = document.getElementById("checkout-coupon");

  // place_order() is a function inside the database. It reads the
  // basket, prices it, writes the order and its lines, records a
  // purchase against each product and empties the basket — all as one
  // indivisible step, so a failure halfway cannot leave an order with
  // no items in it.
  //
  // Only the delivery details and the coupon code are sent. Every
  // price, the discount and the total are worked out down there from
  // the basket rows, so editing this page cannot change what anything
  // costs.
  sb.rpc("place_order", {
    p_name:    document.getElementById("checkout-name").value.trim(),
    p_phone:   document.getElementById("checkout-phone").value.trim(),
    p_address: document.getElementById("checkout-address").value.trim(),
    p_coupon:  couponField ? couponField.value.trim() : "",
  }).then(({ data, error }) => {
    if (error) {
      errorEl.textContent = dbMessage(error, "Could not place the order. Nothing was charged.");
      return;
    }

    const discount = Number(data.discount);

    document.getElementById("checkout-form-section").style.display = "none";
    document.getElementById("checkout-confirmation").style.display = "block";
    document.getElementById("confirm-order-id").textContent = data.orderId;
    document.getElementById("confirm-total").textContent = "RM " + Number(data.total).toFixed(2);

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

onAppReady(() => {
  renderCheckoutSummary();
  prefillFromProfile();
});
