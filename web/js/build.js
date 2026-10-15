// "Own Build" PC builder: pick one part per slot, with compatibility
// filtering (socket, RAM type) and a build summary that checks socket
// match, memory type match, and PSU headroom before checkout.
//
// The eight parts are numbered cards; each opens a picker that slides in
// from the right with a search box, brand tabs and live stock. A progress
// bar sits in the header, and the total, the buttons and the checks sit
// in the side panel.

let currentBuild = {}; // e.g. { CPU: 101, Motherboard: 111, RAM: null, ... }
// The colour picked for a part that comes in several (mostly cases),
// by slot, e.g. { Case: "White" }. Kept apart from currentBuild so a
// saved build from before colours existed still loads.
let buildColours = {};

// What each slot is called on the page, and its icon from CATEGORY_ICONS
// in layout.js.
const BUILD_SLOT_INFO = {
  CPU:         { title: "Processor (CPU)",     icon: "cpu" },
  Cooler:      { title: "CPU Cooler",          icon: "cooler" },
  Motherboard: { title: "Motherboard",         icon: "motherboard" },
  RAM:         { title: "Memory (RAM)",        icon: "ram" },
  GPU:         { title: "Graphics Card (GPU)", icon: "gpu" },
  Storage:     { title: "Storage",             icon: "storage" },
  PSU:         { title: "Power Supply (PSU)",  icon: "psu" },
  Case:        { title: "Case",                icon: "case" },
};

function buildSlotInfo(slot) {
  return BUILD_SLOT_INFO[slot] || { title: slot, icon: "puzzle" };
}

function loadBuild() {
  const text = localStorage.getItem("currentBuild");
  currentBuild = text ? JSON.parse(text) : {};
  builderSlots.forEach((slot) => {
    if (!(slot in currentBuild)) currentBuild[slot] = null;
    // A saved build might name a product we no longer stock — forget it
    // rather than showing a broken slot.
    if (currentBuild[slot] && !getProductById(currentBuild[slot])) {
      currentBuild[slot] = null;
    }
  });
  try { buildColours = JSON.parse(localStorage.getItem("currentBuildColours")) || {}; }
  catch (e) { buildColours = {}; }
  dropStaleColours();
}

function saveBuild() {
  dropStaleColours();
  localStorage.setItem("currentBuild", JSON.stringify(currentBuild));
  localStorage.setItem("currentBuildColours", JSON.stringify(buildColours));
}

// A colour only stands while the part it was picked for is still in the
// slot and still comes in it.
function dropStaleColours() {
  Object.keys(buildColours).forEach((slot) => {
    const p = selectedProduct(slot);
    if (!p || !colourOptionsOf(p).includes(buildColours[slot])) delete buildColours[slot];
  });
}

function selectedProduct(slot) {
  return currentBuild[slot] ? getProductById(currentBuild[slot]) : null;
}

// Returns the list of parts that are allowed in this slot given what's
// already been picked elsewhere (this is the "socket-compatibility filter").
function eligibleOptions(slot) {
  // Legacy / repair-stock boards are sold in the shop but must never appear
  // in Own Build — we don't carry CPUs for their sockets.
  let list = getProductsBySubcategory(slot).filter((p) => !p.excludeFromBuilder);
  const cpu = selectedProduct("CPU");
  const mobo = selectedProduct("Motherboard");

  if (slot === "Motherboard" && cpu) {
    list = list.filter((p) => p.attrs.socket === cpu.attrs.socket);
  }
  if (slot === "CPU" && mobo) {
    list = list.filter((p) => p.attrs.socket === mobo.attrs.socket);
  }
  if (slot === "RAM") {
    const ramGen = (mobo && mobo.attrs.ramGen) || (cpu && cpu.attrs.ramGen);
    if (ramGen) list = list.filter((p) => ramGenFits(p.attrs.ramGen, ramGen));
  }
  // A back-connector motherboard only fits a case built for it.
  if (slot === "Case" && mobo && mobo.attrs.backConnector === "Yes") {
    list = list.filter((p) => p.attrs.supportsBackConnector === "Yes");
  }
  // A few memory kits are known not to work with certain sockets — these come
  // from our own shop testing, not from any published spec sheet.
  if (slot === "RAM" && cpu) {
    list = list.filter((p) =>
      (p.attrs.incompatibleSockets || []).indexOf(cpu.attrs.socket) === -1);
  }
  // A cooler has to mount on the CPU's socket AND cope with most of the heat
  // it makes. A 65W stock cooler on a 219W Core i7 would cook it, so those
  // aren't offered. One a little under the CPU's figure is offered, and the
  // summary warns that the CPU will run hotter (COOLER_MIN_SHARE).
  if (slot === "Cooler" && cpu) {
    list = list.filter((p) =>
      (p.attrs.sockets || []).includes(cpu.attrs.socket) &&
      (p.attrs.coolerRating || 0) >= (cpu.attrs.tdp || 0) * COOLER_MIN_SHARE);
  }

  return list;
}

// If the CPU or motherboard changes, some previously picked parts might no
// longer be compatible — drop those selections instead of leaving a bad combo.
function clearIncompatibleSelections() {
  ["Motherboard", "CPU", "RAM", "Cooler", "Case"].forEach((slot) => {
    const chosen = currentBuild[slot];
    if (!chosen) return;
    const stillEligible = eligibleOptions(slot).some((p) => p.id === chosen);
    if (!stillEligible) currentBuild[slot] = null;
  });
}

function handleSlotChange(slot, productId) {
  currentBuild[slot] = productId ? Number(productId) : null;
  clearIncompatibleSelections();
  saveBuild();
  renderBuilder();
}

// The deal price when there is one, as the cart will charge it.
function partPrice(p) {
  return priceOf(p);
}

// A chosen part's photo, in the picked colour when we have that photo
// (colourImageOf); a colour with no photo of its own falls back to the
// main one.
function slotPhotoTag(part, colour) {
  const src = colourImageOf(part, colour);
  if (!src) return productImageTag(part, "bp-slot-img");
  return `<img class="bp-slot-img" src="${safeUrl(src)}" alt="${escapeHtml(part.name)}"
    onerror="this.onerror=null; this.src='${safeUrl(productImage(part))}';" />`;
}

function renderBuilder() {
  const container = document.getElementById("builder-slots");
  if (!container) return;

  container.innerHTML = builderSlots.map((slot, i) => {
    const info = buildSlotInfo(slot);
    const picked = selectedProduct(slot);
    return `
      <div class="bp-slot${picked ? " picked" : ""}${picked && colourOptionsOf(picked).length ? " has-colour" : ""}">
        <button type="button" class="bp-slot-main" data-slot="${escapeHtml(slot)}">
          <span class="bp-slot-no">${i + 1}</span>
          <span class="bp-slot-icon">${picked
            ? slotPhotoTag(picked, buildColours[slot])
            : categoryIcon(info.icon)}</span>
          <span class="bp-slot-title">${escapeHtml(info.title)}</span>
          <span class="bp-slot-choice">${picked ? escapeHtml(picked.name) : "Not chosen yet"}</span>
          <span class="bp-slot-foot">
            <span class="bp-slot-price">${picked ? money(partPrice(picked)) : ""}</span>
            <span class="bp-slot-action">${picked ? "Change" : "Choose"}</span>
          </span>
        </button>
        ${picked && colourOptionsOf(picked).length
          ? `<label class="bp-slot-colour">${optionKindOf(colourOptionsOf(picked))}
               <select data-colour-slot="${escapeHtml(slot)}">
                 <option value="">Choose one</option>
                 ${colourOptionsOf(picked).map((c) =>
                   `<option value="${escapeHtml(c)}"${buildColours[slot] === c ? " selected" : ""}>${escapeHtml(c)}</option>`).join("")}
               </select>
             </label>`
          : ""}
        ${picked
          ? `<button type="button" class="bp-slot-remove" data-remove="${escapeHtml(slot)}"
               aria-label="Remove ${escapeHtml(info.title)}" title="Remove">&times;</button>`
          : ""}
      </div>`;
  }).join("");

  container.querySelectorAll("[data-slot]").forEach((btn) => {
    btn.onclick = () => openPicker(btn.dataset.slot);
  });
  container.querySelectorAll("[data-remove]").forEach((btn) => {
    btn.onclick = () => handleSlotChange(btn.dataset.remove, null);
  });
  container.querySelectorAll("[data-colour-slot]").forEach((sel) => {
    sel.onchange = () => {
      if (sel.value) buildColours[sel.dataset.colourSlot] = sel.value;
      else delete buildColours[sel.dataset.colourSlot];
      saveBuild();
      const icon = sel.closest(".bp-slot").querySelector(".bp-slot-icon");
      const part = selectedProduct(sel.dataset.colourSlot);
      if (icon && part) icon.innerHTML = slotPhotoTag(part, buildColours[sel.dataset.colourSlot]);
      sel.classList.remove("needs-choice");
    };
  });

  renderProgress();
  renderBuildSummary();
}

// A bar of eight segments in the page header, one per part, filled in as
// parts are chosen.
function renderProgress() {
  const el = document.getElementById("bp-progress");
  if (!el) return;
  const done = builderSlots.filter((slot) => currentBuild[slot]).length;
  el.innerHTML = `
    <span class="bp-progress-label">${done} of ${builderSlots.length} parts chosen</span>
    <span class="bp-progress-track">${builderSlots.map((slot) =>
      `<span class="${currentBuild[slot] ? "on" : ""}" title="${escapeHtml(buildSlotInfo(slot).title)}"></span>`).join("")}
    </span>`;
}

// ------------------------------------------------------------
// The part picker
// ------------------------------------------------------------
// One drawer, refilled for whichever part was clicked.
let pickerSlot = null;
let pickerBrand = "All";

// A short line of the specs that matter for fitting, under each part's
// name. Anything a product doesn't have is simply left out.
function partSpecLine(slot, p) {
  const a = p.attrs || {};
  const bits = {
    CPU:         [a.socket, a.tdp && a.tdp + "W", a.igpu === "No" && "needs a graphics card"],
    Cooler:      [a.coolerRating && "cools up to " + a.coolerRating + "W"],
    Motherboard: [a.socket, a.formFactor, a.ramGen],
    RAM:         [a.ramGen],
    GPU:         [a.length && a.length + "mm long", a.power && a.power + "W"],
    Storage:     [a.pcieGen && "PCIe Gen " + a.pcieGen],
    PSU:         [a.wattage && a.wattage + "W"],
    Case:        [(a.supportedFormFactors || []).join(" / "),
                  a.maxGpuLength && "cards up to " + a.maxGpuLength + "mm"],
  }[slot] || [];
  return bits.filter(Boolean).join(" · ");
}

function openPicker(slot) {
  pickerSlot = slot;
  pickerBrand = "All";
  const info = buildSlotInfo(slot);
  document.getElementById("bp-picker-title").textContent = "Select " + info.title;
  const search = document.getElementById("bp-search");
  search.value = "";
  search.placeholder = "Search all " + info.title;
  document.getElementById("bp-picker").hidden = false;
  document.body.classList.add("bp-picker-open");
  renderPicker();
  search.focus();
}

function closePicker() {
  pickerSlot = null;
  document.getElementById("bp-picker").hidden = true;
  document.body.classList.remove("bp-picker-open");
}

function renderPicker() {
  const slot = pickerSlot;
  if (!slot) return;

  const eligible = eligibleOptions(slot);
  const brands = ["All", ...Array.from(new Set(eligible.map((p) => p.brand))).sort()];
  if (brands.indexOf(pickerBrand) === -1) pickerBrand = "All";

  const tabs = document.getElementById("bp-tabs");
  tabs.innerHTML = brands.map((b) => `
    <button type="button" class="bp-tab${b === pickerBrand ? " active" : ""}"
            data-brand="${escapeHtml(b)}">${escapeHtml(b)}</button>`).join("");
  tabs.querySelectorAll(".bp-tab").forEach((tab) => {
    tab.onclick = () => { pickerBrand = tab.dataset.brand; renderPicker(); };
  });

  const query = document.getElementById("bp-search").value.trim().toLowerCase();
  const shown = eligible.filter((p) =>
    (pickerBrand === "All" || p.brand === pickerBrand) &&
    (!query || p.name.toLowerCase().indexOf(query) !== -1));

  // Parts left out because they won't work with what's already picked.
  // Saying so beats letting someone think we don't sell them.
  const all = getProductsBySubcategory(slot).filter((p) => !p.excludeFromBuilder).length;
  const hidden = all - eligible.length;
  const hiddenNote = hidden > 0
    ? `<p class="bp-hidden-note">${hidden} more ${hidden > 1 ? "are" : "is"} hidden because
         ${hidden > 1 ? "they don't" : "it doesn't"} fit the parts you've already picked.</p>`
    : "";

  const chosen = currentBuild[slot];
  const groups = [];
  shown.forEach((p) => {
    let g = groups.find((x) => x.brand === p.brand);
    if (!g) groups.push(g = { brand: p.brand, parts: [] });
    g.parts.push(p);
  });

  const list = document.getElementById("bp-list");
  list.innerHTML = (groups.length ? groups.map((g) => `
    <p class="bp-group">${escapeHtml(g.brand)}</p>
    ${g.parts.map((p) => {
      const spec = partSpecLine(slot, p);
      return `
      <button type="button" class="bp-option${p.id === chosen ? " chosen" : ""}"
              data-pick="${p.id}" ${p.stock === "out" ? "disabled" : ""}>
        <span class="bp-option-name">${escapeHtml(p.name)}
          ${spec ? `<small>${escapeHtml(spec)}</small>` : ""}</span>
        <span class="bp-option-side">
          <span class="stock-badge stock-${p.stock}">${stockLabel(p.stock)}</span>
          ${hasDeal(p) ? `<span class="price-was">${money(p.price)}</span>` : ""}
          <strong>${money(partPrice(p))}</strong>
        </span>
      </button>`;
    }).join("")}`).join("")
    : `<p class="bp-empty">Nothing matches that search.</p>`) + hiddenNote;

  list.querySelectorAll("[data-pick]").forEach((btn) => {
    btn.onclick = () => {
      handleSlotChange(slot, btn.dataset.pick);
      closePicker();
    };
  });
}

function wirePicker() {
  document.getElementById("bp-picker-close").onclick = closePicker;
  // A click on the dimmed backdrop, outside the box, closes it too.
  document.getElementById("bp-picker").onclick = (e) => {
    if (e.target.id === "bp-picker") closePicker();
  };
  document.getElementById("bp-search").oninput = renderPicker;
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && pickerSlot) closePicker();
  });
}

// ------------------------------------------------------------
// Reset, Copy Specs and Talk to Us
// ------------------------------------------------------------
function buildTotal() {
  return builderSlots.reduce((sum, slot) => {
    const p = selectedProduct(slot);
    return p ? sum + partPrice(p) : sum;
  }, 0);
}

function buildSpecText() {
  const lines = builderSlots
    .filter((slot) => selectedProduct(slot))
    .map((slot) => {
      const p = selectedProduct(slot);
      return buildSlotInfo(slot).title + ": " + p.name + " - " + money(partPrice(p));
    });
  return lines.length
    ? "My eTech PC build\n" + lines.join("\n") + "\nTotal: " + money(buildTotal())
    : "";
}

function wireToolbar() {
  document.getElementById("bp-reset").onclick = () => {
    if (!builderSlots.some((slot) => currentBuild[slot])) return;
    if (!confirm("Start over and clear every part from this build?")) return;
    builderSlots.forEach((slot) => { currentBuild[slot] = null; });
    saveBuild();
    renderBuilder();
  };

  const copy = document.getElementById("bp-copy");
  copy.onclick = () => {
    const text = buildSpecText();
    const done = (label) => {
      copy.textContent = label;
      setTimeout(() => { copy.textContent = "Copy Specs"; }, 1800);
    };
    if (!text) return done("Nothing to copy yet");
    if (!navigator.clipboard) return done("Could not copy");
    navigator.clipboard.writeText(text).then(() => done("Copied"), () => done("Could not copy"));
  };
}

// Which PCIe generation a motherboard's M.2 slot runs at, worked out from
// its chipset. Only the chipsets our supplier confirmed are listed; anything
// else returns null and we simply skip the speed note rather than guess.
function boardPcieGen(mobo) {
  const chipset = (mobo.attrs.chipset || "").toUpperCase();
  if (chipset.indexOf("X870") === 0) return 5;              // X870, X870E
  if (chipset === "Z790") return 5;  // the Strix Z790-I's ROG Hyper M.2 card in the box adds a Gen 5 slot
  if (["B760", "B860", "B850", "A620", "B650", "H810"].indexOf(chipset) !== -1) return 4;
  if (["H610", "B550", "A520", "H510"].indexOf(chipset) !== -1) return 3;
  return null;
}

// Which PCIe generation the board's graphics card slot (the top x16 slot)
// runs at. AM4 APUs (the "G" chips) cut that slot to Gen 3 on any board.
// Unknown chipsets return null and the slot check is skipped.
function boardGpuSlotGen(mobo, cpu) {
  const chipset = (mobo.attrs.chipset || "").toUpperCase();
  if (cpu && cpu.attrs.socket === "AM4" && /\d{4}G/.test(cpu.name)) return 3;
  if (["H61", "H81"].indexOf(chipset) !== -1) return 2;
  if (["A520", "H110", "H310", "H510"].indexOf(chipset) !== -1) return 3;
  if (["B550", "A620", "B650", "H610", "B760", "H810", "B850", "B860"].indexOf(chipset) !== -1) return 4;
  if (chipset === "Z790" || chipset.indexOf("X870") === 0) return 5;
  return null;
}

// The PCIe generation and lane count a graphics card is built for, from its
// chip. The x8 cards lose the most in an older slot.
function gpuPcie(gpu) {
  const chip = gpu.attrs.chip || "";
  if (/^RTX 50|^RX 90/.test(chip)) return { gen: 5, lanes: /^RTX 50(50|60)/.test(chip) ? 8 : 16 };
  if (/^RTX 30/.test(chip)) return { gen: 4, lanes: chip === "RTX 3050" ? 8 : 16 };
  return null;
}

// A cooler rated at 60% or more of the CPU's power copes, just with the CPU
// running hotter and boosting less. Below that it is critical.
const COOLER_MIN_SHARE = 0.6;

// Total memory in GB, and how many sticks, from the kit ("2 x 16GB").
function ramKit(ram) {
  const m = /(\d+)\s*x\s*(\d+)\s*GB/i.exec(ram.attrs.kit || "");
  if (m) return { sticks: +m[1], totalGb: +m[1] * +m[2] };
  const cap = parseInt(ram.attrs.capacity, 10);
  return cap ? { sticks: null, totalGb: cap } : null;
}

// Intel or AMD, from the socket name.
function socketMaker(socket) {
  return /^AM/.test(socket || "") ? "AMD" : "Intel";
}

// Every rule check for a build, as { level, text }. `pick(slot)` returns
// the part in that slot, so the same rules can test the build on screen
// (selectedProduct) or a "what if" build, such as eTech AI's suggested
// swaps before they are offered.
function compatibilityChecks(pick) {
  const messages = [];
  const cpu = pick("CPU");
  const cooler = pick("Cooler");
  const mobo = pick("Motherboard");
  const ram = pick("RAM");
  const gpu = pick("GPU");
  const psu = pick("PSU");
  const pcCase = pick("Case");
  const storage = pick("Storage");

  // Every check lands in one of three levels:
  //   critical — the parts physically won't work together. Must be changed,
  //              and it stops the build going in the cart.
  //   warning  — the build runs, but not as well as it should. Worth knowing,
  //              never blocks the order.
  //   pass     — all good.
  const critical = (text) => messages.push({ level: "critical", text: text });
  const warn = (text) => messages.push({ level: "warning", text: text });
  const pass = (text) => messages.push({ level: "pass", text: text });

  // ---- CRITICAL: parts that physically cannot work together ----

  // 1. CPU socket must match the motherboard socket.
  if (cpu && mobo) {
    cpu.attrs.socket === mobo.attrs.socket
      ? pass(`Socket match: CPU and motherboard are both ${cpu.attrs.socket}.`)
      : critical(`Socket mismatch: CPU is ${cpu.attrs.socket} but motherboard is ${mobo.attrs.socket}` +
          (socketMaker(cpu.attrs.socket) !== socketMaker(mobo.attrs.socket)
            ? ` — an ${socketMaker(cpu.attrs.socket)} processor can't go in an ${socketMaker(mobo.attrs.socket)} board.`
            : `, so this processor won't fit the board.`));
  }

  // 1b. A few memory kits are known from shop testing not to work with
  //     certain processors, whatever the spec sheets say.
  if (ram && cpu && (ram.attrs.incompatibleSockets || []).indexOf(cpu.attrs.socket) !== -1) {
    critical(`${ram.name} does not work with ${cpu.attrs.socket} processors. ` +
      `We confirmed this by testing in the shop — it isn't listed in the specs. Please pick another kit.`);
  }

  // 2. RAM generation must match what the board supports.
  if (ram && (mobo || cpu)) {
    const boardRamGen = (mobo && mobo.attrs.ramGen) || (cpu && cpu.attrs.ramGen);
    ramGenFits(ram.attrs.ramGen, boardRamGen)
      ? pass(`Memory type match: ${ram.attrs.ramGen} RAM fits your board.`)
      : critical(`Memory type mismatch: board needs ${boardRamGen} but you picked ${ram.attrs.ramGen} RAM.`);
  }

  // 3. The cooler must mount on this CPU's socket.
  if (cooler && cpu) {
    (cooler.attrs.sockets || []).includes(cpu.attrs.socket)
      ? pass(`Cooler mounting OK: ${cooler.name} supports ${cpu.attrs.socket}.`)
      : critical(`Cooler won't mount: ${cooler.name} does not support ${cpu.attrs.socket}.`);
  }

  // 4. A CPU with no built-in graphics cannot display anything on its own.
  if (cpu && cpu.attrs.igpu === "No") {
    gpu
      ? pass(`Graphics OK: the ${cpu.name} has no built-in graphics, and you've added the ${gpu.name}.`)
      : critical(`Graphics card required: the ${cpu.name} has NO integrated graphics, ` +
                 `so this PC won't display anything without one.`);
  }

  // 5. The motherboard has to physically fit inside the case.
  if (pcCase && mobo) {
    const fits = pcCase.attrs.supportedFormFactors || [];
    fits.includes(mobo.attrs.formFactor)
      ? pass(`Case fits board: ${pcCase.name} accepts ${mobo.attrs.formFactor} boards.`)
      : critical(`Board too big for case: ${mobo.name} is ${mobo.attrs.formFactor}, but ${pcCase.name} ` +
                 `only fits ${fits.join(" / ")} boards. Pick a bigger case or a smaller board.`);
  }

  // 5b. A back-connector board needs a case designed for it.
  if (pcCase && mobo && mobo.attrs.backConnector === "Yes") {
    pcCase.attrs.supportsBackConnector === "Yes"
      ? pass(`Back-connector pairing OK: ${pcCase.name} supports ${mobo.name}.`)
      : critical(`Back-connector mismatch: ${mobo.name} routes its cables behind the board, which ` +
                 `${pcCase.name} can't take. The Asus A31 is the only case we stock that supports it.`);
  }

  // 6. The graphics card has to be short enough for the case.
  if (pcCase && gpu) {
    const cardLength = gpu.attrs.length || 0;
    const maxLength = pcCase.attrs.maxGpuLength || 0;
    cardLength <= maxLength
      ? pass(`Graphics card fits: ${cardLength}mm card in a case that takes up to ${maxLength}mm.`)
      : critical(`Graphics card too long: ${gpu.name} is ${cardLength}mm but ${pcCase.name} ` +
                 `only fits up to ${maxLength}mm.`);
  }

  // 7. The PSU. Below the build's estimated full-load draw the PC shuts down
  //    under load, so that is critical. Covering the draw but falling short
  //    of the recommended size (the card maker's minimum, or the draw plus
  //    headroom — psuNeedFor) still runs, so that is only a warning.
  if (psu && (cpu || gpu)) {
    const n = psuNeedFor(cpu, gpu);
    const watts = psu.attrs.wattage || 0;
    const why = n.byCard
      ? `we recommend at least ${n.needed}W for a full rig with the ${gpu.name}` +
        (n.makerPsu && n.makerPsu < n.needed ? ` (${n.maker}'s own figure is ${n.makerPsu}W)` : "")
      : `this build draws about ${n.draw}W (CPU ${n.cpuWatts}W + GPU ${n.gpuWatts}W + ` +
        `${OTHER_PARTS_WATTAGE}W other parts), so it needs at least ${n.needed}W with headroom`;
    if (watts >= n.needed) {
      pass(`Power OK: ${why}, and your PSU is ${watts}W.`);
    } else if (watts < n.draw) {
      critical(`PSU too small: this build draws about ${n.draw}W at full load, but your PSU is only ` +
               `${watts}W, so the PC would shut down in games. Pick a ${n.needed}W or bigger supply.`);
    } else {
      warn(`PSU below the recommended size: ${why}, and your PSU is ${watts}W. It covers the ` +
           `estimated ${n.draw}W draw, so it will run, but with little spare for load spikes. ` +
           `A ${n.needed}W supply is the safer pick.`);
    }
  }

  // 8. We stock no SFX supplies, so a Mini-ITX build still needs a case that
  //    takes a full-size ATX unit. Every case we carry does.
  if (mobo && mobo.attrs.formFactor === "mini-ITX" && psu && pcCase) {
    pcCase.attrs.acceptsAtxPsu === "Yes"
      ? pass(`Power supply fits: we only stock full-size ATX supplies, and ${pcCase.name} takes one.`)
      : critical(`${pcCase.name} needs a small SFX power supply, and we don't stock any at the moment.`);
  }

  // ---- WARNINGS: it will build and run, just not at its best ----

  // Cooling. Well under the CPU's power is critical — it would run far too
  // hot to be usable (the dropdown hides those, so that only fires on a build
  // loaded from earlier). A little under still works: the CPU just runs
  // hotter and boosts less.
  if (cooler && cpu) {
    const needed = cpu.attrs.tdp || 0;
    const capacity = cooler.attrs.coolerRating || 0;
    if (capacity >= needed) {
      pass(`Cooling OK: ${cooler.name} handles ${capacity}W, the ${cpu.name} needs ${needed}W.`);
    } else if (capacity < needed * COOLER_MIN_SHARE) {
      critical(`Cooler is too small for this processor: the ${cpu.name} puts out ${needed}W but ` +
               `${cooler.name} only handles ${capacity}W. Please pick a cooler rated for ${needed}W or more.`);
    } else {
      warn(`Cooler below the recommended size: the ${cpu.name} can put out ${needed}W and ` +
           `${cooler.name} handles ${capacity}W. It will work, but under heavy load the processor ` +
           `runs hotter and boosts less. A cooler rated for ${needed}W or more keeps it at full speed.`);
    }
  }

  // Memory. One stick runs in single channel, and too little memory stutters.
  if (ram) {
    const kit = ramKit(ram);
    if (kit && kit.sticks === 1) {
      warn(`${ram.name} is a single stick, so memory runs in single channel — noticeably slower ` +
        `in games and with built-in graphics. Two matching sticks (a 2 x kit) run in dual channel.`);
    }
    if (kit && kit.totalGb < 16) {
      warn(`${kit.totalGb}GB of memory is tight for Windows 11 and current games and apps. ` +
        `16GB or more is the comfortable minimum.`);
    }
  }

  // Storage. A hard drive as the only drive makes the whole PC feel slow.
  if (storage && storage.attrs.driveType === "HDD") {
    warn(`${storage.name} is a hard drive, so Windows and games will load slowly. It is great for ` +
      `bulk storage, but an SSD as the main drive makes the whole PC feel much faster.`);
  }

  // Case airflow. A case with no fans needs some added, or the parts run hot.
  if (pcCase && /^none$/i.test(pcCase.attrs.fansIncluded || "")) {
    warn(`${pcCase.name} comes with no fans. The PC will run hot without them, so add at least ` +
      `two case fans (one in, one out).`);
  }

  // A newer drive in an older M.2 slot is fully compatible, just slower.
  if (storage && mobo && storage.attrs.pcieGen) {
    const boardGen = boardPcieGen(mobo);
    if (boardGen && storage.attrs.pcieGen > boardGen) {
      warn(`${storage.name} is a Gen ${storage.attrs.pcieGen} drive and ${mobo.name} runs its M.2 slot ` +
        `at Gen ${boardGen}. It is fully compatible and will work perfectly — it just won't reach its ` +
        `top speed. A Gen ${boardGen} drive would cost less for the same real-world result.`);
    }
    if (storage.attrs.pcieGen === 5 && storage.attrs.heatsink === "No") {
      warn(`Gen 5 drives run hot: check ${mobo.name} has its own M.2 heat shield, ` +
        `or pick a drive with a heatsink built in.`);
    }
  }

  // A newer graphics card in a Gen 3 (or older) slot still works, just with
  // less bandwidth. The x8 cards (RTX 5050/5060/5060 Ti, RTX 3050) feel it most.
  if (gpu && mobo) {
    const card = gpuPcie(gpu);
    const slotGen = boardGpuSlotGen(mobo, cpu);
    if (card && slotGen && slotGen <= 3 && card.gen > slotGen) {
      const apu = cpu && cpu.attrs.socket === "AM4" && /\d{4}G/.test(cpu.name);
      warn(`${gpu.name} is a PCIe Gen ${card.gen} card, but its slot runs at Gen ${slotGen}` +
        (apu ? ` with the ${cpu.name}` : ` on ${mobo.name}`) + `. It is fully compatible, but ` +
        (card.lanes === 8
          ? `this card only uses 8 lanes, so it can lose a noticeable amount of performance in some games.`
          : `it can lose a little performance.`) +
        (apu ? ` A processor without a "G" in its name runs the slot at full speed.`
             : ` A board with a Gen 4 or newer slot gets the most out of it.`));
    }
  }

  // Whether the processor and graphics card are well matched is judged by
  // eTech AI's review below, not by a hand-kept table of chip "tiers".

  // The RTX 50 cards ship with an adapter, so this is a tidiness issue.
  if (psu && gpu && psu.attrs.connector12VHPWR === "No" &&
      (gpu.attrs.chip || "").indexOf("RTX 5") === 0) {
    warn(`${psu.name} has no 12VHPWR connector, which the ${gpu.attrs.chip} expects. ` +
      `It will work using the adapter in the card's box, but a supply with a native lead is tidier.`);
  }

  // ---- Notes that are simply good news ----
  if (cpu && cpu.attrs.coolerIncluded === "Yes" && !cooler) {
    pass(`The ${cpu.name} comes with a cooler in the box, so a separate cooler is optional.`);
  }

  return messages;
}

function renderBuildSummary() {
  const subtotalEl = document.getElementById("builder-subtotal");
  const messagesEl = document.getElementById("compat-messages");
  if (!subtotalEl) return;

  subtotalEl.textContent = money(buildTotal());

  const messages = compatibilityChecks(selectedProduct);
  const cpu = selectedProduct("CPU");
  const gpu = selectedProduct("GPU");
  const psu = selectedProduct("PSU");

  // ---- Render, grouped by severity ----
  if (messages.length === 0) {
    messagesEl.innerHTML = `<p class="compat-message">Start picking parts and every compatibility check will appear here.</p>`;
  } else {
    const criticals = messages.filter((m) => m.level === "critical");
    const warnings = messages.filter((m) => m.level === "warning");
    const passes = messages.filter((m) => m.level === "pass");

    let header;
    if (criticals.length > 0) {
      header = `<p class="compat-summary compat-warn">${criticals.length} critical problem` +
        `${criticals.length > 1 ? "s" : ""} — this build won't work until you change ` +
        `${criticals.length > 1 ? "them" : "it"}.</p>`;
    } else if (warnings.length > 0) {
      header = `<p class="compat-summary compat-caution">Everything fits. ${warnings.length} thing` +
        `${warnings.length > 1 ? "s are" : " is"} worth a look, but you can order as-is.</p>`;
    } else {
      header = `<p class="compat-summary compat-ok">All ${passes.length} compatibility checks passed.</p>`;
    }

    const group = (list, cls, mark, title) => {
      if (list.length === 0) return "";
      return (title ? `<p class="compat-group-title">${escapeHtml(title)}</p>` : "") +
        list.map((m) => `<p class="compat-message ${cls}">${mark} ${escapeHtml(m.text)}</p>`).join("");
    };

    messagesEl.innerHTML = header +
      group(criticals, "compat-warn", "&#10007;", "Critical — needs changing") +
      group(warnings, "compat-caution", "&#9888;", "Worth knowing") +
      group(passes, "compat-ok", "&#10003;", passes.length && (criticals.length || warnings.length) ? "Checks passed" : "");
  }

  renderPowerMeter(cpu, gpu, psu);
  renderBarInfo();

  // Every slot must be filled — except the cooler, when the CPU already
  // comes with one in the box.
  const coolerOptional = cpu && cpu.attrs.coolerIncluded === "Yes";
  const allPicked = builderSlots.every((slot) => {
    if (slot === "Cooler" && coolerOptional) return true;
    return currentBuild[slot];
  });
  // Only critical problems stop the order — warnings are advice.
  const allCompatible = messages.every((m) => m.level !== "critical");
  const addBtn = document.getElementById("add-build-btn");
  if (addBtn) {
    addBtn.disabled = !(allPicked && allCompatible);
  }

  scheduleAiReview(allPicked, messages);
}

// Estimated draw against the power supply, as a bar, and the supply the
// build needs. The same psuNeedFor() as check 7 above.
function renderPowerMeter(cpu, gpu, psu) {
  const el = document.getElementById("bp-power");
  if (!el) return;
  if (!cpu && !gpu) {
    el.innerHTML = "";
    return;
  }
  const n = psuNeedFor(cpu, gpu);
  const capacity = psu ? psu.attrs.wattage || 0 : 0;
  const share = capacity ? Math.min(100, Math.round(n.draw / capacity * 100)) : 0;
  const short = capacity && capacity < n.draw;
  const tight = capacity && !short && capacity < n.needed;
  el.innerHTML = `
    <div class="bp-power">
      <div class="bp-power-row">
        <span>Estimated power draw</span>
        <strong>about ${n.draw}W</strong>
      </div>
      <div class="bp-power-row">
        <span>Recommended power supply</span>
        <strong>${n.needed}W or more</strong>
      </div>
      ${capacity ? `
        <div class="bp-meter"><span class="${short ? "over" : tight ? "tight" : ""}" style="width:${share}%"></span></div>
        <p class="bp-power-note">${short
          ? `Your ${capacity}W supply is too small for this build.`
          : tight
            ? `${share}% of your ${capacity}W supply — below the ${n.needed}W we recommend.`
            : `${share}% of your ${capacity}W supply.`}</p>`
        : `<p class="bp-power-note">Choose a power supply of at least ${n.needed}W.</p>`}
    </div>`;
}

// The count in the bottom bar, and a Talk to Us link that carries the
// build so far, so the shop sees exactly what the customer is asking about.
function renderBarInfo() {
  const picked = builderSlots.filter((slot) => currentBuild[slot]).length;
  document.getElementById("bp-count").textContent = picked
    ? `${picked} of ${builderSlots.length} parts selected`
    : "No parts selected";

  const spec = buildSpecText();
  document.getElementById("bp-talk").href = whatsappShopLink(spec
    ? "Hi eTech, can you check this build for me?\n\n" + spec
    : "Hi eTech, I'd like help choosing parts for a PC build.");
}

// ------------------------------------------------------------
// eTech AI review
//
// Once every part is picked, the build goes to eTech AI (Gemini, through
// the chat-advisor Edge Function) for a technician's opinion: how well the
// processor and graphics card suit each other, what is not ideal, and up
// to two swaps from our own catalogue. It sorts what it finds the same way
// the checks above do: critical when the build won't work, warning when
// it runs but isn't ideal.
//
// The checks above stay the only thing that can stop an order. eTech AI's
// criticals are shown in red but never disable Add Build to Cart, because
// a language model can be wrong and Google can be down. Its suggested
// swaps are run through the same checks before they are offered, and any
// that would break the build are dropped.
//
// A build is only sent once: the answer is kept in this browser by the
// build's part ids, so changing a part and changing it back costs nothing.
// ------------------------------------------------------------
const AI_REVIEW_DELAY = 1500;          // wait for the customer to stop clicking
const AI_REVIEW_STORE = "aiBuildReviews";
const AI_REVIEW_KEEP = 20;             // reviews remembered in this browser
const AI_REVIEW_MAX_AGE = 24 * 60 * 60 * 1000; // stock and the catalogue move on

let aiReviewTimer = null;
let aiReviewWanted = "";               // the build key the panel should show

const AI_VERDICTS = {
  great:     { cls: "compat-ok",      text: "eTech AI: a well-balanced build." },
  good:      { cls: "compat-ok",      text: "eTech AI: a good build, with room to improve." },
  rethink:   { cls: "compat-caution", text: "eTech AI: it works, but it's worth rethinking." },
  fix_first: { cls: "compat-warn",    text: "eTech AI: fix the critical problems first." },
};

function aiReviewKey() {
  return builderSlots.map((slot) => slot + ":" + (currentBuild[slot] || 0)).join(",");
}

function readAiReviews() {
  try { return JSON.parse(localStorage.getItem(AI_REVIEW_STORE)) || {}; }
  catch (e) { return {}; }
}

function cachedAiReview(key) {
  const hit = readAiReviews()[key];
  return hit && Date.now() - hit.at < AI_REVIEW_MAX_AGE ? hit.review : null;
}

function storeAiReview(key, review) {
  try {
    const all = readAiReviews();
    all[key] = { review: review, at: Date.now() };
    const newest = Object.keys(all)
      .sort((a, b) => all[b].at - all[a].at)
      .slice(0, AI_REVIEW_KEEP);
    const kept = {};
    newest.forEach((k) => { kept[k] = all[k]; });
    localStorage.setItem(AI_REVIEW_STORE, JSON.stringify(kept));
  } catch (e) { /* storage full or blocked: the review just isn't remembered */ }
}

function scheduleAiReview(allPicked, checks) {
  const el = document.getElementById("bp-ai-review");
  if (!el) return;
  clearTimeout(aiReviewTimer);

  if (!allPicked) {
    aiReviewWanted = "";
    renderAiReviewNote("Pick every part and eTech AI will review the whole build: " +
      "how well the parts suit each other, and what to change.");
    return;
  }

  const key = aiReviewKey();
  aiReviewWanted = key;
  const cached = cachedAiReview(key);
  if (cached) return renderAiReview(cached);

  renderAiReviewNote("eTech AI is reviewing your build…", true);
  aiReviewTimer = setTimeout(() => requestAiReview(key, checks), AI_REVIEW_DELAY);
}

function requestAiReview(key, checks) {
  if (typeof sb === "undefined" || !sb.functions) {
    return renderAiReviewFailed(key, checks);
  }
  const build = {};
  builderSlots.forEach((slot) => { if (currentBuild[slot]) build[slot] = currentBuild[slot]; });

  sb.functions
    .invoke("chat-advisor", {
      body: {
        mode: "review",
        build: build,
        checks: checks.map((m) => ({ level: m.level, text: m.text })),
      },
    })
    .then(({ data, error }) => {
      if (key !== aiReviewWanted) return;   // the build changed meanwhile
      if (error || !data || !data.verdict) {
        console.warn("eTech AI review unavailable.", error || data);
        return renderAiReviewFailed(key, checks);
      }
      storeAiReview(key, data);
      renderAiReview(data);
    })
    .catch((error) => {
      if (key !== aiReviewWanted) return;
      console.warn("eTech AI review unreachable.", error);
      renderAiReviewFailed(key, checks);
    });
}

function renderAiReviewNote(text, busy) {
  const el = document.getElementById("bp-ai-review");
  if (!el) return;
  el.innerHTML = `
    <h3>eTech AI review</h3>
    <p class="ai-review-note${busy ? " busy" : ""}">${escapeHtml(text)}</p>`;
}

function renderAiReviewFailed(key, checks) {
  const el = document.getElementById("bp-ai-review");
  if (!el) return;
  el.innerHTML = `
    <h3>eTech AI review</h3>
    <p class="ai-review-note">eTech AI couldn't review this build just now.
      The checks above still apply.</p>
    <button type="button" class="ai-review-retry" id="ai-review-retry">Try again</button>`;
  document.getElementById("ai-review-retry").onclick = () => {
    if (key !== aiReviewWanted) return;
    renderAiReviewNote("eTech AI is reviewing your build…", true);
    requestAiReview(key, checks);
  };
}

// A suggested swap is only offered when the part still exists, belongs in
// that slot, is in stock, and passes every check with it swapped in.
function swapIsSafe(swap) {
  const part = getProductById(swap.product_id);
  if (!part || part.subcategory !== swap.slot || part.excludeFromBuilder) return false;
  if (part.stock === "out" || currentBuild[swap.slot] === part.id) return false;
  const pick = (slot) => (slot === swap.slot ? part : selectedProduct(slot));
  return compatibilityChecks(pick).every((m) => m.level !== "critical");
}

function renderAiReview(review) {
  const el = document.getElementById("bp-ai-review");
  if (!el) return;

  const verdict = AI_VERDICTS[review.verdict] || AI_VERDICTS.good;
  const issues = Array.isArray(review.issues) ? review.issues : [];
  const criticals = issues.filter((i) => i.level === "critical");
  const warnings = issues.filter((i) => i.level !== "critical");
  const swaps = (Array.isArray(review.swaps) ? review.swaps : []).filter(swapIsSafe);

  const group = (list, cls, mark, title) => list.length
    ? `<p class="compat-group-title">${escapeHtml(title)}</p>` +
      list.map((i) => `<p class="compat-message ${cls}">${mark} ${escapeHtml(i.text)}</p>`).join("")
    : "";

  const swapRows = swaps.map((swap) => {
    const part = getProductById(swap.product_id);
    const now = selectedProduct(swap.slot);
    return `
      <div class="ai-swap">
        <div class="ai-swap-body">
          <span class="ai-swap-slot">${escapeHtml(buildSlotInfo(swap.slot).title)}</span>
          <span class="ai-swap-name">${escapeHtml(part.name)}</span>
          ${now ? `<span class="ai-swap-was">instead of ${escapeHtml(now.name)}</span>` : ""}
          <span class="ai-swap-reason">${escapeHtml(swap.reason)}</span>
        </div>
        <div class="ai-swap-side">
          <strong>${money(partPrice(part))}</strong>
          <button type="button" class="ai-swap-btn" data-swap-slot="${escapeHtml(swap.slot)}"
                  data-swap-id="${part.id}">Swap in</button>
        </div>
      </div>`;
  }).join("");

  el.innerHTML = `
    <h3>eTech AI review</h3>
    <p class="compat-summary ${verdict.cls}">${escapeHtml(verdict.text)}</p>
    ${review.summary ? `<p class="ai-review-summary">${escapeHtml(review.summary)}</p>` : ""}
    ${group(criticals, "compat-warn", "&#10007;", "Critical — eTech AI says this won't work")}
    ${group(warnings, "compat-caution", "&#9888;", "Worth knowing")}
    ${swapRows ? `<p class="compat-group-title">Suggested swaps</p>${swapRows}` : ""}
    <p class="ai-review-foot">${criticals.length
      ? "eTech AI can be wrong. If you're unsure, ask us on WhatsApp before you order. "
      : ""}Reviewed by eTech AI from our catalogue. Prices are ours; the checks above decide what can be ordered.</p>`;

  el.querySelectorAll("[data-swap-slot]").forEach((btn) => {
    btn.onclick = () => handleSlotChange(btn.dataset.swapSlot, btn.dataset.swapId);
  });
}

function addBuildToCart() {
  // A part that comes in several colours needs one picked first, or the
  // shop has to ring to ask which case to build in.
  const unpicked = builderSlots.find((slot) => {
    const p = selectedProduct(slot);
    return p && colourOptionsOf(p).length && !buildColours[slot];
  });
  if (unpicked) {
    const sel = document.querySelector(`[data-colour-slot="${unpicked}"]`);
    if (sel) { sel.classList.add("needs-choice"); sel.focus(); }
    alert("Choose a colour for your " + buildSlotInfo(unpicked).title.toLowerCase() + " first.");
    return;
  }
  builderSlots.forEach((slot) => {
    const id = currentBuild[slot];
    if (id) addToCart(id, null, buildColours[slot]);
  });
  window.location.href = "cart.html";
}

onAppReady(() => {
  loadBuild();
  wirePicker();
  wireToolbar();
  renderBuilder();
});
