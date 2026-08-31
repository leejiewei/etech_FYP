// The shop's AI hardware consultant.
//
// The chatbot used to be keyword matching: a chain of `if
// (text.includes("ddr5"))` in web/js/chatbot.js, with a build recommender
// in advisor.js that searched every CPU and GPU pair we sell. That is
// still there and still runs -- see the fallback note at the bottom --
// but it could only answer the questions somebody had thought to write a
// branch for. This function sends the question to Gemini instead.
//
// WHY THIS RUNS ON THE SERVER
//
// The Gemini key bills to our account and, unlike the Supabase
// publishable key, nothing on the other side constrains what a holder can
// do with it. Row Level Security makes the publishable key safe to ship
// inside the website and the app; there is no equivalent for Gemini. A
// key in web/js/ is readable by anyone who opens DevTools, so it lives
// here as a secret and the browser never sees it.
//
// WHY THE MODEL DOES NOT WRITE PRICES
//
// Gemini chooses which products to recommend and returns their ids. It
// does not return prices, stock or names, and the clients do not read any
// it might mention: they look each id up in the catalogue they already
// hold and render the real card. A language model inventing "RM 2,899"
// for a machine we sell at RM 3,599 would be a shop quoting a price it
// will not honour, so the design removes the possibility rather than
// asking the model nicely.

const GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models";
const MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";
// Tried when the main model is at capacity. Lighter, quicker, and much
// less often full.
const FALLBACK_MODEL = Deno.env.get("GEMINI_FALLBACK_MODEL") ?? "gemini-2.5-flash-lite";

// A line break, written this way so the value survives every layer of
// quoting between here and the deployed function.
const NEWLINE = String.fromCharCode(10);

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

// ------------------------------------------------------------
// Authorisation.
//
// verify_jwt is off, and it has to be: this project uses the new
// sb_publishable_... key, which is not a JWT, and the platform's built-in
// check only understands the legacy JWT keys. So the check happens here.
//
// What this actually buys us is modest, and worth being honest about: the
// publishable key ships inside the website, so anyone determined can read
// it out and call this function directly. It stops the function being
// dialled by anything that has not at least looked at our site. The real
// protection against a runaway Gemini bill is a spending cap set on the
// Google side.
// ------------------------------------------------------------
function isAuthorised(req: Request): boolean {
  const presented = req.headers.get("apikey") ??
    (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!presented) return false;

  const accept: string[] = [];
  for (const name of ["SUPABASE_PUBLISHABLE_KEYS", "SUPABASE_SECRET_KEYS"]) {
    try {
      const raw = Deno.env.get(name);
      if (raw) accept.push(...Object.values(JSON.parse(raw) as Record<string, string>));
    } catch { /* malformed env, treated as no keys of that kind */ }
  }
  // The legacy keys still work alongside the new ones.
  for (const name of ["SUPABASE_ANON_KEY", "SUPABASE_SERVICE_ROLE_KEY"]) {
    const value = Deno.env.get(name);
    if (value) accept.push(value);
  }

  return accept.includes(presented);
}

// ------------------------------------------------------------
// The catalogue, as the model sees it.
//
// One line per product: id, name, type, brand, price, stock. Names in
// this shop are unusually descriptive -- "E-Tech ZenForge Ryzen 5 5500
// RTX 3050" already states the processor and the graphics card -- so the
// specifications table is left out. It is the largest table we have, over
// two thousand rows, and including it would cost far more than it adds.
//
// Stock is included because it changes the advice. Nineteen of the
// desktops are on the record's outstanding list and a consultant who
// recommends one without saying so is wasting the customer's time.
// ------------------------------------------------------------
type Row = Record<string, unknown>;

let catalogueCache: { text: string; at: number } | null = null;
const CACHE_MS = 5 * 60 * 1000;

async function rest(path: string, key: string): Promise<Row[]> {
  const url = `${Deno.env.get("SUPABASE_URL")}/rest/v1/${path}`;
  const res = await fetch(url, { headers: { apikey: key, Authorization: `Bearer ${key}` } });
  if (!res.ok) throw new Error(`PostgREST ${res.status} on ${path}: ${await res.text()}`);
  return await res.json();
}

function readKey(): string {
  // Products are readable by anon -- the website reads them with this very
  // key -- so there is no reason to reach for a secret key here.
  try {
    const keys = JSON.parse(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS") ?? "{}");
    if (keys.default) return keys.default as string;
  } catch { /* fall through to the legacy key */ }
  return Deno.env.get("SUPABASE_ANON_KEY") ?? "";
}

async function catalogue(): Promise<string> {
  if (catalogueCache && Date.now() - catalogueCache.at < CACHE_MS) return catalogueCache.text;

  const key = readKey();
  const [products, brands, categories] = await Promise.all([
    rest("products?select=product_id,name,price,stock_status,brand_id,category_id&is_active=eq.1&order=product_id.asc&limit=1000", key),
    rest("brands?select=brand_id,name&limit=1000", key),
    rest("categories?select=category_id,name,parent_id&limit=1000", key),
  ]);

  const brandName = new Map(brands.map((b) => [b.brand_id, b.name]));
  const category = new Map(categories.map((c) => [c.category_id, c]));

  const text = products.map((p) => {
    const own = category.get(p.category_id) as Row | undefined;
    const type = own?.name ?? "Uncategorised";
    const stock = p.stock_status === "in" ? "in stock"
      : p.stock_status === "low" ? "low stock" : "OUT OF STOCK";
    return `${p.product_id}|${p.name}|${type}|${brandName.get(p.brand_id) ?? "-"}|RM${p.price}|${stock}`;
  }).join(NEWLINE);

  catalogueCache = { text, at: Date.now() };
  return text;
}

const SYSTEM = `You are the hardware consultant for eTech Computer Accessories, a computer shop in Malaysia.

You are given the shop's full catalogue, one product per line:
id|name|type|brand|price|stock

Rules, in order of importance:
1. Only ever recommend products from that list. Never invent a product, and never suggest something the shop does not sell. If nothing fits, say so plainly and say what is closest.
2. Put the id of every product you recommend in product_ids. The customer sees each one as a real product card underneath your reply, showing our name, our price and our stock.
2a. NEVER write a price, a ringgit figure or a total in your reply. Not for one product, not for the whole build. The card and the total beneath it are generated from our database and are the only figures the customer should read. Any price sentence you write will be deleted before the customer sees it, so writing one only makes your reply read oddly.
2b. If you name a product, copy its name exactly as it appears in the catalogue. Do not paraphrase a model number: recommending id 2011 and then calling it a "Ryzen 5 5600" when the catalogue says "AMD Ryzen 5 5500" is wrong and confusing.
3. STOCK. Before you mention any product, read the stock field on its catalogue line. If it says OUT OF STOCK you may still recommend it, but you must say that it is out of stock in the same breath. Never write anything that implies a product is available when its line says OUT OF STOCK -- no "you can consider", no "we have", no listing it among things the customer could buy today. If every product you are recommending is out of stock, say so plainly at the start.
4. Prices are Malaysian ringgit. When a customer gives a budget, stay inside it and say what the total comes to.
5. For a full PC build, pick a compatible set: CPU and motherboard must share a socket, the case must fit the motherboard, and the PSU must cover the parts. Recommend every part you would need.
6. Be brief and practical, like a shop assistant who knows the stock. Two or three short sentences, then the products. No markdown, no bullet lists, no headings.
7. If the question is not about computers or this shop, say politely that you can only help with the shop's products.

Set is_build_request to true only when the customer is asking you to spec a whole PC.`;

const SCHEMA = {
  type: "OBJECT",
  properties: {
    reply: { type: "STRING" },
    product_ids: { type: "ARRAY", items: { type: "INTEGER" } },
    is_build_request: { type: "BOOLEAN" },
  },
  required: ["reply", "product_ids", "is_build_request"],
};

// Removes any sentence in which the model talked about a price or about
// stock. Both are facts about our shop, and the model is not the source
// for either -- the cards, the total and stockNote() are.
//
// This is not caution for its own sake; both failures were observed on
// the first day. It reported a total of RM3982 for parts costing RM3792,
// and told a customer that two machines were in stock when all five it
// had picked were on the outstanding list. The ids it chose were right
// both times. So the ids are kept and the prose is filtered.
//
// A whole sentence goes rather than the offending words, because "the
// total comes to ." reads worse than silence -- and the real figure is
// already on screen directly below.
function stripUnreliable(reply: string, hasProducts: boolean): string {
  const unreliable = /RM\s?[\d,]+|\d+\s?(ringgit|MYR)|\b(in|out of)\s+stock\b|\bavailab\w*\b/i;

  const kept = reply
    .split(/(?<=[.!?])\s+/)
    .filter((sentence) => !unreliable.test(sentence));

  const cleaned = kept.join(" ").replace(/\s{2,}/g, " ").trim();
  if (cleaned) return cleaned;

  // Every sentence mentioned a price or stock. The cards carry the
  // substance, so a plain lead-in is better than an empty bubble.
  return hasProducts
    ? "Here is what I would suggest."
    : "I could not find anything that fits.";
}

// States the stock position, from our rows rather than the model's prose.
//
// Rule 3 tells the model to flag anything out of stock, and it does not
// reliably do it -- asked "do you sell a prebuilt gaming pc?" it answered
// that four were available and one was not, when in fact all five are on
// the record's outstanding list. Tightening the wording of the rule did
// not fix it, so the fact is stated here instead of being requested.
//
// When everything recommended is out of stock the note goes first, so the
// correction leads rather than trailing a sentence that implied otherwise.
function stockNote(ids: number[], catalogueText: string): string {
  if (!ids.length) return "";

  const byId = new Map<number, { name: string; stock: string }>();
  for (const line of catalogueText.split(NEWLINE)) {
    const part = line.split("|");
    const id = Number(part[0]);
    if (Number.isInteger(id) && part.length >= 6) {
      byId.set(id, { name: part[1], stock: part[5] });
    }
  }

  const rows = ids.map((id) => byId.get(id)).filter(Boolean) as
    { name: string; stock: string }[];
  if (!rows.length) return "";

  const out = rows.filter((r) => r.stock === "OUT OF STOCK");
  if (!out.length) return "";

  if (out.length === rows.length) {
    return rows.length === 1
      ? "Please note: this is currently out of stock."
      : "Please note: everything below is currently out of stock.";
  }

  const names = out.map((r) => r.name);
  const list = names.length === 1
    ? names[0]
    : `${names.slice(0, -1).join(", ")} and ${names[names.length - 1]}`;
  return `Please note: ${list} ${names.length === 1 ? "is" : "are"} currently out of stock.`;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);
  if (!isAuthorised(req)) return json({ error: "Not authorised." }, 401);

  // Secret names are case-sensitive, and the Dashboard's own form does
  // nothing to hint at that, so the lowercase spelling is accepted too.
  // Reading it under either name is free; a support round trip over a
  // capital letter is not.
  const apiKey = Deno.env.get("GEMINI_API_KEY") ?? Deno.env.get("gemini_api_key");
  if (!apiKey) {
    // The clients fall back to their built-in answers on any non-200, so
    // this reads as "the AI is not configured", not as a broken chatbot.
    //
    // The commonest reason for landing here is a secret saved under a
    // near-miss name -- GEMINI_KEY, GOOGLE_API_KEY, a trailing space. So
    // the reply names any secret that looks related, to tell "not saved
    // yet" apart from "saved as something else". Names only: a secret's
    // value is never put in a response.
    const looksRelated = Object.keys(Deno.env.toObject())
      .filter((name) => /gemini|google|genai|^ai_|_ai$|api_?key/i.test(name))
      .filter((name) => !name.startsWith("SUPABASE_"));

    return json({
      error: "GEMINI_API_KEY is not set on this function.",
      similar_secrets_found: looksRelated,
    }, 503);
  }

  let message = "";
  let history: { role: string; text: string }[] = [];
  try {
    const requestBody = await req.json();
    message = String(requestBody.message ?? "").trim();
    if (Array.isArray(requestBody.history)) history = requestBody.history.slice(-6);
  } catch {
    return json({ error: "Expected a JSON body." }, 400);
  }
  if (!message) return json({ error: "No message." }, 400);
  if (message.length > 1000) message = message.slice(0, 1000);

  let stock: string;
  try {
    stock = await catalogue();
  } catch (error) {
    console.error("Reading the catalogue:", error);
    return json({ error: "Could not read the catalogue." }, 502);
  }

  const contents = [
    ...history.map((turn) => ({
      role: turn.role === "bot" ? "model" : "user",
      parts: [{ text: String(turn.text).slice(0, 1000) }],
    })),
    { role: "user", parts: [{ text: message }] },
  ];

  const body = JSON.stringify({
    systemInstruction: { parts: [{ text: `${SYSTEM}\n\nCATALOGUE:\n${stock}` }] },
    contents,
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: SCHEMA,
      temperature: 0.4,
    },
  });

  async function callGemini(model: string): Promise<Response> {
    return await fetch(`${GEMINI_URL}/${model}:generateContent`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey! },
      body,
    });
  }

  // Gemini answers 503 UNAVAILABLE when the model is busy -- "spikes in
  // demand are usually temporary", and the first call from this project
  // hit one. A customer should not see a shrug because Google was briefly
  // full, so a busy model is retried, then tried on the lighter model,
  // which is far less often at capacity. Only after all of that does the
  // client fall back to its built-in answers.
  const attempts: { model: string; waitMs: number }[] = [
    { model: MODEL, waitMs: 0 },
    { model: MODEL, waitMs: 900 },
    { model: FALLBACK_MODEL, waitMs: 600 },
  ];

  let res: Response | null = null;
  let usedModel = MODEL;

  for (const attempt of attempts) {
    if (attempt.waitMs) await new Promise((done) => setTimeout(done, attempt.waitMs));
    try {
      res = await callGemini(attempt.model);
      usedModel = attempt.model;
    } catch (error) {
      console.error("Calling Gemini:", error);
      res = null;
      continue;
    }
    if (res.ok) break;

    const detail = await res.text();
    console.error("Gemini returned", res.status, "on", attempt.model, detail);

    // 429 is our quota, not their capacity: retrying will not help.
    if (res.status === 429) return json({ error: "AI quota exhausted." }, 502);
    if (res.status !== 503) return json({ error: "The AI service refused." }, 502);
  }

  if (!res) return json({ error: "Could not reach the AI service." }, 502);
  if (!res.ok) return json({ error: "The AI service is busy. Please try again." }, 502);

  const payload = await res.json();
  const raw = payload?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!raw) {
    console.error("Gemini returned no text:", JSON.stringify(payload).slice(0, 500));
    return json({ error: "The AI service returned nothing usable." }, 502);
  }

  let answer: { reply?: string; product_ids?: unknown; is_build_request?: boolean };
  try {
    answer = JSON.parse(raw);
  } catch {
    console.error("Gemini returned non-JSON:", raw.slice(0, 300));
    return json({ error: "The AI service returned malformed JSON." }, 502);
  }

  // The schema asks for integers, but a model can still hand back a string
  // or something that is not an id at all, and the clients look these up
  // in a Map. Anything that is not a positive whole number is dropped.
  const ids = Array.isArray(answer.product_ids)
    ? [...new Set(answer.product_ids
        .map((id) => Number(id))
        .filter((id) => Number.isInteger(id) && id > 0))].slice(0, 12)
    : [];

  let reply = stripUnreliable(String(answer.reply ?? "").trim(), ids.length > 0);
  const note = stockNote(ids, stock);
  if (note) {
    // Everything out of stock: lead with it. Otherwise it follows.
    reply = note.includes("everything below") || note.includes("this is currently")
      ? `${note} ${reply}`
      : `${reply} ${note}`;
  }

  return json({
    reply: reply.trim(),
    product_ids: ids,
    is_build_request: answer.is_build_request === true,
    model: usedModel,
  });
});
