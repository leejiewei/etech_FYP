"""
Exports the Objective 2 model results into a JSON file the staff console reads.

The admin pages otherwise talk to Supabase, which holds the online shop: a few
dozen orders over a handful of months. The models in ml/ are fitted on the
shop's own sales receipts, Jan 2022 - Aug 2026 (docs/data/etech_sales_data.xlsx),
which reach back far further than the online orders do. A trend over the online
orders alone would be a number with nothing behind it, so the forecast page
reads this file instead.

Run after re-executing ml/02_forecasting.ipynb, ml/03_segmentation.ipynb or
ml/04_purchase_segmentation.ipynb:

    python tools/export_ml_to_web.py
"""

import json
from datetime import date, timezone, datetime
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.linear_model import Ridge
from sklearn.metrics import r2_score

ROOT = Path(__file__).resolve().parents[1]
PROCESSED = ROOT / "ml" / "data" / "processed"
OUT = ROOT / "web" / "staff-console" / "data" / "ml_forecast.json"

RANDOM_STATE = 42
TRAIN_FRACTION = 0.8
MONTHS = [f"m_{i}" for i in range(2, 13)]
FEATURES = ["t"] + MONTHS
MONTHS_AHEAD = 6


def load_weekly():
    """The full 243-week series, reassembled from the two split files."""
    train = pd.read_csv(PROCESSED / "train_weekly.csv", parse_dates=["weekStart"])
    test = pd.read_csv(PROCESSED / "test_weekly.csv", parse_dates=["weekStart"])
    weekly = (pd.concat([train, test], ignore_index=True)
                .sort_values("weekStart").reset_index(drop=True))
    if not (weekly.weekStart.diff().dropna().dt.days == 7).all():
        raise SystemExit("weekly series is not contiguous -- re-run 01_sales_preprocessing.ipynb")
    return weekly


def fit_and_forecast(weekly):
    """The same chronological 80/20 split and Ridge fit as 02_forecasting.ipynb."""
    cut = int(len(weekly) * TRAIN_FRACTION)
    train, test = weekly.iloc[:cut], weekly.iloc[cut:]

    model = Ridge(alpha=1.0).fit(train[FEATURES].to_numpy(), train.revenue.to_numpy())
    predicted = model.predict(test[FEATURES].to_numpy())

    actual = test.revenue.to_numpy()
    error = actual - predicted
    weekly_wape = np.abs(error).sum() / actual.sum() * 100

    monthly = (pd.DataFrame({"weekStart": test.weekStart.to_numpy(),
                             "actual": actual, "forecast": predicted})
                 .assign(month=lambda d: d.weekStart.dt.to_period("M").astype(str))
                 .groupby("month")[["actual", "forecast"]].sum()
                 .iloc[1:-1])          # first and last months only part-covered by whole weeks
    monthly_wape = (monthly.forecast - monthly.actual).abs().sum() / monthly.actual.sum() * 100

    return train, test, predicted, {
        "weeklyWAPE": round(weekly_wape, 1),
        "weeklyAccuracy": round(100 - weekly_wape, 1),
        "monthlyWAPE": round(monthly_wape, 1),
        "monthlyAccuracy": round(100 - monthly_wape, 1),
        "mae": round(float(np.abs(error).mean()), 0),
        "rmse": round(float(np.sqrt((error ** 2).mean())), 0),
        "r2": round(float(r2_score(actual, predicted)), 3),
        "monthlyR2": round(float(r2_score(monthly.actual, monthly.forecast)), 3),
    }, monthly


def next_months(weekly, monthly_wape, count=MONTHS_AHEAD):
    """What the model expects the coming month to take.

    Everything else in this file is backtesting: fit on the first 80% of the
    series, predict the last 20%, and report how close it got. That is how you
    earn the right to quote an accuracy figure, but it is not a forecast --
    every week it "predicts" already happened.

    This is the forecast. The same Ridge specification is refitted on the whole
    series, including the test weeks, because when you are actually predicting
    forward there is no reason to withhold the most recent year from the model.
    The weeks of the next calendar month are then built out and summed.

    Two things about the number that the page has to say out loud:

      * A week belongs to the month its Monday falls in, which is the same rule
        the monthly backtest uses. It means a month gets four or five whole
        weeks and never a fraction of one, so a four-week month is genuinely
        smaller than a five-week one and the count is reported alongside.

      * The band is the held-out monthly WAPE applied to the point estimate. It
        is the error this model actually made on months it had never seen, not
        a confidence interval from the fit, and it is the honest width to put
        around a single number.

    The staff console steps through these one month at a time from a button.
    Six months is as far as the band means anything: the backtest's test
    block starts one week and ends eleven months after the last week the
    model saw, so the held-out WAPE was earned on predictions at least that
    far ahead. A year out would be outside anything it was scored on.
    """
    model = Ridge(alpha=1.0).fit(weekly[FEATURES].to_numpy(), weekly.revenue.to_numpy())

    last_week = weekly.weekStart.max()
    first = last_week.to_period("M") + 1
    last = first + (count - 1)

    # Every week from the end of the data to the end of the last month asked
    # for, each carrying the trend index it would have had.
    by_month, t, week = {}, int(weekly.t.max()), last_week
    while True:
        week = week + pd.Timedelta(days=7)
        t += 1
        period = week.to_period("M")
        if period > last:
            break
        if period >= first:
            by_month.setdefault(period, []).append((week, t))

    return [month_forecast(model, weekly, period, weeks, monthly_wape, last_week)
            for period, weeks in sorted(by_month.items())]


def month_forecast(model, weekly, target, weeks, monthly_wape, last_week):
    """One coming month: its weeks predicted, summed and set beside last year."""
    rows = []
    for week, t in weeks:
        features = {"t": t}
        for i in range(2, 13):
            features[f"m_{i}"] = 1 if week.month == i else 0
        rows.append(features)

    predicted = model.predict(pd.DataFrame(rows)[FEATURES].to_numpy())
    # A negative week is arithmetic, not a forecast: the shop cannot take less
    # than nothing, and a linear model extrapolating a quiet January will
    # happily say so.
    predicted = np.clip(predicted, 0, None)
    total = float(predicted.sum())

    # The same month a year earlier, as context. Whether the model is calling
    # for a better or a worse month than last year is the first question
    # anybody asks of a single number.
    #
    # Compared per week, and that is not fussiness. Because a week belongs to
    # the month its Monday falls in, September 2026 gets four weeks and
    # September 2025 got five. Comparing the totals reports a 52% collapse
    # where the model is really calling for a 40% quieter week -- half the
    # headline would be the calendar, not the shop.
    year_before = target - 12
    prior = weekly[weekly.weekStart.dt.to_period("M") == year_before]
    prior_total = float(prior.revenue.sum()) if len(prior) else None
    prior_weeks = int(len(prior))

    per_week = total / len(weeks)
    prior_per_week = (prior_total / prior_weeks) if prior_weeks else None

    return {
        "month": str(target),
        "label": target.strftime("%B %Y"),
        "weeks": len(weeks),
        "weekStarts": [w.strftime("%Y-%m-%d") for w, _ in weeks],
        "revenue": round(total, 0),
        "low": round(total * (1 - monthly_wape / 100), 0),
        "high": round(total * (1 + monthly_wape / 100), 0),
        "bandPct": monthly_wape,
        "fittedTo": last_week.strftime("%Y-%m-%d"),
        "fittedWeeks": int(len(weekly)),
        "perWeek": round(per_week, 0),
        "priorYear": None if prior_total is None else round(prior_total, 0),
        "priorYearWeeks": prior_weeks,
        "priorYearPerWeek": (None if prior_per_week is None
                             else round(prior_per_week, 0)),
        # Per week, deliberately. See the note above about the week counts.
        "changePct": (None if not prior_per_week
                      else round((per_week - prior_per_week) / prior_per_week * 100, 1)),
        "changeBasis": "per week",
    }


def segments():
    """Cluster summary from 03_segmentation.ipynb, plus the slowest current sellers."""
    path = PROCESSED / "product_segments.csv"
    if not path.exists():
        return None, []

    seg = pd.read_csv(path)
    total = seg.revenue.sum()
    summary = (seg.groupby("segment")
                  .agg(skus=("sku", "size"), revenue=("revenue", "sum"),
                       medPrice=("avg_price", "median"), medUnitsWk=("units_per_wk", "median"),
                       current=("status", lambda s: int((s == "Current range").sum())))
                  .sort_values("revenue", ascending=False).reset_index())
    summary["revShare"] = summary.revenue / total * 100

    rows = [{"segment": r.segment, "skus": int(r.skus), "revenue": round(r.revenue, 0),
             "revShare": round(r.revShare, 1), "medPrice": round(r.medPrice, 0),
             "medUnitsWk": round(r.medUnitsWk, 1), "current": int(r.current)}
            for r in summary.itertuples()]

    # The products in the current range that turn over least often -- the ones
    # worth a second look before reordering.
    slowest = (seg[seg.status == "Current range"]
               .nsmallest(10, "units_per_wk")[["name", "category", "units", "weeks_on_sale", "units_per_wk"]])
    slowest_rows = [{"name": r.name, "category": r.category, "units": int(r.units),
                     "weeksOnSale": round(r.weeks_on_sale, 0), "unitsPerWk": round(r.units_per_wk, 2)}
                    for r in slowest.itertuples()]
    return rows, slowest_rows


GROUP_ORDER = ["Gaming & performance", "Business & office", "Everyday computers", "Parts & accessories"]


def purchase_groups():
    """The four customer groups from 04_purchase_segmentation.ipynb.

    Each receipt is one buyer's purchase, so these are groups of purchases, not
    of people. For each group: how many purchases and how much money, what it
    sells most of, and its busiest month. Selling prices only -- no cost, margin
    or customer columns, in line with the data agreement.
    """
    path = PROCESSED / "purchase_segments.csv"
    if not path.exists():
        return []

    lines = pd.read_csv(path, parse_dates=["date"])
    total_purchases, total_revenue = len(lines), lines.lineTotal.sum()

    # Busiest month from full years only: 2026 has no September to December yet.
    full = lines[lines.date.dt.year <= 2025]
    by_month = full.groupby([full.segment, full.date.dt.month]).size().unstack(fill_value=0)

    rows = []
    for name in GROUP_ORDER:
        g = lines[lines.segment == name]
        if g.empty:
            continue
        top = g.subcategory.value_counts().head(4)
        # By name, not sku: the shop's product codes change in January 2026, and
        # the name is what carries a product across that change.
        top_items = g.groupby("itemName").quantity.sum().sort_values(ascending=False).head(3)
        busiest = int(by_month.loc[name].idxmax()) if name in by_month.index else None
        rows.append({
            "segment": name,
            "purchases": int(len(g)),
            "share": round(len(g) / total_purchases * 100, 1),
            "revenue": round(float(g.lineTotal.sum()), 0),
            "revShare": round(float(g.lineTotal.sum() / total_revenue * 100), 1),
            "medPrice": round(float(g.unitPrice.median()), 0),
            "bestSellers": [{"name": n, "purchases": int(c)} for n, c in top.items()],
            "topProducts": [{"name": n, "units": int(u)} for n, u in top_items.items()],
            "busiestMonth": None if busiest is None else date(2000, busiest, 1).strftime("%B"),
        })
    return rows


def main():
    weekly = load_weekly()
    train, test, predicted, metrics, monthly = fit_and_forecast(weekly)
    coming = next_months(weekly, metrics["monthlyWAPE"])
    segment_rows, slowest_rows = segments()
    group_rows = purchase_groups()

    # The chart shows the last year of history for context, then the forecast block.
    history = train.tail(52)

    payload = {
        "meta": {
            "generated": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
            "source": "docs/data/etech_sales_data.xlsx",
            "model": "Ridge regression (trend + month seasonality)",
            "trainWeeks": int(len(train)),
            "testWeeks": int(len(test)),
            "trainTo": train.weekStart.max().strftime("%Y-%m-%d"),
            "testFrom": test.weekStart.min().strftime("%Y-%m-%d"),
            "testTo": test.weekStart.max().strftime("%Y-%m-%d"),
        },
        "metrics": metrics,
        "nextMonths": coming,
        "history": [{"week": d.strftime("%Y-%m-%d"), "actual": round(v, 0)}
                    for d, v in zip(history.weekStart, history.revenue)],
        "forecast": [{"week": d.strftime("%Y-%m-%d"), "actual": round(a, 0), "forecast": round(f, 0)}
                     for d, a, f in zip(test.weekStart, test.revenue, predicted)],
        "monthly": [{"month": m, "actual": round(r.actual, 0), "forecast": round(r.forecast, 0),
                     "errorPct": round((r.forecast - r.actual) / r.actual * 100, 1)}
                    for m, r in monthly.iterrows()],
        "segments": segment_rows,
        "groups": group_rows,
        "slowest": slowest_rows,
    }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    size = OUT.stat().st_size / 1024
    print(f"wrote {OUT.relative_to(ROOT)}  ({size:,.1f} KB)")
    print(f"  {len(payload['history'])} history weeks, {len(payload['forecast'])} forecast weeks, "
          f"{len(payload['monthly'])} months, {len(segment_rows or [])} segments, "
          f"{len(group_rows)} customer groups")
    print(f"  weekly WAPE {metrics['weeklyWAPE']}%  monthly WAPE {metrics['monthlyWAPE']}%")
    for m in coming:
        print(f"  {m['label']:<15} ({m['weeks']} weeks) RM {m['revenue']:>9,.0f} "
              f"(RM {m['low']:,.0f} - RM {m['high']:,.0f})")


if __name__ == "__main__":
    main()
