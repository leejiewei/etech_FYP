// Simulated checkout — no real payment gateway. Card details are only
// checked for basic format (right number of digits), never sent anywhere
// or stored, since this is a mock payment sandbox for the FYP demo.

function renderCheckoutSummary() {
  const cart = getCart();
  const listEl = document.getElementById("checkout-items");
  const totalEl = document.getElementById("checkout-total");

  if (cart.length === 0) {
    document.getElementById("checkout-form-section").style.display = "none";
    document.getElementById("checkout-empty").style.display = "block";
    return;
  }

  let total = 0;
  listEl.innerHTML = cart.map((item) => {
    const lineTotal = item.price * item.qty;
    total += lineTotal;
    return `<li>${item.qty} x ${item.name} — RM ${lineTotal.toFixed(2)}</li>`;
  }).join("");

  totalEl.textContent = "RM " + total.toFixed(2);
  return total;
}

function prefillFromProfile() {
  const user = typeof getCurrentUser === "function" ? getCurrentUser() : null;
  if (!user) return;
  document.getElementById("checkout-name").value = user.name || "";
  document.getElementById("checkout-address").value = user.address || "";
  document.getElementById("checkout-phone").value = user.phone || "";
}

function placeOrder(event) {
  event.preventDefault();

  const cardNumber = document.getElementById("card-number").value.replace(/\s/g, "");
  if (!/^\d{16}$/.test(cardNumber)) {
    document.getElementById("checkout-error").textContent = "Enter a 16-digit mock card number (this is not a real payment).";
    return;
  }

  const cart = getCart();
  const total = cart.reduce((sum, item) => sum + item.price * item.qty, 0);
  const address = document.getElementById("checkout-address").value.trim();

  const order = {
    id: Math.floor(100000 + Math.random() * 900000),
    date: Date.now(),
    items: cart,
    total: total,
    address: address,
  };

  if (typeof getCurrentUser === "function" && getCurrentUser()) {
    addOrderToHistory(order);
  }

  saveCart([]); // empty the cart after "payment"
  updateCartCount();

  document.getElementById("checkout-form-section").style.display = "none";
  document.getElementById("checkout-confirmation").style.display = "block";
  document.getElementById("confirm-order-id").textContent = order.id;
  document.getElementById("confirm-total").textContent = "RM " + total.toFixed(2);
}

document.addEventListener("DOMContentLoaded", () => {
  renderCheckoutSummary();
  prefillFromProfile();
});
