// ============================================================
// Promotions. Creating one, switching it on or off, deleting it.
//
// Reads come from admin_coupons, which joins the category name on and
// counts how many orders have used each code — a correlated subquery
// that no URL could express, which is why it is a view.
//
// Writes go to the coupons table. Worth noticing what is *not* here:
// there is no filter saying "only show promotions that are still
// running". The shop front cannot see an expired coupon because the
// policy on that table hides it; staff can see all of them because a
// second policy says so. One table, two audiences, no page anywhere
// deciding which is which.
// ============================================================

adminPage("Promotions", "coupons", async (content) => {
  const [categories, coupons] = await Promise.all([
    loadCategories(),
    loadCoupons(),
  ]);

  content.innerHTML = `
    <div class="error-box" id="form-errors" style="display:none;"></div>

    <div class="card">
      <h2 style="margin-top:0;">New promotion</h2>
      <p class="hint">
        Switching a promotion on is what sends the customer notification —
        shoppers who have been browsing that category see it on their next visit.
      </p>
      <form id="new-coupon">
        <div class="form-row">
          <div class="field">
            <label for="code">Coupon code</label>
            <input type="text" id="code" placeholder="SAVE15" required style="text-transform:uppercase;" />
          </div>
          <div class="field">
            <label for="discount_percent">Discount %</label>
            <input type="number" id="discount_percent" min="1" max="90" step="0.5" value="10" required />
          </div>
          <div class="field">
            <label for="category_id">Applies to</label>
            <select id="category_id">
              <option value="0">Everything in the shop</option>
              ${categoryOptions(categories, 0)}
            </select>
          </div>
          <div class="field">
            <label for="days">Runs for (days)</label>
            <input type="number" id="days" min="0" value="30" />
            <small>0 means no end date.</small>
          </div>
        </div>
        <div class="field">
          <label for="description">Description shown to customers</label>
          <input type="text" id="description" placeholder="Left blank, one is written for you" />
        </div>
        <button type="submit" class="btn" id="create-button">Create promotion</button>
      </form>
    </div>

    <div class="table-wrap">
    <table class="data">
      <thead>
        <tr><th>Code</th><th>Description</th><th>Applies to</th><th class="num">Discount</th>
            <th>Ends</th><th class="num">Used</th><th>Status</th><th></th></tr>
      </thead>
      <tbody>
      ${coupons.length === 0
        ? `<tr><td colspan="8" style="text-align:center; color:#888; padding:26px;">No promotions yet.</td></tr>`
        : coupons.map(couponRow).join("")}
      </tbody>
    </table>
    </div>`;

  document.getElementById("new-coupon").onsubmit = (event) => {
    event.preventDefault();
    createCoupon(categories);
  };

  wireCouponActions();
});

async function loadCoupons() {
  const { data, error } = await sb.from("admin_coupons")
    .select("coupon_id,code,description,category,discount_percent,ends_at,is_active,created_at,times_used")
    .order("is_active", { ascending: false })
    .order("created_at", { ascending: false });
  if (error) throw error;
  return data;
}

function couponRow(c) {
  const expired = c.ends_at !== null && new Date(c.ends_at) < new Date();
  const live = c.is_active === 1 && !expired;

  return `
    <tr data-id="${c.coupon_id}">
      <td><strong>${e(c.code)}</strong></td>
      <td>${e(c.description)}</td>
      <td>${e(c.category || "Everything")}</td>
      <td class="num">${e(percent(c.discount_percent))}%</td>
      <td><small>${c.ends_at ? e(when(c.ends_at, false)) : "No end date"}</small></td>
      <td class="num">${c.times_used}</td>
      <td>
        ${expired ? '<span class="badge grey">Expired</span>'
          : live  ? '<span class="badge in">Live</span>'
                  : '<span class="badge out">Off</span>'}
      </td>
      <td style="white-space:nowrap;">
        <button type="button" data-act="toggle" data-active="${c.is_active}" class="btn small grey">
          ${c.is_active === 1 ? "Switch off" : "Switch on"}
        </button>
        <button type="button" data-act="delete" class="btn small danger">Delete</button>
      </td>
    </tr>`;
}

// 15.00 -> "15", 12.50 -> "12.5". The database keeps two decimals
// because a discount can be half a percent; the page should not show
// "15.00% off" to a customer or to staff.
function percent(value) {
  return String(num(value)).replace(/\.0+$/, "");
}

function wireCouponActions() {
  document.querySelectorAll("tr[data-id] button[data-act]").forEach((button) => {
    button.onclick = async () => {
      const id = Number(button.closest("tr").dataset.id);
      button.disabled = true;

      try {
        if (button.dataset.act === "toggle") {
          const wasActive = Number(button.dataset.active) === 1;
          await write(sb.from("coupons")
            .update({ is_active: wasActive ? 0 : 1 })
            .eq("coupon_id", id));
          reloadWith(wasActive ? "Promotion switched off." : "Promotion switched on.");
        } else {
          if (!confirm("Delete this promotion?")) { button.disabled = false; return; }
          await write(sb.from("coupons").delete().eq("coupon_id", id));
          reloadWith("Promotion deleted.");
        }
      } catch (error) {
        button.disabled = false;
        alert("Could not do that: " + (error.message || error));
      }
    };
  });
}

async function createCoupon(categories) {
  const errorBox = document.getElementById("form-errors");
  const button = document.getElementById("create-button");
  const field = (id) => document.getElementById(id).value.trim();

  const code = field("code").toUpperCase();
  const percentOff = Number(field("discount_percent"));
  const categoryId = Number(field("category_id"));
  const days = Number(field("days") || 0);
  let description = field("description");

  const errors = [];
  if (code === "") errors.push("A code is required.");
  else if (!/^[A-Z0-9]{3,30}$/.test(code)) {
    errors.push("Code should be 3-30 letters and numbers, no spaces.");
  }
  if (!(percentOff > 0) || percentOff > 90) errors.push("Discount must be between 1% and 90%.");

  if (errors.length > 0) {
    errorBox.innerHTML = errors.map(e).join("<br />");
    errorBox.style.display = "block";
    return;
  }

  button.disabled = true;
  errorBox.style.display = "none";

  // The end date is worked out here rather than as "now + n days" in the
  // statement, because it is a fixed moment once chosen and reads more
  // clearly stored that way.
  const endsAt = days > 0
    ? new Date(Date.now() + days * 24 * 60 * 60 * 1000).toISOString()
    : null;

  if (description === "") {
    const category = categories.find((c) => c.category_id === categoryId);
    description = percent(percentOff) + "% off " +
      (category ? category.name.toLowerCase() : "everything");
  }

  const { error } = await sb.from("coupons").insert({
    code,
    description,
    category_id: categoryId > 0 ? categoryId : null,
    discount_percent: percentOff,
    ends_at: endsAt,
  });

  if (error) {
    button.disabled = false;
    // 23505 is a unique violation, which here can only be the code.
    errorBox.textContent = error.code === "23505"
      ? "That code already exists."
      : "Could not create the promotion: " + error.message;
    errorBox.style.display = "block";
    return;
  }

  reloadWith("Promotion created. Customers browsing that category will be notified.");
}
