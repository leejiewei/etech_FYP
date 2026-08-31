// Shared helper for building a product card. Used by the home page,
// shop page, wishlist page, deals page, and search results so we don't
// repeat the same card HTML in five different files.

// Builds the <img> tag for a product.
// It first tries the real photo (images/101.jpg). If that file isn't there,
// the onerror handler swaps in the drawn illustration (images/cpu.svg).
// Setting this.onerror = null first stops it looping forever if the
// illustration is missing too.
function productImageTag(product, cssClass) {
  return `<img class="${cssClass}" src="${productImage(product)}" alt="${product.name}"
    onerror="this.onerror=null; this.src='${productImageFallback(product)}';" />`;
}

function buildProductCard(product) {
  const card = document.createElement("div");
  card.className = "product-card";

  const stockClass = "stock-" + product.stock; // stock-in / stock-low / stock-out
  const heartFilled = typeof isInWishlist === "function" && isInWishlist(product.id);
  const comparing = typeof isInCompare === "function" && isInCompare(product.id);
  const outOfStock = product.stock === "out";

  card.innerHTML = `
    <button class="wishlist-btn ${heartFilled ? "active" : ""}" onclick="toggleWishlist(${product.id})" title="Add to wishlist">
      ${heartFilled ? "❤️" : "🤍"}
    </button>
    <div class="product-img-wrap">
      ${productImageTag(product, "product-img")}
    </div>
    <h3>${product.name}</h3>
    <p class="product-category">${product.category}${product.subcategory ? " · " + product.subcategory : ""}</p>
    <p class="stock-badge ${stockClass}">${stockLabel(product.stock)}</p>
    <p class="product-price">RM ${product.price.toFixed(2)}</p>
    <button class="add-btn" ${outOfStock ? "disabled" : ""} onclick="addToCart(${product.id})">
      ${outOfStock ? "Out of Stock" : "Add to Cart"}
    </button>
    <label class="compare-check">
      <input type="checkbox" ${comparing ? "checked" : ""} onchange="toggleCompare(${product.id})" />
      Compare
    </label>
  `;

  card.querySelector(".product-img-wrap").addEventListener("click", () => {
    if (typeof trackProductClick === "function") trackProductClick(product.id);
  });

  return card;
}
