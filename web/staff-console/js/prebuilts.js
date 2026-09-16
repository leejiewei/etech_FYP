// ============================================================
// Prebuilt Parts — telling the shop what its own machines are made of.
//
// The Gaming and Office ranges are assembled here, so a machine can only
// be sold when every part of it can be. The database already works that
// out (prebuilt_availability) and the shop and app already show it. What
// it cannot do is guess which catalogue row a spec line refers to.
//
// That is what this page is for. Each machine lists its slots; each slot
// is one of three things:
//
//   Linked        this spec is that product, and its stock counts.
//   Not stocked   there is no product — a processor's box cooler, a PSU
//                 that arrives inside the chassis. Counted as answered.
//   Pending       nobody has said yet.
//
// A machine with any pending slot is not used for its stock badge at
// all; the shop falls back to the machine's own stock_status, exactly as
// it did before this existed. So a half-finished list is safe — it is
// only ever incomplete, never wrong. The badge switches over the moment
// the last slot on a machine is answered.
//
// There are 79 slots across the eleven machines. The seed migration
// answered 22 of them: 15 linked, from the 11 distinct specs whose
// catalogue name matched exactly or with a brand in front of it, and 7
// marked not-stocked. Anything looser was left for a person, because
// "8GB DDR4" matches four different modules and "Stock" matches a
// product called "Intel stock cooler" that means the opposite.
// ============================================================

const SLOT_LABELS = {
  cpu: "Processor", gpu: "Graphics", motherboard: "Motherboard",
  ram: "Memory", ssd: "SSD", psu: "Power Supply",
  cooler: "Cooler", chassis: "Chassis", extras: "Extras",
};

// Which catalogue categories are worth offering for a given slot. Only a
// convenience — the dropdown can still be widened to everything — but it
// turns a 389-item list into a short one for the common case.
// These are the shop's real sub-category names under Components, as they
// stand in the categories table; a name that matches nothing is ignored
// and the full list is shown instead, so a rename here is a slower
// dropdown rather than a broken one.
const SLOT_CATEGORIES = {
  cpu: ["CPU"],
  gpu: ["GPU"],
  motherboard: ["Motherboard"],
  ram: ["RAM", "Laptop Memory"],
  ssd: ["Storage"],
  psu: ["PSU"],
  cooler: ["Cooler"],
  chassis: ["Case"],
  extras: ["Case Fans", "ARGB Lighting"],
};

adminPage("Prebuilt Parts", "prebuilts", async (content) => {
  const [machines, slots, availability, catalogue] = await Promise.all([
    loadMachines(),
    loadSlots(),
    loadAvailability(),
    loadCatalogue(),
  ]);

  const byMachine = {};
  slots.forEach((s) => (byMachine[s.prebuilt_id] ||= []).push(s));

  const productName = {};
  catalogue.forEach((p) => (productName[p.product_id] = p));

  const totalPending = slots.filter((s) => !s.component_id && !s.not_stocked).length;
  const done = machines.filter((m) => (availability[m.product_id]?.pending ?? 1) === 0);

  content.innerHTML = `
    <p class="hint">
      A machine's stock badge is only worked out from its parts once every slot below is
      answered. Until then the shop shows the machine's own stock status and nothing changes.
      <strong>${done.length} of ${machines.length}</strong> machines are complete;
      <strong>${totalPending}</strong> slots still need an answer.
    </p>

    ${machines.map((m) => machineCard(m, byMachine[m.product_id] || [],
                                     availability[m.product_id], productName)).join("")}`;

  wireSlotControls(catalogue);
  wirePosterControls();
  wirePriceControls();
});

// ------------------------------------------------------------
// Reading
// ------------------------------------------------------------
async function loadMachines() {
  // admin_products carries the category names already joined on, which
  // is what decides whether a desktop is one of the shop's own builds.
  const { data, error } = await sb.from("admin_products")
    .select("product_id,name,price,stock_status,category,img_slug,image_path")
    .in("category", ["Prebuilt Gaming PCs", "Office PC Series", "Custom Office CO1"])
    .order("product_id");
  if (error) throw error;
  return data;
}

async function loadSlots() {
  const { data, error } = await sb.from("prebuilt_components")
    .select("prebuilt_id,slot,spec_text,component_id,qty,not_stocked,note")
    .order("prebuilt_id");
  if (error) throw error;
  return data;
}

async function loadAvailability() {
  const { data, error } = await sb.from("prebuilt_availability")
    .select("prebuilt_id,linked,pending,not_stocked,derived_status,blocking_parts");
  if (error) throw error;

  const byId = {};
  data.forEach((row) => (byId[row.prebuilt_id] = row));
  return byId;
}

async function loadCatalogue() {
  // Everything a slot could point at: active products that are not
  // themselves complete machines. Fetched once and reused by every
  // dropdown on the page rather than per slot.
  const { data, error } = await sb.from("admin_products")
    .select("product_id,name,stock_status,category,parent_category")
    .eq("is_active", 1)
    .order("name");
  if (error) throw error;
  return data.filter((p) => (p.parent_category || p.category) !== "Desktops");
}

// ------------------------------------------------------------
// Drawing
// ------------------------------------------------------------
function machineCard(machine, slots, availability, productName) {
  const pending = availability?.pending ?? slots.length;
  const complete = pending === 0;
  const derived = availability?.derived_status;

  const badge = !complete
    ? `<span class="badge low">${pending} slot${pending === 1 ? "" : "s"} to answer</span>`
    : derived === "out"
      ? `<span class="badge out">Out of stock</span>`
      : derived === "low"
        ? `<span class="badge low">Low stock</span>`
        : `<span class="badge in">In stock</span>`;

  const blocking = complete && derived === "out" && availability.blocking_parts
    ? `<p class="hint" style="margin:6px 0 0;">Held back by: <strong>${e(availability.blocking_parts)}</strong></p>`
    : "";

  return `
    <div class="card" style="margin-bottom:22px;">
      <div style="display:flex; gap:16px; align-items:flex-start; flex-wrap:wrap;">
        ${poster(machine)}
        <div style="flex:1; min-width:260px;">
          <div style="display:flex; align-items:baseline; gap:12px; flex-wrap:wrap;">
            <h2 style="margin:0; font-size:17px;">${e(machine.name)}</h2>
            ${badge}
            <small style="color:#999;">${e(machine.category)}</small>
          </div>
          ${priceControl(machine)}
          ${complete
            ? blocking
            : `<p class="hint" style="margin:6px 0 0;">
                 Showing this machine's own status (<strong>${e(machine.stock_status)}</strong>)
                 until every slot is answered.</p>`}
        </div>
      </div>

      <div class="table-wrap" style="margin-top:12px;">
      <table class="data">
        <thead><tr><th style="width:110px;">Slot</th><th style="width:230px;">Written as</th>
                   <th>Which product</th><th style="width:150px;">Stock</th></tr></thead>
        <tbody>
          ${slots.map((s) => slotRow(machine, s, productName)).join("")}
        </tbody>
      </table>
      </div>
    </div>`;
}

function slotRow(machine, slot, productName) {
  const linked = slot.component_id ? productName[slot.component_id] : null;
  const key = `${slot.prebuilt_id}:${slot.slot}`;

  const state = slot.not_stocked
    ? `<span class="badge">Not a stocked part</span>
       ${slot.note ? `<br /><small style="color:#999;">${e(slot.note)}</small>` : ""}`
    : linked
      ? `<span class="badge ${e(linked.stock_status)}">${
           linked.stock_status === "out" ? "Out of stock"
             : linked.stock_status === "low" ? "Low" : "In stock"}</span>`
      : `<span class="badge low">Pending</span>`;

  return `
    <tr>
      <td><strong>${e(SLOT_LABELS[slot.slot] || slot.slot)}</strong></td>
      <td><small>${e(slot.spec_text)}</small></td>
      <td>
        <select data-slot="${e(key)}"
                data-current="${slot.component_id ? slot.component_id : ""}"
                class="slot-pick" style="max-width:100%;">
          <option value="">— pending —</option>
          <option value="none"${slot.not_stocked ? " selected" : ""}>Not a stocked part</option>
        </select>
        ${slot.not_stocked || linked ? "" : `
          <br /><small style="color:#999;">
            Nothing was matched automatically — pick the part this machine actually uses.
          </small>`}
      </td>
      <td>${state}</td>
    </tr>`;
}

// ------------------------------------------------------------
// The poster
//
// Every one of the eleven machines ships with a drawn SVG and no
// photograph — img_slug "prebuilt" for all of them, so the Ember Core
// and the Titan Aegis are the same picture. That is fine for a mouse mat
// and useless for a rig, which is the one thing in the shop somebody
// buys partly on how it looks.
//
// The upload is the product photo uploader, unchanged: js/photo.js
// resizes to 800px, flattens to JPEG and puts it in the product-images
// bucket, and the URL goes into products.image_path — the same column
// and the same bucket the Products page writes. There is no separate
// "poster" field, and deliberately so: a second column would be a
// schema change, and the shop already draws image_path wherever it
// draws a product.
//
// It sits here rather than only on Products > Edit because this is the
// page where somebody thinks about a machine. Making them find the
// product row for "E-Tech Inferno Apex" on another page to give it a
// picture is how the eleven ended up with no pictures.
// ------------------------------------------------------------
function poster(machine) {
  const src = machine.image_path
    ? machine.image_path
    : `../images/${machine.img_slug || "prebuilt"}.svg`;

  return `
    <div style="width:150px; flex-shrink:0;">
      <img src="${e(src)}" alt=""
           style="width:100%; height:110px; object-fit:contain; background:#fafbfc;
                  border:1px solid #e8eaed; border-radius:6px;" />
      <small style="display:block; color:#999; margin:4px 0 6px;">
        ${machine.image_path ? "Photo" : "Drawn illustration"}
      </small>
      <input type="file" class="poster-file" data-machine="${machine.product_id}"
             accept="image/jpeg,image/png,image/webp"
             style="width:100%; font-size:11px;" />
      <button class="btn small poster-save" data-machine="${machine.product_id}"
              style="width:100%; margin-top:6px;" disabled>Upload poster</button>
      ${machine.image_path
        ? `<button class="btn small grey poster-clear" data-machine="${machine.product_id}"
                   style="width:100%; margin-top:4px;">Back to drawing</button>`
        : ""}
    </div>`;
}

function wirePosterControls() {
  // The button stays disabled until a file is chosen, so it never asks
  // the bucket for nothing.
  document.querySelectorAll("input.poster-file").forEach((input) => {
    const id = input.dataset.machine;
    const button = document.querySelector(`button.poster-save[data-machine="${id}"]`);
    input.onchange = () => { button.disabled = !input.files[0]; };
  });

  document.querySelectorAll("button.poster-save").forEach((button) => {
    button.onclick = async () => {
      const id = Number(button.dataset.machine);
      const input = document.querySelector(`input.poster-file[data-machine="${id}"]`);
      const file = input.files[0];
      if (!file) return;

      // Same two questions the Products page asks, asked by photo.js so
      // there is only one answer to keep up to date.
      const problem = checkPhoto(file);
      if (problem) { alert(problem); return; }

      button.disabled = true;
      button.textContent = "Uploading...";
      try {
        const url = await uploadPhoto(file, id);
        await write(sb.from("products").update({ image_path: url }).eq("product_id", id));
        reloadWith("Poster uploaded.");
      } catch (error) {
        button.disabled = false;
        button.textContent = "Upload poster";
        alert("Could not upload that: " + (error.message || error));
      }
    };
  });

  // Clearing the column, not the bucket. The old file stays where it is
  // -- it is a few tens of kilobytes, deleting it is a second thing that
  // can fail, and an order placed while the photo was up should still be
  // able to show what was on the page at the time.
  document.querySelectorAll("button.poster-clear").forEach((button) => {
    button.onclick = async () => {
      if (!confirm("Go back to the drawn illustration for this machine?")) return;
      const id = Number(button.dataset.machine);
      button.disabled = true;
      try {
        await write(sb.from("products").update({ image_path: null }).eq("product_id", id));
        reloadWith("Poster removed.");
      } catch (error) {
        button.disabled = false;
        alert("Could not remove that: " + (error.message || error));
      }
    };
  });
}

// ------------------------------------------------------------
// What the machine sells for.
//
// A prebuilt's price is a plain column on its product row and is not
// worked out from the parts underneath it. That is deliberate and is
// written down in the bill-of-materials migration: a machine is priced as
// a machine, and the itemised parts are what it is made of rather than
// what it costs. So this edits products.price directly, the same column
// and the same way Products > Edit does.
//
// Stock is the opposite and must not be touched here. Once every slot on
// a machine is answered its stock comes from the parts, and typing a
// stock figure onto a prebuilt would be overwritten by the next
// recalculation. Only the price is editable on this page.
//
// It sits here for the reason the poster uploader does: this is the page
// where somebody is thinking about a machine. Sending them to find the
// product row for "E-Tech Inferno Apex" on another page to change its
// price is how prices go stale.
// ------------------------------------------------------------
function priceControl(machine) {
  return `
    <div style="display:flex; align-items:center; gap:8px; flex-wrap:wrap; margin-top:8px;">
      <label style="font-size:13px; color:#555;" for="price-${machine.product_id}">
        Selling price
      </label>
      <span style="font-size:13px; color:#888;">RM</span>
      <input type="number" id="price-${machine.product_id}" class="machine-price"
             data-machine="${machine.product_id}"
             data-was="${num(machine.price).toFixed(2)}"
             value="${num(machine.price).toFixed(2)}"
             step="0.01" min="0"
             style="width:120px; padding:6px 8px; border:1px solid #ccd1d7; border-radius:6px;" />
      <button class="btn small machine-price-save" data-machine="${machine.product_id}" disabled>
        Save price
      </button>
      <span class="hint machine-price-note" data-machine="${machine.product_id}"
            style="margin:0;"></span>
    </div>`;
}

function wirePriceControls() {
  document.querySelectorAll("input.machine-price").forEach((input) => {
    const id = input.dataset.machine;
    const button = document.querySelector(`button.machine-price-save[data-machine="${id}"]`);
    const note = document.querySelector(`span.machine-price-note[data-machine="${id}"]`);
    const was = Number(input.dataset.was);

    // The button is dead until the number in the box is both different
    // and usable, so it never sends the price it already holds and never
    // sends a zero.
    const refresh = () => {
      const now = Number(input.value);
      const changed = input.value.trim() !== "" && now.toFixed(2) !== was.toFixed(2);
      const usable = Number.isFinite(now) && now > 0;

      button.disabled = !(changed && usable);
      note.textContent = !changed ? ""
        : !usable ? "A price has to be more than zero."
          : `was ${money(was)}`;
      note.style.color = changed && !usable ? "#c0392b" : "#999";
    };

    input.oninput = refresh;
    refresh();

    button.onclick = async () => {
      // Rounded here rather than left to the column. numeric(10,2) would
      // round 5499.005 on its way in and the box would then disagree with
      // the row until the next reload.
      const price = Number(Number(input.value).toFixed(2));
      if (!(price > 0)) return;

      // A slipped decimal point is the realistic mistake here -- 5499
      // typed as 549 is a machine sold at a tenth of its price, and
      // nothing downstream would question it. Anything inside half to
      // double saves silently; a jump bigger than that is worth one
      // sentence, and the sentence names both numbers rather than asking
      // "are you sure".
      if (was > 0 && (price < was / 2 || price > was * 2)) {
        const ok = confirm(
          `Change this machine from ${money(was)} to ${money(price)}?\n\n` +
          `That is a big jump, so it is worth a second look at the ` +
          `decimal point.`);
        if (!ok) return;
      }

      button.disabled = true;
      button.textContent = "Saving...";
      try {
        await write(sb.from("products").update({ price }).eq("product_id", Number(id)));
        reloadWith(`Price updated to ${money(price)}.`);
      } catch (error) {
        button.disabled = false;
        button.textContent = "Save price";
        alert("Could not save that price: " + (error.message || error));
      }
    };
  });
}


// ------------------------------------------------------------
// Writing
//
// The options are filled in from JavaScript rather than rendered into
// the HTML above, because every dropdown holds the whole catalogue and
// building 78 copies of a 389-option list as a string is slow enough to
// be visible. They are cloned from one prepared list instead.
// ------------------------------------------------------------
function wireSlotControls(catalogue) {
  const template = document.createElement("select");
  catalogue.forEach((p) => {
    const option = document.createElement("option");
    option.value = String(p.product_id);
    option.textContent = `${p.name}  [${p.stock_status}]`;
    template.appendChild(option);
  });

  document.querySelectorAll("select.slot-pick").forEach((select) => {
    const [prebuiltId, slot] = select.dataset.slot.split(":");
    const current = currentLinkFor(select);

    template.childNodes.forEach((option) => select.appendChild(option.cloneNode(true)));
    if (current) select.value = current;

    // Narrow to the slot's own categories first, with a way back out:
    // the shop sells parts that sit in unexpected categories, and a
    // dropdown that cannot reach them is worse than a long one.
    const wanted = SLOT_CATEGORIES[slot];
    if (wanted) narrow(select, catalogue, wanted);

    select.onchange = async () => {
      select.disabled = true;
      try {
        await saveSlot(Number(prebuiltId), slot, select.value);
        reloadWith("Saved.");
      } catch (error) {
        select.disabled = false;
        alert("Could not save that: " + (error.message || error));
      }
    };
  });
}

// The row already knows what it is linked to — it is in the badge cell —
// but reading it back off the DOM is fragile. The select carries it
// instead, set when the row was built.
function currentLinkFor(select) {
  return select.dataset.current || "";
}

function narrow(select, catalogue, wantedCategories) {
  const keep = new Set(catalogue
    .filter((p) => wantedCategories.includes(p.category) ||
                   wantedCategories.includes(p.parent_category))
    .map((p) => String(p.product_id)));

  if (keep.size === 0) return; // no such category — leave the full list

  const hidden = [];
  Array.from(select.options).forEach((option) => {
    if (option.value === "" || option.value === "none") return;
    if (option.value === select.value) return;      // never hide what is chosen
    if (!keep.has(option.value)) hidden.push(option);
  });
  hidden.forEach((option) => option.remove());

  const showAll = document.createElement("option");
  showAll.value = "__all";
  showAll.textContent = "— show every product —";
  select.appendChild(showAll);
}

async function saveSlot(prebuiltId, slot, value) {
  if (value === "__all") {
    // Not a choice, a request to widen the list. Redrawing the page is
    // the simplest honest way to do it.
    window.location.reload();
    return;
  }

  const patch = value === "none"
    ? { component_id: null, not_stocked: true }
    : value === ""
      ? { component_id: null, not_stocked: false, note: null }
      : { component_id: Number(value), not_stocked: false, note: null };

  const { error } = await sb.from("prebuilt_components")
    .update(patch)
    .eq("prebuilt_id", prebuiltId)
    .eq("slot", slot);
  if (error) throw error;
}
