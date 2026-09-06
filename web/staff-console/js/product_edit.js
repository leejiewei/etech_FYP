// ============================================================
// Add a new product, or edit an existing one — including uploading a
// photo, which replaces the drawn illustration on the shop.
//
// The photo is the part that changed most. product_edit.php took the
// upload, checked it was really an image, resized it with GD and wrote a
// JPEG into web/uploads/. That only worked because there was a PHP
// process with a filesystem behind it, and there isn't one now.
//
// So the same three steps happen in the browser instead — check, resize,
// convert to JPEG — using a canvas, and the result is uploaded to
// Supabase Storage. Doing the resize here is not only a substitute: it
// means a 4MB phone photo becomes an 80KB JPEG before it is sent, rather
// than after.
//
// The checks being in the browser does raise the obvious question, and
// the answer is that they are not the security boundary. The bucket
// itself refuses anything over 5MB or of the wrong type, and refuses
// uploads from anyone who is not staff. What happens here is for the
// person using the page; what happens in the bucket is the rule.
// ============================================================

const MAX_PHOTO_BYTES = 5 * 1024 * 1024;
const MAX_PHOTO_SIDE = 800;
const PHOTO_QUALITY = 0.85;
const PHOTO_BUCKET = "product-images";

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
              ${brands.map((b) => `
                <option value="${b.brand_id}" ${Number(value("brand_id", 0)) === b.brand_id ? "selected" : ""}>
                  ${e(b.name)}
                </option>`).join("")}
            </select>
          </div>
          <div class="field">
            <label for="category_id">Category</label>
            <select id="category_id" required>
              ${categoryOptions(categories, value("category_id", 0))}
            </select>
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

  document.getElementById("product-form").onsubmit = (event) => {
    event.preventDefault();
    save(id, isNew);
  };
});

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
async function save(id, isNew) {
  const button = document.getElementById("save-button");
  const errorBox = document.getElementById("form-errors");
  const field = (name) => document.getElementById(name).value.trim();

  const errors = [];
  const name = field("name");
  const price = Number(field("price"));
  const costRaw = field("cost_price");
  const cost = costRaw === "" ? null : Number(costRaw);
  const qtyRaw = field("stock_qty");
  const qty = qtyRaw === "" ? null : Number(qtyRaw);
  const reorder = Number(field("reorder_level") || 5);
  let status = field("stock_status");

  if (name === "") errors.push("Name is required.");
  if (!(price > 0)) errors.push("Price must be more than zero.");
  if (cost !== null && cost < 0) errors.push("Cost cannot be negative.");
  if (!["in", "low", "out"].includes(status)) status = "in";

  // A real count beats the dropdown.
  if (qty !== null) {
    status = qty <= 0 ? "out" : (qty <= reorder ? "low" : "in");
  }

  const photoFile = document.getElementById("photo").files[0] || null;
  if (photoFile) {
    if (photoFile.size > MAX_PHOTO_BYTES) errors.push("Photo must be under 5MB.");
    if (!["image/jpeg", "image/png", "image/webp"].includes(photoFile.type)) {
      errors.push("Photo must be a JPG, PNG or WEBP.");
    }
  }

  if (errors.length > 0) {
    errorBox.innerHTML = errors.map(e).join("<br />");
    errorBox.style.display = "block";
    return;
  }

  button.disabled = true;
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
    brand_id: Number(field("brand_id")),
    category_id: Number(field("category_id")),
    price,
    cost_price: cost,
    ...stockFields,
    description: field("description"),
    img_slug: field("img_slug") || "default",
    exclude_from_builder: document.getElementById("exclude_from_builder").checked ? 1 : 0,
  };

  try {
    let productId = id;

    if (isNew) {
      // Product ids are not generated: they match the picture files, so a
      // new product takes the next number above the highest in use.
      // product_edit.php read that with MAX(product_id) + 1, which a
      // browser cannot do — and which two people saving at once could
      // get wrong anyway. It is a database function now.
      const { data: nextId, error } = await sb.rpc("admin_next_product_id");
      if (error) throw error;
      productId = nextId;
      await write(sb.from("products").insert({ product_id: productId, ...record }));
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
    errorBox.textContent = "Could not save: " + (error.message || error);
    errorBox.style.display = "block";
  }
}

// ------------------------------------------------------------
// The photo: check it, shrink it, flatten it, send it.
//
// Reading the file into an <img> is also the check that it really is an
// image, in the same way getimagesize() was: a renamed .exe will not
// decode and the promise rejects. Drawing it onto a canvas and reading
// it back as JPEG is what strips anything hidden in the original file,
// which is why the PHP redrew rather than simply moving the upload.
// ------------------------------------------------------------
async function uploadPhoto(file, productId) {
  const image = await readImage(file);

  // Scale down so the shop stays quick to load. Never scales up.
  const scale = Math.min(MAX_PHOTO_SIDE / image.width, MAX_PHOTO_SIDE / image.height, 1);
  const canvas = document.createElement("canvas");
  canvas.width = Math.round(image.width * scale);
  canvas.height = Math.round(image.height * scale);

  const context = canvas.getContext("2d");
  context.fillStyle = "#ffffff";                 // flatten transparency
  context.fillRect(0, 0, canvas.width, canvas.height);
  context.drawImage(image, 0, 0, canvas.width, canvas.height);

  const blob = await new Promise((resolve, reject) =>
    canvas.toBlob((b) => (b ? resolve(b) : reject(new Error("Could not convert that image."))),
                  "image/jpeg", PHOTO_QUALITY));

  // The timestamp is what the PHP used too: a new name every time, so a
  // replaced photo is never served from a stale cache.
  const path = `p${productId}_${Date.now()}.jpg`;

  const { error } = await sb.storage.from(PHOTO_BUCKET)
    .upload(path, blob, { contentType: "image/jpeg", upsert: false });
  if (error) throw error;

  return sb.storage.from(PHOTO_BUCKET).getPublicUrl(path).data.publicUrl;
}

function readImage(file) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const image = new Image();
    image.onload = () => { URL.revokeObjectURL(url); resolve(image); };
    image.onerror = () => { URL.revokeObjectURL(url); reject(new Error("That file is not an image.")); };
    image.src = url;
  });
}
