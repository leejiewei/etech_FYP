// Cards and sections coming in. A grid's cards rise in one after another
// the first time the grid fills, and on the home page each lower section
// rises in as it scrolls into view. Loaded on the home page and the pages
// built around a product grid (shop, deals, prebuilt, rigs, wishlist).
//
// The page itself rising in, the home hero's entrance, and the 3D scene
// (hero3d.js) are CSS and other scripts; none of them is touched here.
//
// Motion (js/vendor/motion.js) does the animating. Four rules:
//   * Reduced motion asked for: nothing here runs.
//   * Nothing is hidden until Motion has loaded, and only what is still
//     below the fold, so the page never blinks and a failed script
//     leaves every product on show.
//   * A grid animates only the first time it fills. Ticking a wishlist
//     heart or a shop filter re-renders a grid, and that must not replay.
//   * Only the first screenful of cards animates. The shop holds over 500;
//     the rest are off screen anyway and simply sit there.

(function () {
  if (typeof Motion === "undefined") return;
  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

  const { animate, inView, stagger } = Motion;

  // Timing and distance come from the :root tokens in style.css, so the
  // site has one set of numbers. Motion takes seconds and bezier arrays.
  const root = getComputedStyle(document.documentElement);
  const seconds = (name) => parseFloat(root.getPropertyValue(name)) / 1000;
  const DURATION = seconds("--dur-slow");
  const CARD_GAP = seconds("--dur-fast") / 4;
  const EASE = (root.getPropertyValue("--ease-out").match(/[\d.]+/g) || [0.2, 0.7, 0.2, 1]).map(Number);
  const RISE = `translateY(${root.getPropertyValue("--space-3").trim()})`;
  const ENTER = { opacity: [0, 1], transform: [RISE, "none"] };
  const FIRST_SCREEN = 12;       // cards brought in when a grid is reached from below

  const GRIDS = ".product-grid, .builds-grid, .prebuilt-grid, .rig-grid, .deal-grid";
  const sections = Array.from(document.querySelectorAll("main.home section.section"));
  const grids = Array.from(document.querySelectorAll(GRIDS));
  const waiting = new Set();     // sections hidden below the fold, not yet shown
  const shown = new Set();       // sections already brought in
  const filled = new WeakSet();  // grids whose first fill has been handled

  const belowFold = (el) => el.getBoundingClientRect().top > window.innerHeight;

  // Once the animation is over, the element goes back to its own CSS, so
  // hover transforms (the build cards lift) work as before. A frame later,
  // because Motion writes its last frame inline just after it resolves.
  function enter(elements, delay) {
    if (elements.length === 0) return;
    animate(elements, ENTER, { duration: DURATION, ease: EASE, delay }).then(() => {
      requestAnimationFrame(() => {
        elements.forEach((el) => { el.style.opacity = ""; el.style.transform = ""; });
      });
    });
  }

  // The cards that can be seen right now.
  const cardsInView = (grid) => Array.from(grid.children).filter((card) => !belowFold(card));
  const firstCards = (grid) => Array.from(grid.children).slice(0, FIRST_SCREEN);

  function gridFilled(grid) {
    if (filled.has(grid) || grid.children.length === 0) return;
    filled.add(grid);

    // Its section will bring the cards in when it is reached.
    if (waiting.has(grid.closest("section"))) return;

    if (belowFold(grid)) {
      const cards = firstCards(grid);
      cards.forEach((card) => { card.style.opacity = "0"; });
      inView(grid, () => { enter(cards, stagger(CARD_GAP)); }, { margin: "0px 0px -10% 0px" });
    } else {
      enter(cardsInView(grid), stagger(CARD_GAP));
    }
  }

  function holdBelowFold(section) {
    // Hidden sections (Picked for you, Recently viewed) have no position
    // yet; their cards are handled when the grid fills.
    if (section.hidden || shown.has(section) || waiting.has(section) || !belowFold(section)) return;

    section.style.opacity = "0";
    waiting.add(section);
    inView(section, () => {
      waiting.delete(section);
      shown.add(section);
      enter([section], 0);
      section.querySelectorAll(GRIDS).forEach((grid) => {
        if (filled.has(grid)) enter(firstCards(grid), stagger(CARD_GAP, { startDelay: CARD_GAP * 2 }));
      });
    }, { margin: "0px 0px -10% 0px" });
  }

  // The products arrive after this runs, and they push the lower sections
  // down. So the check runs again whenever the page grows; a section only
  // ever gets hidden once it is out of sight, so nothing blinks.
  if (sections.length > 0) {
    sections.forEach(holdBelowFold);
    new ResizeObserver(() => sections.forEach(holdBelowFold)).observe(document.body);
  }

  grids.forEach((grid) => {
    gridFilled(grid);
    new MutationObserver(() => gridFilled(grid)).observe(grid, { childList: true });
  });
})();
