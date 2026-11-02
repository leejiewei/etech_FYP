"""
Checks the frozen forecast against months the boss has since sent.

The six coming months in web/staff-console/data/ml_forecast.json were
predicted from receipts up to August 2026. This script does not refit or
re-export anything: it reads each later month's cash-sales workbook, totals
it the way ml/01_sales_preprocessing.ipynb would (services removed), and
writes the result to web/staff-console/data/forecast_checks.json beside the
forecast.

    python tools/check_forecast_months.py

Data. Only the three cash-sales workbooks in docs/data are read (one line
per item: Cash Sales No., Description, Quantity, Unit Price (RM),
Total Price (RM); a PC rig is listed part by part under one number). A
receipt is one Cash Sales No., however many lines it has, and its month is
the MMYY at the end of that number (CINV-<n>-<MMYY>).

Like for like. The forecast counts a week towards the month its Monday falls
in, so "September 2026" is the four weeks from 7 Sep to 4 Oct -- 28 days. The
boss's figure is the calendar month. The actual is scaled to the forecast's
days (the shop's average day that month, times 28) before it is set beside
the prediction. Scaling the prediction instead gives the same error %.

It also writes each calendar month's product sales from the history workbook
(calendarMonths), so the chart can show what the shop took from the 1st to
the last day of a month beside the model's week-based month. Those are
totals of receipts, never predictions.
"""

import json
import re
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "docs" / "data"
FORECAST = ROOT / "web" / "staff-console" / "data" / "ml_forecast.json"
HISTORY = DATA / "etech sales data jan2022-aug2026.xlsx"
OUT = ROOT / "web" / "staff-console" / "data" / "forecast_checks.json"

# One entry per month the boss has sent: forecast month -> workbook, and the
# month total the shop owner reported. The workbook must add up to that total
# exactly, or the script stops. For both months the owner supplied the total;
# the receipt lines were generated or standardised to add up to it, so only
# the total is the shop's own figure (linesGenerated).
MONTHS = {
    "2026-09": {"file": DATA / "etech sales data september.xlsx", "reportedTotal": 484431.43, "linesGenerated": True},
    "2026-10": {"file": DATA / "eTech_October_2026_Cash_Sales.xlsx", "reportedTotal": 532307.39, "linesGenerated": True},
}

# A service is labour, not stock, and the cleaning notebook removes it. The
# cash-sales layout has no category column, so a service is found by name.
# On the history workbook this finds exactly the 603 receipts whose category
# is Service in the archived dated copy, and no product (checked 2 Nov 2026).
SERVICE = re.compile(
    r"service|repair|install|setup|support|cleaning|upgrade|recovery|diagnos|"
    r"deployment|maintenance|assembly|configuration|labou?r|migration|warranty",
    re.IGNORECASE)


def cash_sales(path):
    """Every line of a cash-sales workbook, with its month and whether it is a service.
    The line value is quantity x unit price (the October file's totals are formulas)."""
    lines = pd.read_excel(path, sheet_name=0)
    lines = lines[lines["Cash Sales No."].notna()].copy()
    number = lines["Cash Sales No."].astype(str)
    assert number.str.fullmatch(r"CINV-\d{4}-\d{4}").all(), f"bad receipt number in {path.name}"
    lines["line"] = (lines["Quantity"] * lines["Unit Price (RM)"]).round(2)
    lines["month"] = "20" + number.str[-2:] + "-" + number.str[-4:-2]
    lines["service"] = lines["Description"].astype(str).str.contains(SERVICE)
    return lines


def month_actual(spec, month):
    """Product sales for one calendar month, services removed."""
    lines = cash_sales(spec["file"])
    assert set(lines["month"]) == {month}, f"{spec['file'].name} holds other months: {set(lines['month'])}"
    total = round(float(lines["line"].sum()), 2)
    assert abs(total - spec["reportedTotal"]) < 0.005, f"{spec['file'].name} adds up to {total}, not {spec['reportedTotal']}"
    products = lines[~lines["service"]]
    first = pd.Period(month, "M")
    return {
        "days": int(first.days_in_month),
        "firstDay": first.start_time.strftime("%Y-%m-%d"),
        "lastDay": first.end_time.strftime("%Y-%m-%d"),
        "receipts": int(lines["Cash Sales No."].nunique()),
        "productReceipts": int(products["Cash Sales No."].nunique()),
        "lines": int(len(lines)),
        "serviceRemoved": round(float(lines.loc[lines["service"], "line"].sum()), 2),
        "calendarTotal": round(float(products["line"].sum()), 0),
        "reportedTotal": spec["reportedTotal"],
        "linesGenerated": spec["linesGenerated"],
    }


def calendar_months():
    """Product sales per calendar month from the history workbook, cleaned as
    ml/01_sales_preprocessing.ipynb does: services removed. A rig's parts are
    separate lines of one receipt, so summing lines counts each sale once."""
    lines = cash_sales(HISTORY)
    totals = lines[~lines["service"]].groupby("month")["line"].sum()
    return {month: round(float(total), 2) for month, total in totals.items()}


def main():
    coming = {m["month"]: m for m in json.loads(FORECAST.read_text())["nextMonths"]}

    checks = []
    for month, spec in MONTHS.items():
        if not spec["file"].exists():
            continue
        predicted = coming[month]
        actual = month_actual(spec, month)
        days = predicted["weeks"] * 7
        same_days = round(actual["calendarTotal"] / actual["days"] * days, 0)
        checks.append({
            "month": month,
            "source": spec["file"].relative_to(ROOT).as_posix(),
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
        print(f"{c['month']}: {c['receipts']} receipts, RM {c['reportedTotal']:,.2f} reported; "
              f"products RM {c['calendarTotal']:,.0f} over {c['days']} days = RM {c['actual']:,.0f} over "
              f"{c['forecastDays']}; forecast RM {c['forecast']:,.0f}, error {c['errorPct']:+}%, "
              f"{'inside' if c['inRange'] else 'outside'} the range")


if __name__ == "__main__":
    main()
