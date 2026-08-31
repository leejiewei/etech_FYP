// Wishlist logic. Same pattern as cart.js but no quantities, just a list of product ids.

function getWishlist() {
  const text = localStorage.getItem("wishlist");
  if (text === null) return [];
  return JSON.parse(text);
}

function saveWishlist(list) {
  localStorage.setItem("wishlist", JSON.stringify(list));
}

function isInWishlist(productId) {
  return getWishlist().includes(productId);
}

function toggleWishlist(productId) {
  let list = getWishlist();

  if (list.includes(productId)) {
    list = list.filter((id) => id !== productId);
  } else {
    list.push(productId);
    logEvent("wishlist_add", productId);
  }

  saveWishlist(list);
  updateWishlistCount();

  // Refresh whichever page we're on so the heart icon / list updates.
  if (document.getElementById("wishlist-grid")) {
    renderWishlistPage();
  }
  if (typeof renderProductGrid === "function") {
    renderProductGrid();
  }
}

function updateWishlistCount() {
  const countEl = document.getElementById("wishlist-count");
  if (countEl) {
    countEl.textContent = getWishlist().length;
  }
}

function renderWishlistPage() {
  const grid = document.getElementById("wishlist-grid");
  const emptyMessage = document.getElementById("wishlist-empty");
  if (!grid) return;

  const list = getWishlist();
  grid.innerHTML = "";

  if (list.length === 0) {
    emptyMessage.style.display = "block";
    updateWishlistCount();
    return;
  }

  emptyMessage.style.display = "none";

  list.forEach((productId) => {
    const product = getProductById(productId);
    if (!product) return;
    grid.appendChild(buildProductCard(product));
  });

  updateWishlistCount();
}

document.addEventListener("DOMContentLoaded", updateWishlistCount);
