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
const HIGHEND_BUILDS = [
  // {
  //   title: "White RTX 4080 Super Build",
  //   photo: "images/builds/white-4080s.jpg",
  //   post: "https://www.facebook.com/etech.computer.7/posts/...",
  //   specs: ["Ryzen 7 7800X3D", "RTX 4080 Super", "32GB DDR5", "360mm AIO"],
  // },
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
