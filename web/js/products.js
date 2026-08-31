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

// Slot order used by the PC Builder page.
const builderSlots = ["CPU", "Cooler", "Motherboard", "RAM", "GPU", "Storage", "PSU", "Case"];

// Rough extra wattage for the motherboard, drives and fans, used when we
// work out how big the power supply needs to be.
const OTHER_PARTS_WATTAGE = 100;

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
              "image_path,exclude_from_builder,brand_id,category_id")
      .eq("is_active", 1)
      .order("product_id")),
    selectAllRows(() => sb.from("brands").select("brand_id,name")),
    selectAllRows(() => sb.from("categories").select("category_id,name,parent_id")),
    selectAllRows(() => sb.from("product_attributes").select("product_id,attr_key,attr_value")),
  ])
    .then(([productRows, brandRows, categoryRows, attributeRows]) => {
      products = shapeCatalogue(productRows, brandRows, categoryRows, attributeRows);
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
const ARRAY_SPECS = ["sockets", "supportedFormFactors", "incompatibleSockets"];

// Specifications that are numbers. Everything is stored as text, and
// the compatibility checks compare these with < and >, so "90" has to
// become 90 or a 90W cooler looks bigger than a 105W one.
const NUMBER_SPECS = ["tdp", "coolerRating", "power", "length", "wattage",
                      "maxGpuLength", "pcieGen", "cores", "threads"];

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

// Turns an attrs key into something readable, e.g. "screenSize" -> "Screen Size".
// Used by the shop filters and the compare table.
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
