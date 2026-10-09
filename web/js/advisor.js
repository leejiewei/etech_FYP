// ============================================================
// PC BUILD ADVISOR — the "brain" behind the AI hardware consultant.
//
// What it does: reads a sentence like
//     "build a pc for cs2 game full hd bajet 4k"
// works out (1) the budget, (2) the screen resolution, (3) what the PC is
// for, then puts together a complete build out of our real stock and runs
// it through the SAME compatibility rules as the PC Builder page.
//
// It is NOT a large language model — there's no internet or AI service
// involved. It's a rule-based recommender: it reads the numbers and
// keywords out of the sentence, then searches every CPU + GPU combination
// we sell and keeps the best one that fits the budget and passes all the
// compatibility checks. That's why the answers are always technically
// correct — they're built from the product data, not guessed.
// ============================================================

// How fast each part is, on a 0-100 scale, used only for recommending.
// gaming = frame rates in games, multi = video editing / rendering.
// Looked up by CPU model name so it keeps working when prices or stock change.
const CPU_SCORE = {
  // AMD AM5
  "Ryzen 5 7500F":                    { gaming: 78, multi: 48 },
  "Ryzen 5 7600X":                    { gaming: 82, multi: 52 },
  "Ryzen 5 7500X3D":                  { gaming: 88, multi: 50 },
  "Ryzen 5 9600X":                    { gaming: 86, multi: 56 },
  "Ryzen 7 7800X3D":                  { gaming: 96, multi: 62 },
  "Ryzen 7 9700X":                    { gaming: 88, multi: 68 },
  "Ryzen 9 9900X":                    { gaming: 90, multi: 88 },
  "Ryzen 7 9800X3D":                  { gaming: 100, multi: 70 },
  "Ryzen 9 9950X3D":                  { gaming: 100, multi: 100 },
  // AMD AM4
  "Ryzen 3 3200G":                    { gaming: 30, multi: 18 },
  "Ryzen 5 5500":                     { gaming: 55, multi: 40 },
  "Ryzen 5 3400G":                    { gaming: 33, multi: 22 },
  "Ryzen 5 5600":                     { gaming: 62, multi: 44 },
  "Ryzen 5 5600GT":                   { gaming: 62, multi: 44 },
  "Ryzen 7 5700X":                    { gaming: 68, multi: 58 },
  "Ryzen 7 5800X3D (10th Anniversary)": { gaming: 84, multi: 60 },
  // Intel LGA1851
  "Core Ultra 5 225":                 { gaming: 68, multi: 46 },
  "Core Ultra 5 245KF":               { gaming: 80, multi: 62 },
  "Core Ultra 7 265K":                { gaming: 86, multi: 84 },
  "Core Ultra 7 270K Plus":           { gaming: 88, multi: 88 },
  "Core Ultra 9 285K":                { gaming: 90, multi: 96 },
  // Intel LGA1700
  "Core i5-14400F":                   { gaming: 68, multi: 48 },
  "Core i5-14400":                    { gaming: 68, multi: 48 },
  "Core i5-14600K":                   { gaming: 82, multi: 66 },
  "Core i7-12700":                    { gaming: 74, multi: 62 },
  "Core i7-14700F":                   { gaming: 88, multi: 86 },
  "Core i7-14700":                    { gaming: 88, multi: 86 },
  "Core i9-14900K":                   { gaming: 92, multi: 96 },
};

// Graphics cards are scored by their chip, so all the different brand
// versions of the same card share one score.
const GPU_SCORE = {
  "GT 710": 3, "GT 730": 5, "GT 1030": 8, "GTX 1650": 22, "RTX 3050": 30,
  "RTX 5050": 38, "RTX 5060": 48, "RTX 5060 Ti": 60, "RX 9060 XT": 58,
  "RTX 5070": 72, "RX 9070 XT": 85, "RTX 5070 Ti": 88,
  "RTX 5080": 100, "RTX 5090": 130,
};

function perfOf(product, key) {
  if (product.subcategory === "GPU") {
    return GPU_SCORE[product.attrs.chip] || 0;
  }
  // Product names start with the brand ("Intel Core i7-12700") but the table
  // above is keyed on the model alone, so try the name with the brand removed
  // as well. That way renaming products doesn't break the recommendations.
  let row = CPU_SCORE[product.name];
  if (!row && product.name.indexOf(product.brand + " ") === 0) {
    row = CPU_SCORE[product.name.slice(product.brand.length + 1)];
  }
  return row && row[key] ? row[key] : 0;
}

// ------------------------------------------------------------
// STEP 1 — read the customer's sentence
// ------------------------------------------------------------

// Games and jobs we recognise, and what kind of workload they are.
const WORKLOAD_KEYWORDS = {
  esports: ["cs2", "cs:go", "csgo", "counter strike", "counter-strike", "valorant",
            "dota", "lol", "league of legends", "overwatch", "apex", "rainbow six",
            "r6", "pubg", "rocket league", "esports", "e-sports", "competitive"],
  aaa: ["cyberpunk", "aaa", "triple a", "gta", "elden ring", "starfield", "hogwarts",
        "red dead", "assassin", "witcher", "battlefield", "call of duty", "cod",
        "open world", "ray tracing", "raytracing"],
  creator: ["video editing", "editing", "premiere", "after effects", "render",
            "rendering", "blender", "3d", "cad", "autocad", "photoshop", "streaming",
            "stream", "obs", "content creation", "davinci"],
  office: ["office", "study", "studying", "assignment", "word", "excel", "browsing",
           "typing", "admin", "school", "homework"],
};

// Turns "4k" / "4000" / "rm 4,000" / "4 ribu" into a plain number.
function toRinggit(numberText, suffix) {
  let value = parseFloat(String(numberText).replace(/,/g, ""));
  if (isNaN(value)) return null;
  if (suffix && /^(k|ribu)$/i.test(suffix)) value *= 1000;
  // "budget 4" almost certainly means 4 thousand, not RM4.
  if (value > 0 && value < 100) value *= 1000;
  return Math.round(value);
}

function parseBuildRequest(message) {
  let text = " " + message.toLowerCase() + " ";
  const request = { budget: null, resolution: null, workload: null, wantsBuild: false };

  // --- budget first, so that "bajet 4k" is not mistaken for 4K resolution ---
  // Look for a money word (budget / bajet / rm / under / around ...) followed
  // by a number, then cut that phrase out of the sentence.
  const budgetPattern =
    /(budget|bajet|belanjawan|bajet|rm|myr|ringgit|under|below|around|about|max|maximum|spend|price|harga)\s*:?\s*(?:rm|myr)?\s*(\d[\d,]*(?:\.\d+)?)\s*(k|ribu)?/i;
  const budgetMatch = text.match(budgetPattern);
  if (budgetMatch) {
    request.budget = toRinggit(budgetMatch[2], budgetMatch[3]);
    text = text.replace(budgetMatch[0], " "); // remove so it can't be read as a resolution
  }

  // --- resolution, from whatever is left ---
  if (/\b(1080p?|full\s*hd|fhd)\b/.test(text)) request.resolution = "1080p";
  else if (/\b(1440p|qhd|2\s*k)\b/.test(text)) request.resolution = "1440p";
  else if (/\b(2160p|uhd|4\s*k)\b/.test(text)) request.resolution = "4K";

  // --- if we still have no budget, accept a bare "4k" or a bare number ---
  if (request.budget === null) {
    const bare = text.match(/\b(\d[\d,]*(?:\.\d+)?)\s*(k|ribu)?\b/);
    if (bare) {
      const value = toRinggit(bare[1], bare[2]);
      // Only believe it if it looks like money, not a resolution or a year.
      if (value !== null && value >= 1000 && value <= 60000) request.budget = value;
    }
  }

  // --- what is the PC for ---
  for (const workload in WORKLOAD_KEYWORDS) {
    if (WORKLOAD_KEYWORDS[workload].some((word) => text.includes(word))) {
      request.workload = workload;
      break;
    }
  }

  // --- is the customer actually asking us to build something ---
  const buildWords = /(build|recommend|recomend|suggest|spec|rig|setup|assemble|put together|what should i|which pc|cadang)/;
  const pcWords = /(pc|computer|desktop|rig|system|build)/;
  request.wantsBuild =
    (request.budget !== null && pcWords.test(text)) ||
    (buildWords.test(text) && pcWords.test(text)) ||
    (request.workload !== null && request.budget !== null);

  return request;
}

// ------------------------------------------------------------
// STEP 2 — decide what the build needs to be good at
// ------------------------------------------------------------
// minGpu = the weakest card we're willing to put in this kind of build, so a
// CPU-heavy score can't end up pairing an expensive processor with an
// ancient graphics card. maxRamGB stops a gaming build swallowing the
// leftover budget on memory it will never use.
function targetsFor(request) {
  const resolution = request.resolution || "1080p";
  const workload = request.workload || "gaming";

  if (workload === "office") {
    return { cpuKey: "gaming", cpuWeight: 1, gpuWeight: 0.3, targetGpu: 45, minGpu: 0,
             maxRamGB: 16, label: "office and study work" };
  }
  if (workload === "creator") {
    return { cpuKey: "multi", cpuWeight: 2, gpuWeight: 1, targetGpu: 55, minGpu: 38,
             maxRamGB: 64, label: "video editing and content creation" };
  }
  if (workload === "esports") {
    // Games like CS2 depend far more on the CPU than the graphics card.
    if (resolution === "4K") return { cpuKey: "gaming", cpuWeight: 1.5, gpuWeight: 2, targetGpu: 90, minGpu: 72, maxRamGB: 32, label: "esports at 4K" };
    if (resolution === "1440p") return { cpuKey: "gaming", cpuWeight: 2, gpuWeight: 1.2, targetGpu: 60, minGpu: 48, maxRamGB: 32, label: "esports at 1440p" };
    return { cpuKey: "gaming", cpuWeight: 2.5, gpuWeight: 1, targetGpu: 45, minGpu: 30, maxRamGB: 32, label: "esports at 1080p" };
  }
  // General / AAA gaming — the graphics card matters more as resolution goes up.
  if (resolution === "4K") return { cpuKey: "gaming", cpuWeight: 0.8, gpuWeight: 2.5, targetGpu: 90, minGpu: 72, maxRamGB: 32, label: "gaming at 4K" };
  if (resolution === "1440p") return { cpuKey: "gaming", cpuWeight: 1, gpuWeight: 2, targetGpu: 75, minGpu: 48, maxRamGB: 32, label: "gaming at 1440p" };
  return { cpuKey: "gaming", cpuWeight: 1.2, gpuWeight: 1.5, targetGpu: 55, minGpu: 38, maxRamGB: 32, label: "gaming at 1080p" };
}

// "32GB" -> 32, so we can compare kit sizes.
function capacityGB(product) {
  const match = String(product.attrs.capacity || "").match(/(\d+)/);
  return match ? Number(match[1]) : 0;
}

// ------------------------------------------------------------
// STEP 3 — build a complete, compatible PC around a chosen CPU + GPU
// ------------------------------------------------------------
function inStock(list) {
  return list.filter((p) => p.stock !== "out");
}

// In stock AND allowed in a desktop build — this drops laptop memory,
// DDR3 repair sticks, surveillance hard disks and the legacy boards.
function buildable(list) {
  return inStock(list).filter((p) => !p.excludeFromBuilder);
}

function cheapest(list) {
  if (list.length === 0) return null;
  return list.slice().sort((a, b) => a.price - b.price)[0];
}

// Picks the cheapest part for every remaining slot that is compatible with
// the CPU and GPU we're testing. Returns null if any slot can't be filled.
function assembleBuild(cpu, gpu) {
  // Cooler: must fit the socket AND handle the CPU's heat.
  const cooler = cheapest(inStock(getProductsBySubcategory("Cooler")).filter((c) =>
    (c.attrs.sockets || []).includes(cpu.attrs.socket) &&
    (c.attrs.coolerRating || 0) >= (cpu.attrs.tdp || 0)));
  if (!cooler) return null;

  // Motherboard: same socket, and never the legacy/repair-only boards.
  const mobo = cheapest(inStock(getProductsBySubcategory("Motherboard"))
    .filter((m) => !m.excludeFromBuilder && m.attrs.socket === cpu.attrs.socket));
  if (!mobo) return null;

  // RAM: right generation for the board, not repair-only stock, and not a
  // kit we've found doesn't work with this processor.
  const ram = cheapest(buildable(getProductsBySubcategory("RAM")).filter((r) =>
    ramGenFits(r.attrs.ramGen, mobo.attrs.ramGen) &&
    (r.attrs.incompatibleSockets || []).indexOf(cpu.attrs.socket) === -1));
  if (!ram) return null;

  // Storage: skip the surveillance drives, they're for DVR/NVR duty.
  const storage = cheapest(buildable(getProductsBySubcategory("Storage")));
  if (!storage) return null;

  // PSU: at least what the graphics card's maker recommends, and the
  // build's draw plus 25% spare -- psuNeedFor(), the same rule the PC
  // Builder checks. Running a supply flat out is noisy, shortens its life
  // and trips on a modern card's power spikes, so there is no settling
  // for less: no supply that big in stock means no build.
  const wattsWanted = psuNeedFor(cpu, gpu).needed;
  // The RTX 50 cards expect a native 12VHPWR lead, so don't pair them with
  // the one supply that hasn't got one.
  const needsHpwr = (gpu.attrs.chip || "").indexOf("RTX 5") === 0;
  const psus = buildable(getProductsBySubcategory("PSU"))
    .filter((p) => !needsHpwr || p.attrs.connector12VHPWR !== "No");
  const psu = cheapest(psus.filter((p) => p.attrs.wattage >= wattsWanted));
  if (!psu) return null;

  // Case: must fit the board size, be long enough for the graphics card, and
  // support back-connector wiring if the board needs it.
  const pcCase = cheapest(inStock(getProductsBySubcategory("Case")).filter((c) =>
    (c.attrs.supportedFormFactors || []).includes(mobo.attrs.formFactor) &&
    (c.attrs.maxGpuLength || 0) >= (gpu.attrs.length || 0) &&
    (mobo.attrs.backConnector !== "Yes" || c.attrs.supportsBackConnector === "Yes")));
  if (!pcCase) return null;

  const parts = { CPU: cpu, Cooler: cooler, Motherboard: mobo, RAM: ram,
                  GPU: gpu, Storage: storage, PSU: psu, Case: pcCase };
  return { parts: parts, total: totalOf(parts), wattsNeeded: wattsWanted };
}

function totalOf(parts) {
  return builderSlots.reduce((sum, slot) => sum + (parts[slot] ? parts[slot].price : 0), 0);
}

// Any money left over gets spent on sensible upgrades: a roomier drive
// first, then a bigger memory kit. We take the best option that still fits
// the budget rather than a fixed product, so this keeps working as stock
// changes.
function spendLeftover(build, budget, target) {
  const cpu = build.parts.CPU;
  const mobo = build.parts.Motherboard;
  const maxRamGB = (target && target.maxRamGB) || 32;

  // Best (dearest) drive we can still afford — SSDs only, no hard disks.
  const drives = buildable(getProductsBySubcategory("Storage"))
    .filter((d) => d.attrs.driveType === "SSD")
    .sort((a, b) => b.price - a.price);

  // Best memory kit that suits this board and processor.
  const kits = buildable(getProductsBySubcategory("RAM"))
    .filter((r) => ramGenFits(r.attrs.ramGen, mobo.attrs.ramGen) &&
                   (r.attrs.incompatibleSockets || []).indexOf(cpu.attrs.socket) === -1 &&
                   capacityGB(r) <= maxRamGB)
    .sort((a, b) => b.price - a.price);

  [{ slot: "Storage", options: drives }, { slot: "RAM", options: kits }].forEach((upgrade) => {
    const current = build.parts[upgrade.slot];
    for (const better of upgrade.options) {
      if (better.price <= current.price) break;         // list is dearest-first
      const newTotal = build.total - current.price + better.price;
      if (newTotal <= budget) {
        build.parts[upgrade.slot] = better;
        build.total = newTotal;
        break;
      }
    }
  });

  return build;
}

// ------------------------------------------------------------
// STEP 4 — try every CPU + GPU pair and keep the best one
// ------------------------------------------------------------
function recommendBuild(request) {
  const budget = request.budget;
  const target = targetsFor(request);

  const cpus = inStock(getProductsBySubcategory("CPU"));

  // The GT 710 / 730 / 1030 are display-output cards for repair and office
  // machines, not gaming parts, so we keep them out of gaming builds.
  const DISPLAY_ONLY = ["GT 710", "GT 730", "GT 1030"];
  const allGpus = inStock(getProductsBySubcategory("GPU")).filter((g) =>
    (request.workload === "office") || DISPLAY_ONLY.indexOf(g.attrs.chip) === -1);

  // Prefer cards that actually suit the job. If the budget can't reach that,
  // fall back to the full list so we still give an answer.
  const goodEnough = allGpus.filter((g) => perfOf(g, "gpu") >= (target.minGpu || 0));
  const gpus = goodEnough.length > 0 ? goodEnough : allGpus;

  let best = null;
  let cheapestPossible = null;

  cpus.forEach((cpu) => {
    gpus.forEach((gpu) => {
      const build = assembleBuild(cpu, gpu);
      if (!build) return;

      if (!cheapestPossible || build.total < cheapestPossible.total) cheapestPossible = build;
      if (budget !== null && build.total > budget) return; // can't afford this one

      // A graphics card far above what the resolution needs is wasted money,
      // so we stop counting extra power past the target.
      const usefulGpu = Math.min(perfOf(gpu, "gpu"), target.targetGpu + 10);
      const score = perfOf(cpu, target.cpuKey) * target.cpuWeight + usefulGpu * target.gpuWeight;

      if (!best || score > best.score + 0.001 ||
         (Math.abs(score - best.score) < 0.001 && build.total < best.total)) {
        best = { parts: build.parts, total: build.total, wattsNeeded: build.wattsNeeded, score: score };
      }
    });
  });

  if (!best) return { ok: false, cheapest: cheapestPossible, target: target };

  if (budget !== null) spendLeftover(best, budget, target);
  best.ok = true;
  best.target = target;
  return best;
}

// ------------------------------------------------------------
// STEP 5 — double-check the finished build, then write the answer
// ------------------------------------------------------------
// Re-runs the compatibility rules on the finished build. This is a safety
// net so we can never recommend something that wouldn't actually work.
function verifyBuild(parts) {
  const problems = [];
  const cpu = parts.CPU, cooler = parts.Cooler, mobo = parts.Motherboard;
  const ram = parts.RAM, gpu = parts.GPU, psu = parts.PSU, pcCase = parts.Case;

  if (cpu.attrs.socket !== mobo.attrs.socket) problems.push("socket mismatch");
  if (ram.attrs.ramGen !== mobo.attrs.ramGen) problems.push("RAM type mismatch");
  if (!(cooler.attrs.sockets || []).includes(cpu.attrs.socket)) problems.push("cooler won't mount");
  if ((cooler.attrs.coolerRating || 0) < (cpu.attrs.tdp || 0)) problems.push("cooler too weak");
  if (!(pcCase.attrs.supportedFormFactors || []).includes(mobo.attrs.formFactor)) problems.push("board won't fit case");
  if ((gpu.attrs.length || 0) > (pcCase.attrs.maxGpuLength || 0)) problems.push("graphics card too long");
  if (psu.attrs.wattage < psuNeedFor(cpu, gpu).needed) problems.push("PSU too small");

  return problems;
}

function moneyText(amount) {
  return "RM " + amount.toFixed(2);
}

// Builds the HTML answer shown in the chat window.
function formatBuildReply(request, result) {
  const target = result.target;

  if (!result.ok) {
    const need = result.cheapest ? result.cheapest.total : 0;
    return `Sorry — I can't put a complete PC together for ${moneyText(request.budget)}. ` +
      `The cheapest full build I can make from what's in stock is <strong>${moneyText(need)}</strong>. ` +
      `If you can stretch to that I'll spec it out for you.`;
  }

  const parts = result.parts;
  const problems = verifyBuild(parts);

  let html = `Here's my recommendation for <strong>${escapeHtml(target.label)}</strong>`;
  if (request.budget !== null) html += ` with a <strong>${moneyText(request.budget)}</strong> budget`;
  html += `:<br><br>`;

  html += `<table class="chat-build">`;
  builderSlots.forEach((slot) => {
    const p = parts[slot];
    html += `<tr><td>${escapeHtml(slot)}</td><td>${escapeHtml(p.name)}</td><td>${moneyText(p.price)}</td></tr>`;
  });
  html += `<tr class="chat-build-total"><td>Total</td><td></td><td>${moneyText(result.total)}</td></tr>`;
  html += `</table>`;

  if (request.budget !== null) {
    const left = request.budget - result.total;
    html += `<br>That leaves <strong>${moneyText(left)}</strong> of your budget.`;

    // If there's a decent amount left, suggest what else they could add.
    // (We've already bought the best parts we stock for this job.)
    const extras = suggestExtras(left, request);
    if (extras.length > 0) {
      html += ` With that you could add: ${extras.join(", ")}.`;
    }
  }

  html += `<br><br><strong>Why these parts:</strong> ${whyText(request, parts)}`;

  html += problems.length === 0
    ? `<br><br>All 7 compatibility checks passed.`
    : `<br><br>Please double-check: ${problems.join(", ")}.`;

  const ids = builderSlots.map((slot) => parts[slot].id).join(",");
  html += `<br><br><button class="chat-load-btn" onclick="loadRecommendedBuild('${ids}')">Open this build in the PC Builder</button>`;

  return html;
}

// Once the tower itself is as good as we can make it, any money still left
// is better spent on a monitor and peripherals than on parts we don't stock.
function suggestExtras(moneyLeft, request) {
  const wanted = [];
  if (moneyLeft < 150) return wanted;

  // Pick a monitor that suits the resolution they asked for.
  const resolution = request.resolution || "1080p";
  const monitors = inStock(products.filter((p) => p.category === "Monitors"));
  const preferred = resolution === "4K" ? '32"' : resolution === "1440p" ? '27"' : '24"';
  const monitor = cheapest(monitors.filter((m) => m.attrs.screenSize === preferred)) || cheapest(monitors);

  let remaining = moneyLeft;
  if (monitor && monitor.price <= remaining) {
    wanted.push(`a ${escapeHtml(monitor.name)} (${moneyText(monitor.price)})`);
    remaining -= monitor.price;
  }

  // Then keyboard / mouse / headset, cheapest first, while the money lasts.
  inStock(products.filter((p) => p.category === "Gaming Gear"))
    .sort((a, b) => a.price - b.price)
    .forEach((gear) => {
      if (gear.price <= remaining && wanted.length < 4) {
        wanted.push(`a ${escapeHtml(gear.name)} (${moneyText(gear.price)})`);
        remaining -= gear.price;
      }
    });

  return wanted;
}

// A short plain-English explanation of the choices.
function whyText(request, parts) {
  const workload = request.workload || "gaming";
  const resolution = request.resolution || "1080p";
  const cpu = parts.CPU, gpu = parts.GPU, cooler = parts.Cooler, psu = parts.PSU;

  let why = "";
  if (workload === "esports") {
    why += `Games like CS2 depend far more on the processor than the graphics card, so most of the money went into the ${escapeHtml(cpu.name)}. `;
    why += `At ${escapeHtml(resolution)} the ${escapeHtml(gpu.name)} already pushes high frame rates, so spending more on the GPU wouldn't help much. `;
  } else if (workload === "creator") {
    why += `Editing and rendering use all the CPU cores, so the ${escapeHtml(cpu.name)} does the heavy lifting here, backed by the ${escapeHtml(gpu.name)} for preview and export. `;
  } else if (workload === "office") {
    why += `Office and study work needs very little power, so this build keeps costs down while staying quick and quiet. `;
  } else {
    why += `At ${escapeHtml(resolution)} the graphics card does most of the work, so the ${escapeHtml(gpu.name)} takes the biggest share of the budget, paired with the ${escapeHtml(cpu.name)} so nothing is held back. `;
  }

  why += `The ${escapeHtml(cooler.name)} is rated for ${escapeHtml(cooler.attrs.coolerRating)}W and the ${escapeHtml(cpu.name)} needs ${escapeHtml(cpu.attrs.tdp)}W, so it stays cool. `;
  const power = psuNeedFor(cpu, gpu);
  why += power.byCard
    ? `The ${psu.attrs.wattage}W supply meets the ${power.needed}W we recommend for a full rig with the ${escapeHtml(gpu.name)}.`
    : `The build draws roughly ${power.draw}W, so the ${psu.attrs.wattage}W supply leaves room to spare.`;
  return why;
}

// Loads a recommended build into the PC Builder page.
function loadRecommendedBuild(idList) {
  const ids = idList.split(",").map(Number);
  const build = {};
  builderSlots.forEach((slot, index) => { build[slot] = ids[index]; });
  localStorage.setItem("currentBuild", JSON.stringify(build));
  window.location.href = "build.html";
}

// The single entry point the chatbot calls.
function tryAnswerBuildRequest(message) {
  const request = parseBuildRequest(message);
  if (!request.wantsBuild) return null;

  // No budget given — ask for one rather than guessing.
  if (request.budget === null) {
    return "Happy to spec that out! What's your budget in RM? " +
      "For example: <em>\"build a pc for CS2, full HD, budget 4k\"</em>.";
  }

  const result = recommendBuild(request);
  return formatBuildReply(request, result);
}
