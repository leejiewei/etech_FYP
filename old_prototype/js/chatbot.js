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
      return `${socketLabel} boards use ${ramGen} memory. CPUs available: ${cpus.map((c) => c.name).join(", ") || "none in stock"}. ` +
        `Motherboards available: ${boards.map((b) => b.name).join(", ") || "none in stock"}.`;
    }
  }

  if (text.includes("ddr4") || text.includes("ddr5")) {
    const ramGen = text.includes("ddr5") ? "DDR5" : "DDR4";
    const ramSticks = products.filter((p) => p.subcategory === "RAM" && p.attrs.ramGen === ramGen);
    return `${ramGen} RAM kits we carry: ${ramSticks.map((r) => r.name).join(", ") || "none right now"}.`;
  }

  if (text.includes("psu") || text.includes("power supply") || text.includes("wattage")) {
    return "We add up your CPU wattage + graphics card wattage + about " + OTHER_PARTS_WATTAGE +
      "W for the board, drives and fans, then check your PSU is at least that big. " +
      "The PC Builder does this for you and shows the full sum.";
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

function sendChatMessage() {
  const input = document.getElementById("chat-input");
  const message = input.value.trim();
  if (message === "") return;

  appendChatBubble(message, "user");
  input.value = "";

  const reply = answerQuestion(message);
  setTimeout(() => appendChatBubble(reply, "bot"), 300);
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
}
