// ============================================================
// Add a new product, or edit an existing one — including uploading a
// photo, which replaces the drawn illustration on the shop.
//
// The photo itself is uploaded by js/photo.js, which this page shares
// with the prebuilt page -- a rig gets its poster through the same
// resize-and-store path a mouse mat does.
// ============================================================


adminPage("Edit Product", "products", async (content) => {
  const id = Number(params().id || 0);
  const isNew = id === 0;

  const [brands, categories, product, fromParts] = await Promise.all([
    loadBrands(),
    loadCategories(),
    isNew ? null : loadProduct(id),
    isNew ? false : stockIsDerived(id),
  ]);

  if (!isNew && !product) {
    flash("That product no longer exists.");
    window.location.href = "products.html";
    return;
  }

  document.querySelector(".admin-main h1").textContent = isNew ? "Add Product" : "Edit Product";
  document.title = (isNew ? "Add Product" : "Edit Product") + " - eTech Admin";

  const value = (key, fallback = "") =>
    product && product[key] !== null && product[key] !== undefined ? product[key] : fallback;

  const currentPhoto = value("image_path", null);

  content.innerHTML = `
    <div class="error-box" id="form-errors" style="display:none;"></div>

    <form id="product-form">
      <div class="card">
        <h2 style="margin-top:0;">Details</h2>

        <div class="field">
          <label for="name">Product name</label>
          <input type="text" id="name" required value="${e(value("name"))}" />
          <small>Start with the brand, e.g. "Asus ROG Astral RTX 5090 OC White".</small>
        </div>

        <div class="form-row">
          <div class="field">
            <label for="brand_id">Brand</label>
            <select id="brand_id" required>
              ${brandOptions(brands, value("brand_id", 0))}
            </select>
            <div id="new-brand" style="display:none; margin-top:8px;">
              <input type="text" id="brand_name" maxlength="60" placeholder="e.g. Lian Li" disabled />
              <button type="button" class="btn small" id="brand-button" style="margin-top:6px;" disabled>Add brand</button>
              <small>Written as the maker writes it. It appears on product pages and in the brand filter.</small>
            </div>
          </div>
          <div class="field">
            <label for="category_id">Category</label>
            <select id="category_id" required>
              ${categorySelectOptions(categories, value("category_id", 0))}
            </select>
            <div id="new-category" style="display:none; margin-top:8px;">
              <input type="text" id="category_name" maxlength="60" placeholder="e.g. Capture Card" disabled />
              <select id="parent_id" style="margin-top:6px;" disabled>
                <option value="0">On its own (a new top-level category)</option>
                ${categories.filter((c) => !c.parent).map((c) =>
                  `<option value="${c.category_id}">Under ${e(c.name)}</option>`).join("")}
              </select>
              <button type="button" class="btn small" id="category-button" style="margin-top:6px;" disabled>Add category</button>
              <small>Most new kinds of product sit under an existing category, e.g. a capture card under Components.</small>
            </div>
          </div>
        </div>

        <div class="field">
          <label for="description">Description</label>
          <textarea id="description" rows="3">${e(value("description"))}</textarea>
        </div>
      </div>

      <div class="card">
        <h2 style="margin-top:0;">Price and stock</h2>
        ${fromParts ? `
          <p class="hint" style="margin:0 0 14px;">
            This machine's stock is worked out from its parts, so the three
            stock fields below are read-only. Change a component's stock, or
            what this machine is built from, on
            <a href="prebuilts.html" style="color:#d62839;">Prebuilt Parts</a>.
            A quantity typed in here would be overwritten the next time any
            of its parts moved.
          </p>` : ""}
        <div class="form-row">
          <div class="field">
            <label for="price">Selling price (RM)</label>
            <input type="number" id="price" step="0.01" min="0" required
                   value="${num(value("price", 0)).toFixed(2)}" />
          </div>
          <div class="field">
            <label for="cost_price">Cost price (RM)</label>
            <input type="number" id="cost_price" step="0.01" min="0"
                   value="${costValue(value("cost_price", null))}" />
            <small>What you pay the supplier. Used for margin and dead-stock alerts. Leave blank if unknown.</small>
          </div>
        </div>

        <div class="form-row">
          <div class="field">
            <label for="stock_qty">Quantity in stock</label>
            <input type="number" id="stock_qty" min="0"${fromParts ? " disabled" : ""}
                   value="${value("stock_qty", null) === null ? "" : value("stock_qty")}" />
            <small>Leave blank if not counted yet.</small>
          </div>
          <div class="field">
            <label for="reorder_level">Low-stock level</label>
            <input type="number" id="reorder_level" min="0"${fromParts ? " disabled" : ""} value="${value("reorder_level", 5)}" />
            <small>At or below this many, the shop shows "Low Stock".</small>
          </div>
          <div class="field">
            <label for="stock_status">Status shown in the shop</label>
            <select id="stock_status"${fromParts ? " disabled" : ""}>
              <option value="in"  ${value("stock_status") === "in"  ? "selected" : ""}>In Stock</option>
              <option value="low" ${value("stock_status") === "low" ? "selected" : ""}>Low Stock</option>
              <option value="out" ${value("stock_status") === "out" ? "selected" : ""}>Out of Stock</option>
            </select>
            <small>Worked out from the quantity when one is entered.</small>
          </div>
        </div>
      </div>

      <div class="card">
        <h2 style="margin-top:0;">Picture</h2>
        <div style="display:flex; gap:20px; align-items:flex-start; flex-wrap:wrap;">
          <div style="text-align:center;">
            <img id="photo-preview"
                 src="${e(currentPhoto || "../images/" + value("img_slug", "default") + ".svg")}"
                 style="width:140px; height:110px; object-fit:contain; background:#fafbfc; border:1px solid #e3e6ea; border-radius:6px;" />
            <div style="font-size:12px; color:#999; margin-top:5px;" id="photo-caption">
              ${currentPhoto ? "Uploaded photo" : "Drawn illustration"}
            </div>
          </div>
          <div style="flex:1; min-width:240px;">
            <div class="field">
              <label for="photo">Upload a photo</label>
              <input type="file" id="photo" accept="image/jpeg,image/png,image/webp" />
              <small>JPG, PNG or WEBP, under 5MB. Resized to 800px and saved as JPEG.</small>
            </div>
            <div class="field">
              <label for="img_slug">Fallback drawing</label>
              <input type="text" id="img_slug" value="${e(value("img_slug", "default"))}" />
              <small>Used when there's no photo: cpu, gpu, ram, motherboard, psu, case, cooler,
                     ssd, hdd, monitor, laptop, printer, paper, projector, projectorscreen,
                     monitorarm, keyboard, mouse, headset, mousepad, router, wifi, switch, cable, default.</small>
            </div>
          </div>
        </div>
      </div>

      <div class="card">
        <label style="font-weight:normal;">
          <input type="checkbox" id="exclude_from_builder"
                 ${Number(value("exclude_from_builder", 0)) === 1 ? "checked" : ""} />
          Hide from the PC Builder
        </label>
        <small style="display:block; color:#999; margin-top:4px;">
          For things sold in the shop that don't belong in a desktop build —
          laptop memory, surveillance drives, legacy repair boards.
        </small>
      </div>

      <button type="submit" class="btn" id="save-button">${isNew ? "Add product" : "Save changes"}</button>
      <a href="products.html" class="btn grey">Cancel</a>
    </form>`;

  // Show the chosen photo straight away, so it is obvious something has
  // been picked before anything is saved.
  document.getElementById("photo").onchange = (event) => {
    const file = event.target.files[0];
    if (!file) return;
    document.getElementById("photo-preview").src = URL.createObjectURL(file);
    document.getElementById("photo-caption").textContent = "New photo, not saved yet";
  };

  document.getElementById("brand_id").onchange = () => toggleAddNew("brand");
  document.getElementById("category_id").onchange = () => toggleAddNew("category");
  document.getElementById("brand-button").onclick = () => addBrand(brands);
  document.getElementById("category-button").onclick = () => addCategory(categories);
  // Enter in these boxes means "add this", not "save the product".
  [["brand_name", "brand-button"], ["category_name", "category-button"]].forEach(([input, button]) => {
    document.getElementById(input).onkeydown = (event) => {
      if (event.key !== "Enter") return;
      event.preventDefault();
      document.getElementById(button).click();
    };
  });

  document.getElementById("product-form").onsubmit = (event) => {
    event.preventDefault();
    save(id, isNew, brands, categories);
  };
});

// The last option in each dropdown is "+ Add New ...", and choosing it is
// what opens the box for typing one. ADD_NEW is never a real id, so a
// form saved with it still chosen fails validation rather than the insert.
const ADD_NEW = "new";

// A new product starts on an empty "Choose ..." line rather than the first
// brand in the list, so nobody saves an Acer by not looking. Its value is
// "", which the select's required attribute refuses.
function placeholder(label, selectedId) {
  return `<option value="" ${Number(selectedId) ? "" : "selected"}>${label}</option>`;
}

function brandOptions(brands, selectedId) {
  return placeholder("Choose a brand", selectedId) + brands.map((b) => `
    <option value="${b.brand_id}" ${Number(selectedId) === b.brand_id ? "selected" : ""}>
      ${e(b.name)}
    </option>`).join("") +
    `<option value="${ADD_NEW}">+ Add New Brand</option>`;
}

// categoryOptions() lives in admin.js and other pages use it too, so the
// extra option is added here rather than there.
function categorySelectOptions(categories, selectedId) {
  return placeholder("Choose a category", selectedId) +
    categoryOptions(categories, selectedId) +
    `<option value="${ADD_NEW}">+ Add New Category</option>`;
}

// Shows the new-brand (or new-category) box only while "+ Add New" is
// chosen. Leaving it hides the box, empties what was typed and disables
// the controls, so nothing half-typed can be added by accident.
function toggleAddNew(kind) {
  const adding = document.getElementById(kind + "_id").value === ADD_NEW;
  const box = document.getElementById("new-" + kind);
  box.style.display = adding ? "block" : "none";
  box.querySelectorAll("input, select, button").forEach((control) => {
    control.disabled = !adding;
  });
  const input = document.getElementById(kind + "_name");
  if (adding) {
    input.focus();
  } else {
    input.value = "";
    if (kind === "category") document.getElementById("parent_id").value = "0";
  }
}

// A login can end while the form is open -- the token runs out, and if
// the refresh is refused the client quietly drops the session. Every
// request after that goes out signed out, and the database answers
// "permission denied". This catches it first and says what really
// happened. Signing in again in another tab is enough: both tabs share
// the stored session, so nothing typed here is lost.
const SIGNED_OUT_MESSAGE =
  "Your sign-in has expired, so the database refused this. Sign in again " +
  "in a new tab (login.html), come back to this tab and try again. " +
  "Nothing you typed here is lost.";

async function signedIn() {
  const { data } = await sb.auth.getSession();
  return !!data.session;
}

// 42501 is Postgres's "permission denied". A signed-in member of staff
// can still get it from a policy, so it only means "signed out" when the
// session is gone too.
async function explain(error, prefix) {
  if (error && error.code === "42501" && !(await signedIn())) return SIGNED_OUT_MESSAGE;
  return prefix + (error.message || error);
}

// ------------------------------------------------------------
// A new brand or category, added from inside the product form.
//
// This used to be its own Brands & Categories page, which meant leaving a
// half-filled product to go and make the brand first. Now it is added in
// place: the new row is inserted, put into the dropdown and selected, and
// nothing else on the form is touched -- no reload, so nothing typed so
// far is lost.
//
// The "staff manage brands" and "staff manage categories" policies are
// what allow the insert; to a customer the same request is refused by the
// database, not by this page.
// ------------------------------------------------------------

function showErrors(errors) {
  const box = document.getElementById("form-errors");
  box.innerHTML = errors.map(e).join("<br />");
  box.style.display = "block";
  box.scrollIntoView({ behavior: "smooth", block: "center" });
}

function hideErrors() {
  document.getElementById("form-errors").style.display = "none";
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
  if (!(await signedIn())) {
    button.disabled = false;
    return showErrors([SIGNED_OUT_MESSAGE]);
  }
  const { data, error } = await sb.from("brands").insert({ name }).select("brand_id,name").single();
  button.disabled = false;
  if (error) {
    // 23505 is a unique violation: someone else added it a moment ago.
    return showErrors([error.code === "23505"
      ? `${name} is already a brand.`
      : await explain(error, "Could not add the brand: ")]);
  }

  hideErrors();
  brands.push(data);
  brands.sort((a, b) => a.name.localeCompare(b.name));
  document.getElementById("brand_id").innerHTML = brandOptions(brands, data.brand_id);
  toggleAddNew("brand");
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
  if (!(await signedIn())) {
    button.disabled = false;
    return showErrors([SIGNED_OUT_MESSAGE]);
  }
  const { data, error } = await sb.from("categories")
    .insert({ name, parent_id: parent ? parent.category_id : null })
    .select("category_id,name").single();
  button.disabled = false;
  if (error) {
    return showErrors([error.code === "23505"
      ? "That category already exists there."
      : await explain(error, "Could not add the category: ")]);
  }

  hideErrors();
  categories.push({ category_id: data.category_id, name: data.name, parent: parent ? parent.name : null });
  // Same order loadCategories() gives, so the new one lands beside its parent.
  categories.sort((a, b) =>
    (a.parent || a.name).localeCompare(b.parent || b.name) ||
    (a.parent ? 1 : 0) - (b.parent ? 1 : 0) ||
    a.name.localeCompare(b.name));
  document.getElementById("category_id").innerHTML = categorySelectOptions(categories, data.category_id);
  if (!parent) {
    document.getElementById("parent_id").insertAdjacentHTML("beforeend",
      `<option value="${data.category_id}">Under ${e(data.name)}</option>`);
  }
  toggleAddNew("category");
}

function costValue(cost) {
  return cost === null ? "" : num(cost).toFixed(2);
}

async function loadBrands() {
  const { data, error } = await sb.from("brands").select("brand_id,name").order("name");
  if (error) throw error;
  return data;
}

// True when this product is one of the eleven E-Tech machines and every
// one of its slots has been answered -- at which point recompute_prebuilt_stock()
// owns its badge and anything typed here is temporary.
async function stockIsDerived(id) {
  const { data, error } = await sb.from("prebuilt_availability")
    .select("pending,derived_status").eq("prebuilt_id", id).maybeSingle();
  if (error) throw error;

  // derived_status is null when nothing is linked, which is the case
  // recompute_prebuilt_stock() leaves alone -- the same pair the shop
  // and the Products list check.
  return !!data && data.pending === 0 && !!data.derived_status;
}

async function loadProduct(id) {
  const { data, error } = await sb.from("admin_products")
    .select("product_id,name,brand_id,category_id,price,cost_price,stock_qty," +
            "reorder_level,stock_status,description,img_slug,image_path,exclude_from_builder")
    .eq("product_id", id).maybeSingle();
  if (error) throw error;
  return data;
}

// ------------------------------------------------------------
// Saving
// ------------------------------------------------------------
async function save(id, isNew, brands, categories) {
  const button = document.getElementById("save-button");
  const errorBox = document.getElementById("form-errors");
  const field = (name) => document.getElementById(name).value.trim();

  // A second click while the first save is still going would add the
  // product twice.
  if (button.disabled) return;

  const errors = [];
  const name = field("name");
  const brandId = Number(field("brand_id"));
  const categoryId = Number(field("category_id"));
  const price = Number(field("price"));
  const costRaw = field("cost_price");
  const cost = costRaw === "" ? null : Number(costRaw);
  const qtyRaw = field("stock_qty");
  const qty = qtyRaw === "" ? null : Number(qtyRaw);
  const reorderRaw = field("reorder_level");
  const reorder = reorderRaw === "" ? 5 : Number(reorderRaw);
  let status = field("stock_status");
  const isCount = (n) => Number.isInteger(n) && n >= 0;

  if (name === "") errors.push("Name is required.");
  if (!brands.some((b) => b.brand_id === brandId)) {
    errors.push("Choose a brand, or finish adding the new one with Add brand.");
  }
  if (!categories.some((c) => c.category_id === categoryId)) {
    errors.push("Choose a category, or finish adding the new one with Add category.");
  }
  if (!(price > 0)) errors.push("Price must be more than zero.");
  if (cost !== null && !(cost >= 0)) errors.push("Cost must be a number, zero or more.");
  if (!document.getElementById("stock_qty").disabled) {
    if (qty !== null && !isCount(qty)) errors.push("Quantity in stock must be a whole number, zero or more.");
    if (!isCount(reorder)) errors.push("Low-stock level must be a whole number, zero or more.");
  }
  if (!["in", "low", "out"].includes(status)) status = "in";

  // A real count beats the dropdown.
  if (qty !== null) {
    status = qty <= 0 ? "out" : (qty <= reorder ? "low" : "in");
  }

  const photoFile = document.getElementById("photo").files[0] || null;
  const photoProblem = checkPhoto(photoFile);   // photo.js
  if (photoProblem) errors.push(photoProblem);

  if (errors.length > 0) {
    errorBox.innerHTML = errors.map(e).join("<br />");
    errorBox.style.display = "block";
    return;
  }

  const buttonText = button.textContent;
  button.disabled = true;
  button.textContent = "Saving…";
  errorBox.style.display = "none";

  // A derived machine's stock is left out of the write entirely. Note
  // that disabling a field does not empty it -- it still reads back
  // whatever was loaded -- so this is not about avoiding a null. It is
  // that sending those three would write numbers which look like a
  // decision somebody made and are really just what the page happened to
  // be showing, to be overwritten at the next recompute anyway. Leaving
  // them out keeps the write to what the person actually changed.
  const stockFields = document.getElementById("stock_qty").disabled ? {} : {
    stock_qty: qty,
    reorder_level: reorder,
    stock_status: status,
  };

  const record = {
    name,
    brand_id: brandId,
    category_id: categoryId,
    price,
    cost_price: cost,
    ...stockFields,
    description: field("description"),
    img_slug: field("img_slug") || "default",
    exclude_from_builder: document.getElementById("exclude_from_builder").checked ? 1 : 0,
  };

  try {
    let productId = id;

    if (!(await signedIn())) throw { code: "42501", message: SIGNED_OUT_MESSAGE };

    if (isNew) {
      // Product ids are not generated: they match the picture files, so a
      // new product takes the next number above the highest in use.
      // product_edit.php read that with MAX(product_id) + 1, which a
      // browser cannot do. It is a database function now -- but two people
      // saving at once can still both be handed the same number. The
      // primary key refuses the second insert, so that one asks again.
      for (let attempt = 1; ; attempt++) {
        const { data: nextId, error } = await sb.rpc("admin_next_product_id");
        if (error) throw error;
        if (!nextId) throw { code: "42501", message: "This account is not staff." };
        productId = nextId;
        const { error: insertError } =
          await sb.from("products").insert({ product_id: productId, ...record });
        if (!insertError) break;
        if (insertError.code !== "23505" || attempt === 3) throw insertError;
      }
    } else {
      await write(sb.from("products").update(record).eq("product_id", id));
    }

    // The photo goes last, because its name needs the product's id.
    if (photoFile) {
      const url = await uploadPhoto(photoFile, productId);
      await write(sb.from("products").update({ image_path: url }).eq("product_id", productId));
    }

    flash(isNew ? "Product added." : "Product saved.");
    window.location.href = "products.html";
  } catch (error) {
    console.error(error);
    button.disabled = false;
    button.textContent = buttonText;
    errorBox.textContent = await explain(error, "Could not save: ");
    errorBox.style.display = "block";
    errorBox.scrollIntoView({ behavior: "smooth", block: "center" });
  }
}

