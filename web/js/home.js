// Home page: featured products + a simple "Recommended for you" carousel
// that reorders itself based on what the user has been clicking on
// (see tracking.js). This is a simplified stand-in for a real
// behaviour-based recommendation engine.

function renderFeaturedProducts() {
  const grid = document.getElementById("featured-grid");
  if (!grid) return;

  const featured = products.slice(0, 4);
  grid.innerHTML = "";
  featured.forEach((product) => grid.appendChild(buildProductCard(product)));
}

function renderRecommendedProducts() {
  const section = document.getElementById("recommended-section");
  const grid = document.getElementById("recommended-grid");
  if (!grid) return;

  const topCategory = typeof getTopCategory === "function" ? getTopCategory() : null;

  let recommended;
  let heading;

  if (topCategory) {
    recommended = products.filter((p) => p.category === topCategory && p.stock !== "out").slice(0, 4);
    heading = "Because you viewed " + topCategory;
  } else {
    // No browsing history yet, just show some in-stock picks.
    recommended = products.filter((p) => p.stock === "in").slice(4, 8);
    heading = "Popular Picks";
  }

  document.getElementById("recommended-heading").textContent = heading;
  grid.innerHTML = "";
  recommended.forEach((product) => grid.appendChild(buildProductCard(product)));
}

onAppReady(() => {
  renderFeaturedProducts();
  renderRecommendedProducts();
});
