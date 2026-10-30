"""
Checks the frozen forecast against months the boss has since sent.

The six coming months in web/staff-console/data/ml_forecast.json were
predicted from receipts up to August 2026. This script does not refit or
re-export anything: it reads each later month's workbook, totals it the way
ml/01_sales_preprocessing.ipynb would (services removed), and writes the
result to web/staff-console/data/forecast_checks.json beside the forecast.

    python tools/check_forecast_months.py

Like for like. The forecast counts a week towards the month its Monday falls
in, so "September 2026" is the four weeks from 7 Sep to 4 Oct -- 28 days. The
boss's file is the calendar month, 30 days. The actual is scaled to 28 days
(the shop's average day that month, times 28) before it is set beside the
prediction. Scaling the prediction to 30 days instead gives the same error %.

It also writes each calendar month's product sales from the training
receipts (calendarMonths), so the chart can show what the shop took from
the 1st to the last day of a month beside the model's week-based month.
Those are totals of real receipts, never predictions.
"""

import json
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
FORECAST = ROOT / "web" / "staff-console" / "data" / "ml_forecast.json"
RECEIPTS = ROOT / "docs" / "data" / "etech_sales_data.xlsx"
OUT = ROOT / "web" / "staff-console" / "data" / "forecast_checks.json"

# One entry per month the boss has sent: forecast month -> workbook.
# Add each month once the boss sends its receipts.
MONTHS = {
    "2026-09": ROOT / "docs" / "data" / "ETECH_September_2026_Sales_RM484431_43.xlsx",
}


def month_actual(path, month):
    """Product sales for the month, services removed as step 3 of the cleaning notebook does.

    The September 2026 file (30 Oct) has one sheet, Receipts, with
    Invoice_No, Product, Complete_PC_Rig_Components, Price_MYR and Quantity,
    and no date: the whole file is the calendar month. It has no Category
    column either, so a service is a product whose name says "Service" --
    every service in it is named that way, and no product is."""
    lines = pd.read_excel(path, sheet_name=0)
    lines["Line"] = lines["Price_MYR"] * lines["Quantity"]
    service = lines["Product"].str.contains("service", case=False)
    first = pd.Period(month, "M")
    return {
        "days": int(first.days_in_month),
        "firstDay": first.start_time.strftime("%Y-%m-%d"),
        "lastDay": first.end_time.strftime("%Y-%m-%d"),
        "receipts": int(lines.loc[~service, "Invoice_No"].nunique()),
        "serviceRemoved": round(float(lines.loc[service, "Line"].sum()), 2),
        "calendarTotal": round(float(lines.loc[~service, "Line"].sum()), 0),
        "reportedTotal": round(float(lines["Line"].sum()), 2),
        **file_basis(path),
    }


def file_basis(path):
    """Whether the workbook says its receipt lines were generated.

    An earlier September file (docs/data/ETECH_September_2026_Sales.xlsx,
    not the shop's) had a summary sheet calling itself a synthetic dataset.
    A file like that is flagged, and the page says so."""
    sheets = pd.read_excel(path, sheet_name=None, header=None)
    summary = sheets.get("Monthly Summary")
    if summary is None:
        return {"linesGenerated": False}
    text = " ".join(summary.astype(str).values.ravel()).lower()
    target = summary[summary[0].astype(str).str.strip().eq("Target Sales")]
    return {
        "reportedTotal": round(float(target.iloc[0, 1]), 2) if len(target) else None,
        "linesGenerated": "synthetic" in text or "not authentic" in text,
    }


def calendar_months():
    """Product sales per calendar month, cleaned as ml/01_sales_preprocessing.ipynb does:
    services removed, grouped by the receipt date. The receipts have no
    cancellations or refunds, and one product line per receipt, so nothing
    else is taken out and nothing can be counted twice."""
    raw = pd.read_excel(RECEIPTS, sheet_name="Invoices")
    sales = raw[raw["Category"].ne("Service")]
    assert sales["Invoice_No"].is_unique
    totals = sales.groupby(sales["Date"].dt.strftime("%Y-%m"))["Invoice_Amount_MYR"].sum()
    return {month: round(float(total), 2) for month, total in totals.items()}


def main():
    coming = {m["month"]: m for m in json.loads(FORECAST.read_text())["nextMonths"]}

    checks = []
    for month, path in MONTHS.items():
        if not path.exists():
            continue
        predicted = coming[month]
        actual = month_actual(path, month)
        days = predicted["weeks"] * 7
        same_days = round(actual["calendarTotal"] / actual["days"] * days, 0)
        checks.append({
            "month": month,
            "source": path.relative_to(ROOT).as_posix(),
            **actual,
            "forecastDays": days,
            "actual": same_days,
            "forecast": predicted["revenue"],
            "low": predicted["low"],
            "high": predicted["high"],
            # Same sign as the backtest: positive means the model said more than the shop took.
            "errorPct": round((predicted["revenue"] - same_days) / same_days * 100, 1),
            "inRange": predicted["low"] <= same_days <= predicted["high"],
        })

    OUT.write_text(json.dumps({"checks": checks, "calendarMonths": calendar_months()}, indent=2) + "\n")
    for c in checks:
        print(f"{c['month']}: actual RM {c['actual']:,.0f} over {c['forecastDays']} days "
              f"(RM {c['calendarTotal']:,.0f} over {c['days']}), forecast RM {c['forecast']:,.0f}, "
              f"error {c['errorPct']:+}%, {'inside' if c['inRange'] else 'outside'} the range")


if __name__ == "__main__":
    main()
