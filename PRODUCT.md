# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

The same shop also ships a native Android app (Flutter, `mobile/`), which has its own record in
`mobile/PRODUCT.md`. Since 12 Oct 2026 the two share one design language too (Shop Catalogue, design/TASTE.md).

## Users

Customers of eTech, a computer shop in Malaysia, shopping online. At sign-up every account
picks one of three roles: **Student**, **Gamer** or **Enterprise**. The redesign serves all three
equally (confirmed 9 Oct 2026); none is the default persona.

The site is also the data source for a Final Year Project: recruited beta testers sign in and
shop, and what they view, wishlist, add to cart and buy is the study's dataset (Objective 1).

## Product Purpose

Let a customer find, compare and order computer parts, complete PCs, laptops and peripherals,
or plan a custom build, then collect in store or have it delivered. Success: a customer finds
the right product quickly and finishes checkout; for the FYP, signed-in testers browse freely
enough that their behaviour is meaningful.

## Positioning

A real local shop's own catalogue, not a marketplace: products and links are checked against
the physical shop, prices are in RM, links point to Malaysian maker pages, and the shop's own
workshop rigs ("Built by eTech") are photographed and posted on its Facebook page.

## Operating Context

- Pages: home, shop (catalogue with brand and category filters), product specs, PC builder with
  compatibility checking, prebuilt PCs and their detail pages, workshop rigs, deals, wishlist,
  cart, checkout (collection or delivery), orders, profile, login/register/password reset,
  info, service, contact, privacy policy.
- An AI chat advisor (Gemini, via a Supabase Edge Function) answers build and product questions.
- "Picked for you" personalised recommendations on the home page for signed-in customers;
  deal alerts and order notifications (bell + toast on web, push on Android).
- A privacy notice banner on first visit explains that browsing is recorded for the project.

## Capabilities and Constraints

- Static HTML/CSS/JS in `web/`, deployed on Vercel (`etech-fyp.vercel.app`); data from Supabase,
  called directly from the browser. No server of our own, and no database structure changes
  as part of design work.
- One stylesheet, `web/css/style.css`; shared header/footer built by `web/js/layout.js`.
- Product images must be full Vercel URLs in `image_path`; many products still lack photos, so
  every product surface must look right with no image.
- Catalogue is large (several hundred products across ~24 categories), so the shop page needs
  real navigation, not one endless grid.
- Payment is a placeholder: nothing is charged and no order is really fulfilled.
- Security headers include a Content-Security-Policy (`vercel.json`): new external scripts,
  fonts or images need a CSP change.

## Brand Commitments

- The name **eTech** must stay. Nothing else of the current look is binding: colour (currently
  red/maroon), type and layout may all change (confirmed 9 Oct 2026).
- The user judges the current design as looking generic and AI-made; that look is an
  anti-reference.

## Evidence on Hand

- Real workshop rig photos (Built by eTech) with Facebook post links.
- Real product photos on Vercel (`web/images/products/`) for most, not all, products.
- Reviews and numbers on the home page (15 Oct 2026, the user's call): six real 5-star Google
  reviews copied word for word under five stars (no average is shown;
  Google's is 4.4), and the shop's own figures
  (20+ years, 1,000+ PCs built, 100% new parts). Nothing else of the kind: no invented
  testimonials, ratings, awards or sales figures, and the data agreement still bars customer
  data, supplier details, cost prices and margins.

## Product Principles

1. Finding the right part beats being impressed: search, filter and compare come first.
2. Show only true things: real photos, real stock, real Malaysian links; never invented proof.
3. A missing photo or empty state must still look deliberate.
4. Same content and features on phone and desktop; the phone is a first-class shop.
5. Don't break the behaviour capture the FYP depends on (views, wishlist, cart, purchase events).
