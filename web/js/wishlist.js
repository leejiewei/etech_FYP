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

// Whether the server has answered yet. Until it has, the Wishlist page
// says it is loading rather than "empty".
let wishlistLoaded = false;

// Redraws everything on the page that shows the wishlist. The Wishlist
// page used to be drawn once, by its own onAppReady, which runs before
// this request comes back -- so a signed-in customer with saved items
// saw "Your wishlist is empty" next to a header count of 3 (found in
// Chapter 4 testing, Figure 4.24). Every change now repaints from here.
function refreshWishlistViews() {
  updateWishlistCount();
  if (document.getElementById("wishlist-grid")) renderWishlistPage();
  if (typeof renderProductGrid === "function") renderProductGrid();
  if (typeof renderFeaturedProducts === "function") renderFeaturedProducts();
}

function loadWishlist() {
  if (!isLoggedIn()) {
    wishlistIds = [];
    wishlistLoaded = true;
    // Synchronous here, so before the shop's own start-up has drawn its
    // grid: only the badge and the Wishlist page need anything.
    updateWishlistCount();
    if (document.getElementById("wishlist-grid")) renderWishlistPage();
    return Promise.resolve();
  }

  return sb.from("wishlist_items").select("product_id").order("added_at")
    .then(({ data, error }) => {
      if (error) { console.error("Reading the wishlist:", error); return; }
      wishlistIds = data.map((row) => row.product_id);
    })
    .finally(() => {
      wishlistLoaded = true;
      refreshWishlistViews();
    });
}

// Like adding to the basket, this goes through a database function
// rather than writing the row here. Adding to the wishlist records an
// activity worth 3 in the velocity score and removing does not, and the
// page should not be the thing deciding which of those happened. The
// function hands the whole list back, so one round trip is enough to
// repaint every heart on the page.
// Returns a promise that settles once the wishlist has actually changed.
// Nothing had to wait for it while every heart on the page was redrawn
// by the calls at the bottom of this function; the product modal is not
// one of those pages, and reads the new state itself once this is done.
function toggleWishlist(productId) {
  if (!isLoggedIn()) {
    askToLogIn("You need an account to save things to your wishlist.");
    return Promise.resolve();
  }
  return sb.rpc("toggle_wishlist", { p_product_id: productId }).then(({ data, error }) => {
    if (error) { alert(dbMessage(error, "Could not update your wishlist.")); return; }
    const added = !isInWishlist(productId);
    wishlistIds = data || [];
    // Redraw whichever page we're on so the heart fills or empties.
    refreshWishlistViews();
    if (typeof showToast === "function") {
      showToast(added ? "Saved to your wishlist." : "Removed from your wishlist.", 2200);
    }
  });
}

// The products on the wishlist the shop still sells. A product taken off
// sale stays in wishlist_items but cannot be shown, so it is not counted
// either -- the badge and the page must agree.
function visibleWishlist() {
  if (!productsLoaded) return wishlistIds;
  return wishlistIds.filter((id) => getProductById(id));
}

function updateWishlistCount() {
  const countEl = document.getElementById("wishlist-count");
  if (countEl) countEl.textContent = visibleWishlist().length;
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

  if (!wishlistLoaded) {
    emptyMessage.style.display = "block";
    emptyMessage.textContent = "Loading your wishlist…";
    return;
  }

  const ids = visibleWishlist();
  if (ids.length === 0) {
    emptyMessage.style.display = "block";
    emptyMessage.innerHTML = 'Your wishlist is empty. <a href="shop.html">Browse products</a>';
    return;
  }

  emptyMessage.style.display = "none";
  ids.forEach((productId) => {
    grid.appendChild(buildProductCard(getProductById(productId)));
  });
}

onAppReady(loadWishlist);
