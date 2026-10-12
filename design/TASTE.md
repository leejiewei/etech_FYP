# Taste

## Read this before writing any UI

Before you write markup, CSS or Flutter widgets for this project:

1. Read this file, then the `:root` block in `web/css/style.css` (web) or `mobile/lib/theme.dart` (app).
   Every colour, radius, size and duration you use must come from there. Never invent a hex, a px or a duration.
2. Open the images in `design/references/` and read its README.
3. Read `PRODUCT.md` for what the shop may and may not claim.

## What this project looks like: Shop Catalogue (since 12 Oct 2026)

eTech is a real local computer shop, and its site should look like a working shop's
catalogue, not a designed concept. The previous direction (Shop Receipt: mono prices,
dot leaders, torn receipt edges, a hue per aisle) read as AI-made and was retired.
A theme that announces itself is the tell; a catalogue that just works is not.

- **Plain and familiar.** System UI font, white cards on a light grey ground, grey hairlines.
  Nothing is a metaphor. A customer who has used Newegg, Scan or Shopee knows where everything is.
- **Photos and prices do the work.** The product photo sits on white; the price is the boldest
  thing on a card, in the UI font with tabular figures.
- **Labelled buttons.** "Add to cart" says so in words. Icons sit beside words, never alone, except
  the wishlist heart and header icons on phones.
- **One brand colour: the logo's red** (`--brand`, #bc2000, sampled from `etech logo.jfif`). It is the
  department bar, links, primary buttons and deal prices, the way a shop marks its own sales in its own
  colour; a struck-through old price is what tells a deal from a button. No other accent colour.
- **The logo** is the round red-and-white mark in `web/images/brand/` (transparent PNG, 64 to 512px),
  next to an italic red "eTech". Put it on white or near-black (`--ink`), never on red or maroon.
- **Green / amber / red stock** (`--ok`, `--warn`, `--danger`) as small text with a dot.
- Item number ("Item 206") is plain small grey text, the way a shop prints a SKU.
- Dense: a shop page shows many products per screen. Air goes between groups, not inside cards.
- Missing product photos must look deliberate, never broken.
- The Android app matches the web: same colours, same card anatomy, same type sizes.

## The local market we stand apart from

`design/references/00-avoid-*` are Malaysian PC shops and ROG: rig-photo hero banners,
carousels, stat counters, icon-circle "why us" rows, review sliders, dark neon. eTech stays
light, quiet and list-like. `01-sku-price-list-suncycle.png` is the one thing worth borrowing:
name, maker SKU on its own line, price aligned right.

## Banned by default

- Themes and metaphors in the UI (receipts, tickets, blueprints, terminals)
- Monospace type anywhere a customer reads it
- Dashed or dotted rules, dot leaders, torn or zigzag edges
- Gradient text and gradient backgrounds; glass / backdrop blur
- Emoji as icons (use SVG)
- Centred hero banner with a big CTA, marketplace carousels, stat counters
- Three-column feature card grids with an icon on top
- Condensed or stretched type, letter-spaced caps headings
- Any corner radius other than `--r` (4px)
- Drop shadows on anything that is not floating above the page (menus, modals, toasts)
- Invented proof: fake reviews, fake counts, fake "trusted by", warranty claims the shop didn't make
- Fonts from a CDN (CSP is `font-src 'self'`)

If a brief genuinely requires one of these, say so and ask first.

## Scales

Type is `--text-2xs` … `--text-4xl` (11 to 46px), space is `--space-0` … `--space-16`
(4px base), motion is `--dur-*` and `--ease-out`. Many older values in style.css are still
raw and off-scale. When you touch a rule that has one, move it to the nearest token.

## Checking your work

Run `/design-loop` on the page. It scores Type, Rhythm, Density, Restraint, Alignment,
Focus and Distinct and fixes the lowest one at a time.
