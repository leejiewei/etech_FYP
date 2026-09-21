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

## Confidentiality

Under the data agreement signed with the shop owner, nothing published
may show customer personal data, supplier details, cost prices or profit
margins. The Invoices sheet holds none of them, and the preprocessing
notebook checks every column name before it runs and again before it
writes anything.
