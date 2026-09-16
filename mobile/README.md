# eTech Mobile — customer app

The phone version of the eTech Computer Accessories shop, built with Flutter.

It is not a separate system: it talks to the **same PHP API** as the
website, and that API reads the **same Supabase database**. Sign in on the
phone and your basket, wishlist and orders are the ones you left on the
website, because they live in the database rather than in either device.

The app never talks to Supabase directly and holds no database login. It
asks `api/products.php`, `api/cart.php` and the rest, exactly as the browser
does, so the database password stays on the server:

```
Flutter app  ─┐
              ├─>  PHP API (web/api/)  ─>  Supabase (Postgres)
Web browser  ─┘
```

## Running it

1. Start **Apache** in the XAMPP Control Panel. MySQL is no longer needed —
   the data lives in Supabase now, and the server reaches it over the
   internet using the connection string in `config/etech_config.php`.
   (That file also needs PHP's `pdo_pgsql` extension switched on in
   `php.ini`; see `sql/supabase/README.md`.)
2. Open this folder in Android Studio and press Run, or:

```bash
flutter run
```

### The build needs JDK 21, not whatever Android Studio ships with

Android Studio bundles its own JDK and upgrades it without asking. When it
moved to **Java 25**, every Android build here died with this, and nothing
else:

```
* What went wrong:
25.0.3
```

That number is the *Java version*, not a dependency. Gradle 8.14.x cannot
parse Java 25 at all — it only learned it in Gradle 9. The message names no
file and no task, so it reads like a corrupt dependency and sends you
hunting through `build.gradle.kts`, where the problem is not.

Both halves of the toolchain have to be pointed at JDK 21, which is what
AGP 8.x is built against:

```bash
flutter config --jdk-dir "C:\Users\<you>\.jdks\jbr-21.0.11"
```

and, for Android Studio's Gradle sync, **File → Settings → Build, Execution,
Deployment → Build Tools → Gradle → Gradle JDK → 21**. That setting is stored
in `android/.gradle/config.properties`, which is gitignored, so it is
per-machine and does not survive a reinstall. If the `25.0.3` error comes
back after reinstalling Android Studio, this is why.

### Signing a release build

`flutter build apk --release` **stops** unless `android/key.properties`
exists, because without it the APK would be signed with the public debug
keystore that ships inside the Android SDK — the same key on every machine,
password `android`. Anyone could modify such an APK and re-sign it as this
app.

Create the keystore once, and keep the `.jks` safe — losing it means no
future build can ever update an installed copy:

```bash
keytool -genkey -v -keystore %USERPROFILE%\etech-release.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias etech
```

Then write `mobile/android/key.properties` (gitignored, never commit it):

```properties
storePassword=<what you typed>
keyPassword=<what you typed>
keyAlias=etech
storeFile=C:/Users/<you>/etech-release.jks
```

To build a release APK with the debug key deliberately — your own phone, a
quick size check — say so explicitly. Never hand that build to a tester:

```bash
flutter build apk --release -Petech.allowDebugSigning=true
```

## The server address — the one thing that has to be right

The phone is a separate machine from the one running Apache, so `localhost`
means the phone itself, not your PC.

| Running on | Address to use |
|---|---|
| Android emulator | `http://10.0.2.2/etech` (Android maps this to your PC) |
| A real phone | `http://192.168.1.7/etech` — your PC's WiFi address |

The emulator address is the default. To change it without rebuilding, open
**Account → Server settings** in the app; there are one-tap buttons for both.
For a real phone, both devices must be on the same WiFi, and Windows Firewall
has to allow incoming connections on port 80.

If the address is wrong the app says so plainly rather than showing an empty
screen.

## What is in it

| Screen | What it does |
|---|---|
| Home | Hero banner, live promotions strip, featured and popular products |
| Shop | All 334 products, search, category chips, brand filter, sorting |
| Product | Photo, full specification table, add to cart, wishlist |
| Build PC | Eight slots with the full compatibility engine |
| Cart | Quantities, live totals |
| Checkout | Name and phone for collection, coupon, manual payment |
| Account | Orders with a progress tracker, wishlist, profile, server settings |
| Consultant | The AI hardware advisor |
| Deals | Live coupons, tap to copy the code |

## The compatibility engine

`lib/services/compatibility.dart` holds the same rules as the website, and
they are enforced two ways:

**Hidden before you can choose them** — pick a CPU and the app stops
offering motherboards with the wrong socket, memory of the wrong type, and
any cooler that cannot handle that processor's heat. A 65W stock cooler is
never offered for a 219W Core i7.

**Checked in the summary**, split three ways:

- **Critical** (red) — the parts cannot physically work together. Blocks
  the order.
- **Worth knowing** (amber) — it runs, just not at its best. A Gen 5 drive
  in a Gen 3 slot works perfectly, it simply will not reach top speed, so
  that never blocks a sale.
- **Passed** (green).

## The AI consultant

`lib/services/advisor.dart`. It is **not** a language model and there is no
AI service involved. It reads the budget, resolution and intended use out of
a sentence — including Malay phrasing like "bajet 4k" — then searches every
CPU and graphics card pairing in stock and keeps the best complete build
that fits the budget and passes every compatibility rule.

Try: *"build a pc for cs2 full hd bajet 4k"*.

Because the answer is assembled from the real catalogue rather than
generated, it is always technically correct.

## Tests

```bash
flutter test
```

Ten tests cover the compatibility rules — the socket, memory, cooling, case
fit and PCIe generation logic. They run without a server, since they test
the rules rather than the network.

## How it talks to the server

`lib/services/api.dart`. The website keeps you signed in with a PHP session,
and a browser returns that cookie automatically. Flutter's http package does
not, so this class stores the `PHPSESSID` cookie itself and attaches it to
every request. It is saved to the phone, so closing the app does not sign
you out.

`android/app/src/main/AndroidManifest.xml` allows plain HTTP
(`usesCleartextTraffic`), which Android blocks by default. That is fine for
a local project; a real deployment would use HTTPS and drop that line.
