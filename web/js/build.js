// "Own Build" PC builder: pick one part per slot, with compatibility
// filtering (socket, RAM type) and a build summary that checks socket
// match, memory type match, and PSU headroom before checkout.

let currentBuild = {}; // e.g. { CPU: 101, Motherboard: 111, RAM: null, ... }
let currentBrandFilter = "All";

// All the brands that appear anywhere among buildable parts (CPU, Motherboard,
// RAM, GPU, Storage, PSU, Case), used for the brand filter row at the top.
function getBuilderBrands() {
  const brands = new Set();
  builderSlots.forEach((slot) => {
    getProductsBySubcategory(slot).forEach((p) => brands.add(p.brand));
  });
  return ["All", ...Array.from(brands).sort()];
}

function renderBrandFilter() {
  const container = document.getElementById("builder-brand-filter");
  if (!container) return;

  container.innerHTML = "";
  getBuilderBrands().forEach((brand) => {
    const btn = document.createElement("button");
    btn.textContent = brand;
    btn.className = "filter-btn" + (brand === currentBrandFilter ? " active" : "");
    btn.onclick = () => {
      currentBrandFilter = brand;
      renderBuilder();
    };
    container.appendChild(btn);
  });
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
}

function saveBuild() {
  localStorage.setItem("currentBuild", JSON.stringify(currentBuild));
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
  // A cooler has to physically mount on the CPU's socket.
  // A cooler has to mount on the CPU's socket AND be able to shift the heat
  // it makes. A 65W stock cooler on a 219W Core i7 would cook it, so those
  // simply aren't offered — the same way an incompatible board isn't.
  if (slot === "Cooler" && cpu) {
    list = list.filter((p) =>
      (p.attrs.sockets || []).includes(cpu.attrs.socket) &&
      (p.attrs.coolerRating || 0) >= (cpu.attrs.tdp || 0));
  }

  // Brand filter from the top of the page. If this slot has no products of
  // the chosen brand (e.g. "AMD" doesn't make PSUs or cases), just show
  // everything for that slot instead of leaving the dropdown empty.
  if (currentBrandFilter !== "All") {
    const brandMatches = list.filter((p) => p.brand === currentBrandFilter);
    if (brandMatches.length > 0) list = brandMatches;
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

// Which drawing to show as the greyed-out placeholder for an empty slot.
function slotImageName(slot) {
  const names = {
    CPU: "cpu",
    Cooler: "cooler",
    Motherboard: "motherboard",
    RAM: "ram",
    GPU: "gpu",
    Storage: "ssd",
    PSU: "psu",
    Case: "case",
  };
  return names[slot] || "default";
}

function renderBuilder() {
  const container = document.getElementById("builder-slots");
  if (!container) return;

  renderBrandFilter();
  container.innerHTML = "";

  builderSlots.forEach((slot) => {
    const options = eligibleOptions(slot);
    const chosen = currentBuild[slot];

    // Show a thumbnail of whatever is picked for this slot (or a faded
    // placeholder drawing while the slot is still empty).
    const picked = selectedProduct(slot);
    const slotImg = picked
      ? `<img class="slot-img" src="${safeUrl(productImage(picked))}" alt="${escapeHtml(picked.name)}"
           onerror="this.onerror=null; this.src='${safeUrl(productImageFallback(picked))}';" />`
      : `<img class="slot-img" style="opacity:0.3" src="images/${encodeURIComponent(slotImageName(slot))}.svg" alt="${escapeHtml(slot)}" />`;

    const row = document.createElement("div");
    row.className = "builder-slot";
    row.innerHTML = `
      ${slotImg}
      <span class="slot-name">${escapeHtml(slot)}</span>
      <select onchange="handleSlotChange('${escapeHtml(slot)}', this.value)">
        <option value="">-- Choose ${escapeHtml(slot)} --</option>
        ${options.map((p) => `
          <option value="${p.id}" ${chosen === p.id ? "selected" : ""} ${p.stock === "out" ? "disabled" : ""}>
            ${escapeHtml(p.name)} - RM ${p.price.toFixed(2)} ${p.stock === "out" ? "(Out of stock)" : p.stock === "low" ? "(Low stock)" : ""}
          </option>
        `).join("")}
      </select>
      <span class="slot-price">${selectedProduct(slot) ? "RM " + selectedProduct(slot).price.toFixed(2) : "-"}</span>
    `;
    container.appendChild(row);
  });

  renderBuildSummary();
}

// Which PCIe generation a motherboard's M.2 slot runs at, worked out from
// its chipset. Only the chipsets our supplier confirmed are listed; anything
// else returns null and we simply skip the speed note rather than guess.
function boardPcieGen(mobo) {
  const chipset = (mobo.attrs.chipset || "").toUpperCase();
  if (chipset.indexOf("X870") === 0) return 5;              // X870, X870E
  if (["B760", "B860", "B850"].indexOf(chipset) !== -1) return 4;
  if (["H610", "B550"].indexOf(chipset) !== -1) return 3;
  return null;
}

function renderBuildSummary() {
  const subtotalEl = document.getElementById("builder-subtotal");
  const messagesEl = document.getElementById("compat-messages");
  if (!subtotalEl) return;

  let subtotal = 0;
  builderSlots.forEach((slot) => {
    const p = selectedProduct(slot);
    if (p) subtotal += p.price;
  });
  subtotalEl.textContent = "RM " + subtotal.toFixed(2);

  const messages = [];
  const cpu = selectedProduct("CPU");
  const cooler = selectedProduct("Cooler");
  const mobo = selectedProduct("Motherboard");
  const ram = selectedProduct("RAM");
  const gpu = selectedProduct("GPU");
  const psu = selectedProduct("PSU");
  const pcCase = selectedProduct("Case");
  const storage = selectedProduct("Storage");

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
      : critical(`Socket mismatch: CPU is ${cpu.attrs.socket} but motherboard is ${mobo.attrs.socket}.`);
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

  // 7. The PSU must cover the whole system. Too small and the PC shuts down
  //    under load, so this one is critical rather than a warning.
  if (psu && (cpu || gpu)) {
    const cpuWatts = cpu ? (cpu.attrs.tdp || 0) : 0;
    const gpuWatts = gpu ? (gpu.attrs.power || 0) : 0;
    const totalNeeded = cpuWatts + gpuWatts + OTHER_PARTS_WATTAGE;
    const sum = `about ${totalNeeded}W (CPU ${cpuWatts}W + GPU ${gpuWatts}W + ${OTHER_PARTS_WATTAGE}W other parts)`;
    psu.attrs.wattage >= totalNeeded
      ? pass(`Power OK: this build draws ${sum} and your PSU is ${psu.attrs.wattage}W.`)
      : critical(`PSU too small: this build draws ${sum} but your PSU is only ${psu.attrs.wattage}W.`);
  }

  // 8. We stock no SFX supplies, so a Mini-ITX build still needs a case that
  //    takes a full-size ATX unit. Every case we carry does.
  if (mobo && mobo.attrs.formFactor === "mini-ITX" && psu && pcCase) {
    pcCase.attrs.acceptsAtxPsu === "Yes"
      ? pass(`Power supply fits: we only stock full-size ATX supplies, and ${pcCase.name} takes one.`)
      : critical(`${pcCase.name} needs a small SFX power supply, and we don't stock any at the moment.`);
  }

  // ---- WARNINGS: it will build and run, just not at its best ----

  // Cooling is a hard limit. The dropdown already hides coolers that can't
  // cope, so this only fires on a build loaded from earlier — but we won't
  // sell the pairing, because it would run far too hot to be usable.
  if (cooler && cpu) {
    const needed = cpu.attrs.tdp || 0;
    const capacity = cooler.attrs.coolerRating || 0;
    capacity >= needed
      ? pass(`Cooling OK: ${cooler.name} handles ${capacity}W, the ${cpu.name} needs ${needed}W.`)
      : critical(`Cooler is too small for this processor: the ${cpu.name} puts out ${needed}W but ` +
                 `${cooler.name} only handles ${capacity}W. Please pick a cooler rated for ${needed}W or more.`);
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
}

function addBuildToCart() {
  builderSlots.forEach((slot) => {
    const id = currentBuild[slot];
    if (id) addToCart(id);
  });
  window.location.href = "cart.html";
}

onAppReady(() => {
  loadBuild();
  renderBuilder();
});
