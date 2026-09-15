"""
Exports the Objective 2 model results into a JSON file the staff console reads.

The admin pages otherwise talk to Supabase, which holds the live shop: a few
dozen real orders over a handful of months. The models in ml/ are fitted on the
five-year sales dataset in docs/data/, which is a different body of data
entirely -- far longer, and generated rather than traded. Pointing a model
fitted on one at the other would produce a number with nothing behind it, so
the forecast page reads this file instead and says on its face which dataset it
is describing.

Run after re-executing ml/02_forecasting.ipynb or ml/03_segmentation.ipynb:

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


def segments():
    """Cluster summary from 03_segmentation.ipynb, plus the dormant products."""
    path = PROCESSED / "product_segments.csv"
    if not path.exists():
        return None, []

    seg = pd.read_csv(path)
    total = seg.revenue.sum()
    summary = (seg.groupby("segment")
                  .agg(skus=("sku", "size"), revenue=("revenue", "sum"),
                       medPrice=("avg_price", "median"), medUnits=("units", "median"),
                       medRecency=("recency_wk", "median"))
                  .sort_values("revenue", ascending=False).reset_index())
    summary["revShare"] = summary.revenue / total * 100

    rows = [{"segment": r.segment, "skus": int(r.skus), "revenue": round(r.revenue, 0),
             "revShare": round(r.revShare, 1), "medPrice": round(r.medPrice, 0),
             "medUnits": int(r.medUnits), "medRecency": round(r.medRecency, 0)}
            for r in summary.itertuples()]

    dormant = (seg[seg.segment.str.startswith("Dormant")]
               .nlargest(10, "revenue")[["name", "category", "revenue", "recency_wk"]])
    dormant_rows = [{"name": r.name, "category": r.category,
                     "revenue": round(r.revenue, 0), "recencyWk": round(r.recency_wk, 0)}
                    for r in dormant.itertuples()]
    return rows, dormant_rows


def main():
    weekly = load_weekly()
    train, test, predicted, metrics, monthly = fit_and_forecast(weekly)
    segment_rows, dormant_rows = segments()

    # The chart shows the last year of history for context, then the forecast block.
    history = train.tail(52)

    payload = {
        "meta": {
            "generated": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
            "source": "docs/data/etech_sales_2022_2026.xml",
            "synthetic": True,
            "model": "Ridge regression (trend + month seasonality)",
            "trainWeeks": int(len(train)),
            "testWeeks": int(len(test)),
            "trainTo": train.weekStart.max().strftime("%Y-%m-%d"),
            "testFrom": test.weekStart.min().strftime("%Y-%m-%d"),
            "testTo": test.weekStart.max().strftime("%Y-%m-%d"),
        },
        "metrics": metrics,
        "history": [{"week": d.strftime("%Y-%m-%d"), "actual": round(v, 0)}
                    for d, v in zip(history.weekStart, history.revenue)],
        "forecast": [{"week": d.strftime("%Y-%m-%d"), "actual": round(a, 0), "forecast": round(f, 0)}
                     for d, a, f in zip(test.weekStart, test.revenue, predicted)],
        "monthly": [{"month": m, "actual": round(r.actual, 0), "forecast": round(r.forecast, 0),
                     "errorPct": round((r.forecast - r.actual) / r.actual * 100, 1)}
                    for m, r in monthly.iterrows()],
        "segments": segment_rows,
        "dormant": dormant_rows,
    }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    size = OUT.stat().st_size / 1024
    print(f"wrote {OUT.relative_to(ROOT)}  ({size:,.1f} KB)")
    print(f"  {len(payload['history'])} history weeks, {len(payload['forecast'])} forecast weeks, "
          f"{len(payload['monthly'])} months, {len(segment_rows or [])} segments")
    print(f"  weekly WAPE {metrics['weeklyWAPE']}%  monthly WAPE {metrics['monthlyWAPE']}%")


if __name__ == "__main__":
    main()
