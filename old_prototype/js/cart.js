// Shopping cart logic.
// We keep the cart as a simple array of {id, name, price, qty} saved in
// localStorage so it stays there even if the page is refreshed.

function getCart() {
  const cartText = localStorage.getItem("cart");
  if (cartText === null) {
    return [];
  }
  return JSON.parse(cartText);
}

function saveCart(cart) {
  localStorage.setItem("cart", JSON.stringify(cart));
}

// Add a product (by id) to the cart, or increase its quantity if it's already there.
function addToCart(productId) {
  const product = products.find((p) => p.id === productId);
  if (!product) return;
  if (product.stock === "out") {
    alert("Sorry, " + product.name + " is out of stock.");
    return;
  }

  if (typeof logEvent === "function") logEvent("cart_add", productId);

  const cart = getCart();
  const existingItem = cart.find((item) => item.id === productId);

  if (existingItem) {
    existingItem.qty += 1;
  } else {
    cart.push({
      id: product.id,
      name: product.name,
      price: product.price,
      icon: product.icon,
      img: product.img,
      qty: 1,
    });
  }

  saveCart(cart);
  updateCartCount();
  alert(product.name + " added to cart!");
}

function removeFromCart(productId) {
  let cart = getCart();
  cart = cart.filter((item) => item.id !== productId);
  saveCart(cart);
  renderCartPage();
}

function changeQty(productId, amount) {
  const cart = getCart();
  const item = cart.find((item) => item.id === productId);
  if (!item) return;

  item.qty += amount;
  if (item.qty < 1) {
    item.qty = 1;
  }

  saveCart(cart);
  renderCartPage();
}

// Shows how many items are in the cart, next to the "Cart" link in the nav bar.
function updateCartCount() {
  const cart = getCart();
  const totalItems = cart.reduce((sum, item) => sum + item.qty, 0);
  const countEl = document.getElementById("cart-count");
  if (countEl) {
    countEl.textContent = totalItems;
  }
}

// Builds the cart table on cart.html.
function renderCartPage() {
  const cart = getCart();
  const cartBody = document.getElementById("cart-body");
  const emptyMessage = document.getElementById("cart-empty");
  const totalEl = document.getElementById("cart-total");

  if (!cartBody) return; // not on the cart page, nothing to do

  cartBody.innerHTML = "";

  if (cart.length === 0) {
    emptyMessage.style.display = "block";
    totalEl.textContent = "RM 0.00";
    updateCartCount();
    return;
  }

  emptyMessage.style.display = "none";

  let total = 0;

  cart.forEach((item) => {
    const lineTotal = item.price * item.qty;
    total += lineTotal;

    // Bundle items (from the Prebuilt page) use text ids like "bundle-123",
    // normal products use numeric ids — quote text ids so the onclick call
    // below stays valid JavaScript either way.
    const idArg = typeof item.id === "number" ? item.id : `'${item.id}'`;

    // Bundles from the Prebuilt page have no real photo, so they go straight
    // to their illustration. Normal products try images/<id>.jpg first.
    const fallbackSrc = "images/" + (item.img || "default") + ".svg";
    const firstSrc = typeof item.id === "number" ? "images/" + item.id + ".jpg" : fallbackSrc;

    const row = document.createElement("tr");
    row.innerHTML = `
      <td class="cart-product">
        <img class="cart-img" src="${firstSrc}" alt="${item.name}"
          onerror="this.onerror=null; this.src='${fallbackSrc}';" />
        <span>${item.name}</span>
      </td>
      <td>RM ${item.price.toFixed(2)}</td>
      <td>
        <button class="qty-btn" onclick="changeQty(${idArg}, -1)">-</button>
        <span class="qty-value">${item.qty}</span>
        <button class="qty-btn" onclick="changeQty(${idArg}, 1)">+</button>
      </td>
      <td>RM ${lineTotal.toFixed(2)}</td>
      <td><button class="remove-btn" onclick="removeFromCart(${idArg})">Remove</button></td>
    `;
    cartBody.appendChild(row);
  });

  totalEl.textContent = "RM " + total.toFixed(2);
  updateCartCount();
}

// Update the cart count badge on every page load.
document.addEventListener("DOMContentLoaded", updateCartCount);
