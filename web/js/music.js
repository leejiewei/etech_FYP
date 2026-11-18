// Background music for the customer shop.
//
// One looping track, played quietly. The header's Music button turns it
// on and off, and the choice is kept in this browser. It is on until the
// customer turns it off.
//
// Browsers do not let a page start sound by itself: Chrome, Safari and
// Firefox all block it until the visitor has clicked, tapped or pressed
// a key on the site. So the music starts on the customer's first click
// anywhere on the page, not the instant the page opens. That is the
// browser's rule, not a bug.
//
// The shop is separate pages, so each page load starts a new player.
// The position is kept for the visit (sessionStorage) and the next page
// carries on from where the last one stopped, with a short gap while
// it loads.
//
// TO CHANGE THE SONG: replace web/audio/bgm.mp3 (keep the name), or
// point MUSIC_SRC below at the new file.

(function () {
  const MUSIC_SRC = "audio/bgm.mp3";
  const VOLUME = 0.25;
  const PREF_KEY = "etech-music";   // "on" | "off", localStorage
  const POS_KEY = "etech-music-pos"; // seconds into the track, sessionStorage

  function wanted() {
    try { return localStorage.getItem(PREF_KEY) !== "off"; } catch (e) { return true; }
  }
  function remember(on) {
    try { localStorage.setItem(PREF_KEY, on ? "on" : "off"); } catch (e) { /* still toggles */ }
  }

  const audio = new Audio();
  audio.src = MUSIC_SRC;
  audio.loop = true;
  audio.volume = VOLUME;
  audio.preload = "auto";

  let available = true;

  audio.addEventListener("loadedmetadata", () => {
    let pos = 0;
    try { pos = parseFloat(sessionStorage.getItem(POS_KEY)) || 0; } catch (e) { /* start at 0 */ }
    if (pos > 0 && pos < audio.duration) audio.currentTime = pos;
  });

  // No song file on the server: hide the button rather than show one
  // that does nothing.
  audio.addEventListener("error", () => {
    available = false;
    sync();
  });

  function savePosition() {
    try { sessionStorage.setItem(POS_KEY, String(audio.currentTime || 0)); } catch (e) { /* ignore */ }
  }
  let lastSave = 0;
  audio.addEventListener("timeupdate", () => {
    const now = Date.now();
    if (now - lastSave > 2000) { lastSave = now; savePosition(); }
  });
  window.addEventListener("pagehide", savePosition);

  audio.addEventListener("play", sync);
  audio.addEventListener("pause", sync);

  function play() {
    if (!available) return;
    const p = audio.play();
    if (p && p.catch) p.catch(() => { /* blocked until the first click; see below */ });
  }

  function sync() {
    const on = !audio.paused;
    document.querySelectorAll("[data-music-toggle]").forEach((b) => {
      (b.closest("li") || b).hidden = !available;
      b.setAttribute("aria-pressed", String(on));
      b.setAttribute("aria-label", on ? "Turn music off" : "Turn music on");
      b.title = b.getAttribute("aria-label");
    });
  }

  // The first click, tap or key anywhere starts the music, if the
  // customer wants it. A click on the Music button itself is left to
  // the button.
  function firstGesture(e) {
    if (e.target && e.target.closest && e.target.closest("[data-music-toggle]")) return;
    stopListening();
    if (wanted()) play();
  }
  function stopListening() {
    ["pointerdown", "pointerup", "click", "keydown", "touchend"].forEach((t) =>
      document.removeEventListener(t, firstGesture, true));
  }
  ["pointerdown", "pointerup", "click", "keydown", "touchend"].forEach((t) =>
    document.addEventListener(t, firstGesture, true));

  // Try straight away too: a browser that has seen the customer use the
  // site before may allow it.
  if (wanted()) play();

  window.etechMusic = {
    toggle() {
      stopListening();
      if (audio.paused) {
        remember(true);
        play();
      } else {
        remember(false);
        audio.pause();
      }
    },
    sync,
  };
})();
