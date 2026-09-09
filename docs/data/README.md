# Five years of eTech sales — synthetic

`etech_sales_2022_2026.xml` holds 5,381 sale lines across 2,424 orders,
January 2022 to August 2026.

**None of it happened.** It is generated. eTech's real `orders` table has
37 rows, all from 2026, and most of those were placed while testing the
checkout. That is not something you can fit a trend to, so this file
supplies a history with a shape in it. It must never be presented as a
record of real trading — the file says so in its own `<meta>` block, and
so should you, in the report and in the viva.

What *is* real: the 389 products. Names, brands, categories and 2026
prices come straight out of eTech's live Supabase catalogue, exported on
9 September 2026. So the shop in this dataset sells exactly what the shop
sells.

## What is in it

| Year | Orders | Lines | Revenue (RM) | Services (RM) | Gross profit (RM) |
|------|-------:|------:|-------------:|--------------:|------------------:|
| 2022 | 678 | 1,514 | 878,036 | 57,866 | 155,317 |
| 2023 | 634 | 1,397 | 786,774 | 60,348 | 143,577 |
| 2024 | 498 | 1,095 | 668,138 | 38,067 | 107,482 |
| 2025 | 404 |   914 | 588,320 | 29,824 |  87,451 |
| 2026 (Jan–Aug) | 210 | 461 | 337,751 | 16,676 | 47,064 |

## The four decisions behind it

**1. The shop is shrinking.** Orders drift down about 19% a year, applied
month by month rather than as a jump each January. Seasonality and random
noise sit on top, so a single year can land above or below the trend line
— 2023 is only 6% below 2022 in orders, which is noise, not a change of
direction. Revenue falls more evenly, about 13% a year, every year.

**2. Each year only sells what that year could sell.** An RTX 5070 does
not appear in 2022. `tools/sales_history/launch_years.py` dates every
product by reading its name — chipsets, CPU generations, DDR version,
PCIe generation — and the generator will not sell anything before its
launch month. 243 distinct products sell in 2022, growing to 267 in 2025
as the catalogue fills out.

These launch years are **judgement, not records**. Hardware release dates
are public and checkable, but nobody compared them against eTech's own
purchase history, because no such history exists. Anything the rules do
not recognise is assumed to have always been in stock, which is the safe
direction to be wrong in. Run `python tools/sales_history/launch_years.py`
to print every product with the rule that dated it, and argue with it.

**3. Services are included, and they are invented.** The database has 39
categories and not one is a service, so the sixteen in
`tools/sales_history/services.py` were written for this dataset — PC
assembly RM 80, virus removal RM 80, data recovery RM 250, and so on, at
what a small Malaysian shop charges. They carry labour margins of 60–85%
against 6–12% on a graphics card, which is why gross profit falls more
slowly than revenue. Service revenue declines across the window but not
in a straight line: 2023 comes in slightly above 2022.

**4. Prices drift.** The catalogue price is the 2026 price, so selling a
Ryzen 5 5600 in 2022 at its 2026 price would understate the revenue of
the busiest year. Older years are marked up — ×1.28 in 2022 falling to
×1.00 in 2026 — with a 6% premium in a part's launch year and ±2% noise
per line.

## Two effects worth noticing before you explain them

- **Average order value rises** as the shop shrinks: RM 1,295 in 2022 to
  RM 1,608 in 2026. Fewer customers, bigger baskets, because the
  expensive new stock (RTX 5080, 5090) only exists in the later years.
- **Online share triples**, 16% of orders in 2022 to 43% in 2026. The
  shop is shrinking and moving online at the same time. Repairs stay at
  the counter — a service-only order is always `WALK_IN`.

## Reading it

Each `<sale>` is one line of one receipt with the order's details
repeated onto it. That repetition is deliberate: it loads flat.

```python
import pandas as pd
df = pd.read_xml("docs/data/etech_sales_2022_2026.xml", xpath=".//sale")
monthly = df.groupby(["year", "month"])["lineTotal"].sum()
```

The file also carries `<monthlySummary>` (56 rows) and `<yearlySummary>`
already aggregated, so a forecasting exercise does not have to parse
5,381 records to get its series:

```python
months = pd.read_xml("docs/data/etech_sales_2022_2026.xml", xpath=".//monthlyTotal")
```

The wrappers are `<monthlyTotal>` and `<yearlyTotal>`, not `<month>` and
`<year>`, because every `<sale>` already has a `<month>` and a `<year>`
child — `.//month` would match all 5,381 sales too and hand back a frame
of mostly NaN.

Fields on each sale: `saleId`, `orderId`, `date`, `year`, `month`,
`channel` (WALK_IN / ONLINE), `customerType` (INDIVIDUAL / SME /
SCHOOL), `paymentMethod` (CASH / CARD / DUITNOW_QR / BANK_TRANSFER),
`sku`, `itemType` (PRODUCT / SERVICE), `itemName`, `category`, `brand`,
`quantity`, `unitPrice`, `lineTotal`, `unitCost`, `lineProfit`.

## Regenerating

```
python tools/sales_history/generate_sales_xml.py
```

Seeded with 20260909, so it writes the same file every time. Change
`ORDERS_AT_START`, `ANNUAL_RETENTION` or `SEASONALITY` at the top of the
generator to reshape it; change `SEED` for a different draw of the same
shape.
