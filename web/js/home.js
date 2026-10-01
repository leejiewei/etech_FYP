// Home page: "Picked for you" first, then the featured products.
//
// "Picked for you" is the FYP's recommender showing its work. The list
// comes from recommend_for_me() in the database, which blends four
// things about the signed-in customer:
//
//   * what they look at, carry to the cart, save and buy, by category
//     (keep opening laptops and the row fills with laptops),
//   * what other customers who touched the same products went on to
//     choose (item-to-item collaborative filtering),
//   * the role they picked at sign-up -- Student, Gamer or Enterprise --
//     which is all there is to go on for a brand-new account,
//   * and plain popularity, as a tie-breaker.
//
// See supabase/migrations/…_picked_for_you.sql for the weights.
//
// Signed-in customers only. Nobody else has a history the database can
// put a name to, so the row stays hidden rather than pretending.

function renderFeaturedProducts() {
  const grid = document.getElementById("featured-grid");
  if (!grid) return;

  const featured = products.slice(0, 4);
  grid.innerHTML = "";
  featured.forEach((product) => grid.appendChild(buildProductCard(product)));
}

// Accounts made before roles existed have none. Rather than guess, the
// row asks, and re-ranks the moment they answer.
function renderRolePicker(user) {
  const picker = document.getElementById("role-picker");
  const buttons = document.getElementById("role-picker-buttons");
  if (!picker || !buttons) return;

  if (user.role) { picker.hidden = true; return; }

  picker.hidden = false;
  buttons.innerHTML = "";
  SHOPPER_ROLES.forEach((r) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "role-chip";
    button.innerHTML = `<strong>${escapeHtml(r.label)}</strong><span>${escapeHtml(r.hint)}</span>`;
    button.addEventListener("click", () => {
      buttons.querySelectorAll("button").forEach((b) => { b.disabled = true; });
      setShopperRole(r.value).then((error) => {
        if (error) {
          buttons.querySelectorAll("button").forEach((b) => { b.disabled = false; });
          picker.querySelector("p").textContent = error;
          return;
        }
        renderPicks();
      });
    });
    buttons.appendChild(button);
  });
}

function renderPicks() {
  const section = document.getElementById("picks-section");
  const grid = document.getElementById("picks-grid");
  const sub = document.getElementById("picks-sub");
  if (!section || !grid) return;

  const user = getCurrentUser();
  if (!user) { section.hidden = true; return; }

  section.hidden = false;
  renderRolePicker(user);
  // No explanation under the heading or the cards (user, 1 Oct): like a
  // marketplace's "Recommended for you", the picks speak for themselves.
  if (sub) sub.textContent = "";

  sb.rpc("recommend_for_me", { p_limit: 8 }).then(({ data, error }) => {
    if (error) {
      // A recommender having a bad day must not take the home page with it.
      console.error("Loading recommendations:", error);
      section.hidden = true;
      return;
    }

    // Matched against the catalogue already in the page. Anything the
    // catalogue does not hold (delisted since) is simply skipped.
    const picks = (data || [])
      .map((row) => getProductById(row.product_id))
      .filter(Boolean);

    if (picks.length === 0) { section.hidden = true; return; }

    grid.innerHTML = "";
    picks.forEach((product) => grid.appendChild(buildProductCard(product)));
  });
}

onAppReady(() => {
  renderPicks();
  renderFeaturedProducts();
});
