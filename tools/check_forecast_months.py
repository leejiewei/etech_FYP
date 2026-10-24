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
"""

import json
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
FORECAST = ROOT / "web" / "staff-console" / "data" / "ml_forecast.json"
OUT = ROOT / "web" / "staff-console" / "data" / "forecast_checks.json"

# One entry per month the boss has sent: forecast month -> workbook.
MONTHS = {
    "2026-09": ROOT / "docs" / "data" / "ETECH_September_2026_Sales.xlsx",
}


def month_actual(path):
    """Product sales for the month, services removed as step 3 of the cleaning notebook does."""
    lines = pd.read_excel(path, sheet_name=0)
    lines["Date"] = pd.to_datetime(lines["Date"])
    service = lines["Category"].eq("Service")
    return {
        "days": int(lines["Date"].dt.days_in_month.iloc[0]),
        "firstDay": lines["Date"].min().strftime("%Y-%m-%d"),
        "lastDay": lines["Date"].max().strftime("%Y-%m-%d"),
        "receipts": int(lines.loc[~service, "Invoice No"].nunique()),
        "serviceRemoved": round(float(lines.loc[service, "Line Total (RM)"].sum()), 2),
        "calendarTotal": round(float(lines.loc[~service, "Line Total (RM)"].sum()), 0),
    }


def main():
    coming = {m["month"]: m for m in json.loads(FORECAST.read_text())["nextMonths"]}

    checks = []
    for month, path in MONTHS.items():
        if not path.exists():
            continue
        predicted = coming[month]
        actual = month_actual(path)
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

    OUT.write_text(json.dumps({"checks": checks}, indent=2) + "\n")
    for c in checks:
        print(f"{c['month']}: actual RM {c['actual']:,.0f} over {c['forecastDays']} days "
              f"(RM {c['calendarTotal']:,.0f} over {c['days']}), forecast RM {c['forecast']:,.0f}, "
              f"error {c['errorPct']:+}%, {'inside' if c['inRange'] else 'outside'} the range")


if __name__ == "__main__":
    main()
