# eTech sales data (cash-sales invoices)

Since 2 November 2026 this folder holds exactly **three** sales workbooks, all in
the shop's cash-sales invoice layout. Nothing else here is sales data.

| File | Covers | Receipts | Lines | Total (RM) |
|---|---|---:|---:|---:|
| `etech sales data jan2022-aug2026.xlsx` | 1 Jan 2022 – 31 Aug 2026 (56 months) | 8,542 | 22,128 | 31,896,893.61 |
| `etech sales data september.xlsx` | 1 – 30 Sep 2026 | 208 | 621 | 484,431.43 |
| `eTech_October_2026_Cash_Sales.xlsx` | 1 – 31 Oct 2026 | 208 | 716 | 532,307.39 |

All counts and totals were checked by script on 2 November 2026.

## Layout

One sheet of invoice lines (the first sheet), one row per item:

| Column | Meaning |
|---|---|
| `Cash Sales No.` | Receipt number, `CINV-<nnnn>-<MMYY>`. **One receipt = one number**, however many lines it has |
| `Description` | What was sold |
| `Quantity` | Units |
| `Unit Price (RM)` | Price per unit |
| `Total Price (RM)` | Quantity × unit price (in the October file this is a formula, `=C×D`) |

**PC rigs.** A complete PC is listed part by part (CPU, motherboard, RAM, SSD,
power supply, case, and graphics card and cooler where it has them), each part
as its own line under the **same** receipt number. There is no separate rig
title line, so a rig is never counted twice.
- The history and September files prefix each part with its type (`CPU: …`).
- The October file lists the parts without the prefix.

**Month.** The month of a receipt is the `MMYY` at the end of its number. For
2022 to August 2026 this agrees with the date on every receipt in the dated copy
(see *Archived files*).

## How the monthly figures are worked out

There are no summary sheets to trust or keep in step: every monthly figure is
derived from the invoice lines, in `tools/check_forecast_months.py`.

1. **Revenue** for a month is the sum of quantity × unit price over its lines.
2. **Receipts** are counted by unique `Cash Sales No.`, never by line.
3. **Products only.** Services are labour, not stock, and the forecast is of
   product sales, so service lines are removed.
   - The layout has no category, so a service is found by name: description
     contains *service, repair, install, setup, support, cleaning, upgrade,
     recovery, diagnos, deployment, maintenance, assembly, configuration,
     labour, migration* or *warranty*.
   - On the history file this finds exactly the 603 service receipts
     (RM 438,102.61) of the dated copy, and no product.
   - The rule's product totals for all 56 months equal the ones the
     forecasting notebook uses, to the cent.

Checks on 2 November 2026:
- No zero or negative quantities or prices, and every line total equals
  quantity × unit price.
- No repeated lines in the history or September files.
- September adds up to the reported RM 484,431.43 and October to the reported
  RM 532,307.39, to the cent. The script stops if either total ever stops
  matching.
- October has 29 lines that repeat another line on the same receipt (mostly
  two identical RAM sticks in one rig, written as two one-unit lines). They are
  left as supplied: they sit inside one receipt each, so receipts are not
  double-counted, and the month total still reconciles.

## What is real and what is generated

| | History, Jan 2022 – Aug 2026 | September 2026 | October 2026 |
|---|---|---|---|
| Month total | Shop's receipts | **Reported by the shop owner** (RM 484,431.43) | **Reported by the shop owner** (RM 532,307.39) |
| Invoice lines | Shop's receipts, supplied 21 Sep 2026, re-laid out as cash sales | Reconstructed to add up to the reported total | Generated to add up to the reported total (the workbook's own *Read Me* sheet says so) |
| Used for | Training the forecast and segmentation | Checking the frozen forecast (month total only) | Checking the frozen forecast (month total only) |

The September and October lines must not be cited as real transactions. Only
their month totals are the shop's figures, so the services taken out of them,
and any comparison built on those lines, are estimates. The Staff Console says
this on both months.

## Where each file is used

- **`tools/check_forecast_months.py`** reads all three files and writes
  `web/staff-console/data/forecast_checks.json`:
  - the calendar-month product sales for 2022 – Aug 2026
  - the September and October checks against the frozen forecast
- **Staff Console, Sales Forecast page and Dashboard:** show both months.
  - Each month's reported total, its product sales scaled to the forecast's
    four weeks, the forecast, and the difference.
  - Every month is marked as an estimate from a reported total.
  - The forecast itself (`ml_forecast.json`, 18 Oct 2026) was not refitted.
- **`ml/01_sales_preprocessing.ipynb`** needs a **date** for every receipt to
  build the weekly series. The cash-sales layout has none, so the notebook reads
  the archived dated copy (below).

## Archived files (2 November 2026)

Moved out of this folder to `D:\eTech_FYP_archive_2Nov2026\sales_data\` (copies
checksum-verified before removal). Not deleted; the two that were tracked are
also in git history.

| File | Why it was moved | Still needed? |
|---|---|---|
| `etech_sales_data.xlsx` | Same 8,542 receipts as the history file above, with `Date`, `Category`, `Brand`, `Product_ID` and the rig parts as columns | **Yes:** the forecasting and segmentation notebooks read it from the archive for the dates |
| `ETECH_September_2026_Sales_RM484431_43.xlsx` | Same 208 receipts and amounts as `etech sales data september.xlsx`, older layout | No |
| `etech_sales_by_month_2022-2026.xlsx` | A compiled monthly summary; monthly figures are now derived from the invoices instead | No |

The earlier `ETECH_September_2026_Sales.xlsx` (24 Oct) was not the shop's file
and was deleted on 2 Nov 2026; it remains only in git history. Do not restore
or use it.

## Confidentiality

Under the data agreement signed with the shop owner, nothing published may show
customer personal data, supplier details, cost prices or profit margins. These
workbooks hold none of them: they record receipt number, item, quantity and
selling price only.
