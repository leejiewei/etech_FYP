// "Built by eTech" on the home page: the shop's own high-end builds, one
// photo each, and a click through to the Facebook post that has the rest.
//
// The shop already posts every finished build to its Facebook page with
// the full set of photos, so this does not try to be a gallery. It shows
// the best photo, names the parts that make the build worth looking at,
// and sends the visitor to the post for everything else.
//
// TO ADD A BUILD
//   1. Save one photo into web/images/builds/ (a landscape JPG around
//      1200px wide is plenty).
//   2. Open the post on Facebook, click its date/time under the page
//      name, and copy the address bar -- that is the post's own link.
//   3. Add an entry below. Keep `specs` to the three or four parts a
//      buyer would ask about first.
//
// The section stays hidden while this list is empty.
// Specs are the tower's headline parts only, taken from each Facebook
// post's own list. The posts also price the whole sale, which for some
// of these includes a monitor or speakers, so the totals are left to the
// post rather than shown beside four tower parts.
const HIGHEND_BUILDS = [
  {
    title: "ROG Astral RTX 5080 Upgrade",
    photo: "images/builds/black-rtx5080-astral.jpg",
    post: "https://www.facebook.com/etech.computer.7/posts/pfbid023VzpZ3WmPAipXfEi5PxSjrebM38FKw93rQTNHcQYGH2TxLGkBmecEd1gv2BjfHmsl",
    specs: ["ROG Astral RTX 5080 OC", "TUF Gaming B850M-Plus WiFi 7", "32GB DDR5 6000", "TUF LC III 360 ARGB LCD"],
  },
  {
    title: "White 9800X3D RTX 5070 Ti",
    photo: "images/builds/white-rtx5070ti-tuf.jpg",
    post: "https://www.facebook.com/etech.computer.7/posts/pfbid0BezEx2AqaiZFW4ErwhsuKyrWp6vw2iizBSEDqs68xVAuPKXPR7dhcArwFYwXRji3l",
    specs: ["Ryzen 7 9800X3D", "TUF Gaming RTX 5070 Ti 16GB", "32GB DDR5 6000 CL30", "Prime LC 360 ARGB"],
  },
  {
    title: "White 7800X3D RTX 5070",
    photo: "images/builds/white-rtx5070-zotac.jpg",
    post: "https://www.facebook.com/etech.computer.7/posts/pfbid02od1URxTpwMkCxyNz9J1fs9AJPGX9UF5fdq5MxowMZ6wyNhxWJvuL4vaHqdj4XLKvl",
    specs: ["Ryzen 7 7800X3D", "ZOTAC RTX 5070 AMP White", "16GB DDR5 6000 CL30", "Prime LC 360 ARGB"],
  },
  {
    title: "9700X RTX 5070 Ti Build",
    photo: "images/builds/black-rtx5070ti-tuf.jpg",
    post: "https://www.facebook.com/etech.computer.7/posts/pfbid04d64B4Ec83uKgy4C6S8M8qHdTxEW31sVSvfYNfWzirgmDnjLknkLVVGYv6Buv5atl",
    specs: ["Ryzen 7 9700X", "TUF Gaming RTX 5070 Ti 16GB", "32GB DDR5", "FX360 LCD ARGB AIO"],
  },
  {
    title: "9800X3D RTX 5070 RGB Build",
    photo: "images/builds/black-rtx5070-prime.jpg",
    post: "https://www.facebook.com/etech.computer.7/posts/pfbid022NMyVEvDS5qLY61pRVki4yaz3JASqWnPgEJJN69wpCYY9kPN4fPcigPWc483347tl",
    specs: ["Ryzen 7 9800X3D", "Prime RTX 5070 12GB OC", "32GB DDR5 6000", "TUF LC III 360 ARGB LCD"],
  },
  {
    title: "Core Ultra 7 RTX 5070 Upgrade",
    photo: "images/builds/black-rtx5070-ultra7.jpg",
    post: "https://www.facebook.com/etech.computer.7/posts/pfbid0Vgg5JZktiwzzgJcaf8tG9aGUAePEYbGEkhUcdz6MeG8ivRoR1CYyWe4zCTUEhjyGl",
    specs: ["Core Ultra 7 270K Plus", "Prime RTX 5070 12GB OC", "32GB DDR5 6000 CL30", "FX240 LCD ARGB AIO"],
  },
];

const ETECH_FACEBOOK = "https://www.facebook.com/etech.computer.7/";

function renderHighendBuilds() {
  const section = document.getElementById("builds-section");
  const grid = document.getElementById("builds-grid");
  if (!section || !grid || HIGHEND_BUILDS.length === 0) return;

  grid.innerHTML = HIGHEND_BUILDS.map((build) => `
    <a class="build-card" href="${safeUrl(build.post) || ETECH_FACEBOOK}" target="_blank" rel="noopener"
       aria-label="${escapeHtml(build.title)} - see all photos on Facebook">
      <div class="build-photo">
        <img src="${safeUrl(build.photo)}" alt="${escapeHtml(build.title)}" loading="lazy" />
        <span class="build-more">See all photos</span>
      </div>
      <div class="build-body">
        <h3>${escapeHtml(build.title)}</h3>
        <ul class="build-specs">
          ${(build.specs || []).map((s) => `<li>${escapeHtml(s)}</li>`).join("")}
        </ul>
        <span class="build-link">View on Facebook &#8599;</span>
      </div>
    </a>`).join("");

  section.hidden = false;
}

// Nothing here waits on the catalogue, so it draws straight away rather
// than behind onAppReady() with the product grids.
renderHighendBuilds();
