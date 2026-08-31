// ============================================================
// Start-up.
//
// This is the last script on every page. By the time it runs, all the
// other files have defined their functions, so it can safely kick off
// the two requests every page needs:
//
//   1. the product catalogue   (loadProducts, in products.js)
//   2. who is signed in        (loadSession, in auth.js)
//
// Both go out at the same time rather than one after the other. When
// they have both come back — and the HTML is parsed — everything
// queued with onAppReady() runs.
// ============================================================

loadProducts();

loadSession().finally(() => {
  sessionLoaded = true;
  runReadyCallbacks();
});

document.addEventListener("DOMContentLoaded", runReadyCallbacks);
