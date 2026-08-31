// ============================================================
// Shopping cart.
//
// The basket used to sit in localStorage, which meant it only existed
// in one browser. It then moved to the database behind api/cart.php.
// It is still in the database — the browser just reaches it itself now,
// so the basket follows the customer between devices and the prices are
// the shop's prices, not something this page could tamper with.
//
// Two of the four operations are ordinary statements against the
// cart_items table: change a quantity, remove a line. The policy on
// that table pins every one of them to the signed-in customer, so a
// request cannot touch anybody else's basket even if it tries.
//
// Adding is not an ordinary statement, and deliberately so — see
// addToCart() below.
// ============================================================

let cartItems = [];          // last copy the database gave us
let cartTotal = 0;

// The basket, with each line's product joined on so one request brings
// back the names, prices and pictures too. This is the same query
// api/cart.php was running; PostgREST spells the join as a nested
// select.
function fetchCart() {
  return sb.from("cart_items")
    .select("product_id,quantity,products(name,price,icon,img_slug,image_path,stock_status)")
    .order("added_at")
    .then(({ data, error }) => {
      if (error) { console.error("Reading the basket:", error); return; }
      applyCart(data);
    });
}

// Turns basket rows into what the page draws, and refreshes it.
function applyCart(rows) {
  cartItems = rows.map((row) => {
    const product = row.products;
    return {
      id:        row.product_id,
      name:      product.name,
      price:     Number(product.price),
      qty:       row.quantity,
      icon:      product.icon,
      img:       product.img_slug,
      imagePath: product.image_path,
      stock:     product.stock_status,
      lineTotal: Number(product.price) * row.quantity,
    };
  });

  cartTotal = cartItems.reduce((sum, item) => sum + item.lineTotal, 0);

  updateCartCount();
  if (document.getElementById("cart-body")) drawCartTable();
}

function loadCart() {
  if (!isLoggedIn()) { cartItems = []; cartTotal = 0; updateCartCount(); return Promise.resolve(); }
  return fetchCart();
}

function getCart() {
  return cartItems;
}

// ------------------------------------------------------------
// Adding.
//
// This one goes through a database function rather than writing the row
// directly, because adding to the basket is two things at once: the
// basket line, and an activity record worth 3 in the Inventory Velocity
// score. If the browser could write those separately it could write the
// second without the first, and the score the admin dashboard is built
// on would mean nothing. cart_add() does both or neither.
//
// It also re-checks the stock. The test below is only there to save a
// round trip on the obvious case; the database makes up its own mind.
// ------------------------------------------------------------
function addToCart(productId) {
  if (!isLoggedIn()) {
    askToLogIn("You need an account to add things to your cart.");
    return;
  }
  const product = getProductById(productId);
  if (product && product.stock === "out") {
    alert("Sorry, " + product.name + " is out of stock.");
    return;
  }

  sb.rpc("cart_add", { p_product_id: productId }).then(({ error }) => {
    if (error) { alert(dbMessage(error, "Could not add that to your cart.")); return; }
    fetchCart().then(() => {
      if (product) alert(product.name + " added to cart!");
    });
  });
}

function removeFromCart(productId) {
  sb.from("cart_items").delete().eq("product_id", productId)
    .then(({ error }) => {
      if (error) { alert(dbMessage(error, "Could not remove that.")); return; }
      fetchCart();
    });
}

function changeQty(productId, amount) {
  const item = cartItems.find((i) => i.id === productId);
  if (!item) return;
  const wanted = item.qty + amount;
  if (wanted < 1) return;

  sb.from("cart_items").update({ quantity: wanted }).eq("product_id", productId)
    .then(({ error }) => {
      if (error) { alert(dbMessage(error, "Could not change the quantity.")); return; }
      fetchCart();
    });
}

// Emptying the basket names the customer explicitly. The policy would
// stop it reaching anybody else's rows regardless, but a delete with no
// filter at all is refused outright, and rightly so.
function clearCart() {
  const user = getCurrentUser();
  if (!user) return Promise.resolve();

  return sb.from("cart_items").delete().eq("customer_id", user.id)
    .then(({ error }) => {
      if (error) { console.error("Emptying the basket:", error); return; }
      return fetchCart();
    });
}

// Shows how many items are in the cart, next to the "Cart" link in the nav bar.
function updateCartCount() {
  const countEl = document.getElementById("cart-count");
  if (countEl) {
    countEl.textContent = cartItems.reduce((sum, item) => sum + item.qty, 0);
  }
}

// Builds the cart table on cart.html.
function drawCartTable() {
  const cartBody = document.getElementById("cart-body");
  const emptyMessage = document.getElementById("cart-empty");
  const totalEl = document.getElementById("cart-total");
  if (!cartBody) return;

  cartBody.innerHTML = "";

  if (!isLoggedIn()) {
    emptyMessage.style.display = "block";
    emptyMessage.innerHTML = 'Please <a href="login.html">log in</a> to see your cart.';
    totalEl.textContent = "RM 0.00";
    return;
  }

  if (cartItems.length === 0) {
    emptyMessage.style.display = "block";
    emptyMessage.innerHTML = 'Your cart is empty. <a href="shop.html">Go shopping</a>';
    totalEl.textContent = "RM 0.00";
    return;
  }

  emptyMessage.style.display = "none";

  cartItems.forEach((item) => {
    const fallbackSrc = "images/" + (item.img || "default") + ".svg";
    const firstSrc = item.imagePath ? item.imagePath : "images/" + item.id + ".jpg";

    const row = document.createElement("tr");
    row.innerHTML = `
      <td class="cart-product">
        <img class="cart-img" src="${firstSrc}" alt="${item.name}"
          onerror="this.onerror=null; this.src='${fallbackSrc}';" />
        <span>${item.name}</span>
      </td>
      <td>RM ${item.price.toFixed(2)}</td>
      <td>
        <button class="qty-btn" onclick="changeQty(${item.id}, -1)">-</button>
        <span class="qty-value">${item.qty}</span>
        <button class="qty-btn" onclick="changeQty(${item.id}, 1)">+</button>
      </td>
      <td>RM ${item.lineTotal.toFixed(2)}</td>
      <td><button class="remove-btn" onclick="removeFromCart(${item.id})">Remove</button></td>
    `;
    cartBody.appendChild(row);
  });

  totalEl.textContent = "RM " + cartTotal.toFixed(2);
}

// Kept so cart.html's existing call still works.
function renderCartPage() {
  loadCart().then(drawCartTable);
}

onAppReady(loadCart);
