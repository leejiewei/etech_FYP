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
  // Two requests rather than one nested select. cart_item_upgrades hangs
  // off cart_items by a two-column key, which PostgREST will not walk
  // without being told which constraint to use; asking for the rows
  // plainly and matching them up here keeps working when the schema is
  // next touched.
  return Promise.all([
    sb.from("cart_items")
      .select("product_id,quantity,products(name,price,icon,img_slug,image_path,stock_status)")
      .order("added_at"),
    sb.from("cart_item_upgrades")
      .select("product_id,prebuilt_upgrades(upgrade_id,slot,label,price_delta,kind)"),
  ]).then(([lines, upgrades]) => {
    if (lines.error) { console.error("Reading the basket:", lines.error); return; }
    if (upgrades.error) console.error("Reading basket upgrades:", upgrades.error);
    applyCart(lines.data, upgrades.data || []);
  });
}

// Turns basket rows into what the page draws, and refreshes it.
function applyCart(rows, upgradeRows) {
  const chosen = {};
  (upgradeRows || []).forEach((row) => {
    if (!row.prebuilt_upgrades) return;
    (chosen[row.product_id] ||= []).push({
      id: row.prebuilt_upgrades.upgrade_id,
      slot: row.prebuilt_upgrades.slot,
      label: row.prebuilt_upgrades.label,
      priceDelta: Number(row.prebuilt_upgrades.price_delta),
      kind: row.prebuilt_upgrades.kind || "upgrade",
    });
  });
  Object.values(chosen).forEach((list) =>
    list.sort((a, b) => a.slot.localeCompare(b.slot)));

  cartItems = rows.map((row) => {
    const product = row.products;
    const upgrades = chosen[row.product_id] || [];

    // A live deal changes what the line costs, so the basket has to know
    // about it or the total on screen disagrees with the total charged.
    // priceOf() reads the deal out of the catalogue, which is the same
    // window place_order reads out of the deals table.
    //
    // The catalogue is keyed on the shaped product, not on this basket
    // row, so it is looked up by id. If it is not there -- a product
    // switched off while it sat in somebody's basket -- the row's own
    // price stands, which is what the till would charge for it too.
    const catalogueEntry = typeof getProductById === "function"
      ? getProductById(row.product_id)
      : null;
    const listPrice = Number(product.price);
    const unitPrice = catalogueEntry ? priceOf(catalogueEntry) : listPrice;

    // Each machine carries its own upgrades, so two of them cost two
    // upgrade fees -- the same way two of anything costs twice. This is
    // the same arithmetic place_order does on the other side; if the two
    // ever disagree the database wins, because it is the one charging.
    const perUnit = unitPrice +
      upgrades.reduce((sum, u) => sum + u.priceDelta, 0);

    return {
      id:        row.product_id,
      name:      product.name,
      price:     unitPrice,
      listPrice: listPrice,
      onDeal:    unitPrice < listPrice,
      qty:       row.quantity,
      icon:      product.icon,
      img:       product.img_slug,
      imagePath: product.image_path,
      stock:     product.stock_status,
      upgrades:  upgrades,
      lineTotal: perUnit * row.quantity,
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
// [upgradeIds] are the options ticked on a prebuilt card. They are
// written after the line exists, because cart_item_upgrades is keyed on
// the line and there is nothing to key to before then. Adding the same
// machine again replaces its upgrades with the newer choice rather than
// merging the two, which is what a customer changing their mind on the
// card expects.
//
// Only the ids travel. What each one costs is read from
// prebuilt_upgrades by place_order, on the server -- a browser that
// could name its own price is not a shop, which is the same reason
// adding goes through cart_add rather than an insert.
function addToCart(productId, upgradeIds) {
  if (!isLoggedIn()) {
    askToLogIn("You need an account to add things to your cart.");
    return;
  }
  const product = getProductById(productId);
  // stockOf, not product.stock: for one of the shop's own builds this is
  // the answer its parts give.
  if (product && stockOf(product) === "out") {
    alert("Sorry, " + product.name + " is out of stock.");
    return;
  }

  const picked = upgradeIds || [];

  sb.rpc("cart_add", { p_product_id: productId }).then(({ error }) => {
    if (error) { alert(dbMessage(error, "Could not add that to your cart.")); return; }
    if (!picked.length) {
      fetchCart().then(() => {
        if (product) alert(product.name + " added to cart!");
      });
      return;
    }

    saveUpgrades(productId, picked)
      .then((upgradeError) => fetchCart().then(() => {
        if (upgradeError) {
          alert("Added, but the upgrades could not be saved: " +
                dbMessage(upgradeError, "please try again from your cart."));
        } else if (product) {
          alert(product.name + " added with " + picked.length +
                (picked.length === 1 ? " upgrade!" : " upgrades!"));
        }
      }));
  });
}

function saveUpgrades(productId, upgradeIds) {
  // shapeCustomer() in auth.js renames customer_id to id; the policy on
  // cart_item_upgrades checks this against current_customer_id() anyway,
  // so a wrong value here is refused rather than written.
  const customerId = getCurrentUser().id;
  return sb.from("cart_item_upgrades").delete().eq("product_id", productId)
    .then(() => sb.from("cart_item_upgrades").insert(
      upgradeIds.map((id) => ({
        customer_id: customerId,
        product_id: productId,
        upgrade_id: id,
      }))))
    .then(({ error }) => error || null)
    .catch((error) => error);
}

// Drop one upgrade from a basket line, from the cart page.
function removeUpgrade(productId, upgradeId) {
  sb.from("cart_item_upgrades").delete()
    .eq("product_id", productId)
    .eq("upgrade_id", upgradeId)
    .then(({ error }) => {
      if (error) { alert(dbMessage(error, "Could not remove that upgrade.")); return; }
      fetchCart();
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
        <img class="cart-img" src="${safeUrl(firstSrc)}" alt="${escapeHtml(item.name)}"
          onerror="this.onerror=null; this.src='${safeUrl(fallbackSrc)}';" />
        <span>${escapeHtml(item.name)}</span>
        ${item.upgrades && item.upgrades.length ? `
        <ul class="cart-upgrades">
          ${item.upgrades.map((u) => `
            <li>+ ${escapeHtml(u.label)} <em>RM ${u.priceDelta.toFixed(2)}</em>
                <button type="button" class="upgrade-drop"
                        title="Remove this upgrade"
                        onclick="removeUpgrade(${item.id}, ${u.id})">&times;</button>
            </li>`).join("")}
        </ul>` : ""}
      </td>
      <td>
        ${item.onDeal
          ? `<span class="price-was">RM ${item.listPrice.toFixed(2)}</span>
             <span class="price-now">RM ${item.price.toFixed(2)}</span>`
          : `RM ${item.price.toFixed(2)}`}
      </td>
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
