# eTech sales receipts, January 2022 – August 2026

`etech_sales_data.xlsx` is eTech's sales history, supplied by the shop:
8,542 receipts from 1 January 2022 to 31 August 2026, RM 31,896,893.61 in
total. It is the input to Objective 2 (sales forecasting and product
segmentation); `ml/01_sales_preprocessing.ipynb` reads it.

## Sheets

| Sheet | What it is | Used by the pipeline |
|---|---|---|
| **Invoices** | One receipt per row | Yes: the data |
| **Summary** | The shop's totals per year and per category | Yes: a cross-check; every year must reconcile exactly |
| **Price Benchmarks** | Market price reference per product and year | No |

## Invoices columns

| Column | Meaning |
|---|---|
| `Date` | Date of sale |
| `Invoice_No` | Receipt number, `CINV-<n>-<MMYY>` |
| `Product_ID`, `Product`, `Brand` | What was sold |
| `Category`, `Subcategory` | The shop's own categories (8 top-level) |
| `Model_Year` | Laptops only |
| `CPU`, `Motherboard`, `PSU`, `Cooler`, `Case`, `GPU`, `RAM`, `SSD` | Complete PC rigs only: the parts in the build (`Cooler` and `GPU` blank on rigs without a graphics card) |
| `Quantity`, `Unit_Price_MYR`, `Invoice_Amount_MYR` | Units, price per unit, receipt total (= quantity × unit price, no discounts) |
| `Year` | Derived from `Date` |

## Things to know before analysing it

- **One product per receipt.** Every receipt holds exactly one product
  line (with a quantity). There are no baskets, so basket or attach-rate
  analysis has nothing to work on.
- **The product range changes in January 2026.** Laptops (`LAP-`) and
  services (`SRV-`) keep their IDs throughout. Every other line moves to
  new models with `E`-prefixed IDs (`RIG-` → `ERIG-`, `CMP-` → `ECMP-`,
  `PER-` → `EPER-`, `PRN-` → `EPRN-`, `CBL-` → `ECBL-`, `ITM-` → `EITM-`).
  A per-product history therefore stops in December 2025 or starts in
  January 2026; category-level series run straight across.
- **Services** are category `Service` / ID prefix `SRV-`: 603 receipts,
  RM 438,102.61. The preprocessing removes them (labour, not stock).
- **Nobody is named.** There is no customer column, so segmentation is
  of products, not customers.

## September 2026: `ETECH_September_2026_Sales_RM484431_43.xlsx`

The shop's September 2026 receipts, supplied 30 Oct 2026: 208 receipts,
RM 484,431.43. Kept exactly as supplied. It is a different layout from
the history above: one sheet, **Receipts**, with `Invoice_No`, `Product`,
`Complete_PC_Rig_Components` (the build's parts in one cell, rigs only),
`Price_MYR` and `Quantity`.

- **No date column.** The whole file is the calendar month 1–30 Sep, so
  it can be checked against the forecast as a month total only, not week
  by week, and it cannot be appended to the weekly training series.
- **No category column.** A service is a product whose name contains
  "Service": 16 receipts, RM 15,845.23, removed as in the history.
  Products: RM 468,586.20.
- It is used by `tools/check_forecast_months.py` to check the frozen
  September forecast (FC-05); the model is not retrained on it.

`ETECH_September_2026_Sales.xlsx` (24 Oct) is **not** the shop's: its own
summary sheet calls it a synthetic dataset. Do not use it.

## Confidentiality

Under the data agreement signed with the shop owner, nothing published
may show customer personal data, supplier details, cost prices or profit
margins. The Invoices sheet holds none of them, and the preprocessing
notebook checks every column name before it runs and again before it
writes anything.
