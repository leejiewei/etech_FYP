# Chapter 5 test cases: evidence from the 28 Oct audit

"Observed" is what was actually seen on 28 Oct 2026. Status is one of
**Passed**, **Failed** or **Not verified**. Nothing here was assumed.

How each test was run:
- **Browser (live)**: Playwright against https://etech-fyp.vercel.app.
- **Browser (mocked)**: the page is real, but the auth server's reply was faked so no account or email was created.
- **DB (rolled back)**: run in the live database as a real customer or staff member, inside a transaction that was always undone. No data was changed.
- **Unit**: `flutter test` (22 tests).

A screenshot marked "needed" still has to be taken by a person. None exist yet.

## A. Customer website

| ID | Test | Expected | Observed | Status | How | Screenshot needed |
|---|---|---|---|---|---|---|
| C01 | Register with valid details | Green "Account created successfully! Please check your email…" | Green box with that text | Passed | Browser (mocked) | Yes, real sign-up |
| C02 | Register with mismatched passwords | Red "Passwords do not match.", no green box | As expected | Passed | Browser (local, 28 Oct) | Yes |
| C03 | Register refused by server (weak password) | Red message, green box stays hidden | Red "That password is too easy to guess…" | Passed | Browser (mocked) | Optional |
| C04 | Log in with wrong password | "Incorrect email or password." | As expected | Passed | Browser (live) | Yes |
| C05 | Log in before confirming email | "Please verify your email…" + resend button | As expected | Passed | Browser (mocked) | Yes, with a real unconfirmed account |
| C06 | Open an expired confirmation link | "That confirmation link has expired…" + resend button | As expected | Passed | Browser (live) | Yes |
| C07 | Forgot password | Same message whatever the address | "If that address has an account, a link…" | Passed | Browser (mocked) | Yes |
| C08 | Open reset page without a link | Form not offered | "This page only works from the link in a password reset email." | Passed | Browser (live) | Optional |
| C09 | Reset password from a real email link | New password accepted, old sessions signed out | — | Not verified | Needs a real inbox | Yes |
| C10 | Search "rtx 5070" | Only matching products, with price, stock, photo | 13 results, all match, 0 broken images | Passed | Browser (live) | Yes |
| C11 | Search with no match | "No products match your filters." | As expected | Passed | Browser (live) | Optional |
| C12 | Filter Components > CPU + AMD + AM5 | 9 products (database count) | 9 products, same 9 names | Passed | Browser (live) + SQL | Yes (Fig 4.23) |
| C13 | Reload with filters set | Same 9 products, AM5 still ticked | As expected (`spec.socket=AM5` in URL) | Passed | Browser (live) | Optional |
| C14 | Only CPU spec filters shown for CPUs | Socket, Built-in Graphics, Cooler Included, RAM Type | As expected | Passed | Browser (local) | Optional |
| C15 | Wishlist add / remove / re-add | Toggles; never two rows for one product | Add true, remove true, 1 row after re-add | Passed | DB (rolled back) | Yes, in browser (Fig 4.24) |
| C16 | Wishlist page while signed out | "Please log in to see your wishlist." | As expected | Passed | Browser (live) | Optional |
| C17 | Add to cart while signed out | Asked to log in, cart stays 0 | "You need an account to add things to your cart." | Passed | Browser (live) | Optional |
| C18 | Checkout while signed out | Asked to log in | "Please log in to check out." | Passed | Browser (live) | Optional |
| C19 | Place order with PARTS10 on a CPU (RM 459.00) | Discount 45.90, total 413.10, Pending/PENDING | Exactly that | Passed | DB (rolled back) | Yes, real order |
| C20 | Coupon not valid / wrong category | Shopper told before ordering | Server ignores it silently (discount 0); **fixed** in `2b544e1`, the page now says why | Failed → fixed | DB + browser (local) | Yes, after the fix is live |
| C21 | PC Builder: Ryzen 5 5500 | Cooler optional, graphics card required | As expected | Passed | Browser (live) | Yes |
| C22 | PC Builder: Ryzen 7 9700X | Cooler required, graphics card optional | As expected | Passed | Browser (live) | Yes |
| C23 | PC Builder: RTX 5090 + 600W PSU | Critical "PSU too small" | "draws about 740W… only 600W" (critical) | Passed | Browser (live) | Yes |
| C24 | PC Builder: AM4-only cooler on AM5 CPU | Critical "won't mount" | As expected | Passed | Browser (live) | Optional |
| C25 | PC Builder: all 8 parts compatible | Add Build to Cart enabled, no criticals | As expected | Passed | Browser (live) | Yes |
| C26 | eTech AI build review | Real review under the parts | Review covering the bottleneck, power supply, cooler, memory and storage | Passed | Browser (live, 1 Gemini call) | Yes |
| C27 | Layout: chatbot left, Contact us right, review under parts | As agreed | As expected, no overlap at 1440px and 390px | Passed | Browser (live + local) | Optional |
| C28 | Powered by ASUS menu: hover, click, keyboard | Opens; Enter/ArrowDown/Escape work | As expected | Passed | Browser (live) | Yes |
| C29 | Powered by ASUS / ASUS Agent pages | Real products, prices, no broken images | 12 and 16 product cards, 0 broken | Passed | Browser (live) | Yes |
| C30 | Upload receipt to own order | Saved; payment stays PENDING (not approved) | As expected | Passed | DB (rolled back) | Yes, in browser |
| C31 | Bell, unread count, toast, mark read | Customer's own only | Mark-read works server side; UI not driven | Not verified (UI) | DB only | Yes (Fig 4.31) |

## B. Staff console

The staff pages were **not opened in a browser**: no staff login was available
for automated testing. Server logic was run as a real staff account (rolled back).

| ID | Test | Expected | Observed | Status | How | Screenshot needed |
|---|---|---|---|---|---|---|
| S01 | Dashboard data loads | All page queries succeed | Every column list the page requests works | Passed (server) | DB (rolled back) | Yes (Fig 4.33) |
| S02 | Revenue counts confirmed payments only | RM 1,666.00 confirmed + unchecked shown apart | Logic in place; card not viewed | Not verified (UI) | Code | Yes |
| S03 | Stock Alerts lists Ryzen 5 5500 (3 left, level 5) | In "Low and out of stock" | In the list | Passed (server) | DB (rolled back) | Yes (Fig 4.35) |
| S04 | Product Edit loads specs | Specs for product 2011 | 7 spec rows returned | Passed (server) | DB (rolled back) | Yes (Fig 4.38) |
| S05 | Add Brand / Category | Added, selected, green message | — | Not verified | Needs staff browser | Yes (Fig 4.39) |
| S06 | Deal audience count | i7-14700: 1 (saved) | 1, reason "saved" | Passed (server) | DB (rolled back) | Yes (Fig 4.36) |
| S07 | Skip a stage (Pending → Ready) | Refused | "Order #2 cannot go from Pending to Ready" | Passed | DB (rolled back) | Yes (Fig 4.21) |
| S08 | Hand over unpaid order (#23 → Collected) | Refused | "Approve the payment… first" | Passed | DB (rolled back) | Yes |
| S09 | Approve payment with no receipt | Refused | "There is no receipt to check yet." | Passed | DB (rolled back) | Optional |
| S10 | Staff edits orders table directly | Refused | "permission denied for table orders" | Passed | DB (rolled back) | No |
| S11 | Staff opens receipts | All receipts visible | 5 visible | Passed (server) | DB (rolled back) | Yes (Fig 4.34) |
| S12 | Approve payment → Processing + one "Payment received" | As described | — | Not verified | Needs staff browser + real order | Yes |
| S13 | Mark shipped / delivered → one message each | As described | — | Not verified | Same | Yes |

## C. Security

| ID | Test | Expected | Observed | Status | How |
|---|---|---|---|---|---|
| X01 | Customer sees only own orders | Own only | Customer A 1 of 9, customer B 7 of 9 | Passed | DB (rolled back) |
| X02 | Customer sees others' notifications / wishlist / profile / receipts | None | 0 / 0 / own row only / 0 | Passed | DB (rolled back) |
| X03 | Customer reads cost price | Refused | Refused | Passed | DB (rolled back) |
| X04 | Customer calls a staff function | "Staff access only." | As expected | Passed | DB (rolled back) |
| X05 | Visitor (not signed in) reads orders / customers / notifications | Refused | Permission denied on all three; 0 receipts | Passed | DB (rolled back) |
| X06 | Attach receipt to another customer's order | Refused | "That order could not be found." | Passed | DB (rolled back) |
| X07 | Attach a file from another account's folder | Refused | "That receipt does not belong to this account." | Passed | DB (rolled back) |
| X08 | Every table has RLS; every owner-rights function pins search_path | Yes | Yes (0 exceptions) | Passed | SQL |
| X09 | Supabase security advisor | No new issues | Only known items (see report) | Passed | Advisor |

## D. Flutter app

| ID | Test | Expected | Observed | Status | How |
|---|---|---|---|---|---|
| F01 | Builder rules (8 scenarios incl. RTX 5090 + 600W, office PC on built-in graphics) | As brief | 22/22 tests pass | Passed | Unit |
| F02 | Code analysis | No issues | No issues | Passed | `flutter analyze` |
| F03 | Sign-in, catalogue, cart, orders on a phone | Work | — | Not verified | No phone connected |
| F04 | Push notification arrives | Arrives on the phone | — | Not verified | No phone connected |
| F05 | Coupon warning in the app | Told before ordering | Analyzer clean; not run on a phone | Not verified | Code |
