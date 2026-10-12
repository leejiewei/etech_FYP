# Taste

## Read this before writing any UI

Before you write markup, CSS or Flutter widgets for this project:

1. Open every image in `design/references/`. Look at them. Do not skip this.
2. Read the `:root` block in `web/css/style.css` (web) or `mobile/lib/theme.dart` (app).
   Every colour, radius and font you use must come from there. Never invent a hex, a px or a duration.
3. Read the direction contract in `.impeccable/surfaces/web-index-html.md` and `PRODUCT.md`.
4. Read any `*-DESIGN.md` in `design/references/` for component and state rules.

## What this project looks like: Shop Receipt

eTech is a real local computer shop, and the site speaks in receipt grammar.

- Prices are dot-leadered to a right edge in tabular figures. The price is the biggest thing on a product card.
- The cart prints line by line like a till roll; an order ends as a real receipt with its code.
- Every product shows its catalogue code ("No. ####"), and the same code appears on the receipt.
- Ground is cool thermal-paper white (`--paper`), text is thermal black (`--ink`).
- Blue PAID-stamp ink (`--stamp`) is the shell and primary actions. Nothing else.
- End-of-roll pink (`--roll`) means *something changed*: price dropped, back in stock, order moved. Never decoration.
- Amber (`--path`) marks the step the customer is on in the builder and checkout. Nothing else.
- Each top-level category owns one hue (`--hue-*`) on its tab, chips and card edge strip.
- Archivo for UI and display, condensed caps for receipt headers. Azeret Mono only for data:
  prices, codes, quantities, totals.
- Torn/perforated edges only on receipt surfaces (cart strip, checkout summary, order).
- Missing product photos must look deliberate, never broken.
- The Android app stays native Material 3; it borrows the colours and fonts as accents only.

## The local market we stand apart from

`design/references/00-avoid-*` are five Malaysian PC shops and ROG. They all
open with a rig-photo hero banner, then carousels, stat counters, icon-circle
"why us" rows and review sliders, mostly dark with neon. eTech must not be
mistakable for any of them. The one thing worth taking is in
`01-sku-price-list-suncycle.png`: maker SKU on its own line, price aligned right.

## Banned by default

- Gradient text and gradient backgrounds
- Glass / backdrop blur
- Emoji as icons (use SVG)
- Centred hero banner with a big CTA, identical red-button cards, marketplace carousels
- Three-column feature card grids with an icon on top
- Any corner radius other than `--r` (3px)
- Drop shadows on anything that is not floating above the page
- Mono type on anything that is not data
- Invented proof: fake reviews, fake counts, fake "trusted by", warranty claims the shop didn't make
- Fonts from a CDN (CSP is `font-src 'self'`; fonts live in `web/fonts/`)

If a brief genuinely requires one of these, say so and ask first.

## Scales

Type is `--text-2xs` … `--text-4xl` (11 to 46px), space is `--space-0` … `--space-16`
(4px base), motion is `--dur-*` and `--ease-out`. About 250 older values in style.css
are still raw and off-scale (10px, 14px, 18px, 13.5px…). When you touch a rule that
has one, move it to the nearest token and check the page didn't shift.

## Checking your work

Run `/design-loop` on the page. It scores Type, Rhythm, Density, Restraint,
Alignment and Focus and fixes the lowest one at a time.

Use playwright-cli to screenshot the page at desktop (1440px) and phone (390px) widths into
`design/screenshots/`, then compare against `design/references/` before calling it done.
