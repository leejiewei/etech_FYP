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

  // One from each department, in stock, so the row shows the breadth of
  // the shop rather than the first eight rows of one table.
  const featured = HOME_DEPARTMENTS
    .map((d) => products.find((p) => p.category === d.name && stockOf(p) !== "out"))
    .filter(Boolean)
    .slice(0, 8);
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
    const featured = document.getElementById("featured-section");
    if (featured) featured.hidden = true;
  });
}

// ------------------------------------------------------------
// The department index: each aisle with a dot leader running to its
// product count, the way a receipt runs a line to its price. The counts
// are the catalogue's own, so they are true the moment the page loads.
// ------------------------------------------------------------
const HOME_DEPARTMENTS = [
  { name: "Components", hue: "components", param: "category" },
  { name: "Laptops", hue: "laptops", param: "category" },
  { name: "Gaming Gear", hue: "gaming", param: "category" },
  { name: "Monitors", hue: "monitors", param: "category" },
  { name: "Printers", hue: "printers", param: "category" },
  { name: "Networking", hue: "networking", param: "category" },
  { name: "Accessories", hue: "accessories", param: "category" },
  { name: "Branded PC", hue: "pcs", param: "category" },
];

function renderDepartmentIndex() {
  const index = document.getElementById("dept-index");
  if (!index) return;

  const rows = HOME_DEPARTMENTS
    .map((d) => ({ ...d, count: products.filter((p) => p.category === d.name).length }))
    .filter((d) => d.count > 0);

  index.innerHTML = rows.map((d) => `
    <a class="dept-row" href="shop.html?${d.param}=${encodeURIComponent(d.name)}"
       style="--row-hue: var(--hue-${d.hue})">
      <span class="dept-name">${escapeHtml(d.name)}</span>
      <span class="dept-leader" aria-hidden="true"></span>
      <span class="dept-count">${d.count}<span class="visually-hidden"> products</span></span>
    </a>`).join("") + `
    <a class="dept-row dept-all" href="shop.html">
      <span class="dept-name">Everything</span>
      <span class="dept-leader" aria-hidden="true"></span>
      <span class="dept-count">${products.length}<span class="visually-hidden"> products</span></span>
    </a>`;
}

// ------------------------------------------------------------
// The till: the customer's cart, printed down the side of the home
// page like a receipt coming off the roll.
//
// Redrawn whenever the cart changes (cart.js calls renderTill from
// updateCartCount). Lines that were not there on the last draw are
// "printed": they feed in from the top, once. Nothing else moves.
// ------------------------------------------------------------
let tillPrinted = null;   // ids on the last draw; null before the first

function renderTill() {
  const till = document.getElementById("till");
  if (!till) return;

  const user = typeof getCurrentUser === "function" ? getCurrentUser() : null;
  const items = typeof getCart === "function" ? getCart() : [];
  const now = new Date();
  const stamp = now.toLocaleDateString("en-MY", { day: "2-digit", month: "short", year: "numeric" });

  const head = `
    <div class="till-head">
      <span class="logo-mark">eTech</span>
      <span class="till-meta">Computer Accessories<br><span class="till-date">${escapeHtml(stamp)}</span></span>
    </div>`;

  if (!user) {
    renderTillBar(0, 0);
    till.innerHTML = head + `
      <p class="till-empty">Your receipt starts here. Log in and every part you add prints on this roll.</p>
      <a class="add-btn till-action" href="login.html">Log in</a>
      <a class="till-sub" href="register.html">New here? Create an account</a>`;
    tillPrinted = [];
    return;
  }

  if (items.length === 0) {
    renderTillBar(0, 0);
    till.innerHTML = head + `
      <p class="till-empty">Nothing printed yet. Add a part and it prints here.</p>`;
    tillPrinted = [];
    return;
  }

  const fresh = (id) => tillPrinted !== null && !tillPrinted.includes(id);
  const count = items.reduce((s, i) => s + i.qty, 0);
  const total = items.reduce((s, i) => s + i.lineTotal, 0);

  till.innerHTML = head + `
    <ol class="till-lines">
      ${items.map((i) => receiptLineHtml(i, fresh(i.id) ? "printing" : "")).join("")}
    </ol>
    <div class="till-total">
      <span>Total <small>${count} item${count === 1 ? "" : "s"}</small></span>
      <span class="till-sum">${money(total)}</span>
    </div>
    <a class="add-btn till-action" href="checkout.html">Check out</a>
    <a class="till-sub" href="cart.html">Edit cart</a>`;

  const printedNew = items.some((i) => fresh(i.id));
  tillPrinted = items.map((i) => i.id);
  // Once a line has printed it is an ordinary line again.
  till.querySelectorAll(".till-line.printing").forEach((line) =>
    line.addEventListener("animationend", () => line.classList.remove("printing"), { once: true }));
  renderTillBar(count, total, printedNew);
}

// On a phone the till folds into a bar along the foot of the screen:
// how many things, what they come to, and the way to pay. Tapping the
// bar pulls the same receipt up as a sheet, so a new line still prints
// on a phone; while the sheet is shut, the total pulses instead. The
// bar only exists while the cart has something in it.
function renderTillBar(count, total, printedNew) {
  let bar = document.getElementById("till-bar");
  if (!count) {
    if (bar) bar.remove();
    setTillSheet(false);
    document.body.classList.remove("has-till-bar");
    return;
  }
  if (!bar) {
    bar = document.createElement("div");
    bar.id = "till-bar";
    bar.className = "till-bar";
    document.body.appendChild(bar);
  }
  const open = document.body.classList.contains("till-open");
  bar.innerHTML = `
    <button type="button" class="till-bar-toggle" aria-controls="home-side"
            aria-expanded="${open}" onclick="setTillSheet(!document.body.classList.contains('till-open'))">
      <span class="till-bar-count">${count} item${count === 1 ? "" : "s"}</span>
      <span class="till-bar-sum">${money(total)}</span>
      ${uiIcon("chevron", "till-bar-chevron")}
    </button>
    <a class="till-bar-go" href="checkout.html">Check out</a>`;
  if (printedNew && !open) {
    const sum = bar.querySelector(".till-bar-sum");
    sum.classList.add("pulse");
    sum.addEventListener("animationend", () => sum.classList.remove("pulse"), { once: true });
  }
  document.body.classList.add("has-till-bar");
}

function setTillSheet(open) {
  document.body.classList.toggle("till-open", open);
  const toggle = document.querySelector(".till-bar-toggle");
  if (toggle) toggle.setAttribute("aria-expanded", String(open));
}

document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && document.body.classList.contains("till-open")) setTillSheet(false);
});

// A tap on the dimmed page behind the sheet shuts it.
document.addEventListener("click", (e) => {
  if (!document.body.classList.contains("till-open")) return;
  if (e.target.closest("#home-side, #till-bar")) return;
  setTillSheet(false);
});

onAppReady(() => {
  renderDepartmentIndex();
  renderPicks();
  renderFeaturedProducts();
  renderTill();
});
