// ============================================================
// Product catalogue.
//
// This used to be a long hard-coded list, then a call to
// api/products.php. The products are read straight out of Supabase now,
// but they end up in exactly the same `products` array with the same
// fields, so the shop, the PC Builder and the advisor did not have to
// change a line.
//
// The reshaping that api/products.php was doing had to come with them,
// because it is what turns four database tables into the flat object
// the rest of the site expects. That work is in shapeCatalogue() below.
//
// The catch is that fetching takes a moment, and every page needs the
// products before it can draw anything. So instead of each page doing
//     document.addEventListener("DOMContentLoaded", start)
// they now do
//     onAppReady(start)
// which waits for the page AND the catalogue to both be ready.
// ============================================================

let products = [];          // filled in by loadProducts()
let productsLoaded = false;

// The shop's own builds, keyed by the machine's product id. Both stay
// empty for every product that is not one, and the helpers below are
// written so an empty map means "nothing to say", never "no".
let prebuiltAvailability = {};
let prebuiltUpgrades = {};

// Timed deals, keyed by product id. Same shape of promise as the two
// above: a product with no deal on it is simply not in here.
let liveDeals = {};

// Slot order used by the PC Builder page.
const builderSlots = ["CPU", "Cooler", "Motherboard", "RAM", "GPU", "Storage", "PSU", "Case"];

// Rough extra wattage for the motherboard, drives and fans, used when we
// work out how big the power supply needs to be.
const OTHER_PARTS_WATTAGE = 100;

// A supply should not run flat out: the build's estimated draw plus a
// quarter again, so it copes with the spikes a modern graphics card
// makes and is not working at its limit.
const PSU_HEADROOM = 1.25;

// How big a power supply a build needs: the larger of the supply the
// shop recommends for a full rig with the graphics card and the
// estimated draw plus headroom, rounded up to the next 50W. Shared by
// the builder's check and its power meter so the two never disagree.
//
// Each card carries two figures: recommendedPsu is NVIDIA's or AMD's
// own (shown in the spec table), shopPsu the shop's full-rig one, a
// size up, because the makers' number assumes their own test system.
// A card without a shopPsu falls back to the maker's figure.
function psuNeedFor(cpu, gpu) {
  const cpuWatts = cpu ? (cpu.attrs.tdp || 0) : 0;
  const gpuWatts = gpu ? (gpu.attrs.power || 0) : 0;
  const draw = cpuWatts + gpuWatts + OTHER_PARTS_WATTAGE;
  const withHeadroom = Math.ceil(draw * PSU_HEADROOM / 50) * 50;
  const makerPsu = gpu ? (gpu.attrs.recommendedPsu || 0) : 0;
  const cardMin = gpu ? (gpu.attrs.shopPsu || makerPsu) : 0;
  return {
    cpuWatts, gpuWatts, draw, makerPsu,
    maker: gpu && /^RX /.test(gpu.attrs.chip || "") ? "AMD" : "NVIDIA",
    needed: Math.max(withHeadroom, cardMin),
    // Which rule set the figure, for the message.
    byCard: cardMin >= withHeadroom && cardMin > 0,
  };
}

// ------------------------------------------------------------
// Loading, and the "wait until everything is ready" helper
// ------------------------------------------------------------
// A page can only draw once three things are true: the HTML is parsed,
// the catalogue has arrived, and we know who (if anyone) is signed in.
const readyCallbacks = [];
let sessionLoaded = false;

function everythingReady() {
  return productsLoaded && sessionLoaded && document.readyState !== "loading";
}

function onAppReady(callback) {
  if (everythingReady()) {
    callback();
  } else {
    readyCallbacks.push(callback);
  }
}

function runReadyCallbacks() {
  if (!everythingReady()) return;
  while (readyCallbacks.length > 0) {
    readyCallbacks.shift()();
  }
}

function showLoadError(message) {
  const box = document.createElement("div");
  box.className = "load-error";
  box.textContent = message;
  if (document.body) document.body.prepend(box);
}

// ------------------------------------------------------------
// Reading the catalogue.
//
// Four tables, fetched at the same time rather than one after another.
// A product's brand and category are separate tables, and its
// specifications are one row per spec — which is what lets a printer
// have a paper size and a CPU have a socket without the products table
// growing a column for every idea anyone ever has.
//
// The specification rows are the reason selectAllRows() exists: there
// are more than a thousand of them, and Supabase sends at most a
// thousand per request. See db.js.
// ------------------------------------------------------------
function loadProducts() {
  return Promise.all([
    selectAllRows(() => sb.from("products")
      .select("product_id,name,price,stock_status,description,icon,img_slug," +
              "image_path,official_url,exclude_from_builder,brand_id,category_id")
      .eq("is_active", 1)
      .order("product_id")),
    selectAllRows(() => sb.from("brands").select("brand_id,name")),
    selectAllRows(() => sb.from("categories").select("category_id,name,parent_id")),
    selectAllRows(() => sb.from("product_attributes").select("product_id,attr_key,attr_value")),
    // The shop's own builds. Fetched with the catalogue rather than when
    // the Prebuilt page opens, because a machine's stock badge has to
    // read the same everywhere it appears -- search, the shop grid, the
    // product modal -- not only on the one page.
    selectAllRows(() => sb.from("prebuilt_availability")
      .select("prebuilt_id,linked,pending,not_stocked,derived_status,blocking_parts")),
    selectAllRows(() => sb.from("prebuilt_upgrades")
      .select("upgrade_id,prebuilt_id,slot,label,price_delta,kind")
      .eq("is_active", 1)
      .order("prebuilt_id")
      .order("sort_order")),
    // Timed deals, fetched with the catalogue for the same reason the
    // prebuilt availability is: a struck-through price has to read the
    // same on the home page, in the shop grid, in the product modal and
    // in the basket, not only on the Deals page.
    //
    // live_deals is a view, and it is already only the running ones --
    // the policy on the table hides the rest from the shop front and the
    // view's own WHERE hides them from a signed-in member of staff. The
    // browser is not asked to filter anything.
    //
    // This one is allowed to fail on its own. Every other request in
    // this list is the shop -- no products, no site -- but a shop that
    // cannot read its deals is a shop at list price, which is a worse
    // day rather than a broken one. It also means the site keeps working
    // if this JavaScript is deployed before the migration that creates
    // the view.
    selectAllRows(() => sb.from("live_deals")
      .select("deal_id,product_id,discount_price,start_time,end_time"))
      .catch((error) => {
        console.error("Loading deals (prices shown will be list prices):", error);
        return [];
      }),
  ])
    .then(([productRows, brandRows, categoryRows, attributeRows,
            availabilityRows, upgradeRows, dealRows]) => {
      products = shapeCatalogue(productRows, brandRows, categoryRows, attributeRows);
      shapePrebuilts(availabilityRows, upgradeRows);
      shapeDeals(dealRows);
    })
    .catch((error) => {
      console.error("Loading the catalogue failed:", error);
      showLoadError("Could not load the product catalogue. " +
        "Check that this machine is online and can reach Supabase.");
    })
    .finally(() => { productsLoaded = true; runReadyCallbacks(); });
}

// Specifications that can hold several values, so they must come back
// as a list even when there happens to be only one.
// colourOption is the list a shopper picks from when a product comes in
// more than one colour; see colourOptionsOf() in ui.js.
const ARRAY_SPECS = ["sockets", "supportedFormFactors", "incompatibleSockets",
                     "colourOption"];

// Specifications that are numbers. Everything is stored as text, and
// the compatibility checks compare these with < and >, so "90" has to
// become 90 or a 90W cooler looks bigger than a 105W one.
const NUMBER_SPECS = ["tdp", "coolerRating", "power", "recommendedPsu", "shopPsu", "length", "wattage",
                      "maxGpuLength", "pcieGen", "cores", "threads"];

// Some CPUs and boards accept either memory type, recorded as "DDR4/DDR5".
// Says whether a stick of `ramGen` works with a `supported` value. Shared
// by the PC Builder and the chat advisor; the app's Compatibility.ramGenFits
// is the same rule.
function ramGenFits(ramGen, supported) {
  if (!supported) return true;
  return supported.split("/").indexOf(ramGen) !== -1;
}

function shapeCatalogue(productRows, brandRows, categoryRows, attributeRows) {
  const brandName = new Map(brandRows.map((b) => [b.brand_id, b.name]));
  const category  = new Map(categoryRows.map((c) => [c.category_id, c]));

  // Group the specifications by product, rather than looking them up
  // one product at a time.
  const specsFor = new Map();
  attributeRows.forEach((row) => {
    let specs = specsFor.get(row.product_id);
    if (!specs) { specs = {}; specsFor.set(row.product_id, specs); }

    let value = row.attr_value;
    if (NUMBER_SPECS.includes(row.attr_key) && value !== "" && !isNaN(value)) {
      value = Number(value);
    }

    if (ARRAY_SPECS.includes(row.attr_key)) {
      if (!specs[row.attr_key]) specs[row.attr_key] = [];
      specs[row.attr_key].push(value);
    } else {
      specs[row.attr_key] = value;
    }
  });

  return productRows.map((row) => {
    const own    = category.get(row.category_id);
    const parent = own && own.parent_id !== null ? category.get(own.parent_id) : null;

    // A category with a parent is a sub-category: "Components > CPU".
    // The site shows the top-level name as the category and the child
    // as the subcategory.
    const item = {
      id:          row.product_id,
      name:        row.name,
      brand:       brandName.get(row.brand_id),
      category:    parent ? parent.name : (own ? own.name : null),
      price:       Number(row.price),
      stock:       row.stock_status,
      icon:        row.icon,
      img:         row.img_slug,
      description: row.description,
      attrs:       specsFor.get(row.product_id) || {},
    };

    if (parent)                      item.subcategory = own.name;
    if (row.exclude_from_builder)    item.excludeFromBuilder = true;
    if (row.image_path)              item.imagePath = row.image_path;
    if (row.official_url)            item.officialUrl = row.official_url;

    return item;
  });
}

// The actual start-up happens in app.js, which is the last script on every
// page — by then loadSession() from auth.js exists.

// ------------------------------------------------------------
// Look-ups used all over the site
// ------------------------------------------------------------
function getProductsBySubcategory(subcategory) {
  return products.filter((p) => p.subcategory === subcategory);
}

function getProductById(id) {
  return products.find((p) => p.id === id);
}

function stockLabel(stock) {
  if (stock === "in") return "In Stock";
  if (stock === "low") return "Low Stock";
  return "Out of Stock";
}

// ------------------------------------------------------------
// Timed deals
//
// A deal is a price on one product for a stated window. The window is
// checked twice, and the second check is the one that matters here:
//
//   * the database only ever hands over a deal that is running, so a
//     finished one cannot be drawn by mistake;
//   * dealFor() checks the end time again on every call, because a page
//     can be left open. Somebody who opens the shop at 11:58 and is
//     still looking at it at 12:01 should see the sale end in front of
//     them, and the till agrees with that -- place_order reads the
//     window itself and will charge list price the moment it closes.
//
// priceOf() is the one function that answers "what does this cost". Ask
// it rather than reading product.price, the same way stockOf() is asked
// rather than reading product.stock.
// ------------------------------------------------------------
function shapeDeals(dealRows) {
  liveDeals = {};
  (dealRows || []).forEach((row) => {
    liveDeals[row.product_id] = {
      id:       row.deal_id,
      price:    Number(row.discount_price),
      startsAt: row.start_time,
      endsAt:   row.end_time,
    };
  });
}

function dealFor(product) {
  if (!product) return null;
  const deal = liveDeals[product.id];
  if (!deal) return null;
  if (new Date(deal.endsAt).getTime() <= Date.now()) return null;
  // A deal typed in above list price is a slip, not an offer. The till
  // takes the lower of the two as well.
  if (!(deal.price < product.price)) return null;
  return deal;
}

function priceOf(product) {
  const deal = dealFor(product);
  return deal ? deal.price : (product ? product.price : 0);
}

function hasDeal(product) {
  return dealFor(product) !== null;
}

// Milliseconds left, or 0. Kept here so the card, the modal and the
// Deals page all count down to the same instant.
function dealTimeLeft(deal) {
  if (!deal) return 0;
  return Math.max(0, new Date(deal.endsAt).getTime() - Date.now());
}

// When a deal ends, written out for somewhere a ticking clock would be
// noise -- in the shopper's own time zone, because that is the one they
// will be looking at their phone in.
function dealEndsText(product) {
  const deal = dealFor(product);
  if (!deal) return "";
  return new Date(deal.endsAt).toLocaleString(undefined, {
    day: "numeric", month: "short", hour: "2-digit", minute: "2-digit",
  });
}

// ------------------------------------------------------------
// The shop's own builds
//
// A Gaming or Office machine is assembled here from parts the shop also
// sells separately, so "can this be sold?" is a question about those
// parts rather than about the machine's own row. The database works it
// out in prebuilt_availability; this files the answers by machine and
// hands them out.
//
// The mobile app carries the same three helpers in Shop (stockOf,
// blockedBy, upgradesFor). The two have to agree, because they are
// describing one shop.
// ------------------------------------------------------------
function shapePrebuilts(availabilityRows, upgradeRows) {
  prebuiltAvailability = {};
  availabilityRows.forEach((row) => {
    prebuiltAvailability[row.prebuilt_id] = row;
  });

  prebuiltUpgrades = {};
  upgradeRows.forEach((row) => {
    (prebuiltUpgrades[row.prebuilt_id] ||= []).push({
      id: row.upgrade_id,
      slot: row.slot,
      label: row.label,
      priceDelta: Number(row.price_delta),
      kind: row.kind || "upgrade",
    });
  });
}

// True once every slot of a machine has been answered, so its derived
// status can be trusted on its own.
function prebuiltIsDescribed(productId) {
  const row = prebuiltAvailability[productId];
  return Boolean(row) && Number(row.pending) === 0 && row.derived_status;
}

// The stock status to show for a product.
//
// For anything that is not one of the shop's builds, and for a build
// whose bill of materials is unfinished, this is the product's own
// status and nothing has changed. For a build that is fully described,
// the parts decide: one of them out and the machine is out.
//
// Every page should ask this rather than reading product.stock, so a
// machine cannot read "In Stock" in the shop grid and "Out of Stock" on
// the Prebuilt page.
function stockOf(product) {
  if (!product) return "in";
  return prebuiltIsDescribed(product.id)
    ? prebuiltAvailability[product.id].derived_status
    : product.stock;
}

// Which parts are holding a machine back, when that is why it is out.
// Null whenever there is nothing useful to say.
function blockedBy(productId) {
  const row = prebuiltAvailability[productId];
  if (!prebuiltIsDescribed(productId)) return null;
  if (row.derived_status !== "out" || !row.blocking_parts) return null;
  return row.blocking_parts;
}

// Everything tickable on a machine, in the shop's own order.
function upgradesFor(productId) {
  return prebuiltUpgrades[productId] || [];
}

// An upgrade changes the machine itself; an accessory is sold beside it
// at a with-purchase price. Same tick box, different fact, so the card
// lists them under separate headings.
function machineUpgrades(productId) {
  return upgradesFor(productId).filter((u) => u.kind !== "accessory");
}

function machineAccessories(productId) {
  return upgradesFor(productId).filter((u) => u.kind === "accessory");
}

// Turns an attrs key into something readable, e.g. "screenSize" -> "Screen Size".
// Used by the shop filters and the product detail modal.
function attrLabel(key) {
  const labels = {
    socket: "Socket",
    sockets: "Socket Support",
    ramGen: "RAM Type",
    screenSize: "Screen Size",
    storageSize: "Storage",
    ram: "Memory",
    wattage: "Wattage",
    power: "Power Draw (W)",
    recommendedPsu: "Maker's Recommended PSU (W)",
    shopPsu: "eTech Recommended PSU, Full Rig (W)",
    length: "Card Length (mm)",
    tdp: "Cooling Needed (W)",
    coolerRating: "Cooler Capacity (W)",
    formFactor: "Board Size",
    supportedFormFactors: "Fits Board Sizes",
    maxGpuLength: "Max Card Length (mm)",
    // printers
    printerType: "Printer Type",
    wifi: "WiFi",
    // monitors
    resolution: "Resolution",
    refreshRate: "Refresh Rate",
    panel: "Panel Type",
    colour: "Colour",
    // cases
    fansIncluded: "Fans Included",
    acceptsAtxPsu: "Takes ATX Power Supply",
    supportsBackConnector: "Back-connector Ready",
    // components
    chipset: "Chipset",
    chip: "Chip",
    vram: "Video Memory",
    cores: "Cores",
    threads: "Threads",
    igpu: "Built-in Graphics",
    coolerIncluded: "Cooler Included",
    backConnector: "Back-connector Board",
    incompatibleSockets: "Known Not To Fit",
    capacity: "Capacity",
    speed: "Speed",
    cl: "CAS Latency",
    kit: "Kit",
    driveType: "Drive Type",
    connection: "Interface",
    driveFormFactor: "Form Factor",
    pcieGen: "PCIe Generation",
    heatsink: "Heatsink",
    driveClass: "Drive Class",
    rpm: "Spin Speed",
    cache: "Cache",
    rating: "80+ Rating",
    modularity: "Cabling",
    connector12VHPWR: "12VHPWR Connector",
    // projectors / arms / paper
    productType: "Type",
    armType: "Arm Type",
    vesa: "VESA Mount",
    paperSize: "Paper Size",
    weight: "Paper Weight",
    // coolers
    coolerType: "Cooling Type",
    radiator: "Radiator Size",
    lcd: "LCD Screen",
    lighting: "Lighting",
    // networking
    wifiStd: "WiFi Standard",
    speedRating: "Speed Rating",
    bands: "Bands",
    // case fans
    fanSize: "Fan Size",
    pack: "Pack Size",
    bladeDirection: "Blade Direction",
    // accessories
    connector: "Connector",
    // keyboards, mice and mouse pads
    switch: "Switch",
    battery: "Power",
    size: "Size",
    colourOption: "Available In",
    // complete systems: laptops, towers, all-in-ones and prebuilts
    sku: "SKU",
    cpu: "Processor",
    gpu: "Graphics",
    motherboard: "Motherboard",
    ssd: "SSD",
    psu: "Power Supply",
    cooler: "Cooler",
    chassis: "Chassis",
    touch: "Touchscreen",
    // Not specs any product carries -- the slots a prebuilt upgrade or
    // accessory sits in when it adds something rather than replacing a
    // part. Kept in step with _labels in mobile/lib/screens/product_detail.dart.
    extras: "Extras",
    monitor: "Monitor",
    peripherals: "Keyboard & Mouse",
    audio: "Audio",
  };
  return labels[key] || key;
}

// Where to find a product's picture.
//
// The database now records whether a product has a real photo, in
// image_path. If it has one we use it; if not we go straight to the
// drawn illustration. Previously the page guessed at images/<id>.jpg
// for every product and let most of them 404, which worked but filled
// the console with failed requests.
function productImage(product) {
  return product.imagePath ? product.imagePath : productImageFallback(product);
}

function productImageFallback(product) {
  return "images/" + (product.img || "default") + ".svg";
}
