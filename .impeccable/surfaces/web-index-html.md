---
version: 1
slug: "web-index-html"
primary_target: "web/index.html"
related_targets: ["web/shop.html","web/build.html","web/cart.html","web/checkout.html"]
---

# Customer shop (web) — surface brief

Scope: every customer page in `web/` (home, shop, product modal, builder, prebuilt, prebuilt-detail, rigs,
deals, wishlist, cart, checkout, orders, profile, auth pages, info/service/contact/privacy). Mode: Operate.
The Android app (`mobile/`) takes the same world as accents only, in native Material 3 controls.

Audience and job: Student, Gamer and Enterprise customers find a part or a PC, compare, add to cart and
check out (collection or delivery). Order of care: Home → Shop + product → Builder + prebuilt → Cart + checkout.
Constraints: PRODUCT.md (no invented proof, missing photos must look deliberate, CSP font-src 'self',
behaviour events must keep firing). User's one hard "wrong": still looking AI-made.

## Direction contract

THESIS: The shop speaks in receipt grammar. Prices are dot-leadered to a right edge in tabular figures,
the cart prints line by line like a till roll as you shop, and an order ends as a real receipt with its
code. Refuses the category default: centred hero banner, identical red-button cards, marketplace carousel.

OWN-WORLD: Cool thermal-paper white ground (#f6f6f2), thermal black ink (#1c1c1e), faded grey for
secondary. Shell and primary actions in blue PAID-stamp ink (#2448a8). Pink end-of-roll stripe (#d43a7a)
is the alert colour, used only for change: price dropped, back in stock, order moved. Each top-level
category owns one full-strength section hue on its tab, chips and card edge strip. Type: Archivo
(variable width) for UI and display, condensed caps for receipt headers; Azeret Mono only for data:
prices, codes, quantities, totals. Torn/perforated edges appear only on receipt surfaces (cart strip,
checkout summary, order). No radius above 4px; no glass, no gradients.

STORY: The visitor sees a real local shop at once: search, aisles, today's picks and the workshop's own
rigs. They trust the numbers because every price lines up like a receipt, and they act: add to cart and
watch it print.

FIRST VIEWPORT: Blue stamp-ink header: eTech wordmark left, wide search centre, wishlist/cart/account
right; under it the category aisle strip in section hues. Main area: left two-thirds "Picked for you"
(or "Popular this week" when signed out) as a tight product grid with mono RM prices; right third the
receipt strip: the live cart as a till roll with a total and Checkout (bottom sheet on phones). Built by
eTech rigs follow below the fold as a photo row.

FORM: Shop Receipt, position 7 of the round-2 grounded list; seed key 507a576a (re-roll 1).
Raises: section hues (acetate manual); reserved path colour for current builder/checkout step
(orienteering); visible catalogue code per product, same code on the receipt (factory catalogue);
price is the biggest thing on a card (type specimen); isolated destructive actions (console).

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
