// Home page motion: each section rises in as it scrolls into view, and
// a product grid's cards come in one after another the first time the
// grid fills. The hero's entrance is CSS (style.css, "the 3D band") and
// the 3D scene is hero3d.js; neither is touched here.
//
// Motion (js/vendor/motion.js) does the animating. Three rules:
//   * Reduced motion asked for: nothing here runs.
//   * Nothing is hidden until Motion has loaded, and only what is still
//     below the fold, so the page never blinks and a failed script
//     leaves every product on show.
//   * A grid animates only the first time it fills. Ticking a wishlist
//     heart re-renders Featured, and that must not replay the entrance.

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

  const sections = Array.from(document.querySelectorAll("main.home section.section"));
  const grids = Array.from(document.querySelectorAll("main.home .product-grid, main.home .builds-grid"));
  const waiting = new Set();     // sections hidden below the fold, not yet shown
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

  const cardsOf = (grid) => Array.from(grid.children);

  function showCards(grid) {
    enter(cardsOf(grid), stagger(CARD_GAP));
  }

  function gridFilled(grid) {
    if (filled.has(grid) || grid.children.length === 0) return;
    filled.add(grid);

    // Its section will bring the cards in when it is reached.
    if (waiting.has(grid.closest("section"))) return;

    if (belowFold(grid)) {
      cardsOf(grid).forEach((card) => { card.style.opacity = "0"; });
      inView(grid, () => { showCards(grid); }, { margin: "0px 0px -10% 0px" });
    } else {
      showCards(grid);
    }
  }

  const shown = new Set();       // sections already brought in

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
      section.querySelectorAll(".product-grid, .builds-grid").forEach((grid) => {
        if (filled.has(grid)) enter(cardsOf(grid), stagger(CARD_GAP, { startDelay: CARD_GAP * 2 }));
      });
    }, { margin: "0px 0px -10% 0px" });
  }

  // The products arrive after this runs, and they push the lower sections
  // down. So the check runs again whenever the page grows; a section only
  // ever gets hidden once it is out of sight, so nothing blinks.
  sections.forEach(holdBelowFold);
  new ResizeObserver(() => sections.forEach(holdBelowFold)).observe(document.body);

  grids.forEach((grid) => {
    gridFilled(grid);
    new MutationObserver(() => gridFilled(grid)).observe(grid, { childList: true });
  });
})();
