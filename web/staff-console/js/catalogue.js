// ============================================================
// Brands & Categories. Adding a new brand, or a new category on its own
// or under an existing one, so a product from a new maker or of a new
// kind can be entered on the product page.
//
// Both tables are written straight from here. The "staff manage brands"
// and "staff manage categories" policies are what allow it; to a customer
// the same insert is refused by the database, not by this page.
//
// Nothing here deletes. Removing a category takes its sub-categories with
// it (ON DELETE CASCADE) and a brand still on a product cannot go at all,
// so that stays a decision made in the database, not one click away.
// ============================================================

adminPage("Brands & Categories", "catalogue", async (content) => {
  const [brands, categories, products] = await Promise.all([
    select(sb.from("brands").select("brand_id,name").order("name")),
    loadCategories(),
    select(sb.from("admin_products").select("brand_id,category_id")),
  ]);

  const perBrand = tally(products, "brand_id");
  const perCategory = tally(products, "category_id");
  const topLevel = categories.filter((c) => !c.parent);

  content.innerHTML = `
    <div class="error-box" id="form-errors" style="display:none;"></div>

    <div class="form-row">
      <div class="card field">
        <h2 style="margin-top:0;">New brand</h2>
        <form id="new-brand">
          <div class="field">
            <label for="brand_name">Brand name</label>
            <input type="text" id="brand_name" maxlength="60" placeholder="e.g. Lian Li" required />
            <small>Written as the maker writes it. It appears on product pages and in the brand filter.</small>
          </div>
          <button type="submit" class="btn" id="brand-button">Add brand</button>
        </form>
      </div>

      <div class="card field">
        <h2 style="margin-top:0;">New category</h2>
        <form id="new-category">
          <div class="field">
            <label for="category_name">Category name</label>
            <input type="text" id="category_name" maxlength="60" placeholder="e.g. Capture Card" required />
          </div>
          <div class="field">
            <label for="parent_id">Sits under</label>
            <select id="parent_id">
              <option value="0">Nothing (a new top-level category)</option>
              ${topLevel.map((c) => `<option value="${c.category_id}">${e(c.name)}</option>`).join("")}
            </select>
            <small>Most new kinds of product belong under an existing category, e.g. a capture card under Components.</small>
          </div>
          <button type="submit" class="btn" id="category-button">Add category</button>
        </form>
      </div>
    </div>

    <div class="form-row">
      <div class="field">
        <h2>Brands (${count(brands.length)})</h2>
        <div class="table-wrap">
          <table class="data">
            <thead><tr><th>Brand</th><th class="num">Products</th></tr></thead>
            <tbody>
              ${brands.map((b) => `
                <tr><td>${e(b.name)}</td><td class="num">${count(perBrand[b.brand_id] || 0)}</td></tr>`).join("")}
            </tbody>
          </table>
        </div>
      </div>

      <div class="field">
        <h2>Categories (${count(categories.length)})</h2>
        <div class="table-wrap">
          <table class="data">
            <thead><tr><th>Category</th><th class="num">Products</th></tr></thead>
            <tbody>
              ${categories.map((c) => `
                <tr><td>${c.parent ? "&nbsp;&nbsp;&nbsp;&nbsp;" + e(c.name) : `<strong>${e(c.name)}</strong>`}</td>
                    <td class="num">${count(perCategory[c.category_id] || 0)}</td></tr>`).join("")}
            </tbody>
          </table>
        </div>
      </div>
    </div>`;

  document.getElementById("new-brand").onsubmit = (event) => {
    event.preventDefault();
    addBrand(brands);
  };
  document.getElementById("new-category").onsubmit = (event) => {
    event.preventDefault();
    addCategory(categories);
  };
});

function tally(rows, key) {
  const counts = {};
  rows.forEach((r) => { counts[r[key]] = (counts[r[key]] || 0) + 1; });
  return counts;
}

function showErrors(errors) {
  const box = document.getElementById("form-errors");
  box.innerHTML = errors.map(e).join("<br />");
  box.style.display = "block";
}

// Spaces tidied, so "Lian  Li " and "Lian Li" are not two brands.
function cleanName(id) {
  return document.getElementById(id).value.trim().replace(/\s+/g, " ");
}

async function addBrand(brands) {
  const name = cleanName("brand_name");
  const button = document.getElementById("brand-button");

  if (name === "") return showErrors(["A brand name is required."]);
  // The column is unique, but it compares exactly. "asus" next to "ASUS"
  // would pass the database and give the brand filter two boxes.
  const same = brands.find((b) => b.name.toLowerCase() === name.toLowerCase());
  if (same) return showErrors([`${same.name} is already a brand.`]);

  button.disabled = true;
  const { error } = await sb.from("brands").insert({ name });
  if (error) {
    button.disabled = false;
    // 23505 is a unique violation: someone else added it a moment ago.
    return showErrors([error.code === "23505"
      ? `${name} is already a brand.`
      : "Could not add the brand: " + error.message]);
  }
  reloadWith(`Brand "${name}" added. It can now be chosen on the product page.`);
}

async function addCategory(categories) {
  const name = cleanName("category_name");
  const parentId = Number(document.getElementById("parent_id").value);
  const parent = categories.find((c) => c.category_id === parentId);
  const button = document.getElementById("category-button");

  if (name === "") return showErrors(["A category name is required."]);
  const same = categories.find((c) =>
    c.name.toLowerCase() === name.toLowerCase() &&
    (c.parent || null) === (parent ? parent.name : null));
  if (same) {
    return showErrors([parent
      ? `${parent.name} already has a category called ${same.name}.`
      : `${same.name} is already a top-level category.`]);
  }

  button.disabled = true;
  const { error } = await sb.from("categories").insert({
    name,
    parent_id: parent ? parent.category_id : null,
  });
  if (error) {
    button.disabled = false;
    return showErrors([error.code === "23505"
      ? "That category already exists there."
      : "Could not add the category: " + error.message]);
  }
  reloadWith(`Category "${parent ? parent.name + " > " : ""}${name}" added. It can now be chosen on the product page.`);
}
