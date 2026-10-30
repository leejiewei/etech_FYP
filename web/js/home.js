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
// A guest has no history the database can put a name to, so their row
// is worked out here instead, from what this browser has viewed -- see
// guestPicks(). A guest who has viewed nothing gets no row, and
// "Featured products" below stands in.

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
  if (!user) { renderGuestPicks(section, grid, sub); return; }

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
// Picks for a guest, from this browser's Recently viewed list.
//
// Every product the shop has in stock is scored against each viewed
// one. Only the same department counts at all (4); on top of that, the
// same type (sub-category) 3, the same maker 1.5 and a price within half
// to double 1. Without that rule an ASUS laptop would pull in ASUS
// graphics cards. A view counts less the further back it is (1, 1/2,
// 1/3 ...), so the row follows what they are looking at now. Products
// already viewed and anything out of stock are left out. One department
// fills at most 5 of the 8, so a guest who looked at a graphics card and
// then a laptop still sees some of each.
// ------------------------------------------------------------
const GUEST_PICKS_SHOWN = 8;
const GUEST_PICKS_PER_DEPARTMENT = 5;

function guestPicks(viewedIds) {
  const viewed = viewedIds.map(getProductById).filter(Boolean);
  if (viewed.length === 0) return [];
  const seen = new Set(viewed.map((p) => p.id));

  return products
    .filter((p) => !seen.has(p.id) && p.price > 0 && stockOf(p) !== "out")
    .map((p) => {
      let score = 0;
      viewed.forEach((v, i) => {
        if (p.category !== v.category) return;
        let match = 4;
        if (v.subcategory && p.subcategory === v.subcategory) match += 3;
        if (v.brand && p.brand === v.brand) match += 1.5;
        if (v.price > 0 && p.price >= v.price / 2 && p.price <= v.price * 2) match += 1;
        score += match / (i + 1);
      });
      return { p, score };
    })
    .filter((r) => r.score > 0)
    .sort((a, b) => b.score - a.score
      || (stockOf(a.p) === "in" ? 0 : 1) - (stockOf(b.p) === "in" ? 0 : 1)
      || a.p.id - b.p.id)
    .reduce((picked, r, i, ranked) => {
      const same = picked.filter((p) => p.category === r.p.category).length;
      const othersLeft = ranked.slice(i + 1).some((o) => o.p.category !== r.p.category);
      if (picked.length < GUEST_PICKS_SHOWN && (same < GUEST_PICKS_PER_DEPARTMENT || !othersLeft)) picked.push(r.p);
      return picked;
    }, []);
}

function renderGuestPicks(section, grid, sub) {
  const picker = document.getElementById("role-picker");
  if (picker) picker.hidden = true;
  if (sub) sub.textContent = "";
  const ids = typeof getGuestRecent === "function" ? getGuestRecent().map((r) => r.id) : [];
  const picks = guestPicks(ids);
  const featured = document.getElementById("featured-section");

  section.hidden = picks.length === 0;
  if (featured) featured.hidden = picks.length > 0;
  grid.innerHTML = "";
  picks.forEach((product) => grid.appendChild(buildProductCard(product)));
}

// ------------------------------------------------------------
// The shop's departments. "Featured products" shows one in-stock
// product from each, so the row covers the whole shop. (The home page
// used to list them as tiles too; the user removed that on 15 Oct 2026
// because the header and its search already lead to them.)
// ------------------------------------------------------------
const HOME_DEPARTMENTS = [
  { name: "Components", param: "category" },
  { name: "Laptops", param: "category" },
  { name: "Gaming Gear", param: "category" },
  { name: "Monitors", param: "category" },
  { name: "Printers", param: "category" },
  { name: "Networking", param: "category" },
  { name: "Accessories", param: "category" },
  { name: "Branded PC", param: "category" },
];

// ------------------------------------------------------------
// Your cart, down the side of the home page.
//
// Redrawn whenever the cart changes (cart.js calls renderTill from
// updateCartCount). Lines that were not there on the last draw are
// marked new and fade in, once. Nothing else moves.
// ------------------------------------------------------------
let tillPrinted = null;   // ids on the last draw; null before the first

function renderTill() {
  const till = document.getElementById("till");
  if (!till) return;

  const user = typeof getCurrentUser === "function" ? getCurrentUser() : null;
  const items = typeof getCart === "function" ? getCart() : [];
  const head = `<h2 class="till-head">${typeof uiIcon === "function" ? uiIcon("cart") : ""}Your cart</h2>`;

  if (!user) {
    renderTillBar(0, 0);
    till.innerHTML = head + `
      <p class="till-empty">Log in to start a cart. What you add stays saved on your account.</p>
      <a class="add-btn till-action" href="login.html">Log in</a>
      <a class="till-sub" href="register.html">New here? Create an account</a>`;
    tillPrinted = [];
    return;
  }

  if (items.length === 0) {
    renderTillBar(0, 0);
    till.innerHTML = head + `
      <p class="till-empty">Your cart is empty. Add a part and it shows here.</p>`;
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

// ------------------------------------------------------------
// Recently viewed, newest first, one of each. A signed-in customer
// sees their account's list, a guest this browser's -- see
// loadRecentViews() in tracking.js. Hidden until there is one.
// ------------------------------------------------------------
const RECENT_SHOWN = 4;

function renderRecentlyViewed() {
  const section = document.getElementById("recent-section");
  const grid = document.getElementById("recent-grid");
  if (!section || !grid || typeof loadRecentViews !== "function") return Promise.resolve([]);

  return loadRecentViews().then((ids) => {
    const recent = ids.map(getProductById).filter(Boolean);
    section.hidden = recent.length === 0;
    grid.innerHTML = "";
    recent.slice(0, RECENT_SHOWN).forEach((product) => grid.appendChild(buildProductCard(product)));
    return recent;
  });
}

// ------------------------------------------------------------
// Why customers trust eTech.
//
// The reviews are real 5-star Google reviews of the shop, copied word
// for word on 15 Oct 2026 (the user picked 5-star only). The listing
// stood at 4.4 from 72 reviews that day; the page shows no average.
// The three numbers and the promises are the shop's own, given by the
// user the same day.
// ------------------------------------------------------------
const GOOGLE_REVIEWS_URL = "https://maps.google.com/?cid=10756806437846608701";

const GOOGLE_REVIEWS = [
  { name: "JX Chow", text: "I had a fantastic experience with Yeoh while purchasing my customized desktop. He's not only a nice and professional person but also helped tailor the PC to my budget. After using it for a few months, the performance is excellent. The free software updates and dust cleaning service are a great bonus. Highly recommend, and be sure to ask for Yeoh!" },
  { name: "Kris Khaira", text: "Great customer service and quality products. Yeoh has a systematic way to help you identify your problem, and then recommend the right solution. I've bought a Wi-Fi router from them, and a DisplayPort to USB-C cable. They are also open everyday incl Sunday." },
  { name: "Charles Alejandro", text: "Thank you for this shop, they have good customer service and their price point is really good. We will definitely come back to buy more pc parts and maybe get a new set up. Thank you again. Update: Almost 5 months after buying my gpu from this shop, I did a big pc upgrade and they never fail to assist and cater to my needs thank you E-Tech. From great deals to great recommendations. Again, I'll come back and do more pc upgrades." },
  { name: "Danial Nashri", text: "I bought a gaming pc in August 2021. All parts are new complete with box and warranty. Staff are friendly to questions and helped to carry the pc back to my car. Reliable and professional service overall" },
  { name: "Kong YB", text: "Kudos to this shop~ their PC component price remain reasonable although at this global pandemic situation which causing CPU/GPU shortage. Response in FB messenger is quick and they wont hard push customer to make decision~" },
  { name: "michael vincent gaytano (gmvincent)", text: "The staff is friendly and kind to answer every question. Diagnosed and provided solutions on the slow down of the laptop. Their service and charges are kind of reasonable if not cheap." },
];

const CARE_PROMISES = [
  { icon: "clock", title: "Open every day", text: "Sundays too, at Kompleks Bukit Jambul." },
  { icon: "package", title: "New parts, box and warranty", text: "Every part is brand new, in its box, with the maker's warranty." },
  { icon: "shieldCheck", title: "Tested before handover", text: "We test every PC we build before you take it home." },
];

function fiveStars() {
  return `<span class="stars" role="img" aria-label="5 out of 5 stars">${uiIcon("star").repeat(5)}</span>`;
}

function renderTrust() {
  const track = document.getElementById("review-track");
  if (!track) return;

  // Five full stars for the reviews shown, which are all 5-star ones.
  // Deliberately no average: Google's is 4.4, and a number here would
  // either repeat that or claim a rating the listing doesn't have.
  document.getElementById("trust-stars").innerHTML = fiveStars();
  document.getElementById("trust-google").href = GOOGLE_REVIEWS_URL;

  track.innerHTML = GOOGLE_REVIEWS.map((r) => `
    <figure class="review-card">
      <figcaption class="review-who">
        <span class="review-initial" aria-hidden="true">${escapeHtml(r.name.charAt(0).toUpperCase())}</span>
        <span><strong>${escapeHtml(r.name)}</strong><small>Google review</small></span>
      </figcaption>
      ${fiveStars()}
      <blockquote>${escapeHtml(r.text)}</blockquote>
    </figure>`).join("");

  // The arrows move the rail one card at a time.
  const step = (dir) => {
    const card = track.querySelector(".review-card");
    const by = card ? card.getBoundingClientRect().width + 16 : 300;
    track.scrollBy({ left: dir * by, behavior: "smooth" });
  };
  const prev = document.getElementById("review-prev");
  const next = document.getElementById("review-next");
  prev.innerHTML = uiIcon("chevron");
  next.innerHTML = uiIcon("chevron");
  prev.addEventListener("click", () => step(-1));
  next.addEventListener("click", () => step(1));
  const ends = () => {
    prev.disabled = track.scrollLeft <= 2;
    next.disabled = track.scrollLeft + track.clientWidth >= track.scrollWidth - 2;
  };
  track.addEventListener("scroll", ends, { passive: true });
  window.addEventListener("resize", ends);
  ends();

  document.getElementById("care-list").innerHTML = CARE_PROMISES.map((c) => `
    <li>
      <span class="care-icon">${uiIcon(c.icon)}</span>
      <strong>${escapeHtml(c.title)}</strong>
      <span>${escapeHtml(c.text)}</span>
    </li>`).join("");

  countUpStats();
}

// The three numbers count up once, the first time they scroll into
// view. With reduced motion they simply stand at their value.
function countUpStats() {
  const nums = document.querySelectorAll(".stat-num[data-count]");
  if (!nums.length || !("IntersectionObserver" in window)) return;
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

  const show = (el, v) => { el.textContent = v.toLocaleString("en-MY") + el.dataset.suffix; };
  const run = (el) => {
    const target = Number(el.dataset.count);
    const start = performance.now();
    const ms = 1200;
    const tick = (now) => {
      const t = Math.min(1, (now - start) / ms);
      show(el, Math.round(target * (1 - Math.pow(1 - t, 3))));
      if (t < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  };
  const io = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      io.unobserve(entry.target);
      run(entry.target);
    });
  }, { threshold: 0.6 });
  nums.forEach((el) => { show(el, 0); io.observe(el); });
}

// A product opened from this page changes both rows. A signed-in
// customer's picks come from the database and are left as they are.
document.addEventListener("recentviewschange", () => {
  renderRecentlyViewed();
  if (!getCurrentUser()) renderPicks();
});

onAppReady(() => {
  renderRecentlyViewed();
  renderTrust();
  renderPicks();
  renderFeaturedProducts();
  renderTill();
});
