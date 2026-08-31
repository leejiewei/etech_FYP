// ============================================================
// Wishlist. Like the cart, it belongs to the customer's account rather
// than to one browser, so it needs a login — and like the cart it is
// read straight from Supabase, with the policy on wishlist_items making
// "your wishlist" mean the same thing to the database as it does here.
// ============================================================

let wishlistIds = [];        // last copy the server sent us

function getWishlist() {
  return wishlistIds;
}

function isInWishlist(productId) {
  return wishlistIds.indexOf(productId) !== -1;
}

function loadWishlist() {
  if (!isLoggedIn()) { wishlistIds = []; updateWishlistCount(); return Promise.resolve(); }

  return sb.from("wishlist_items").select("product_id").order("added_at")
    .then(({ data, error }) => {
      if (error) { console.error("Reading the wishlist:", error); return; }
      wishlistIds = data.map((row) => row.product_id);
      updateWishlistCount();
    });
}

// Like adding to the basket, this goes through a database function
// rather than writing the row here. Adding to the wishlist records an
// activity worth 3 in the velocity score and removing does not, and the
// page should not be the thing deciding which of those happened. The
// function hands the whole list back, so one round trip is enough to
// repaint every heart on the page.
function toggleWishlist(productId) {
  if (!isLoggedIn()) {
    askToLogIn("You need an account to save things to your wishlist.");
    return;
  }
  sb.rpc("toggle_wishlist", { p_product_id: productId }).then(({ data, error }) => {
    if (error) { alert(dbMessage(error, "Could not update your wishlist.")); return; }
    wishlistIds = data || [];
    updateWishlistCount();

    // Redraw whichever page we're on so the heart fills or empties.
    if (document.getElementById("wishlist-grid")) renderWishlistPage();
    if (typeof renderProductGrid === "function") renderProductGrid();
    if (typeof renderFeaturedProducts === "function") renderFeaturedProducts();
  });
}

function updateWishlistCount() {
  const countEl = document.getElementById("wishlist-count");
  if (countEl) countEl.textContent = wishlistIds.length;
}

function renderWishlistPage() {
  const grid = document.getElementById("wishlist-grid");
  const emptyMessage = document.getElementById("wishlist-empty");
  if (!grid) return;

  grid.innerHTML = "";

  if (!isLoggedIn()) {
    emptyMessage.style.display = "block";
    emptyMessage.innerHTML = 'Please <a href="login.html">log in</a> to see your wishlist.';
    return;
  }

  if (wishlistIds.length === 0) {
    emptyMessage.style.display = "block";
    emptyMessage.innerHTML = 'Your wishlist is empty. <a href="shop.html">Browse products</a>';
    return;
  }

  emptyMessage.style.display = "none";
  wishlistIds.forEach((productId) => {
    const product = getProductById(productId);
    if (product) grid.appendChild(buildProductCard(product));
  });
}

onAppReady(loadWishlist);
