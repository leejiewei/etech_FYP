// ============================================================
// Rig showcase moderation.
//
// Customers submit a build — photographs, a title, and the parts they
// used — and nothing appears in the public gallery until somebody here
// has looked at it. That is the whole job of this page: look, then say
// yes or no.
//
// Two things it deliberately does not do.
//
// It does not grant the ASUS badge. That is worked out in the database
// from the tagged parts by a trigger, every time the tags change. A
// badge a member of staff could switch on by hand would be one that
// could be switched on by mistake, and one that would go on saying ASUS
// Certified after the ASUS board was untagged. What this page shows is
// the answer, not a control.
//
// It does not delete the photographs when a submission is rejected. The
// bucket is public — it is a gallery — so a rejected image stays
// reachable by anybody holding its URL until somebody removes it. Doing
// that automatically here would destroy the evidence in the case where
// the rejection is disputed, so it is a separate, deliberate act. The
// Delete button below does it.
// ============================================================

const SHOWCASE_STATES = ["PENDING", "APPROVED", "REJECTED"];

const SHOWCASE_LABELS = {
  PENDING:  "Waiting",
  APPROVED: "Published",
  REJECTED: "Turned down",
};

adminPage("Rig Showcase", "showcases", async (content) => {
  const filter = SHOWCASE_STATES.includes(params().status) ? params().status : "PENDING";

  const rigs = await loadShowcases(filter);
  const parts = rigs.length === 0 ? [] : await loadShowcaseParts(rigs.map((r) => r.rig_id));

  const partsFor = {};
  parts.forEach((row) => (partsFor[row.rig_id] ||= []).push(row));

  content.innerHTML = `
    <p class="hint">
      Nothing reaches the public gallery until it is published here. The ASUS
      badge is worked out from the parts the customer tagged and is not
      something this page can grant.
    </p>

    <div class="filters">
      ${SHOWCASE_STATES.map((s) => `
        <a href="showcases.html?status=${encodeURIComponent(s)}"
           class="btn ${filter === s ? "" : "grey"}">${e(SHOWCASE_LABELS[s])}</a>`).join("")}
    </div>

    ${rigs.length === 0
      ? `<div class="card" style="text-align:center; color:#888;">Nothing here.</div>`
      : rigs.map((r) => showcaseCard(r, partsFor[r.rig_id] || [])).join("")}`;

  wireShowcaseActions();
});

async function loadShowcases(status) {
  const { data, error } = await sb.from("admin_rig_showcases")
    .select("rig_id,customer_id,title,description,image_urls,is_asus_verified," +
            "status,review_note,created_at,reviewed_at,customer_name," +
            "customer_email,tagged_parts")
    .eq("status", status)
    .order("created_at", { ascending: false })
    .limit(60);
  if (error) throw error;
  return data;
}

// The tags, straight from the join table rather than through the public
// gallery view — that view only returns approved rigs, and the whole
// point of this page is the ones that are not approved yet.
async function loadShowcaseParts(ids) {
  const { data, error } = await sb.from("rig_showcase_parts")
    .select("rig_id,product_id,products(name,price,brands(name))")
    .in("rig_id", ids);
  if (error) throw error;

  return data.map((row) => ({
    rig_id: row.rig_id,
    product_id: row.product_id,
    name: row.products ? row.products.name : "(product removed)",
    brand: row.products && row.products.brands ? row.products.brands.name : "",
  }));
}

function showcaseCard(r, parts) {
  const photos = r.image_urls || [];

  return `
    <div class="card" data-rig="${r.rig_id}">
      <div style="display:flex; justify-content:space-between; flex-wrap:wrap; gap:12px;">
        <div>
          <h2 style="margin:0;">${e(r.title)}
            ${r.is_asus_verified === 1
              ? `<span class="badge in">ASUS Certified</span>`
              : `<span class="badge grey">No ASUS part tagged</span>`}
          </h2>
          <div style="font-size:13px; color:#888;">
            ${e(when(r.created_at))}
            &nbsp;·&nbsp; ${e(r.customer_name)} (${e(r.customer_email)})
          </div>
        </div>
        <div>
          <span class="badge ${r.status === "APPROVED" ? "in" : r.status === "REJECTED" ? "out" : "low"}">
            ${e(SHOWCASE_LABELS[r.status] || r.status)}
          </span>
        </div>
      </div>

      ${r.description
        ? `<p style="margin-top:10px; font-size:13.5px; color:#444;">${e(r.description)}</p>`
        : ""}

      <div style="display:flex; gap:8px; overflow-x:auto; margin-top:12px; padding-bottom:6px;">
        ${photos.map((url, i) => `
          <a href="${e(url)}" target="_blank" rel="noopener">
            <img src="${e(url)}" alt="Build photo ${i + 1}"
                 style="height:170px; border-radius:6px;" />
          </a>`).join("")}
      </div>

      <div style="margin-top:12px; font-size:13px;">
        <strong>Parts tagged (${r.tagged_parts})</strong>
        ${parts.length === 0
          ? `<div style="color:#c0392b;">None — the badge cannot be earned without them.</div>`
          : `<ul style="list-style:none; margin-top:6px;">
               ${parts.map((p) => `
                 <li style="padding:2px 0;">
                   ${e(p.name)} <span style="color:#999;">${e(p.brand)}</span>
                 </li>`).join("")}
             </ul>`}
      </div>

      ${r.review_note
        ? `<div style="margin-top:10px; font-size:12px; color:#999;">
             Note: ${e(r.review_note)}
           </div>`
        : ""}

      <div style="margin-top:14px; display:flex; gap:8px; align-items:center; flex-wrap:wrap;">
        <input type="text" data-field="note" placeholder="Reason, shown to the customer"
               style="flex:1; min-width:200px; padding:8px 10px; border:1px solid #ccd1d7; border-radius:6px;" />
        ${r.status !== "APPROVED"
          ? `<button type="button" data-set="APPROVED" class="btn small">Publish</button>` : ""}
        ${r.status !== "REJECTED"
          ? `<button type="button" data-set="REJECTED" class="btn small danger">Turn down</button>` : ""}
        ${r.status !== "PENDING"
          ? `<button type="button" data-set="PENDING" class="btn small grey">Back to waiting</button>` : ""}
        <button type="button" data-act="delete" class="btn small danger">Delete</button>
      </div>
    </div>`;
}

function wireShowcaseActions() {
  document.querySelectorAll("[data-rig] button[data-set]").forEach((button) => {
    button.onclick = async () => {
      const card = button.closest("[data-rig]");
      const rigId = Number(card.dataset.rig);
      const note = card.querySelector('[data-field="note"]').value.trim();
      const status = button.dataset.set;

      button.disabled = true;
      const { error } = await sb.rpc("admin_set_rig_status", {
        p_rig_id: rigId,
        p_status: status,
        p_note: note,
      });

      if (error) {
        button.disabled = false;
        alert("Could not update that submission: " + error.message);
        return;
      }
      reloadWith(`Submission ${SHOWCASE_LABELS[status].toLowerCase()}.`);
    };
  });

  document.querySelectorAll("[data-rig] button[data-act='delete']").forEach((button) => {
    button.onclick = async () => {
      const card = button.closest("[data-rig]");
      const rigId = Number(card.dataset.rig);

      if (!confirm("Delete this submission and its photos? This cannot be undone.")) return;
      button.disabled = true;

      try {
        // The photos first, then the row. The other way round would lose
        // the list of what to delete and leave the pictures in the bucket
        // with nothing pointing at them.
        const paths = [...card.querySelectorAll("img")]
          .map((img) => storagePathOf(img.getAttribute("src")))
          .filter((path) => path !== null);

        if (paths.length > 0) {
          const { error } = await sb.storage.from("rig-showcases").remove(paths);
          if (error) throw error;
        }

        await write(sb.from("rig_showcases").delete().eq("rig_id", rigId));
        reloadWith("Submission deleted.");
      } catch (error) {
        button.disabled = false;
        alert("Could not delete that: " + (error.message || error));
      }
    };
  });
}

// A public storage URL ends in /object/public/<bucket>/<path>, and the
// remove() call wants that last part on its own.
function storagePathOf(url) {
  const marker = "/object/public/rig-showcases/";
  const at = String(url || "").indexOf(marker);
  return at === -1 ? null : decodeURIComponent(url.slice(at + marker.length));
}
