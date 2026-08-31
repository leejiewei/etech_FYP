# eTech database — setup notes

> **The live database is no longer this one.** On 26 August 2026 everything
> moved to Supabase (Postgres), and `web/api/` and `web/admin/` now connect
> there — see [`supabase/README.md`](supabase/README.md). The MySQL scripts
> below are kept because they are how the data was built, and `03_seed.sql`
> is still what gets regenerated when the product list changes. Running them
> rebuilds the old local copy; it does not affect what the website and the
> phone app read.

## Rebuilding the database

Run the four files in order. Script 01 drops and recreates the whole
database, so this is always safe to repeat from a clean slate:

```bash
cd C:\xampp\htdocs\etech\sql
C:\xampp\mysql\bin\mysql.exe -u root < 01_schema.sql
C:\xampp\mysql\bin\mysql.exe -u root < 02_users.sql
C:\xampp\mysql\bin\mysql.exe -u root < 03_seed.sql
C:\xampp\mysql\bin\mysql.exe -u root < 04_admin_and_coupons.sql
```

Or import each one through phpMyAdmin at `localhost/phpmyadmin`.

| File | What it does |
|---|---|
| `01_schema.sql` | Creates the `etech` database, all 14 tables and the 2 reporting views |
| `02_users.sql` | Creates the two database logins and their privileges |
| `03_seed.sql` | Loads all 269 products, 53 brands, 24 categories, 1,339 spec rows |
| `04_admin_and_coupons.sql` | Starter staff login and the 6 category promotions |

`03_seed.sql` is generated from the website's `js/products.js` — don't edit
it by hand, regenerate it if the product list changes.

## The two database logins

| Login | Password | Used by |
|---|---|---|
| `etech_admin` | `etech_admin_2026` | The admin panel |
| `etech_client` | `etech_client_2026` | The customer-facing shop |

The client login is deliberately limited **by the database itself**, not
just by the application. Even a hand-written query on that connection is
refused:

```
SELECT cost_price FROM products;
  -> SELECT command denied ... for column 'cost_price'

UPDATE products SET price = 1;
  -> UPDATE command denied ... for table `etech`.`products`

SELECT * FROM admins;
  -> SELECT command denied ... for table `etech`.`admins`
```

So if someone tampered with the shop's JavaScript in their browser, they
still could not change a price, delete a product, promote their own order
to "Delivered", or find out what we pay for stock.

## Staff login

Username `admin`, password `admin123`. The password is stored as a bcrypt
hash from PHP's `password_hash()` — the plain text is never in the
database. **Change it before showing or hosting the project.**

## Fields still to fill

Carried over from the supplier records' own "Outstanding" notes:

- **`cost_price`** — NULL on every product. Needed for margin figures and
  for the "high-cost stagnant item" test in the dead-stock alerts.
- **`stock_qty`** — NULL on every product. `stock_status` currently holds
  the value the shop uses. Once real counts are entered, status should be
  derived from the quantity: `out` at 0, `low` at or below `reorder_level`,
  otherwise `in`.

## Notes on a couple of design choices

**Why `product_attributes` is a separate table.** A printer has no CPU
socket and a graphics card has no paper size. Giving every product a
column for every possible spec would leave a table that is mostly empty.
Instead each spec is a row, and a spec with several values — the sockets a
cooler fits, the board sizes a case accepts — is simply several rows
sharing one key.

**Why order items copy the name and price.** `order_items` stores the
product name and unit price as they were at the time of sale. If a product
is later renamed, repriced or discontinued, old orders still show what the
customer actually bought and paid.

**Why product ids are not auto-increment.** They keep the ids the website
already uses, so `images/2201.jpg` still matches the right product.
