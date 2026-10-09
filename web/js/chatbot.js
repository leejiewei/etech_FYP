// "AI Hardware Consultant" chatbot.
//
// For the viva: this is NOT a real NLP/AI model — there is no internet or
// AI service involved. It works in two parts:
//   1. advisor.js  — reads the budget, resolution and game out of the
//      sentence, then searches every CPU + GPU combination we sell and
//      returns the best complete build that fits the budget and passes all
//      the compatibility checks.
//   2. this file   — answers general questions (sockets, RAM, cooling,
//      case sizes) by looking them up in the product data.
// Either way the answers come from real product data, so they are always
// technically correct rather than guessed.

function answerQuestion(message) {
  const text = message.toLowerCase();

  // First see if the customer is asking us to recommend a whole PC,
  // e.g. "build a pc for cs2 full hd bajet 4k". advisor.js handles that.
  if (typeof tryAnswerBuildRequest === "function") {
    const buildReply = tryAnswerBuildRequest(message);
    if (buildReply) return buildReply;
  }

  const sockets = ["am4", "am5", "lga1700"];
  for (const socket of sockets) {
    if (text.includes(socket)) {
      const socketLabel = socket.toUpperCase();
      const cpus = products.filter((p) => p.subcategory === "CPU" && p.attrs.socket === socketLabel);
      const boards = products.filter((p) => p.subcategory === "Motherboard" && p.attrs.socket === socketLabel);
      const ramGen = boards[0] ? boards[0].attrs.ramGen : "?";
      // These land in a chat bubble through innerHTML, and every name in
      // them comes out of the catalogue -- see js/escape.js.
      return `${escapeHtml(socketLabel)} boards use ${escapeHtml(ramGen)} memory. ` +
        `CPUs available: ${escapeHtml(cpus.map((c) => c.name).join(", ")) || "none in stock"}. ` +
        `Motherboards available: ${escapeHtml(boards.map((b) => b.name).join(", ")) || "none in stock"}.`;
    }
  }

  if (text.includes("ddr4") || text.includes("ddr5")) {
    const ramGen = text.includes("ddr5") ? "DDR5" : "DDR4";
    const ramSticks = products.filter((p) => p.subcategory === "RAM" && p.attrs.ramGen === ramGen);
    return `${escapeHtml(ramGen)} RAM kits we carry: ${escapeHtml(ramSticks.map((r) => r.name).join(", ")) || "none right now"}.`;
  }

  if (text.includes("psu") || text.includes("power supply") || text.includes("wattage")) {
    return "We add up your CPU wattage + graphics card wattage + about " + OTHER_PARTS_WATTAGE +
      "W for the board, drives and fans, add a quarter on top for headroom, and never go below " +
      "what the graphics card's maker recommends -- an RTX 5070 Ti or 5080 needs at least 850W. " +
      "The PC Builder does this for you and shows the figure.";
  }

  // Getting this wrong destroys hardware, so it's checked before anything else.
  if (text.includes("argb") || text.includes("rgb") || text.includes("lighting") ||
      text.includes("led strip") || text.includes("light strip")) {
    return "<strong>Careful with this one.</strong> Everything we stock is " +
      "<strong>3-pin 5V ARGB</strong> (addressable). That is NOT the same as " +
      "<strong>4-pin 12V RGB</strong>, and the two are not interchangeable — " +
      "plugging a 5V ARGB device into a 12V RGB header will destroy it. " +
      "The plugs look similar, so check the header on your motherboard is marked " +
      "5V / ARGB / A-RGB before connecting anything. If your board only has 12V RGB " +
      "headers, use one of our ARGB controllers, which run from the power supply instead.";
  }

  if (text.includes("reverse") && (text.includes("fan") || text.includes("blade"))) {
    return "Reverse-blade fans push air the opposite way to a normal fan. They're for " +
      "builds where the fan is mounted the 'wrong' way round and you still want the airflow " +
      "going in the right direction — dual-chamber cases, or something like the Lian Li " +
      "PC-O11 Vision Compact. We stock four: the Slev ASQ Vortex Reverse (white and black), " +
      "the Slev ASQ Spectra S Reverse, and the Asus MR120 Reverse.";
  }

  if (text.includes("aio") || text.includes("liquid") || text.includes("water cool") ||
      text.includes("radiator")) {
    return "We carry 13 all-in-one liquid coolers — eight with a 360mm radiator (rated to " +
      "about 300W) and five with 240mm (about 250W). Eight of them have an LCD screen on the " +
      "pump. All of them mount on AM4, AM5, LGA1700 and LGA1851. Air coolers are the cheaper " +
      "option and go up to about 260W with the Deepcool AG620 Digital. Tell me your CPU and " +
      "I'll say what's enough.";
  }

  if (text.includes("cooler") || text.includes("cooling") || text.includes("overheat") ||
      text.includes("thermal") || text.includes("stock")) {
    return "Every CPU has a cooling requirement in watts, and every cooler has a capacity. " +
      "A stock cooler only handles about 65W, so it's fine for a Ryzen 5 5600X or Core i5-12400F, " +
      "but a Core i7-14700K needs 220W — that would overheat and throttle. For high-end Intel chips " +
      "use a dual tower air cooler or a 240mm/360mm AIO. The PC Builder warns you if the cooler is too weak.";
  }

  if (text.includes("case") || text.includes("casing") || text.includes("atx") ||
      text.includes("form factor") || text.includes("size")) {
    return "Board sizes go ATX (biggest), mATX, then Mini-ITX (smallest). A case fits its own size and " +
      "anything smaller — so an ATX case takes ATX/mATX/ITX, but an mATX case will NOT fit a full ATX board. " +
      "Cases also have a maximum graphics card length, so a long card may not fit a small case. " +
      "The PC Builder checks both.";
  }

  if (text.includes("compatib")) {
    return "The PC Builder runs 7 checks: 1) CPU socket matches the motherboard, 2) RAM type (DDR4/DDR5) " +
      "matches the board, 3) the cooler mounts on that socket, 4) the cooler is strong enough for the CPU's heat, " +
      "5) the motherboard physically fits the case, 6) the graphics card is short enough for the case, and " +
      "7) the PSU covers the whole system's wattage. It won't let you add an incompatible build to the cart.";
  }

  if (text.includes("budget") || text.includes("cheap") || text.includes("student")) {
    return "For a budget build, the AMD Ryzen 5 5600 or Ryzen 5 5600GT on an AM4 board is the cheapest way in. " +
      "Note the Ryzen 5 5600 has no built-in graphics, so it needs a graphics card — the 5600GT does have one. " +
      "Give me a budget figure and I'll put a full build together.";
  }

  if (text.includes("gaming")) {
    return "For gaming, the AMD Ryzen 7 9800X3D or Ryzen 7 7800X3D paired with an RTX 5070 / RTX 5070 Ti " +
      "is a strong combo. Tell me your budget and I'll spec the whole build instead of guessing.";
  }

  if (text.includes("hi") || text.includes("hello")) {
    return "Hi! Tell me what you want the PC for and your budget — for example " +
      "<em>\"build a pc for CS2, full HD, budget 4k\"</em> — and I'll spec the whole thing out. " +
      "I can also answer questions on sockets, RAM, cooling and case sizes.";
  }

  return "Tell me what the PC is for and your budget and I'll build you a full spec, e.g. " +
    "<em>\"gaming pc for 1440p, budget 6000\"</em> or <em>\"video editing pc rm 8000\"</em>.<br><br>" +
    "I can also answer questions about socket compatibility (AM4/AM5/LGA1700), RAM type (DDR4/DDR5), " +
    "cooling, case sizes and PSU wattage.";
}

// ------------------------------------------------------------
// Asking Gemini.
//
// The question goes to the chat-advisor Edge Function, which holds the
// Gemini key, hands the model our catalogue and makes it answer in a
// fixed shape: { reply, product_ids, is_build_request }.
//
// The key is not here, and cannot be. Row Level Security is what makes
// the Supabase publishable key safe to ship in this file; Gemini has no
// equivalent, so a key in here would be a key anyone could lift out of
// DevTools and spend. See supabase/functions/chat-advisor/index.ts.
//
// Gemini picks the products; it does not price them. We render each id
// from the catalogue this page already loaded, so the customer always
// sees our price and our stock rather than a number a model wrote.
// ------------------------------------------------------------
const chatHistory = [];   // the last few turns, for follow-up questions

function askGemini(message) {
  if (typeof sb === "undefined" || !sb.functions) return Promise.resolve(null);

  return sb.functions
    .invoke("chat-advisor", { body: { message, history: chatHistory.slice(-6) } })
    .then(({ data, error }) => {
      if (error || !data || !data.reply) {
        // Not shown to the customer: they get the built-in answer instead,
        // which is a worse answer but still a correct one.
        console.warn("AI consultant unavailable, using built-in answers.", error || data);
        return null;
      }
      return data;
    })
    .catch((error) => {
      console.warn("AI consultant unreachable, using built-in answers.", error);
      return null;
    });
}

// A recommended product, drawn from our own data. Only the id came from
// the model.
function recommendationCard(product) {
  const outOfStock = product.stock === "out";
  return `
    <div class="chat-rec" onclick="openProductModal(${product.id})">
      ${productImageTag(product, "chat-rec-img")}
      <div class="chat-rec-body">
        <span class="chat-rec-name">${escapeHtml(product.name)}</span>
        <span class="chat-rec-meta">${escapeHtml(product.subcategory || product.category)} ·
          <span class="stock-${product.stock}">${stockLabel(product.stock)}</span></span>
        <span class="chat-rec-price">${money(product.price)}</span>
      </div>
      <button class="add-btn chat-rec-add" ${outOfStock ? "disabled" : ""}
        onclick="event.stopPropagation(); addToCart(${product.id})">
        ${outOfStock ? "Out of Stock" : "Add"}
      </button>
    </div>`;
}

function renderRecommendations(ids) {
  if (!Array.isArray(ids) || !ids.length) return "";

  // An id the model made up, or one for a product since withdrawn, simply
  // does not appear. It is never rendered as a broken card.
  const found = ids.map((id) => getProductById(id)).filter(Boolean);
  if (!found.length) return "";

  const total = found.reduce((sum, p) => sum + p.price, 0);
  const totalLine = found.length > 1
    ? `<p class="chat-rec-total">Total: ${money(total)}</p>` : "";

  return `<div class="chat-recs">${found.map(recommendationCard).join("")}${totalLine}</div>`;
}

function sendChatMessage() {
  const input = document.getElementById("chat-input");
  const message = input.value.trim();
  if (message === "") return;

  appendChatBubble(message, "user");
  input.value = "";

  const thinking = appendChatBubble("<em>Thinking…</em>", "bot");

  askGemini(message).then((answer) => {
    let reply;
    let wasBuildRequest;

    if (answer) {
      // escapeHtml because the model's prose is text, not markup, and it
      // is going into the page with innerHTML alongside the cards we build.
      reply = escapeHtml(answer.reply).replace(/\n/g, "<br>") +
              renderRecommendations(answer.product_ids);
      wasBuildRequest = answer.is_build_request;
    } else {
      // Gemini is off, out of quota or unreachable. The keyword answers
      // and the build recommender below still work, so the chatbot
      // degrades rather than dying.
      reply = answerQuestion(message);
      wasBuildRequest = typeof parseBuildRequest === "function" &&
        parseBuildRequest(message).wantsBuild;
    }

    if (thinking) thinking.innerHTML = reply;
    const log = document.getElementById("chat-log");
    if (log) log.scrollTop = log.scrollHeight;

    chatHistory.push({ role: "user", text: message });
    chatHistory.push({ role: "bot", text: stripFormatting(reply) });

    logChat(message, reply, wasBuildRequest);
  });
}

// escapeHtml used to be defined here, as a local copy. It now lives in
// js/escape.js so the shop front has one answer to "how does text get
// into the page" rather than one per file. Same behaviour.

function logChat(message, reply, wasBuildRequest) {

  // The reply contains formatting — build tables, buttons — which the
  // admin panel has no use for and would have to escape. api/track.php
  // ran it through strip_tags() before storing it; this is the same
  // idea, done by letting the browser parse the HTML and handing back
  // only the text inside it.
  //
  // Insert only, like the view events: the policy on chatbot_logs lets
  // anyone add a line and only staff read them back.
  const user = getCurrentUser();
  sb.from("chatbot_logs").insert({
    customer_id:       user ? user.id : null,
    anon_id:           typeof getAnonId === "function" ? getAnonId() : null,
    source:            "web",
    question:          message,
    answer:            stripFormatting(reply),
    was_build_request: wasBuildRequest ? 1 : 0,
  }).then(({ error }) => {
    // Logging must never break the chat.
    if (error) console.error("Logging the conversation:", error);
  });
}

function stripFormatting(html) {
  const holder = document.createElement("div");
  holder.innerHTML = html;
  return (holder.textContent || "").trim();
}

function appendChatBubble(text, who) {
  const log = document.getElementById("chat-log");
  if (!log) return;
  const bubble = document.createElement("div");
  bubble.className = "chat-bubble " + who;

  // Our own replies contain formatting (build tables, buttons) so they go in
  // as HTML. Whatever the customer typed goes in as plain text, so their
  // message can never inject HTML into the page.
  if (who === "bot") {
    bubble.innerHTML = text;
  } else {
    bubble.textContent = text;
  }

  log.appendChild(bubble);
  log.scrollTop = log.scrollHeight;

  // Handed back so the caller can replace a placeholder in place -- the
  // "Thinking…" bubble becomes the answer rather than sitting above it.
  return bubble;
}
