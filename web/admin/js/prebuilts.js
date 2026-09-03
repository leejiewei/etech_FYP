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
});

// ------------------------------------------------------------
// Reading
// ------------------------------------------------------------
async function loadMachines() {
  // admin_products carries the category names already joined on, which
  // is what decides whether a desktop is one of the shop's own builds.
  const { data, error } = await sb.from("admin_products")
    .select("product_id,name,price,stock_status,category")
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
    .select("product_id,name,stock_status,category,parent")
    .eq("is_active", 1)
    .order("name");
  if (error) throw error;
  return data.filter((p) => (p.parent || p.category) !== "Desktops");
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
      <div style="display:flex; align-items:baseline; gap:12px; flex-wrap:wrap;">
        <h2 style="margin:0; font-size:17px;">${e(machine.name)}</h2>
        ${badge}
        <small style="color:#999;">${e(machine.category)} &middot; ${e(money(machine.price))}</small>
      </div>
      ${complete
        ? blocking
        : `<p class="hint" style="margin:6px 0 0;">
             Showing this machine's own status (<strong>${e(machine.stock_status)}</strong>)
             until every slot is answered.</p>`}

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
                   wantedCategories.includes(p.parent))
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
