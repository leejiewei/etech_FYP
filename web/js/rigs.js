// ============================================================
// Powered by ASUS: the public gallery, and the form that feeds it.
//
// Two halves of one page, and the join between them is the point. A
// build is photographs plus a list of parts, and each part is a real
// product id rather than a line of text — so the gallery is not a
// scrapbook, it is a set of routes back into the shop.
//
// Nothing here decides what is published. The gallery reads rig_gallery,
// a view that only ever returns approved submissions, and the policy
// underneath it says the same thing. If this file forgot to filter it
// would come back empty rather than publishing somebody's pending
// photograph, which is the difference between a check and a guarantee.
//
// The ASUS badge is not decided here either. A trigger in the database
// works it out from the tagged parts every time they change. This page
// only draws what it is told.
// ============================================================

const MAX_RIG_PHOTOS = 6;

let rigs = [];
let rigParts = {};          // rig_id -> the products tagged in it
let chosenParts = [];       // what the form has tagged so far
let rigFilter = "all";      // all | asus

// ------------------------------------------------------------
// The gallery
// ------------------------------------------------------------
function loadRigs() {
  return Promise.all([
    sb.from("rig_gallery")
      .select("rig_id,title,description,image_urls,is_asus_verified,created_at,builder")
      .order("created_at", { ascending: false }),
    sb.from("rig_gallery_parts")
      .select("rig_id,product_id,product_name,price,brand"),
  ]).then(([gallery, parts]) => {
    if (gallery.error) throw gallery.error;

    rigs = gallery.data || [];
    rigParts = {};
    (parts.data || []).forEach((row) => {
      (rigParts[row.rig_id] ||= []).push(row);
    });
  });
}

function renderRigFilters() {
  const bar = document.getElementById("rig-filters");
  if (!bar) return;

  const counts = {
    all: rigs.length,
    asus: rigs.filter((r) => r.is_asus_verified === 1).length,
  };

  bar.innerHTML = "";
  [["all", `All builds (${counts.all})`], ["asus", `ASUS Certified (${counts.asus})`]]
    .forEach(([key, label]) => {
      const button = document.createElement("button");
      button.className = "filter-btn" + (rigFilter === key ? " active" : "");
      button.textContent = label;
      button.onclick = () => { rigFilter = key; renderRigFilters(); renderRigs(); };
      bar.appendChild(button);
    });
}

function renderRigs() {
  const grid = document.getElementById("rig-grid");
  const empty = document.getElementById("rig-empty");
  if (!grid) return;

  const shown = rigFilter === "asus"
    ? rigs.filter((r) => r.is_asus_verified === 1)
    : rigs;

  empty.style.display = shown.length === 0 ? "block" : "none";
  grid.innerHTML = shown.map(rigCard).join("");
}

function rigCard(rig) {
  const parts = rigParts[rig.rig_id] || [];
  const photos = rig.image_urls || [];

  return `
    <article class="rig-card">
      ${rig.is_asus_verified === 1
        ? `<span class="rig-badge" title="This build uses ASUS, ROG or TUF hardware">ASUS Certified</span>`
        : ""}

      <div class="rig-photos">
        ${photos.map((url, i) => `
          <img src="${safeUrl(url)}" alt="${escapeHtml(rig.title)} photo ${i + 1}"
               loading="lazy" />`).join("")}
      </div>

      <h3>${escapeHtml(rig.title)}</h3>
      <p class="rig-builder">Built by ${escapeHtml(rig.builder || "a customer")}</p>
      ${rig.description
        ? `<p class="rig-description">${escapeHtml(rig.description)}</p>`
        : ""}

      ${parts.length === 0 ? "" : `
        <div class="rig-parts">
          <strong>Parts used</strong>
          <ul>
            ${parts.map((part) => `
              <li>
                <a href="shop.html?search=${encodeURIComponent(part.product_name)}">
                  ${escapeHtml(part.product_name)}
                </a>
                <span class="rig-part-brand">${escapeHtml(part.brand)}</span>
              </li>`).join("")}
          </ul>
        </div>`}
    </article>`;
}

// ------------------------------------------------------------
// Tagging parts
//
// Searched against the catalogue already in memory rather than against
// the database: every page has the products loaded before it draws
// anything, so this is a filter over an array and costs nothing per
// keystroke.
// ------------------------------------------------------------
function searchRigParts(term) {
  const results = document.getElementById("rig-part-results");
  const needle = term.trim().toLowerCase();

  if (needle.length < 2) { results.innerHTML = ""; return; }

  const matches = products
    .filter((p) => (p.name + " " + p.brand).toLowerCase().includes(needle))
    .filter((p) => !chosenParts.some((c) => c.id === p.id))
    .slice(0, 8);

  results.innerHTML = matches.length === 0
    ? `<p class="form-note">Nothing matches that.</p>`
    : matches.map((p) => `
        <button type="button" class="rig-part-option" data-add="${p.id}">
          ${escapeHtml(p.name)}
          <span class="rig-part-brand">${escapeHtml(p.brand)}</span>
        </button>`).join("");

  results.querySelectorAll("[data-add]").forEach((button) => {
    button.onclick = () => addRigPart(Number(button.dataset.add));
  });
}

function addRigPart(productId) {
  const product = getProductById(productId);
  if (!product || chosenParts.some((c) => c.id === productId)) return;

  chosenParts.push(product);
  document.getElementById("rig-part-search").value = "";
  document.getElementById("rig-part-results").innerHTML = "";
  renderChosenParts();
}

function removeRigPart(productId) {
  chosenParts = chosenParts.filter((p) => p.id !== productId);
  renderChosenParts();
}

// The badge the submission is heading for, worked out from the same rule
// the database uses. It is a preview and nothing more -- the trigger has
// the final word -- but somebody choosing parts should be able to see
// the badge appear as they tag the board that earns it.
function taggedPartsLookAsus() {
  return chosenParts.some((p) => /^(asus|rog)/i.test(p.brand || ""));
}

function renderChosenParts() {
  const box = document.getElementById("rig-part-chosen");

  if (chosenParts.length === 0) {
    box.innerHTML = `<p class="form-note">Nothing tagged yet.</p>`;
    return;
  }

  box.innerHTML = `
    ${taggedPartsLookAsus()
      ? `<p class="rig-badge-preview">ASUS Certified — one of these is ASUS, ROG or TUF hardware.</p>`
      : ""}
    ${chosenParts.map((p) => `
      <span class="rig-part-chip">
        ${escapeHtml(p.name)}
        <button type="button" title="Remove" data-drop="${p.id}">&times;</button>
      </span>`).join("")}`;

  box.querySelectorAll("[data-drop]").forEach((button) => {
    button.onclick = () => removeRigPart(Number(button.dataset.drop));
  });
}

// ------------------------------------------------------------
// Sending it
//
// The photographs go up first, one at a time, each shrunk and
// re-encoded in the browser by photo.js. Then one call to
// submit_rig_showcase() writes the build and its tags together -- two
// statements from here could land the first and lose the second, and a
// rig with no parts on it is the one case the badge rule cannot answer.
// ------------------------------------------------------------
function submitRig(event) {
  event.preventDefault();

  const errorEl = document.getElementById("rig-error");
  const doneEl = document.getElementById("rig-done");
  const button = document.getElementById("rig-submit");
  const files = Array.from(document.getElementById("rig-photos").files);

  errorEl.textContent = "";
  doneEl.style.display = "none";

  if (files.length === 0) {
    errorEl.textContent = "Add at least one photo of the build.";
    return;
  }
  if (files.length > MAX_RIG_PHOTOS) {
    errorEl.textContent = `Six photos is the most a build can have.`;
    return;
  }

  const badFile = files.map(checkPhoto).find((problem) => problem !== null);
  if (badFile) { errorEl.textContent = badFile; return; }

  const user = getCurrentUser();
  if (!user) { errorEl.textContent = "Please log in first."; return; }

  button.disabled = true;
  button.textContent = "Uploading…";

  uploadRigPhotos(files, user.id)
    .then((urls) => sb.rpc("submit_rig_showcase", {
      p_title:       document.getElementById("rig-title").value.trim(),
      p_description: document.getElementById("rig-description").value.trim(),
      p_image_urls:  urls,
      p_product_ids: chosenParts.map((p) => p.id),
    }))
    .then(({ error }) => {
      if (error) throw error;

      document.getElementById("rig-form").reset();
      chosenParts = [];
      renderChosenParts();

      doneEl.style.display = "block";
      doneEl.textContent =
        "Thanks — your build is with us. It appears in the gallery once a " +
        "member of staff has had a look at it.";
      button.textContent = "Submit my build";
      button.disabled = false;
    })
    .catch((error) => {
      button.disabled = false;
      button.textContent = "Submit my build";
      errorEl.textContent = dbMessage(error, "Could not send that build.");
    });
}

// One at a time rather than all at once. Six 4MB photographs resized in
// parallel is six canvases in memory on a phone, and the upload is not
// the slow part.
async function uploadRigPhotos(files, customerId) {
  const urls = [];
  for (const file of files) {
    urls.push(await uploadRigPhoto(file, customerId));
  }
  return urls;
}

onAppReady(() => {
  const form = document.getElementById("rig-form");
  const signedOut = document.getElementById("rig-signed-out");

  if (isLoggedIn()) {
    form.style.display = "block";
    renderChosenParts();
  } else {
    signedOut.style.display = "block";
  }

  loadRigs()
    .then(() => { renderRigFilters(); renderRigs(); })
    .catch((error) => {
      console.error("Loading the gallery:", error);
      document.getElementById("rig-empty").style.display = "block";
      document.getElementById("rig-empty").textContent =
        "Could not load the gallery just now.";
    });
});
