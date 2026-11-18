// Light and dark mode for the customer shop.
//
// Loaded in <head>, before the stylesheet paints, so a customer who
// chose dark never sees a white flash between pages. It sets
// data-theme="light" or "dark" on <html>; style.css swaps its colour
// tokens on that attribute and every rule follows.
//
// Until the customer presses the switch, the shop follows the device's
// own light/dark setting. Once they press it, their choice is kept in
// this browser (localStorage) and wins over the device.

(function () {
  const KEY = "etech-theme";

  function stored() {
    try {
      const v = localStorage.getItem(KEY);
      return v === "light" || v === "dark" ? v : null;
    } catch (e) {
      return null;
    }
  }

  const deviceDark = window.matchMedia ? window.matchMedia("(prefers-color-scheme: dark)") : null;

  function current() {
    return stored() || (deviceDark && deviceDark.matches ? "dark" : "light");
  }

  function apply(theme) {
    document.documentElement.setAttribute("data-theme", theme);
    document.querySelectorAll("[data-theme-toggle]").forEach((b) => {
      b.setAttribute("aria-pressed", String(theme === "dark"));
      b.setAttribute("aria-label", theme === "dark" ? "Switch to light mode" : "Switch to dark mode");
      b.title = b.getAttribute("aria-label");
    });
  }

  apply(current());

  // The device switched between light and dark while the page was open,
  // and the customer has not picked one themselves: follow it.
  if (deviceDark && deviceDark.addEventListener) {
    deviceDark.addEventListener("change", () => {
      if (!stored()) apply(current());
    });
  }

  window.etechTheme = {
    get: current,
    toggle() {
      const next = current() === "dark" ? "light" : "dark";
      try { localStorage.setItem(KEY, next); } catch (e) { /* private window: still switches */ }
      apply(next);
    },
    // layout.js calls this after drawing the header, so the new button
    // shows the right icon straight away.
    sync() { apply(current()); },
  };
})();
