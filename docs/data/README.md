# Five years of eTech sales — synthetic

`etech_sales_2022_2026.xml` holds 7,838 sale lines across 3,599 orders,
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
| 2022 | 1,032 | 2,265 | 1,032,872 | 80,807 | 202,690 |
| 2023 |   877 | 1,893 |   797,746 | 65,698 | 160,020 |
| 2024 |   760 | 1,681 |   683,999 | 57,645 | 133,521 |
| 2025 |   610 | 1,296 |   557,474 | 42,580 | 100,443 |
| 2026 (Jan–Aug) | 320 | 703 | 286,346 | 22,501 | 50,417 |

Orders, lines, revenue, service revenue and gross profit all fall every
year without exception.

## The four decisions behind it

**1. The shop is shrinking.** Orders drift down about 19% a year, applied
month by month rather than as a jump each January. Seasonality and random
noise sit on top, so a single year can land above or below the trend line
— but at this volume every measure happens to fall cleanly. Revenue
drops faster than orders because the earlier years are priced higher
too.

**2. Each year only sells what that year could sell.** An RTX 5070 does
not appear in 2022. `tools/sales_history/launch_years.py` dates every
product by reading its name — chipsets, CPU generations, DDR version,
PCIe generation — and the generator will not sell anything before its
launch month. 253 distinct products sell in 2022 and 260 in 2025
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
against 6–12% on a graphics card, so they lift the shop's overall gross
margin to about 19%.

Service revenue falls every year alongside everything else, and gross
margin slips a little as it does — 19.6% in 2022 to 17.6% in 2026 —
because the high-margin service work is shrinking slightly faster than
the thin-margin hardware around it.

**4. Prices drift.** The catalogue price is the 2026 price, so selling a
Ryzen 5 5600 in 2022 at its 2026 price would understate the revenue of
the busiest year. Older years are marked up — ×1.28 in 2022 falling to
×1.00 in 2026 — with a 6% premium in a part's launch year and ±2% noise
per line.

## Three effects worth noticing before you explain them

- **Average order value is flat**, RM 1,001 in 2022 to RM 895 in 2026.
  It drifts down slightly rather than up: the expensive new stock (RTX
  5080, 5090) only exists in the later years, but a shop this size sells
  one or two of those a year, not enough to lift the average.
- **Service revenue holds a steady ~8% of turnover**, even though the
  proportion of repair-only visits is set to climb from 14% to 22%. A
  service costs RM 45–250 against a basket near RM 900, so many more
  repair jobs still add up to very little money. Raise
  `SERVICE_ONLY_SHARE_*` hard if you need a rising service share.
- **Online share doubles**, 17% of orders in 2022 to 38% in 2026. The
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
7,838 records to get its series:

```python
months = pd.read_xml("docs/data/etech_sales_2022_2026.xml", xpath=".//monthlyTotal")
```

The wrappers are `<monthlyTotal>` and `<yearlyTotal>`, not `<month>` and
`<year>`, because every `<sale>` already has a `<month>` and a `<year>`
child — `.//month` would match all 7,838 sales too and hand back a frame
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
`ORDERS_AT_START` (how busy the first month is), `ANNUAL_RETENTION` (how
fast the shop shrinks) or `SEASONALITY` at the top of the generator to
reshape it; change `SEED` for a different draw of the same shape.

One knob is worth understanding before you touch it. `PRICE_RESISTANCE`
is the exponent in `weight = demand / price ** PRICE_RESISTANCE`, and it
decides how often the shop sells something expensive. It was 0.5 in the
first version, which made an RM 25,999 RTX 5090 only nine times less
likely than an RM 300 stick of RAM. At higher volumes that put seven
RM 6,000-plus cards into 2025 and none into 2024, and RM 64,000 of lumpy
revenue in one year was enough to lift 2025 above 2024 and break the
decline. At 0.85 a part costing eighty times more is about fifty times
rarer, which is what a shop this size actually sells. Lower it and the
trend gets noisy at the top end.
