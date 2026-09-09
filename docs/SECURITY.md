# Security controls — eTech

What is in place, where it lives, and what is deliberately not done.

Written against the twenty-item review of 4 September 2026, plus email
verification added on 5 September. Each item is
recorded whether it needed work or not, because "already done" and "does
not apply here" are answers a reviewer needs as much as "fixed".

## The shape of the system, which decides most of the answers

There is no server of ours. The website is static files on Vercel and the
Flutter app is a binary on a phone; both talk to Supabase (Postgres,
Auth, Storage) directly, and one Supabase Edge Function holds the Gemini
key for the chatbot. What used to be `web/api/*.php` and
`web/admin/*.php` is now Row Level Security policies and `SECURITY
DEFINER` functions inside the database.

That has two consequences that run through everything below:

- **The publishable key is public on purpose.** It grants nothing on its
  own. Every request it makes arrives at Postgres as `anon`, and the
  policies decide what `anon` may see. The key that must never ship is
  `service_role`, and it does not.
- **There is no session cookie.** Being signed in is a bearer token in
  `localStorage`, sent in an `Authorization` header by our own code.
  Nothing is attached to a request automatically, which is why items 2
  and 19 read the way they do.

---

## 1. HSTS — done

`vercel.json`, applied to every response:

```
Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
```

Alongside it, and for the same cost: `Content-Security-Policy`,
`X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`,
`Referrer-Policy`, `Permissions-Policy`, `Cross-Origin-Opener-Policy`.

The CSP allows `'unsafe-inline'` for scripts. That is not a decision so
much as a description: eight pages carry an inline `<script>` block and
six use inline `onclick`/`onchange` handlers, and a CSP without
`'unsafe-inline'` would break all of them. It still restricts `connect-src`
to our own Supabase project, forbids `object-src`, pins `base-uri` and
`form-action`, and sets `frame-ancestors 'none'`. Removing
`'unsafe-inline'` means moving those handlers into the `.js` files first;
worth doing, not done here.

## 2. CSRF tokens — does not apply, and here is why

A CSRF token defends a request that the browser authorises **by itself**.
That is a cookie: the browser attaches it to any request to the site,
including one triggered by a form on somebody else's page, so the server
needs a second secret the other page cannot know.

Nothing here works that way. The Supabase session is a token in
`localStorage`, read by our own JavaScript and put into an
`Authorization` header. A form on `evil.example` posting to our Supabase
project sends no token at all and arrives as `anon`. There is nothing for
a CSRF token to add.

What *is* real from the same family, and is done: **clickjacking**. Our
pages carry the session, so framing one and tricking a signed-in customer
into clicking through it would work. `X-Frame-Options: DENY` and
`frame-ancestors 'none'` in `vercel.json` close it.

## 3. Reset sessions on password change — done

Two halves, because there was no password-change flow at all before this.

- `changePassword()` in `web/js/auth.js`, and a form on `profile.html`.
  It re-authenticates with the current password, calls `updateUser`, then
  `signOut({ scope: "others" })`.
- `secure_password_change = true` in `supabase/config.toml`, so Auth
  enforces the re-authentication too.

The `signOut({ scope: "others" })` is the point of the item. Supabase
sessions are independent signed tokens that refresh themselves; changing
a password does **not** invalidate them. Without that line, a customer
who changes their password *because* somebody else is in their account
achieves nothing — the intruder's session carries on refreshing. `others`
rather than `global` so the customer is not signed out of the page they
are standing on.

## 4. Expire reset links — done

`auth.email.otp_expiry` in `supabase/config.toml`: `3600` → `900`.

An hour is a long time for a password-reset link to sit in an inbox, a
mail log, or a forwarded message. Fifteen minutes is enough to walk to
the machine.

## 5. Prevent user enumeration — done

`registerError()` in `web/js/auth.js` said "An account with this email
already exists." That was the one place on the site that would confirm
whether a given person shops here — type an address, read the answer,
repeat. It now returns the same sentence for a duplicate as for a fault,
and points at the login page. `register()` in
`mobile/lib/services/shop.dart` had the identical leak and also returned
Supabase's raw message; both are fixed.

The sign-in page never had the problem — it answers "Incorrect email or
password." to both a wrong password and an unknown address — and
`hook_password_verification_attempt` deliberately keeps that true.

**This is now fully closed by item 21 below.** Supabase Auth's own HTTP
response to a sign-up used to differ for a known address while email
confirmations were off; with confirmation on, both answers look the same.
The client-side wording above still matters — it is the half that does
not depend on a Dashboard setting staying switched on.

## 6. Whitelist upload types — already done, verified

The `product-images` bucket, checked live:

```
allowed_mime_types: image/jpeg, image/png, image/webp
file_size_limit:    5242880 (5MB)
```

with `INSERT`/`UPDATE`/`DELETE` policies all gated on `is_admin()`. The
admin page additionally re-encodes every upload through a canvas to JPEG
before sending, which destroys anything hidden in the original file. The
existing comment in `product_edit.js` already says the browser checks are
for the person using the page and the bucket is the rule, which is the
right way round. Nothing to change.

## 7. Verify payment webhooks — not applicable, no gateway

Checkout is a mock. `web/checkout.html` says "Mock Payment (sandbox — not
a real gateway)" on the page, the card number is a 16-digit format check
and nothing else, and no money moves. There is no gateway, so there is no
webhook to verify.

**When one is added**, the three things this item is asking for:

1. Verify the provider's signature over the **raw** request body, before
   parsing it. Any framework that hands you a parsed object has already
   changed the bytes the signature covers.
2. Treat the webhook as the only source of "paid". A client saying it
   paid is a client saying anything.
3. Make it idempotent on the provider's event id — gateways retry, and a
   retry must not fulfil an order twice.

An Edge Function is where this would live, for the same reason the Gemini
key does.

## 8. Set prices server side — already done, verified

`place_order()` takes `(name, phone, address, coupon)` and no money at
all. It computes the subtotal from `products.price` and
`prebuilt_upgrades.price_delta`, validates the coupon against `coupons`
including its date window, and writes `order_items` from the same rows.
`INSERT`/`UPDATE`/`DELETE` on `orders` and `order_items` are revoked from
every client role, so a shopper cannot name their own total by any route.

## 9. Block prompt injection — done

`supabase/functions/chat-advisor/index.ts`:

- The customer's message goes inside a named fence, and rule 0 of the
  system instruction says everything between the markers is data.
- `asData()` strips the fence spelling, leading role labels
  (`system:`, `assistant:`), and control characters from anything that
  arrives from a client.
- **`history` is the vector that mattered most.** The client sends the
  previous turns back and nothing proved the model ever said them, so a
  forged `{role: "bot", text: "..."}` was a way of putting words in the
  model's own mouth. Turns are now re-labelled from a fixed pair of
  roles, capped, and sanitised, and rule 0 says prior turns attributed to
  the model are not proof it said anything.

The load-bearing controls remain the ones that do not depend on the model
behaving: it returns product **ids** only, `stripUnreliable()` deletes any
sentence containing a price or a stock claim, and both clients render
prices from our own rows. A fully captured model still cannot make the
shop quote a price it will not honour.

## 10. Cap AI usage — the in-memory limit does not fire

Rate limiting in the same function: 8 calls per caller per minute, 120 per
isolate per minute, keyed on the session token when there is one and the
forwarded IP otherwise. `429` with `Retry-After`.

**Measured on 2026-09-07 against the deployed function, and it never
trips.** Forty-two authorised calls in about two minutes from one address
-- eight sequential, twenty in parallel, then twelve down a single
keep-alive connection -- produced not one `429`, and every response
carried a different `x-deno-execution-id`.

The counters are module-level, so they only accumulate while an isolate
is reused. On this project's traffic each request appears to get a fresh
isolate, which resets both buckets to zero. This was written expecting a
weakened limit -- "a brake, not a cap". The measurement says it is not
even a brake, and the code should not be described as rate limited.

The cap that cannot be got round by any request pattern is the spending
limit on the Google side, and until that is set nothing bounds this bill.
A limit that actually held would have to count somewhere outside the
isolate -- a table with an RPC, keyed on the user or the address -- which
is a schema change and has not been made.

## 11. Limit request size — done

`readBody()` in the same function. `Content-Length` is checked first
because it is free, then the body is read through a counter that stops at
16KB whether the header was accurate or absent. Message capped at 1000
characters, history at 6 turns of 1000. Over-size gets `413`.

## 12. Rate limit password resets — done

`auth.email.max_frequency` in `supabase/config.toml`: `1s` → `60s`, under
the existing `auth.rate_limit.email_sent = 2` per hour.

One second is no limit: a script could fill a stranger's inbox and,
because each new link invalidates the last, keep the real owner from ever
using one.

## 13. Sanitize before storing — done, as *escape on output*

The item says "before storing"; the fix is at output, and that is
deliberate. Escaping on the way in means the database holds HTML entities
instead of text, which breaks search, sorting and the mobile app, and
still fails wherever a value reaches a different context. Escaping at the
point of rendering is correct once and stays correct.

`web/js/escape.js` is new: `escapeHtml()` and `safeUrl()`, loaded on every
page. Applied through `ui.js`, `cart.js`, `compare.js`, `deals.js`,
`prebuilt.js`, `build.js`, `layout.js`, `shop.js`, `checkout.js`,
`chatbot.js` and `advisor.js`. The staff console already escaped its
output via `e()` and was not the gap; the shop front was.

`safeUrl()` exists because escaping quotes does nothing about
`javascript:` as a scheme — `<img src="javascript:...">` contains no quote
to escape. `products.image_path` is typed into the admin panel and lands
in a `src` attribute, so it goes through it. `data:image/svg+xml` is
refused along with everything else unrecognised: an SVG can carry a
`<script>`.

Verified in a browser against the real render path: a product named
``PWNED <img src=x onerror=...>`` with `image_path` of `javascript:...`
renders as visible text, creates no element, and fires neither payload.

**Who could have exploited it:** the catalogue is written by staff, so
this was never reachable by the public directly. It matters because "only
an admin can do it" is one compromised staff password away from "anyone
can", and the payload would then be stored and served to every visitor.

## 14. Lock down CORS — done

`chat-advisor` answered `Access-Control-Allow-Origin: *`, so any page on
the internet could embed our chatbot and our Gemini bill. It now echoes
the origin only when it is on an allowlist (`ALLOWED_ORIGINS`, plus
localhost for development).

A request with **no** `Origin` header is still served: that is the Flutter
app and `curl`, neither of which is a browser and neither of which CORS
was ever able to constrain. CORS is a rule browsers enforce on pages, not
a door lock — item 10 is what protects the bill.

Supabase's own PostgREST/Auth CORS is separate and is governed by the
project's allowed origins in the Dashboard.

## 15. Disable directory listing — satisfied by the platform, dead file removed

Vercel does not list directories; a directory path with no `index.html`
returns 404. There is no configuration to set.

`web/uploads/` was removed. It had been empty since product photos moved
to Supabase Storage, and its only content was an `.htaccess` carrying
`Options -Indexes` and a PHP-execution block — an Apache file on a host
that never reads it. Leaving a security control in place that does
nothing is worse than not having it, because a review counts it.

## 16. Remove default admin route — done

`web/admin/` → `web/staff-console/`. The one link to it
(`web/login.html:61`) was updated; every page inside uses `../`-relative
paths at the same depth, so nothing else moved. `vercel.json` adds
`X-Robots-Tag: noindex, nofollow, noarchive` and `Cache-Control: no-store`
to that path.

This is obscurity and is worth naming as such: any static path is
enumerable, and the control that actually matters is that
`staff-console/js/admin.js` gates on `is_admin()` and every policy behind
it does too. It removes the panel from the first page of guesses, nothing
more.

## 17. Lock accounts after failed login — done

`hook_password_verification_attempt` in
`supabase/migrations/20260904140000_security_hardening.sql`.
Five failures in fifteen minutes locks the account for fifteen; a
successful sign-in clears the count.

**Why it is an Auth hook and not a check in the login page.** The obvious
version — ask the database whether the account is locked before calling
`signInWithPassword` — is worth nothing, because the browser is the
attacker's own code and they would call Auth directly and never ask. The
password verification hook runs *inside* Auth, on every password check,
and a decision returned from it is one no client can skip.

Supabase's built-in limit is 30 sign-in requests per five minutes per IP.
That is not an account lockout: it is over eight thousand guesses a day
from one address, there is no shortage of addresses, and it is indifferent
to *which* account is being guessed.

The lock is tested before `valid` is read, so a locked account stays
locked even when the attacker finally guesses right.

`login_attempts` — a MySQL-era table nothing had written to since the PHP
was removed — is reshaped to key on the auth user id and back this.

**Needs one manual step:** Dashboard → Authentication → Hooks → Password
Verification Attempt → Postgres → `public.hook_password_verification_attempt`.
Until then the function exists and never runs.

## 18. Log security events — done

`security_events` in the same migration, plus `log_security_event()` and
four triggers.

Recorded: failed sign-ins and lockouts; changes to who is staff; product
price and visibility changes; order status changes; coupon changes.
Browsing is already in `events` and is not security.

Staff can read it. **Nothing can write it through the API** — no `INSERT`
policy, no `INSERT` grant, and `EXECUTE` on `log_security_event()` revoked
from `anon` and `authenticated`. Rows arrive only from `SECURITY DEFINER`
functions and triggers, which is what makes the trail worth reading: a
client that could write here could write a false entry, or flood the table
until the real one scrolled off.

Triggers rather than calls added to each function, for the same reason —
a trigger cannot be gone round.

## 19. Set secure cookie flags — does not apply

There are no cookies. `grep document.cookie` across `web/js`,
`web/staff-console/js` and `mobile/lib` returns nothing. The session is a
token in `localStorage` under `etech-auth` (`etech-admin-auth` for staff,
a separate key on purpose so signing in as staff in one tab does not sign
a customer out in another).

`Secure`, `HttpOnly` and `SameSite` have nothing to attach to.

**The trade-off, stated rather than skipped:** `localStorage` is readable
by JavaScript, so an XSS gets the token — which an `HttpOnly` cookie would
not give up. That is precisely why item 13 was worth doing, and why the
CSP is set. The alternative — cookie-based sessions — would need a server
of ours to set them, which is the architecture this project deliberately
left behind, and would bring item 2 back with it.

## 20. Restrict database permissions — done

In the migration:

- `EXECUTE` revoked from `anon` and `authenticated` on
  `handle_new_auth_user()`, `prebuilt_parts_changed()` and
  `prebuilt_stock_follows_parts()`. All three are **trigger** functions:
  they need no `EXECUTE` grant at all, and the default one did nothing
  except publish them at `/rest/v1/rpc/<name>` where anyone holding the
  publishable key could call them.
- `recompute_prebuilt_stock()` restricted to `authenticated` (the admin
  Prebuilt Parts page calls it; it rewrites stock on the prebuilt
  machines).
- `admin_dashboard` and `admin_products` revoked from `anon`.
- `ALTER DEFAULT PRIVILEGES ... REVOKE EXECUTE ON FUNCTIONS FROM anon`, so
  the next migration to add a function does not silently reopen this.

This continues the pass `20260828005426_revoke_anon_defaults.sql` did for
the functions that existed then; the four above arrived later, with the
Supabase default grant still attached.

### Advisor findings deliberately left as they are

- **`admin_dashboard` / `admin_products` are `SECURITY DEFINER` views
  (reported as ERROR).** Intentional. They exist to show `cost_price` and
  `stock_qty`, which are revoked from every client role precisely so a
  shopper cannot read the shop's margins — a `security_invoker` view could
  not read them either. Both carry `WHERE (SELECT public.is_admin())`, so a
  non-admin gets zero rows. The mechanism is the finding and the mechanism
  is the point.
- **`login_attempts` has RLS on with no policy (reported as INFO).** That
  is the intent: "nobody, by any route that respects RLS". Auth reaches it
  as `supabase_auth_admin`, which is not subject to policies.
- **`current_customer_id()` callable by `anon` (WARN).** Deliberate and
  documented in `20260828005426`. The `anon` INSERT policies on `events`
  and `chatbot_logs` call it in their `WITH CHECK`, and a policy expression
  runs with the caller's privileges — revoking it would stop a logged-out
  visitor being tracked or using the chatbot. It returns NULL for `anon`,
  which is what those policies expect.
- **`admin_*` functions callable by `authenticated` (WARN).** Each checks
  `is_admin()` before doing anything and returns nothing, or raises
  `Staff access only.`, otherwise. This is the intended pattern; the
  advisor cannot see inside the body.

## 21. Email verification — added on request, needs SMTP first

Not on the original twenty; asked for afterwards.
`auth.email.enable_confirmations` is `false` → `true` in
`supabase/config.toml`.

What it buys:

- An address that signs up is one somebody can actually read, so an
  account cannot be opened in a stranger's name and orders cannot be
  placed under an address its owner never sees.
- It closes the remainder of item 5. The client stopped *saying* whether
  an address was registered; this stops Auth's own response from saying
  it either.
- Password reset stops being reachable for an unverified address.

**It needs custom SMTP before it is switched on, or the beta cannot
run.** *(Done on 2026-09-07 — Gmail SMTP, rate limit 100/hour. The
paragraphs below are the reasoning as it stood beforehand; see the
Dashboard configuration section for what was actually set.)* Supabase's built-in mail service is documented as being for
testing, at a best-effort **two emails per hour**. Objective 1 needs real
testers signing up over several days; at two an hour the third person in
any given hour never receives a link and simply cannot register.

Set it at Dashboard → Project Settings → Authentication → SMTP Settings.
Free tiers that cover a beta comfortably: Resend (3,000/month), Brevo
(300/day), SendGrid (100/day). Then raise `auth.rate_limit.email_sent`
from 2 — 30 is a sensible beta figure — and not before, or sign-ups will
appear to work while the emails quietly do not arrive.

**Code changes this forced**, in both clients. Sign-up used to have two
outcomes and now has three: refused, made-and-signed-in, and
made-but-go-and-confirm. The third is a *success*, and both clients
would have painted it in the red error box — telling somebody their
sign-up had failed at the moment it succeeded.

- `registerUser()` in `web/js/auth.js` returns `{ ok, message }` instead
  of a bare string; `web/register.html` shows the notice in green and
  stays on the page rather than redirecting home signed out.
- `register()` in `mobile/lib/services/shop.dart` returns
  `({bool ok, String? message})`; `mobile/lib/screens/login.dart` gained
  a `_notice` box beside `_error`.

The mobile half needs an APK rebuild to reach the phone.

---

# Second pass — full-system scan, 5 September 2026

A scan of web, mobile and database after the first twenty items. Six
findings; four fixed, two recorded.

## 22. Anyone could forge behaviour events — fixed

`supabase/migrations/20260905090000_protect_behaviour_capture.sql`.
**Policies and grants only — no table, column or row is touched.**

The INSERT policy on `events` checked only `customer_id`, and `anon` held
INSERT on `event_type`. The enum is
`view / cart_add / wishlist_add / purchase`, so anyone holding the
publishable key — which ships in `web/js/config.js` and in the APK, by
design — could post `event_type: 'purchase'` for any product, dated to
any moment, as often as they liked.

Two things broke. The Inventory Velocity score weights purchases 5×, so
the admin ranking became whatever the last person with `curl` wanted. And
`events` **is** the Objective 1 dataset — forged rows are
indistinguishable from real ones afterwards, so a polluted table is a
lost result, not a bad report.

Now: clients may assert `event_type = 'view'` and nothing else;
`created_at` and `event_id` are no longer columns any client may set;
`chatbot_logs` and `search_logs` gained length and range caps in their
policies. `cart_add`, `wishlist_add` and `purchase` rows still arrive
from `cart_add()`, `toggle_wishlist()` and `place_order()` — SECURITY
DEFINER, so not subject to these policies at all. That is the design: the
event types that mean something are written by the database when the
thing happens; the one that cannot be verified is the only one a client
may claim.

Verified with eight assertions against the live schema inside a rolled
back transaction — genuine inserts accepted, forged purchase refused,
backdated row refused, client-chosen id refused, oversized chat refused,
negative result count refused.

**A note on how the first attempt was wrong.** It used
`REVOKE INSERT (created_at, event_id)`, and the test showed a backdated
row still being accepted: a table-level `GRANT INSERT` beats any
column-level `REVOKE`. The fix is to revoke the table-level grant and
re-grant the named columns — `20260827114650_client_privileges.sql`
documents the same trap for `SELECT`. Worth recording because it fails
silently: the statement succeeds and changes nothing.

**Not fixed, and not closeable with a policy:** a visitor can still post
any number of genuine-looking *view* rows. A view is a client assertion
with nothing to check it against. What changed is the weight — a forged
view counts 1 rather than 5, and cannot be backdated. A per-`anon_id`
rate limit needs somewhere to count, and therefore a table.

## 23. The release APK was signed with the public Android debug key — fixed

`mobile/android/app/build.gradle.kts` carried Flutter's generated
`signingConfig = signingConfigs.getByName("debug")` and its unactioned
TODO. That is not a weak key but a *published* one: the debug keystore
ships with the Android SDK, is byte-identical on every machine, and its
password is `android`. Anyone could take a tester's APK, modify it —
point it at their own Supabase project, log what the tester types —
re-sign it with the same key, and Android would install it over the top
as a legitimate update.

Release signing now reads `android/key.properties` (already gitignored
alongside `*.jks`). Without that file the build still works and still
uses the debug key, because blocking `flutter build apk` outright would
be worse than the problem — but it logs a warning every time, so it
cannot be forgotten silently the way the TODO was.

**You still have to create the keystore.** Both paths were verified with
a throwaway key, since an untested signing config a week before deploy is
worth little: with `key.properties` the APK came out
`CN=eTech Test Only`; without it, `CN=Android Debug`. The throwaway was
deleted afterwards.

Keep the `.jks` safe. Losing it means no future build can ever update an
installed copy.

## 24. Cleartext HTTP and device backup — fixed

`AndroidManifest.xml`:

- `android:usesCleartextTraffic="true"` removed. It was there for XAMPP
  on plain `http://`; that server is gone and the app talks only to
  Supabase over HTTPS, so it bought nothing and left a downgrade and
  intercepting-proxy path open. Removing it restores Android 9's default
  of refusing plaintext.
- `android:allowBackup="false"` added. The Supabase session token lives
  in `SharedPreferences`, which is plain XML; with backup on that file
  can leave the phone through Android's backup and device-transfer paths,
  and a session token is a signed-in account to whoever holds it. Nothing
  here is worth restoring anyway — cart, wishlist and orders are all in
  the database.

## 25. R8 enabled on the release build — fixed

`isMinifyEnabled` and `isShrinkResources`, with a Flutter-aware
`proguard-rules.pro`. Flutter's Dart is AOT compiled into `libapp.so` and
unaffected, so this is a smaller download and a slightly harder APK to
read rather than a control in its own right. Release APK builds clean at
52.0MB.

## 26. `claim_anon_activity` trusts a caller-supplied id — recorded, not fixed

A signed-in user who learned another visitor's `anon_id` could absorb
that visitor's *unclaimed* rows. The function is otherwise tight —
`customer_id IS NULL` in every `WHERE`, target always
`current_customer_id()` and never an argument — so it cannot take rows
that already belong to somebody, nor assign them to anyone but the
caller. `anon_id` is a v4 UUID and is published nowhere, so this is a
dataset-integrity note rather than a live risk. Fixing it properly means
changing how the clients hand the id over.

## 27. No privacy notice existed — fixed

Not a vulnerability; the thing most likely to cost you the beta.

No page in `web/` mentioned privacy, consent or the PDPA, and the site
was about to start recording every product viewed, every search and every
chatbot message from real named people with accounts. Under the PDPA,
notice is owed at the point of collection. Ethics approval for
human-subject data collection is normally required *before* collection —
if it turns out you needed it, data gathered without it may not be usable
in the dissertation.

Added `web/privacy.html`, linked in the footer, plus a one-time notice on
first visit (`injectPrivacyNotice()` in `web/js/layout.js`). It states
what is recorded and why, that the record *is* the object of study, that
checkout is simulated, what the anonymous device id does and does not
mean, that Gemini receives chatbot messages but no account details, how
long data is kept, and how to ask for a copy or a deletion. It doubles as
a participant information sheet.

The notice sits along the bottom and does not block the page — a banner
that blocks teaches people to dismiss it unread, which is worse than
useless for consent. The acknowledgement is stored in the browser only;
if the project needs per-participant evidence of consent, that belongs
with the account record, not in `localStorage`.

**The ethics question is settled for Objective 1.** The supervisor was
asked on 1 September and confirmed on 7 September that the beta test may
go ahead. The privacy notice and `web/privacy.html` stand as the
participant information sheet for that session. Objective 2's data
source is a separate question and was not covered by that approval.

### Dashboard configuration — done 2026-09-07

Not settable from a migration or `config.toml` on the hosted project. All
of the following were applied and verified against the live project on
the day the site was deployed to `https://etech-fyp.vercel.app`.

1. **Site URL and redirect URLs** (Auth → URL Configuration) — Site URL
   `https://etech-fyp.vercel.app`, redirect allowlist
   `https://etech-fyp.vercel.app/**`. Verified end to end: a test
   registration's confirmation link redeemed once and landed on that
   domain. No localhost entry remains, which is harmless because
   `signUp()` passes no `emailRedirectTo` and the link is always built
   from Site URL.
2. **Custom SMTP** (Auth → Emails → SMTP Settings) — Gmail,
   `smtp.gmail.com:465`, sender and username both `chlee9580@gmail.com`,
   authenticated with a Google app password. Confirmed by the auth log
   line `Email limiter from 2/1h to 30`, which Supabase only writes when
   it accepts the SMTP configuration, and by a real delivered email.
3. **Email confirmation** — was already on (`mailer_autoconfirm: false`
   on the public settings endpoint). Nothing to change.
4. **Email rate limit** (Auth → Rate Limits) — raised to 100/hour. The
   built-in mailer's 2/hour would have stranded the third tester in any
   hour; 30/hour, the custom-SMTP default, counts every auth email
   including resends.
5. **`ALLOWED_ORIGINS`** on `chat-advisor` — set to
   `https://etech-fyp.vercel.app`, and the function redeployed from this
   repo (it had been stale at v13, still answering
   `Access-Control-Allow-Origin: *`; now v15). Verified: the preflight
   echoes our origin, refuses a foreign one, and still allows
   `localhost:5500`.

Still outstanding, and not Dashboard work:

- **Leaked password protection** (Auth → Attack Protection) — checks new
  passwords against HaveIBeenPwned. **Not available on this project:** it
  is gated behind the Pro plan, and this is a Free-plan project. The
  advisor will keep flagging it, and that warning cannot be cleared
  without paying. What stands in its place is the minimum password
  length; there is no way to reject a breached password on this plan.
- **The password verification hook** — see item 17.
- **A spending limit on the Google side** — see item 10. This is now the
  only real bound on the Gemini bill.

---

# Third pass — the six-item feature build, 8 September 2026

Six pieces of work were added: the category emoji and brands fixes, timed
deals, manual payment verification, the rig showcase, smooth category
navigation and a stock filter. Four of them touch the database. What
follows is what that added to the security surface and what was done
about it.

**APPLIED to the live project on 2026-09-09.** All five migrations behind
this work are live and verified against the hosted database:
`20260908010000_timed_deals.sql`,
`20260908020000_manual_payment_verification.sql`,
`20260908030000_rig_showcases.sql`,
`20260908040000_rig_helpers_are_internal.sql` and
`20260908050000_rig_gallery_carries_its_own_builder_name.sql`. This
section describes the live database. (It said the opposite while the
migrations were pending; the deploy that made it true is commit
`521d0ee`.)

## 28. A deal price the browser could name — prevented, not fixed

The obvious way to build a sale is to let the page work out the reduced
price and send it to the till. That is the same mistake as letting a
client name its own total, which item 8 already rules out.

`place_order()` reads the deal itself, from the `deals` table, inside the
same statement that prices the basket, and takes `LEAST(p.price,
deal_price)` — so a deal typed in above list price cannot charge more
than the shelf does either. The browser sends nothing about money. The
struck-through price on a product card is a *picture* of what the till
has already decided, not an instruction to it.

The window is checked in the function as well as in the policy, because
`place_order` is `SECURITY DEFINER` and so is not subject to RLS: a deal
that ended a second ago is invisible to the shop front by policy and
uncharged by the till by that explicit `WHERE`.

## 29. Receipts are private, and the bucket is what says so

`payment-receipts` is the first **non-public** bucket in this project. A
bank transfer receipt carries a name, an account number and an amount;
`product-images` is public because a product photo on a shop front is
about as public as a thing gets, and that reasoning does not transfer.

```
public:             false
allowed_mime_types: image/jpeg, image/png, image/webp
file_size_limit:    5242880 (5MB)
```

Reads are policed as well as writes. Every object goes under a folder
named after the customer's `customer_id`, and the policies compare that
folder against `current_customer_id()`:

- `customers add their own receipts` — INSERT, own folder only
- `customers read their own receipts` — SELECT, own folder only
- `staff read every receipt` — SELECT, `is_admin()`
- `staff remove receipts` — DELETE, `is_admin()`

There is no customer UPDATE or DELETE. A rejected receipt is answered
with another upload and both survive, which is what anybody looking into
a dispute afterwards would want to find.

The admin console holds no key to the bucket. It asks Storage for a URL
signed for five minutes at the moment somebody clicks *View receipt*, and
Storage decides whether to issue one by asking the same `is_admin()`
every other policy asks.

## 30. Attaching a receipt goes through a function, not an UPDATE

`INSERT`/`UPDATE`/`DELETE` on `orders` are revoked from every client role
(item 20) and that stays true. A customer needs to write exactly one
column, so `attach_payment_receipt(order_id, path)` does it and checks
three things first:

1. the order belongs to the caller — read from the session, not from the
   argument;
2. the payment is not already `APPROVED` — a receipt swapped in after the
   money was checked is the one thing this feature exists to prevent;
3. the path is inside the caller's own folder — so a valid caller cannot
   point their order at somebody else's receipt.

`payment_status` is not an argument to `place_order()` and cannot be. It
takes its `PENDING` default, and only `admin_set_payment_status()` —
which looks the caller up in `admins` — moves it.

## 31. Item 7 revisited: still no gateway, and now that is the design

Item 7 said checkout was a mock and there was no webhook to verify. The
mock is gone. What replaced it is not a gateway but a manual process: the
customer pays from their own banking app and uploads the receipt, and a
member of staff approves it.

The three rules in item 7 still hold for the day a gateway is added, and
one of them has been satisfied early: **"paid" is never something a
client asserts.** The app and the website can say which method the
customer intends to use. Neither can say the money arrived.

## 32. The rig showcase is moderated, and the ASUS badge is not an opinion

Customer-submitted photographs are the first user-generated content this
shop publishes, so:

- Nothing is public until staff approve it. `rig_gallery` returns only
  `status = 'APPROVED'`, the policy on `rig_showcases` says the same, and
  the gallery page filters nothing itself — a page that forgot would come
  back empty rather than publish a stranger's photograph.
- Submitting goes through `submit_rig_showcase()`. The customer id is
  read from the session; `status` is not an argument; tagged product ids
  are filtered through a join against `products` so a hand-edited request
  cannot put a made-up id into the gallery.
- `is_asus_verified` is written by a trigger from the tagged parts and by
  nothing else. A badge staff could grant by hand is a badge that can be
  granted by mistake, and one that would go on claiming *ASUS Certified*
  after the ASUS board was untagged.
- Every uploaded photo goes through the same canvas re-encode as a
  product photo, which destroys anything hidden in the original file
  (item 6).

**The honest limitation:** `rig-showcases` is a *public* bucket, because
it is a gallery and signing every image on every page load would be a
round trip per picture for nothing. So a photograph attached to a
submission still waiting for approval is reachable by anybody holding its
URL. Nothing links to it and the names carry a timestamp and a random
suffix, so it is not discoverable — but it is not secret either. That is
the right trade for a picture somebody uploaded *in order to have it
published*, and the wrong one for a bank receipt, which is why that
bucket is private. Deleting a rejected submission removes its objects,
and that is a deliberate act on the moderation page rather than an
automatic one, so a disputed rejection still has its evidence.

## 33. The bank account is real now; the DuitNow ID is not

Updated 2026-09-09. `web/js/payment.js` and
`mobile/lib/payment_details.dart` carry the account the customer is told
to pay into, and both now hold the shop's actual Maybank account. They
agree with each other, which matters more than either being right on its
own: two clients quoting two different account numbers is worse than
either being wrong.

**Money sent to the details on the checkout page now arrives.** That is
the point of filling them in, and it is also the thing to be deliberate
about during a beta — a tester who follows the instructions has made a
real transfer. `web/privacy.html` already tells testers not to send a real
receipt; if the beta is meant to take no money at all, the checkout copy
is where to say so, not this file.

The DuitNow entry is still a placeholder and is still written to be
unmistakable rather than plausible, for the original reason: a realistic
looking identifier in a demo gets screenshotted, quoted in a report, or
paid into by somebody who did not read the surrounding page.

### Half-filled is its own hazard, so the shop stops offering the half

Leaving DuitNow on the form while it cannot be paid would have been worse
than either state. It was the **default selected method** on
`web/checkout.html` and the fallback in `chosenPaymentMethod()`, so a
tester clicking straight through would have chosen, by default, the one
method with nowhere to send money — and the panel would have shown them
our own to-do note as though it were an instruction.

One predicate decides it in each client, `duitNowReady()` in
`web/js/payment.js` and `PaymentDetails.duitNowReady` in the Dart, both
checking the same thing: that `duitNowId` is set and is not the
placeholder. While it is false:

- the DuitNow radio is disabled and reads "Unavailable at the moment",
  greyed rather than removed, because the shop does accept DuitNow and is
  between QR codes rather than never having taken it;
- bank transfer is selected in its place, on both clients;
- the QR panel — which is still reachable from an older order that
  recorded `QR_CODE` — tells the customer to pay by transfer instead of
  showing them the developer note.

**To finish it:** set `duitNowId` in both files and add the image at
`web/images/duitnow-qr.png` and `mobile/assets/images/duitnow-qr.png`
(the Dart asset also needs a line in `pubspec.yaml`). Nothing else has to
change — the option turns itself back on everywhere it appears.

## 34. `orders` gained three columns and one backfill worth stating

`payment_method` is **nullable**, and a NULL means something: that order
was placed through the old card sandbox, before the shop could be paid at
all. Filling those in with a method nobody used would be inventing a
record.

`payment_status` is `NOT NULL DEFAULT 'PENDING'`, and the migration
**backfills every existing order to `APPROVED`**. That is a deliberate
statement and not a tidy-up: those orders were worked through to Shipped
and Delivered on the understanding they were settled, and leaving them at
the default would open the feature with a queue of historical orders
waiting for a receipt nobody ever asked for.

## 35. There was no way back into a forgotten account — fixed

Items 4, 5 and 12 all tightened the password-reset path: the links expire
in fifteen minutes, the sender is rate-limited, and the answer gives
nothing away. What none of them noticed is that **the shop had no reset
path at all**. `resetPasswordForEmail` was never called anywhere, and
nothing served the page a recovery link would have landed on. The
settings were guarding a door that had not been built.

For an ordinary shop that is an inconvenience. For the Objective 1 beta
it is worse: a tester registers on the day, mistypes the password they
meant to use, and is finished — the address is taken, so they cannot
register again, and nobody can read the old password back to them
because nobody has it. Only a bcrypt hash is stored.

`web/forgot-password.html` asks for the address; `web/reset-password.html`
is what the emailed link opens. Three things about them are security
decisions rather than layout:

**The answer is the same for an address that has an account and one that
does not.** Same sentence, same delay, and most failures are folded into
it too, with the real error going to the console. Item 5 removed this
oracle from sign-up; adding it back on a new page would have undone that
work.

**The page requires evidence of a recovery link, not merely a session.**
The session a recovery link creates is an ordinary one and is
indistinguishable afterwards from being logged in normally. A page that
offered "set a new password, no old password needed" to anyone already
signed in would be `changePassword()` with its re-authentication guard
removed, and an unlocked laptop would be enough to take the account. So
`reset-password.html` reads `type=recovery` out of the URL in a `<head>`
script that runs *before* the Supabase client — which consumes the token
and wipes it from the address bar — and keeps only the fact that it was
there, never the token. Without that flag the form is not shown, however
the visitor is signed in. Customers who know their password still change
it from the profile page, which asks for the old one.

**A completed reset revokes every other session**, exactly as item 3 has
`changePassword()` do, and for the sharper version of the same reason:
somebody resetting a password is more likely than average to be doing it
because another person has it.

### Verified end to end, and two warnings withdrawn

**Tested on the live site on 2026-09-09**: the email arrives, the link
opens the form, and the new password works. The flow is complete.

This item was first written with two cautions attached, and both were
wrong. They are recorded here rather than deleted, because each was a
plausible-sounding claim drawn from the wrong source:

- *"The redirect target must be added to the allow-list."* It did not
  need adding. The allow-list set on 2026-09-07 is
  `https://etech-fyp.vercel.app/**`, and that wildcard already matches
  `/reset-password.html`. Nothing was configured to make the flow work.
- *"The mail allowance is two an hour."* That is the **built-in** mailer's
  ceiling, and it is the number in `supabase/config.toml` — a file that
  governs a local stack and says nothing about the hosted project. Custom
  Gmail SMTP was configured on 2026-09-07 and the auth rate limit raised
  to **100/hour**. See the *Dashboard configuration* section above, which
  had already recorded this.

The lesson is the same one this item opens with. `config.toml` describing
a limit is not evidence the hosted project has that limit, exactly as a
setting guarding password resets was not evidence a reset path existed.

## 36. WhatsApp, and the difference between composing and sending

Manual payment verification created two moments where somebody wants to
say something to somebody else: a customer telling the shop they have
paid, and staff telling a customer whether it was accepted. Both are now
WhatsApp links, and `web/js/whatsapp.js` holds the number and the rules
for writing one — loaded by the shop front and the staff console alike,
the same move `photo.js` made.

**Nothing here sends a message.** A `wa.me` link opens WhatsApp with the
recipient and the text filled in, and a person presses send. That is
worth stating plainly because the alternative was considered and
rejected: sending automatically means the WhatsApp Business Cloud API,
which needs a verified Meta business account, a message template approved
in advance by Meta, a server-side access token and a per-conversation
fee. The token alone would have meant another Edge Function; the approval
alone would have meant waiting on Meta. Neither is worth it before a beta
that runs this week.

The operational consequence is the one to remember: **a clicked button is
not a delivered message.** Staff can open the chat and never press send.
Nothing in the database records that a customer was contacted, and the
console must not be read as though it did.

### What is disclosed, and to whom

The staff button puts a customer's phone number and first name into a
`wa.me` URL, which opens Meta's app or website. Staff already hold that
number — it is on the order — so the new fact is that it now reaches Meta
when a member of staff clicks. That is the ordinary consequence of using
WhatsApp at all, and the shop's floating chat button has been on every
page since long before this, but it had never been written down.

`web/privacy.html` gains a section saying it: that the number given at
checkout may be used to message the customer about that order, that a
human writes and sends it, that WhatsApp is Meta's service under Meta's
policy, and that a customer can ask to be contacted by email instead. The
receipt upload on the site does the same job, so nobody has to open a
WhatsApp conversation to buy anything.

### The number that is not a number

`orders.shipping_phone` is typed into a form by a customer, so it arrives
as `011-1074 3634`, or `+60 11 1074 3634`, or `0111074 3634`. `wa.me`
accepts exactly one shape and, given any other, **opens a chat with
nobody rather than failing** — which would leave staff believing they had
messaged a customer who never heard from them. `whatsappNumber()`
normalises the common Malaysian forms and returns an empty string for
anything under eight digits, and every caller checks it: no usable
number, no button drawn. Ten cases are covered, including the empty and
junk ones.
