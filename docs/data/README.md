# Five years of eTech sales — synthetic

`etech_sales_2022_2026.xml` holds 10,434 sale lines across 3,490 orders,
January 2022 to August 2026. The same rows are written beside it as
`etech_sales_2022_2026.xlsx` (everything in one workbook — the one to
open in Excel), and as `etech_sales_2022_2026.csv` and
`etech_sales_monthly.csv` for anything that wants a plain file.

**None of it happened.** It is generated. eTech's real `orders` table has
37 rows, all from 2026, and most of those were placed while testing the
checkout. That is not something you can fit a trend to, so this file
supplies a history with a shape in it. It must never be presented as a
record of real trading — the file says so in its own `<meta>` block, and
so should you, in the report and in the viva.

What *is* real: the 389 products. Names, brands, categories and 2026
prices come straight out of eTech's live Supabase catalogue, exported on
9 September 2026. So the shop in this dataset sells what the shop sells.

Four things are sold here that are *not* in that export, and each says
so in the file's `<meta>` block: sixteen services, twenty-six cables,
twenty peripherals and thirty-four dated machines and monitors. They are invented,
they are marked, and the reasons are decisions 3, 3a and 3b below.
Everything invented is countable — the services sit under category
`Services`, the cables and peripherals under `Cables` and `Peripherals`,
and the machines keep their real category names but carry an `M-` sku
against the catalogue's `P-####` — so any analysis that wants only
genuine catalogue stock can drop them in one filter.

**Every sale is over the counter, and nobody is named.** eTech has not
traded online, so there is no channel column and no online orders — the
web shop in this project is the thing being built, not something with a
sales history behind it. There is no customer column either: no names, no
segments, nothing that identifies a buyer. A receipt here is a date, a
payment method and what was on it.

**Nothing in the file says what a sale cost the shop.** There is no cost
column and no profit column. The generator does hold a margin per item
and prints the gross profit it implies when you run it, as a check that
the numbers are sane, but those margins are guesses — nobody has eTech's
real buying prices — and a `lineProfit` column would publish the cost
anyway, since it is just `lineTotal` minus profit. So the file is revenue
only.

## What is in it

| Year | Orders | Lines | Revenue (RM) | Services (RM) |
|------|-------:|------:|-------------:|--------------:|
| 2022 | 1,132 | 3,377 | 1,409,867 | 95,150 |
| 2023 |   804 | 2,435 | 1,073,160 | 71,886 |
| 2024 |   679 | 2,014 |   839,136 | 53,953 |
| 2025 |   561 | 1,661 |   717,780 | 43,079 |
| 2026 (Jan–Aug) | 314 | 947 | 433,594 | 29,827 |

Orders, lines, revenue and service revenue all fall every year without
exception.

## The five decisions behind it

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
launch month. 281 distinct products sell in 2022 and 320 in 2025
as the catalogue fills out.

These launch years are **judgement, not records**. Hardware release dates
are public and checkable, but nobody compared them against eTech's own
purchase history, because no such history exists. Run
`python tools/sales_history/launch_years.py` to print every product with
the rule that dated it, and argue with it.

**"Anything unrecognised is assumed always in stock" is the safe
direction to be wrong in — except when it isn't**, and the monitors and
routers proved it. 178 of the 389 catalogue products matched no rule and
so were sold from January 2022, and among them were *every* monitor
whose name carries no readable generation marker and *every* WiFi 7
router. The `WiFi 7` rule never fired once, because not one router in the
catalogue says "WiFi 7" in its name — they say `RT-BE58U` and
`Archer BE400`, with the generation in the model code. The result was an
RM 649 27" 180Hz gaming panel and a WiFi 7 router on 2022 receipts,
years before either existed.

Both are now dated: routers and mesh kits by the BE/AX letter pair,
monitors by model code (`XG27ACS` 2024, `ED270R` 2023, and eleven more),
projectors by name, and any cooler with an LCD or digital readout on the
block by that fact. 133 products still match no rule, and that residual
is defensible in a way the old one was not: it is cases, fans, PSUs,
SATA drives, printer consumables and mounts — categories where a model
genuinely does sit on the shelf for years, and where being a year out on
an RM 199 case is not the same kind of error as selling a monitor that
did not exist.

**Every product sale line in the file has been audited against its own
source** — 8,346 lines against catalogue launch years, accessory launch
months, and the dated stock's first and last years. Nothing is sold
before the model existed, nothing is sold after it was discontinued, and
no sku is undated.

**3. Services are included, and they are invented.** The database has 39
categories and not one is a service, so the sixteen in
`tools/sales_history/services.py` were written for this dataset — PC
assembly RM 80, virus removal RM 80, data recovery RM 250, and so on, at
what a small Malaysian shop charges. They sit under category `Services`,
and their `brand` says `Services` too: the shop's own name has no place
in a brand column and a repair job has no manufacturer.

Service revenue falls every year alongside everything else. Behind the
file the services carry labour margins of 60–85% against 6–12% on a
graphics card, which lifts the shop's implied gross margin to about 19%
and slips it from 17.9% in 2022 to 15.6% in 2026 as the high-margin
repair work shrinks slightly faster than the thin-margin hardware. None
of that is in the data — run the generator and read its console table if
you need the figures.

**3a. So is the rack by the door.** The catalogue export is a builder's
catalogue: 34 graphics cards and one mouse pad. It has no HDMI lead in
it, no Cat 6, no USB-C, and exactly three input devices — and its five
"Cable Kits" are all sleeved power extensions for the inside of a case,
which is a different product from a cable somebody walks in for. Taken
literally it would have meant a computer shop that sold nothing under
RM 40 for five years: no small change, no impulse line, and an average
basket dragged upward by parts.

So `tools/sales_history/accessories.py` adds two categories, on the same
footing as the services and marked the same way:

- **`Cables`** — 26 of them, RM 8 to RM 129. USB Type-C 1.5m, USB male
  to male 3m, Cat 6 at 2/5/10/15/20m, HDMI 2.0 and 2.1, DisplayPort,
  VGA, SATA data, a 3.5mm aux lead, a USB-C hub.
- **`Peripherals`** — 20 keyboards, mice and headsets, from an RM 39
  A4Tech board to an RM 429 Keychron. Gaming-branded models sit here
  too, so the four genuine `Gaming Gear` rows stay countable as what the
  database actually holds.

These are real products a Malaysian shop stocks, at local prices. They
are not eTech's stock and no price came from eTech's records. The three
that launched inside the window carry their real release *month*, not
just the year, so a June 2022 headset cannot appear on a January 2022
receipt.

They reach a receipt three ways, which is why they are 17.5% of all sale
lines and 3.6% of the revenue:

1. On their own, through the usual weighted pick — 209 receipts in the
   file are nothing but cable.
2. Attached to what caused them. 55% of monitor orders, 53% of router
   orders and 62% of finished-desktop orders carry a lead.
3. Home with a build. 57% of rigs leave with a keyboard and mouse, 41%
   with a display cable, and a gaming build often adds a headset — a
   built PC comes with none of those in the box.

Their margins are shop margins, not component margins: 40% on a cable,
24% on a keyboard, against 7% on a graphics card. A rack of cables earns
more than it looks like it does. Cable and peripheral revenue falls
across the window like everything else, RM 60,600 in 2022 to RM 22,900 in
2025.

**3b. Whole machines, and the two things that were wrong with them.**
eTech sells finished computers as well as parts: laptops, branded
desktops, all-in-ones, and eleven of its own builds under `Prebuilt
Gaming PCs`, `Office PC Series` and `Custom Office CO1`. The dataset now
carries them all: 119 laptops, 40 branded desktops and 6 all-in-ones
sold as boxed products, and **125 E-Tech machines sold itemised** — see
3c for why those are different.

It took two fixes to get there, and both are worth knowing about because
both were silently wrong.

*They barely sold at all.* `PRICE_RESISTANCE` divides a product's pick
weight by its price, which is right for choosing between an RTX 5060 and
an RTX 5090 and wrong for a category where **everything** is expensive:
a RM 5,500 prebuilt came out 70 times less likely than a RM 400 drive
before demand was even considered, and the category has 5 products
against storage's 28. Left at the 0.8–1.5 they were first given, the
shop sold **seven finished machines in five years and not one prebuilt
gaming PC** — absurd for a business with eleven of its own builds on the
website. `CATEGORY_DEMAND` for those six categories is now 10–55, which
looks ridiculous beside storage's 10 and is not: the number is a
per-product multiplier that price then divides, not a popularity score.

*They sold in the wrong years.* A laptop model lives about eighteen
months and a monitor panel line about two years, so a 2026 catalogue
snapshot contains nothing the shop stocked in 2022 — every laptop,
branded desktop **and all 21 monitors** in the export date to 2023 or
later. Taken literally the shop sold its first laptop in 2023, its first
monitor in 2023, and whole machines climbed from 8% of revenue in 2022
to 24% in 2026: the biggest-ticket line *growing* as a share of a
business that is supposed to be shrinking, purely because the catalogue
is dated from the wrong end.

The tempting fix — letting the 2023 models sell in 2022 — would have
bought the trend back with a checkable factual error, which is exactly
what `launch_years.py` exists to prevent. So the early years got their
own stock instead: `tools/sales_history/dated_stock.py` holds 34 items
that really were on sale in Malaysia in 2020–2023, at what they really
cost. Twelve laptops (Acer Aspire 3, Lenovo IdeaPad 3, Nitro 5, TUF
Gaming F15…), four branded desktops, two all-in-ones, four of eTech's
own builds of the day — a GTX 1650 box at the bottom, an RTX 3070 at the
top, which is what an RM 6,000 gaming PC was in 2022 — and twelve
monitors, from an RM 429 75Hz office panel to an RM 1,299 27" 144Hz.

That last group makes the dataset tell a true story it was hiding: the
2022 monitors average RM 614 and the 2025 ones RM 662, but an RM 999
27" 144Hz in 2020 is an RM 649 27" 180Hz in 2024. Panels got cheaper and
better, and both ends of that are now in the file.

They behave differently from everything else in two ways, and both are
deliberate:

- **They retire.** Each carries a `last_year`, so a 2021 Aspire leaves
  the shelf around 2023 rather than being sold new in 2026. Nothing else
  in the dataset stops being available, because a 2026 snapshot cannot
  say when something was discontinued. The handover is clean: the dated models carry 2022 almost alone and
  have handed over entirely by 2024.
- **Their price does not drift.** `YEAR_PRICE_FACTOR` marks older years
  up because a catalogue price is a 2026 price. These are already priced
  in their own year's money and there is no 2026 price to mark up from,
  so they are exempt.

**3c. An E-Tech machine is sold as its parts, on one bill.** eTech's own
builds — ZenForge, Titan Aegis, Inferno Apex, the Office PC series,
Custom Office CO1 — are not really products on the live site. Their
stock is *derived*: the site works out how many ZenForges it can sell by
counting components on the shelf, because a ZenForge **is** a pile of
parts somebody screwed together. Nobody orders a crate of them from a
supplier.

The file was not saying that. A prebuilt sale came out as one line
reading `E-Tech ZenForge Ryzen 5 5500 RTX 3050 — RM 2,999`, which tells
you nothing about what left the shelf: eight components moved and the
data recorded a product with no supplier.

So a prebuilt is now itemised, exactly like a custom build — **one
order id, one date, one payment method, a line per part**:

```
CPU           1x Intel Core i7-14700F                    RM 1,333.36
Motherboard   1x Asus Prime B760M-A WiFi D4              RM   755.18
RAM           1x Kingston Fury Beast 16GB DDR4-3200MHz   RM   737.39
Storage       1x WD Purple 3TB Surveillance HDD          RM   755.18
PSU           1x Cooler Master MWE Gold 750 V3           RM   319.33
Case          1x Tecware VXN+ (Black)                    RM   212.59
Cooler        1x ID-Cooling Frozn A620 Pro SE ARGB       RM   159.22
GPU           1x Asus RTX 5050 Dual OC                   RM 1,199.93
Cables        3x HDMI 2.0 Cable 5m                       RM   166.38
Services      1x Extended Warranty (1 Year)              RM   197.76
```

- **Which parts.** The machine's own name gives the two that matter —
  `Inferno Apex Ryzen 7 7800X3D RX 9060 XT` names its processor and its
  card, and both are real catalogue products — so those lines are read
  off the name. Board, memory, storage, PSU, case and cooler are picked
  the way `rigs.py` picks them, constrained to fit the named processor
  and to a price band scaled to the machine's price. An office machine
  whose name has no card gets none: an Office PC Ryzen 3 3200G runs on
  the APU.
- **The price is unchanged.** Parts bought separately cost more than the
  machine — that is what a prebuilt is for — so the catalogue prices are
  scaled by one factor to make the bill total the machine's advertised
  price, the same discount on every line rather than hidden in one of
  them. Itemising changes what the receipt says, not what was paid.
- **No assembly labour.** That is now the only difference between the
  two kinds of whole machine: a rig is built to order and charged the
  RM 80, a prebuilt was built already. All 225 rig builds carry it; none
  of the 125 prebuilts do.
- **Only eTech's own builds.** A Lenovo IdeaCentre arrives in a sealed
  box and a laptop cannot be broken into shop stock at all, so branded
  desktops, all-in-ones and laptops stay one line each — 165 of them
  across the window.

125 prebuilt orders, averaging 8.5 lines and RM 2,960, 8.3% of revenue,
falling 35 machines in 2022 to 14 in the part-year 2026.

All 350 whole machines in the file — 225 rigs and 125 prebuilts —
were re-checked for socket, memory generation **and cooler fit**. That
last one was added here: an `CPE R120 (Intel stock cooler)` had been
turning up on Ryzen machines in both kinds of build, which is the sort
of thing a reader spots at a glance. Zero incompatible now.

**4. Prices drift.** The catalogue price is the 2026 price, so selling a
Ryzen 5 5600 in 2022 at its 2026 price would understate the revenue of
the busiest year. Older years are marked up — ×1.28 in 2022 falling to
×1.00 in 2026 — with a 6% premium in a part's launch year and ±2% noise
per line.

**5. Some receipts are a whole computer.** eTech builds machines, so
about one order in fifteen is a rig: processor, motherboard, memory,
storage, power supply, case, cooler, usually a graphics card, sometimes
a pack of fans, usually a keyboard and mouse and often a lead to the
monitor, plus the labour to put it together. Eight to sixteen lines on
one order, against a counter sale's 2.1. Every part is charged at the
price it sells for on its own — the shop does not discount a bundle, it
charges for the build.

225 of the 3,490 orders are builds, averaging RM 6,456 and 11.7 lines,
and they run from RM 2,180 for an office box to RM 19,062. At 6.4% of
the orders they are 32.5% of all revenue, which is
what makes this a builder's sales history rather than a parts counter's.

The parts in a build fit each other. `tools/sales_history/rigs.py` reads
the socket off the part names — a chipset number gives the socket, the
socket gives the memory generation — so a Ryzen 7 5800X3D lands on a
B550 with DDR4 beside it and never on a B850. All 225 builds check out
on socket and on memory. The sockets are also dated properly: no AM5
build appears before the platform launched in September 2022 — the first
one in the file is September 2022 — and LGA1851 does not turn up until
September 2025.

That is name-reading, not a compatibility database. It gets the socket
and the memory right, which is what anyone will check. It says nothing
about whether the cooler clears the memory or the card fits the case.

Three tiers decide what goes in — an office box, a gaming machine, a
high-end build — as a price band per category, so a cheap A620 board
does not turn up under a Ryzen 9. A year with nothing in a band gets the
nearest thing it has, which is why a 2022 "high-end" build ships an RTX
3050: the catalogue is a 2026 snapshot and holds nothing else from then.

## Three effects worth noticing before you explain them

- **Average order value does not fall**, RM 1,245 in 2022 against
  RM 1,381 in 2026. What is
  shrinking is the number of people coming in, not what they spend. It
  also wanders, because a year's average depends on how many builds
  landed in it: a counter sale averages RM 844 and a build RM 6,456.
- **A fifth of the sale lines are worth 5% of the money.** Cables and
  peripherals are 17.5% of all lines and 3.6% of revenue. Any analysis
  that counts *lines* rather than ringgit will be dominated by the cable
  rack — group by `lineTotal`, not by row count.
- **Service revenue holds ~6–8% of turnover**, even though the
  proportion of repair-only visits is set to climb from 14% to 22%. A
  service costs RM 45–250 against a basket near RM 1,282, so many more
  repair jobs still add up to very little money. Raise
  `SERVICE_ONLY_SHARE_*` hard if you need a rising service share.
- **The till changes even though the shop does not.** Cash falls from 54%
  of receipts in 2022 to 43% in 2026 while DuitNow QR climbs 15% to 28%
  and overtakes card. All four methods are counter payments; the 6% of
  bank transfers are somebody paying from their phone at the till, not a
  web checkout.

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
10,434 records to get its series:

```python
months = pd.read_xml("docs/data/etech_sales_2022_2026.xml", xpath=".//monthlyTotal")
```

The wrappers are `<monthlyTotal>` and `<yearlyTotal>`, not `<month>` and
`<year>`, because every `<sale>` already has a `<month>` and a `<year>`
child — `.//month` would match all 10,434 sales too and hand back a frame
of mostly NaN.

**`saleId` is the bill, not the line.** Every line of one sale carries
the same invoice number, `CINV-NNNN-MMYY` — a counter that restarts at
`0001` each month, then the month and two-digit year, so
`CINV-0001-0122` is the first bill of January 2022 — and `lineNo`
counts 1..n within it. So an
eleven-part rig build reads as eleven rows of one sale, which is what it
is. The pair `saleId` + `lineNo` is unique per row.

It used to be the other way round: a running `S000001` per line with a
separate `orderId` for the receipt. In Excel that read badly for exactly
the thing this dataset most wants to show — a rig build came out as
eleven consecutive rows whose *first* column changed on every one of
them, so one RM 6,400 build looked like eleven separate sales unless you
noticed the second column staying still. `orderId` is gone rather than
left holding the identical value under a second name.

Fifteen fields on each sale: `saleId`, `lineNo`, `date`, `year`,
`month`, `orderType` (RETAIL / RIG_BUILD / PREBUILT), `paymentMethod` (CASH / CARD
/ DUITNOW_QR / BANK_TRANSFER), `sku`, `itemType` (PRODUCT / SERVICE),
`itemName`, `category`, `brand`, `quantity`, `unitPrice`, `lineTotal`.

`orderType` is on every line of an order, so whole machines separate out
in one filter:

```python
builds    = df[df.orderType == "RIG_BUILD"].groupby("saleId").lineTotal.sum()
prebuilts = df[df.orderType == "PREBUILT"].groupby("saleId").lineTotal.sum()
```

One `PREBUILT` order is one E-Tech machine, so `nunique()` on its
`saleId` is the count of prebuilts sold — the machine's *name* is not
in the file, only the parts that make it up. See decision 3c.

The monthly and yearly summaries carry `orders`, `lines`, `units`,
`revenue`, `productRevenue` and `serviceRevenue`.

Basket sizes still vary the way a counter's do — one person replacing a
fan, a small office buying six of something — because the generator
draws a buyer profile per order to size the basket. That profile is
thrown away and never written to the file.

### In Excel

Excel will not simply open the XML. It can be made to — Data > Get Data >
From File > From XML — but it asks about a schema and then splits the
three sections into separate tables, which is a lot of clicking to look
at a column of numbers.

**Open `etech_sales_2022_2026.xlsx`.** It is everything in one file:

| Sheet | What is on it |
|---|---|
| Read me first | The synthetic warning, and what is real against what is invented |
| Sales | 10,434 rows, one per line of one receipt, 15 columns |
| Monthly | 56 months — the series to forecast against |
| Yearly | 5 years, 2026 being January to August only |

Dates are real dates and money is real numbers, so the columns sum,
chart and pivot without being converted first — which the CSVs, being
text, do not always do. The header row is frozen with filters on, and
the front sheet carries the warning, so nobody can reach the numbers
without passing it.

The two CSVs are still written for anything that wants a plain file:

- `etech_sales_2022_2026.csv` — the 10,434 sale lines, same 15 fields, one
  header row.
- `etech_sales_monthly.csv` — the 56 monthly totals.

All four files are written in one pass from the same rows, so they
cannot drift out of step with each other. The CSVs carry a UTF-8 BOM,
which is what stops Excel on Windows from mangling names like *be
quiet!* on open; `pd.read_csv()` strips it without being told.

**Opening the sales CSV in Excel shows `#####` in most of the date
column.** Every date is there. A CSV cannot carry a column width, so
Excel opens the column at its default width, 8 characters. On a
Malaysian Windows install it then shows each date as `d/m/yyyy`, which
fits for 4/1/2022 but not for 14/1/2022 or 4/12/2022. In Excel that was
8,258 of the 10,434 dates. Double-click the right edge of the column C
header to widen it, or open the `.xlsx`, whose date column is already
wide enough.

The workbook needs `openpyxl` (`pip install openpyxl`). Without it the
generator writes the other three and says so on the console rather than
failing — the XML is the deliverable, the workbook is the convenience.

## Regenerating

```
python tools/sales_history/generate_sales_xml.py
```

Seeded, so it writes the same four files every time. Change
`ORDERS_AT_START` (how busy the first month is), `ANNUAL_RETENTION` (how
fast the shop shrinks), `RIG_BUILD_SHARE` (how much of the shop is
whole machines) or `SEASONALITY` at the top of the generator to reshape
it; change `SEED` for a different draw of the same shape.

**The seed has been changed twice**, both times for the same reason. The
shop's revenue is lumpy at the top: a rig build is worth seven counter
sales and a prebuilt gaming PC is worth twenty, so a year that happens to
draw a few extra rises above the trend line. On the original dated seed,
20260909, 2025 came in 4% above 2024 while selling 11% fewer orders.
Seed 3 fixed that — and then whole machines went in and left it fixed by
only 2% in the tightest year, which is one unlucky draw from not being
fixed at all.

So it is now 15, chosen by sweeping 1–20 and taking the seed whose
*worst* year-on-year fall is largest: revenue drops at least 16% every
year. Order counts fall every year on all twenty seeds; revenue does on
seventeen of them. That is the draw, not the model, but a series that
ticks up in the middle is a poor thing to hand a forecaster. If a lumpy
one is what you want, seeds 1, 13 and 16 all rise in 2025.

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

`CATEGORY_DEMAND` is the knob that goes with it, and its numbers are not
comparable across price bands — which is the single most misleading
thing in the generator, so it is worth stating plainly. A value there is
a *per-product multiplier that `PRICE_RESISTANCE` then divides by the
price*, not a share of sales. That is why it runs from 1.8 for `Cables`
to 55 for `Prebuilt Gaming PCs` when a cable outsells a prebuilt fifty
to one:

- `Cables` and `Peripherals` sit low because they are cheap twice over —
  RM 19 against a RM 400 drive, with 26 cables to draw from — and
  because they arrive by two routes the weighting never sees,
  `attach_cable()` and `rigs.py`. At 4.5 apiece, where they started, a
  lead landed on one line in five on its own and the two categories took
  29% of every sale line in the file.
- The six whole-machine categories sit high because price and a narrow
  shelf tax them twice over in the other direction. See decision 3b.

Change one of these and check the unit counts, not the weights.
