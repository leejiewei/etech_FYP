// ============================================================
// Timed deals. Putting a price on one product until a stated moment,
// switching one off, deleting one.
//
// Reads come from admin_deals, which joins the product name and its
// list price on and works out the percentage — the same reason every
// other report here is a view rather than a URL.
//
// Writes go to the deals table. As on every other page in this console
// there is no "are you staff" check written here, because one would be
// worth nothing: the policy on that table refuses the statement if the
// answer is no, and a check in this file could be avoided by not using
// this file.
//
// What is deliberately *not* here is a price. The form takes a price
// and sends it, and the shop front draws whatever comes back — but the
// number the customer is charged is read out of this table by
// place_order at the moment of checkout, not sent up from their phone.
// So this page sets the price; it does not hand the browser one to
// quote.
// ============================================================

adminPage("Timed Deals", "deals", async (content) => {
  const [productList, deals] = await Promise.all([
    loadDealProducts(),
    loadDeals(),
  ]);

  content.innerHTML = `
    <div class="error-box" id="form-errors" style="display:none;"></div>

    <div class="card">
      <h2 style="margin-top:0;">New deal</h2>
      <p class="hint">
        A deal is a price on one product for a stated window. Nothing is typed
        in by the customer — the shop shows the old price struck through, counts
        down to the end time, and the checkout charges the deal price until the
        moment it closes.
      </p>
      <form id="new-deal">
        <div class="form-row">
          <div class="field" style="min-width:280px;">
            <label for="product_id">Product</label>
            <select id="product_id" required>
              <option value="">Choose a product…</option>
              ${productList.map((p) =>
                `<option value="${p.product_id}" data-price="${p.price}">
                   ${e(p.name)} — ${e(money(p.price))}
                 </option>`).join("")}
            </select>
          </div>
          <div class="field">
            <label for="discount_price">Deal price (RM)</label>
            <input type="number" id="discount_price" min="0.01" step="0.01" required />
            <small id="price-hint">Must be below the list price.</small>
          </div>
        </div>
        <div class="form-row">
          <div class="field">
            <label for="start_time">Starts</label>
            <input type="datetime-local" id="start_time" required />
            <small>Left as now if you do not change it.</small>
          </div>
          <div class="field">
            <label for="end_time">Ends</label>
            <input type="datetime-local" id="end_time" required />
          </div>
        </div>
        <button type="submit" class="btn" id="create-button">Create deal</button>
      </form>
    </div>

    <div class="table-wrap">
    <table class="data">
      <thead>
        <tr><th>Product</th><th class="num">Was</th><th class="num">Deal</th>
            <th class="num">Off</th><th>Starts</th><th>Ends</th>
            <th>Status</th><th></th></tr>
      </thead>
      <tbody>
      ${deals.length === 0
        ? `<tr><td colspan="8" style="text-align:center; color:#888; padding:26px;">No deals yet.</td></tr>`
        : deals.map(dealRow).join("")}
      </tbody>
    </table>
    </div>`;

  prefillTimes();
  wirePriceHint(productList);

  document.getElementById("new-deal").onsubmit = (event) => {
    event.preventDefault();
    createDeal(productList);
  };

  wireDealActions();
});

// The catalogue, for the dropdown. Read from admin_products so a
// switched-off product cannot be put on offer.
async function loadDealProducts() {
  const { data, error } = await sb.from("admin_products")
    .select("product_id,name,price")
    .eq("is_active", 1)
    .order("name");
  if (error) throw error;
  return data;
}

async function loadDeals() {
  const { data, error } = await sb.from("admin_deals")
    .select("deal_id,product_id,product_name,original_price,discount_price," +
            "percent_off,start_time,end_time,is_active,is_live,created_at")
    .order("is_live", { ascending: false })
    .order("end_time", { ascending: true });
  if (error) throw error;
  return data;
}

function dealRow(d) {
  const finished = new Date(d.end_time) <= new Date();
  const waiting = !finished && new Date(d.start_time) > new Date();

  return `
    <tr data-id="${d.deal_id}">
      <td><strong>${e(d.product_name)}</strong></td>
      <td class="num">${e(money(d.original_price))}</td>
      <td class="num">${e(money(d.discount_price))}</td>
      <td class="num">${e(num(d.percent_off))}%</td>
      <td><small>${e(when(d.start_time))}</small></td>
      <td><small>${e(when(d.end_time))}</small></td>
      <td>
        ${d.is_active !== 1 ? '<span class="badge out">Off</span>'
          : finished       ? '<span class="badge grey">Ended</span>'
          : waiting        ? '<span class="badge grey">Scheduled</span>'
                           : '<span class="badge in">Live</span>'}
      </td>
      <td style="white-space:nowrap;">
        <button type="button" data-act="toggle" data-active="${d.is_active}" class="btn small grey">
          ${d.is_active === 1 ? "Switch off" : "Switch on"}
        </button>
        <button type="button" data-act="delete" class="btn small danger">Delete</button>
      </td>
    </tr>`;
}

// The two pickers open on something sensible rather than on 1970: now,
// and a week from now. datetime-local wants the browser's own clock in
// its own zone with no offset on the end, which is what this builds.
function localInputValue(date) {
  const pad = (n) => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` +
         `T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function prefillTimes() {
  const now = new Date();
  const week = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
  document.getElementById("start_time").value = localInputValue(now);
  document.getElementById("end_time").value = localInputValue(week);
}

// Says what the chosen product costs today, so the deal price is typed
// against a number rather than from memory.
function wirePriceHint(productList) {
  const select = document.getElementById("product_id");
  const hint = document.getElementById("price-hint");

  select.onchange = () => {
    const product = productList.find((p) => String(p.product_id) === select.value);
    hint.textContent = product
      ? `List price is ${money(product.price)}. The deal must be below it.`
      : "Must be below the list price.";
  };
}

async function createDeal(productList) {
  const errorBox = document.getElementById("form-errors");
  const button = document.getElementById("create-button");
  const field = (id) => document.getElementById(id).value.trim();

  const productId = Number(field("product_id"));
  const dealPrice = Number(field("discount_price"));
  const startsAt = field("start_time");
  const endsAt = field("end_time");
  const product = productList.find((p) => p.product_id === productId);

  const errors = [];
  if (!productId || !product) errors.push("Choose a product.");
  if (!(dealPrice > 0)) errors.push("The deal price must be more than zero.");
  else if (product && dealPrice >= num(product.price)) {
    errors.push(`The deal price must be below the list price of ${money(product.price)}.`);
  }
  if (startsAt === "" || endsAt === "") errors.push("Both a start and an end time are needed.");
  else if (new Date(endsAt) <= new Date(startsAt)) {
    errors.push("The deal has to end after it starts.");
  }

  if (errors.length > 0) {
    errorBox.innerHTML = errors.map(e).join("<br />");
    errorBox.style.display = "block";
    return;
  }

  button.disabled = true;
  errorBox.style.display = "none";

  // The pickers give a local wall-clock time with no zone on it. It is
  // converted to a real instant here, so a deal set to end at 23:59 ends
  // at 23:59 where the shop is, not where the reader's browser is.
  // Through the function rather than straight into the table, because
  // creating a deal also messages everyone who was watching the product
  // -- saved it, or came back to it three times. Both happen in one
  // transaction, so a deal never goes live with the news half sent, and
  // the count comes back so staff can see it did something.
  const { data: alerted, error } = await sb.rpc("admin_create_deal", {
    p_product_id: productId,
    p_discount_price: dealPrice,
    p_start_time: new Date(startsAt).toISOString(),
    p_end_time: new Date(endsAt).toISOString(),
  });

  if (error) {
    button.disabled = false;
    errorBox.textContent = "Could not create the deal: " + (error.message || error);
    errorBox.style.display = "block";
    return;
  }

  const told = Number(alerted || 0);
  reloadWith(told === 0
    ? "Deal created. Nobody was watching this product yet."
    : `Deal created. ${told} customer${told === 1 ? "" : "s"} alerted.`);
}

function wireDealActions() {
  document.querySelectorAll("tr[data-id] button[data-act]").forEach((button) => {
    button.onclick = async () => {
      const id = Number(button.closest("tr").dataset.id);
      button.disabled = true;

      try {
        if (button.dataset.act === "toggle") {
          const wasActive = Number(button.dataset.active) === 1;
          await write(sb.from("deals")
            .update({ is_active: wasActive ? 0 : 1 })
            .eq("deal_id", id));
          reloadWith(wasActive ? "Deal switched off." : "Deal switched on.");
        } else {
          if (!confirm("Delete this deal?")) { button.disabled = false; return; }
          await write(sb.from("deals").delete().eq("deal_id", id));
          reloadWith("Deal deleted.");
        }
      } catch (error) {
        button.disabled = false;
        alert("Could not do that: " + (error.message || error));
      }
    };
  });
}
