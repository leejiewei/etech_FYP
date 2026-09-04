// ============================================================
// Product list: search, filter, and quick edits to price and stock.
// Adding and full editing happen on product_edit.html.
//
// The reads come from admin_products, a view that joins the brand and
// category names on and — unlike anything the shop front can query —
// includes cost_price, stock_qty and reorder_level. Those three columns
// are revoked from every client role, which is how the old etech_client
// MySQL login's restriction survived the move; the view is allowed to
// show them and checks is_admin() before it shows anybody anything.
//
// The writes go to the products table itself. There is no check here
// that the person doing it is staff, because there is no point in one:
// the policy on that table refuses the statement outright if they are
// not, and a check in this file could be skipped by not using this file.
// ============================================================

const PER_PAGE = 25;

adminPage("Products", "products", async (content) => {
  const q = params();
  const search = (q.q || "").trim();
  const categoryId = Number(q.cat || 0);
  const stock = ["in", "low", "out"].includes(q.stock) ? q.stock : "";
  const showGone = q.inactive === "1";
  let page = Math.max(1, Number(q.page || 1));

  const categories = await loadCategories();

  // Build the query once for counting and again for the page of rows,
  // because the filters have to be identical for the pager to be right.
  const filtered = () => {
    let query = sb.from("admin_products")
      .select("product_id,name,price,cost_price,stock_qty,reorder_level," +
              "stock_status,img_slug,image_path,is_active,brand,category," +
              "parent_category,category_id,parent_category_id",
              { count: "exact" })
      .eq("is_active", showGone ? 0 : 1);

    if (search !== "") {
      // ILIKE is LIKE that ignores case, so searching "asus" finds
      // "ASUS". The term is stripped of the punctuation PostgREST uses
      // to separate the parts of a filter, or a comma in the search box
      // would be read as "and now here is another condition".
      const term = search.replace(/[,()"\\]/g, " ");
      query = query.or(`name.ilike.%${term}%,brand.ilike.%${term}%`);
    }
    if (categoryId > 0) {
      // Matches the category itself or anything under it.
      query = query.or(`category_id.eq.${categoryId},parent_category_id.eq.${categoryId}`);
    }
    if (stock !== "") query = query.eq("stock_status", stock);

    return query;
  };

  // Ask for the first page, find out how many there are, and only ask
  // again if the page number in the URL turned out to be past the end.
  let { data: rows, count: total, error } = await filtered()
    .order("product_id").range((page - 1) * PER_PAGE, page * PER_PAGE - 1);
  if (error) throw error;

  const pages = Math.max(1, Math.ceil(total / PER_PAGE));
  if (page > pages) {
    page = pages;
    ({ data: rows, error } = await filtered()
      .order("product_id").range((page - 1) * PER_PAGE, page * PER_PAGE - 1));
    if (error) throw error;
  }

  content.innerHTML = `
    <p class="hint">
      ${count(total)} product${total === 1 ? "" : "s"}${showGone ? " removed from the shop" : " in the shop"}.
      Price and stock can be changed here; use Edit for everything else.
    </p>

    <form class="filters" id="filters">
      <div class="field">
        <label>Search</label>
        <input type="text" name="q" value="${e(search)}" placeholder="Name or brand" />
      </div>
      <div class="field">
        <label>Category</label>
        <select name="cat">
          <option value="0">All categories</option>
          ${categoryOptions(categories, categoryId)}
        </select>
      </div>
      <div class="field">
        <label>Stock</label>
        <select name="stock">
          <option value="">Any</option>
          <option value="in"  ${stock === "in"  ? "selected" : ""}>In stock</option>
          <option value="low" ${stock === "low" ? "selected" : ""}>Low stock</option>
          <option value="out" ${stock === "out" ? "selected" : ""}>Out of stock</option>
        </select>
      </div>
      <button type="submit" class="btn">Filter</button>
      <a href="products.html" class="btn grey">Clear</a>
      <a href="product_edit.html" class="btn">+ Add product</a>
      <a href="${showGone ? "products.html" : "products.html?inactive=1"}" class="btn grey">
        ${showGone ? "Back to live products" : "View removed"}
      </a>
    </form>

    <div class="table-wrap">
    <table class="data">
      <thead>
        <tr>
          <th>ID</th><th></th><th>Product</th><th>Category</th>
          <th class="num">Price (RM)</th><th class="num">Cost</th>
          <th class="num">Qty</th><th>Status</th><th></th>
        </tr>
      </thead>
      <tbody>
      ${rows.length === 0
        ? `<tr><td colspan="9" style="text-align:center; color:#888; padding:26px;">Nothing matches those filters.</td></tr>`
        : rows.map(productRow).join("")}
      </tbody>
    </table>
    </div>

    ${pager(page, pages)}`;

  // The filter form is a plain GET, the same as it always was — the URL
  // stays shareable and the back button still works.
  document.getElementById("filters").onsubmit = (event) => {
    event.preventDefault();
    const form = new FormData(event.target);
    window.location.search = new URLSearchParams({
      ...(showGone ? { inactive: "1" } : {}),
      ...Object.fromEntries([...form].filter(([, v]) => v !== "" && v !== "0")),
    }).toString();
  };

  wireRowActions(rows);
});

function productRow(r) {
  const img = r.image_path ? r.image_path : "../images/" + (r.img_slug || "default") + ".svg";
  const categoryPath = r.parent_category ? r.parent_category + " > " + r.category : r.category;

  return `
    <tr data-id="${r.product_id}">
      <td>${r.product_id}</td>
      <td><img class="thumb" src="${e(img)}" alt="" /></td>
      <td>
        <strong>${e(r.name)}</strong><br />
        <small style="color:#999;">${e(r.brand)}</small>
      </td>
      <td><small>${e(categoryPath)}</small></td>
      <td class="num">
        <input type="number" step="0.01" min="0" data-field="price"
               style="width:100px; text-align:right;" value="${num(r.price).toFixed(2)}" />
      </td>
      <td class="num">
        ${r.cost_price === null
          ? '<small style="color:#bbb;">not set</small>'
          : e(money(r.cost_price))}
      </td>
      <td class="num">
        <input type="number" min="0" data-field="stock_qty"
               style="width:70px; text-align:right;" placeholder="&mdash;"
               value="${r.stock_qty === null ? "" : r.stock_qty}" />
      </td>
      <td>
        <select data-field="stock_status" style="width:105px;">
          <option value="in"  ${r.stock_status === "in"  ? "selected" : ""}>In stock</option>
          <option value="low" ${r.stock_status === "low" ? "selected" : ""}>Low</option>
          <option value="out" ${r.stock_status === "out" ? "selected" : ""}>Out</option>
        </select>
      </td>
      <td style="white-space:nowrap;">
        <button type="button" data-act="save" class="btn small">Save</button>
        <a href="product_edit.html?id=${r.product_id}" class="btn small grey">Edit</a>
        ${r.is_active
          ? `<button type="button" data-act="remove" class="btn small danger">Remove</button>`
          : `<button type="button" data-act="restore" class="btn small">Restore</button>`}
      </td>
    </tr>`;
}

function wireRowActions(rows) {
  const byId = new Map(rows.map((r) => [r.product_id, r]));

  document.querySelectorAll("tr[data-id] button[data-act]").forEach((button) => {
    button.onclick = async () => {
      const row = button.closest("tr");
      const id = Number(row.dataset.id);
      const act = button.dataset.act;
      button.disabled = true;

      try {
        if (act === "save") {
          const value = (field) => row.querySelector(`[data-field="${field}"]`).value.trim();
          const qty = value("stock_qty") === "" ? null : Number(value("stock_qty"));
          let status = value("stock_status");

          // If a real count is given, work the badge out from it rather
          // than trusting the dropdown — the number is the better source.
          if (qty !== null) {
            const reorder = byId.get(id).reorder_level ?? 5;
            status = qty <= 0 ? "out" : (qty <= reorder ? "low" : "in");
          }

          await write(sb.from("products").update({
            price: Number(value("price")),
            stock_qty: qty,
            stock_status: status,
          }).eq("product_id", id));

          reloadWith("Saved.");

        } else if (act === "remove") {
          // A soft delete: the row stays, so old orders still point at a
          // real product, it just stops being listed in the shop.
          if (!confirm("Remove this product from the shop? Past orders keep it.")) {
            button.disabled = false;
            return;
          }
          await write(sb.from("products").update({ is_active: 0 }).eq("product_id", id));
          reloadWith("Product removed from the shop. Past orders are unaffected.");

        } else if (act === "restore") {
          await write(sb.from("products").update({ is_active: 1 }).eq("product_id", id));
          reloadWith("Product put back in the shop.");
        }
      } catch (error) {
        button.disabled = false;
        alert("Could not save: " + (error.message || error));
      }
    };
  });
}

