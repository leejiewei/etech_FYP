#!/usr/bin/env python3
"""Filter the REES46 multi-category clickstream down to eTech's own domain.

The published files are seven monthly .csv.gz totalling 16.5 GB (Oct 2019 - Apr
2020, 285M events). Only a fraction of that is a computer shop, so this script
streams each month straight from https://data.rees46.com - no Kaggle account,
no unzipping - and keeps only the rows worth loading into Supabase.

    event_time, event_type, product_id, category_id, category_code,
    brand, price, user_id, user_session

Typical runs:

    # what categories are actually in there (reads 300 MB, writes nothing)
    python filter_rees46.py taxonomy --max-bytes 300MB

    # the sales table: computer + electronics purchases, all seven months
    python filter_rees46.py extract --events purchase -o out/purchases.csv

    # the behaviour table: every view/cart/purchase in those categories
    python filter_rees46.py extract --events all -o out/events.csv

    # a cheap trial on one month before committing to 16.5 GB
    python filter_rees46.py extract --months 2019-Oct --max-bytes 500MB \
        -o out/sample.csv

Already downloaded the files? Point --source at the folder holding them and
nothing is fetched over the network.
"""

import argparse
import collections
import csv
import gzip
import io
import json
import os
import sys
import time
import urllib.request
import zlib

BASE_URL = "https://data.rees46.com/datasets/marketplace/%s.csv.gz"

ALL_MONTHS = ["2019-Oct", "2019-Nov", "2019-Dec",
              "2020-Jan", "2020-Feb", "2020-Mar", "2020-Apr"]

COLUMNS = ["event_time", "event_type", "product_id", "category_id",
           "category_code", "brand", "price", "user_id", "user_session"]
IDX = {c: i for i, c in enumerate(COLUMNS)}

# What eTech sells. Everything else in the file - appliances, apparel, furniture,
# auto, kids, sport - is dropped.
DEFAULT_PREFIXES = ("computers.", "electronics.")

CHUNK = 1 << 20


# --------------------------------------------------------------------------
# reading


def parse_size(text):
    """'500MB' / '2.5GB' / '1000000' -> bytes."""
    if text is None:
        return None
    t = str(text).strip().upper()
    for suffix, mult in (("GB", 1 << 30), ("MB", 1 << 20), ("KB", 1 << 10), ("B", 1)):
        if t.endswith(suffix):
            return int(float(t[: -len(suffix)]) * mult)
    return int(float(t))


def iter_month_lines(month, source, max_bytes=None, progress=True):
    """Yield decoded CSV lines for one month, header already skipped.

    Decompression is incremental, so memory stays flat no matter how big the
    month is. A byte budget stops early mid-stream, which is what makes the
    trial runs cheap.
    """
    local = None
    if source:
        for name in ("%s.csv.gz" % month, "%s.csv" % month):
            candidate = os.path.join(source, name)
            if os.path.exists(candidate):
                local = candidate
                break
        if local is None:
            raise SystemExit("no file for %s in %s" % (month, source))

    if local and local.endswith(".csv"):
        with open(local, "r", encoding="utf-8", errors="replace") as fh:
            fh.readline()
            for line in fh:
                yield line.rstrip("\n")
        return

    if local:
        stream = open(local, "rb")
        total = os.path.getsize(local)
    else:
        url = BASE_URL % month
        headers = {}
        if max_bytes:
            headers["Range"] = "bytes=0-%d" % (max_bytes - 1)
        stream = urllib.request.urlopen(urllib.request.Request(url, headers=headers),
                                        timeout=600)
        total = max_bytes or int(stream.headers.get("Content-Length") or 0)

    dec = zlib.decompressobj(zlib.MAX_WBITS | 16)
    read = 0
    tail = ""
    first = True
    started = time.time()
    last_note = 0.0
    try:
        while True:
            if max_bytes and read >= max_bytes:
                break
            buf = stream.read(CHUNK)
            if not buf:
                break
            read += len(buf)
            try:
                blob = dec.decompress(buf)
            except zlib.error:
                break  # a byte-budget cut lands mid-member; the rows so far are fine
            if not blob:
                continue
            tail += blob.decode("utf-8", "replace")
            lines = tail.split("\n")
            tail = lines.pop()
            if first and lines:
                lines.pop(0)
                first = False
            for line in lines:
                yield line
            if progress and time.time() - last_note > 5:
                last_note = time.time()
                pct = (100.0 * read / total) if total else 0.0
                rate = read / 1e6 / max(time.time() - started, 0.001)
                sys.stderr.write("\r  %s  %5.1f%%  %6.0f MB read  %4.1f MB/s"
                                 % (month, pct, read / 1e6, rate))
                sys.stderr.flush()
        if tail and not first:
            yield tail
    finally:
        stream.close()
        if progress:
            sys.stderr.write("\r" + " " * 70 + "\r")
            sys.stderr.flush()


def wanted(category_code, prefixes):
    return bool(category_code) and category_code.startswith(prefixes)


# --------------------------------------------------------------------------
# commands


def cmd_taxonomy(args):
    """Count what is in the file without writing anything."""
    prefixes = tuple(args.prefixes)
    full = collections.Counter()
    second = collections.Counter()
    roots = collections.Counter()
    brands = collections.defaultdict(collections.Counter)
    types = collections.Counter()
    total = 0
    kept = 0

    for month in args.months:
        for line in iter_month_lines(month, args.source, parse_size(args.max_bytes)):
            f = line.split(",")
            if len(f) < 9:
                continue
            total += 1
            code = f[IDX["category_code"]]
            roots[code.split(".")[0] if code else "(untagged)"] += 1
            if not wanted(code, prefixes):
                continue
            kept += 1
            types[f[IDX["event_type"]]] += 1
            full[code] += 1
            second[".".join(code.split(".")[:2])] += 1
            brands[".".join(code.split(".")[:2])][f[IDX["brand"]] or "(no brand)"] += 1

    print("scanned %s events, %s matched %s (%.1f%%)"
          % (f"{total:,}", f"{kept:,}", "/".join(prefixes), 100.0 * kept / max(total, 1)))

    print("\nEvery top-level category in the file:")
    for name, count in roots.most_common():
        print("  %-24s %12s  %5.1f%%" % (name, f"{count:,}", 100.0 * count / max(total, 1)))

    print("\nEvent types within the kept rows:")
    for name, count in types.most_common():
        print("  %-24s %12s  %5.1f%%" % (name, f"{count:,}", 100.0 * count / max(kept, 1)))

    print("\nFull category tree of the kept rows:")
    for name, count in sorted(full.items(), key=lambda kv: -kv[1]):
        print("  %-46s %12s" % (name, f"{count:,}"))

    print("\nLeading brands per subcategory:")
    for name, _ in second.most_common():
        top = ", ".join("%s(%s)" % (b, f"{c:,}") for b, c in brands[name].most_common(12))
        print("  %-28s %s" % (name, top))

    if args.out:
        with open(args.out, "w", encoding="utf-8") as fh:
            json.dump({"scanned": total, "kept": kept,
                       "roots": dict(roots), "event_types": dict(types),
                       "categories": dict(full),
                       "brands": {k: dict(v) for k, v in brands.items()}},
                      fh, indent=1, ensure_ascii=False)
        print("\nwrote %s" % args.out)


def cmd_extract(args):
    """Write the filtered rows out as one CSV (optionally gzipped)."""
    prefixes = tuple(args.prefixes)
    keep_types = None if args.events == "all" else set(args.events.split(","))
    max_bytes = parse_size(args.max_bytes)

    out_path = args.out
    parent = os.path.dirname(os.path.abspath(out_path))
    if parent:
        os.makedirs(parent, exist_ok=True)

    opener = gzip.open if out_path.endswith(".gz") else open
    handle = opener(out_path, "wt", encoding="utf-8", newline="")
    writer = csv.writer(handle)
    writer.writerow(COLUMNS + ["source_month"])

    per_month = []
    users = set()
    products = set()
    categories = collections.Counter()
    types = collections.Counter()
    first_seen = None
    last_seen = None
    revenue = 0.0
    total = 0
    kept = 0

    try:
        for month in args.months:
            m_total = 0
            m_kept = 0
            started = time.time()
            for line in iter_month_lines(month, args.source, max_bytes):
                f = line.split(",")
                if len(f) < 9:
                    continue
                total += 1
                m_total += 1
                code = f[IDX["category_code"]]
                if not wanted(code, prefixes):
                    continue
                etype = f[IDX["event_type"]]
                if keep_types is not None and etype not in keep_types:
                    continue
                kept += 1
                m_kept += 1
                writer.writerow(f[:9] + [month])
                types[etype] += 1
                categories[".".join(code.split(".")[:2])] += 1
                users.add(f[IDX["user_id"]])
                products.add(f[IDX["product_id"]])
                stamp = f[IDX["event_time"]]
                if first_seen is None or stamp < first_seen:
                    first_seen = stamp
                if last_seen is None or stamp > last_seen:
                    last_seen = stamp
                if etype == "purchase":
                    try:
                        revenue += float(f[IDX["price"]])
                    except ValueError:
                        pass
            per_month.append((month, m_total, m_kept, time.time() - started))
            print("  %-9s %13s events -> %11s kept   (%.0fs)"
                  % (month, f"{m_total:,}", f"{m_kept:,}", per_month[-1][3]))
    finally:
        handle.close()

    size_mb = os.path.getsize(out_path) / 1e6
    print("\nwrote %s  (%.1f MB)" % (out_path, size_mb))
    print("  %s of %s events kept (%.1f%%)"
          % (f"{kept:,}", f"{total:,}", 100.0 * kept / max(total, 1)))
    print("  %s distinct users, %s distinct products"
          % (f"{len(users):,}", f"{len(products):,}"))
    print("  window %s .. %s" % (first_seen, last_seen))
    if types.get("purchase"):
        print("  %s purchases worth %s" % (f"{types['purchase']:,}", f"{revenue:,.0f}"))
    print("  event types: " + ", ".join("%s %s" % (k, f"{v:,}") for k, v in types.most_common()))
    print("  categories:  " + ", ".join("%s %s" % (k, f"{v:,}") for k, v in categories.most_common(8)))

    summary = {
        "output": os.path.abspath(out_path),
        "size_mb": round(size_mb, 1),
        "prefixes": list(prefixes),
        "events": args.events,
        "months": [{"month": m, "scanned": t, "kept": k, "seconds": round(s, 1)}
                   for m, t, k, s in per_month],
        "scanned": total,
        "kept": kept,
        "users": len(users),
        "products": len(products),
        "first_event": first_seen,
        "last_event": last_seen,
        "purchase_revenue": round(revenue, 2),
        "event_types": dict(types),
        "categories": dict(categories),
    }
    side = os.path.splitext(out_path)[0] + ".summary.json"
    with open(side, "w", encoding="utf-8") as fh:
        json.dump(summary, fh, indent=1)
    print("  summary %s" % side)


def cmd_profile(args):
    """Read a filtered CSV back and report the numbers Objective 2 turns on:
    repeat-purchase rate, monthly revenue, RFM-readiness."""
    opener = gzip.open if args.file.endswith(".gz") else open
    orders = collections.defaultdict(set)      # user -> set of order keys
    monthly = collections.Counter()
    monthly_orders = collections.defaultdict(set)
    spend = collections.Counter()
    last_seen = {}
    categories = collections.Counter()
    rows = 0

    with opener(args.file, "rt", encoding="utf-8", errors="replace") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            if row.get("event_type") != "purchase":
                continue
            rows += 1
            user = row["user_id"]
            stamp = row["event_time"]
            month = stamp[:7]
            # No order_id in this feed - a user's session stands in for the basket.
            order_key = row.get("user_session") or stamp[:13]
            orders[user].add(order_key)
            monthly_orders[month].add((user, order_key))
            try:
                price = float(row["price"])
            except (ValueError, KeyError):
                price = 0.0
            monthly[month] += price
            spend[user] += price
            if user not in last_seen or stamp > last_seen[user]:
                last_seen[user] = stamp
            categories[".".join((row.get("category_code") or "").split(".")[:2])] += 1

    if not rows:
        raise SystemExit("no purchase rows in %s" % args.file)

    counts = [len(v) for v in orders.values()]
    repeat2 = sum(1 for c in counts if c >= 2)
    repeat5 = sum(1 for c in counts if c >= 5)
    print("purchase rows      : %s" % f"{rows:,}")
    print("customers          : %s" % f"{len(orders):,}")
    print("baskets (sessions) : %s" % f"{sum(counts):,}")
    print("2+ baskets         : %s  (%.1f%%)" % (f"{repeat2:,}", 100.0 * repeat2 / len(orders)))
    print("5+ baskets         : %s  (%.1f%%)" % (f"{repeat5:,}", 100.0 * repeat5 / len(orders)))
    print("revenue            : %s" % f"{sum(monthly.values()):,.0f}")
    print("mean spend/customer: %.0f" % (sum(spend.values()) / len(spend)))

    print("\nmonthly revenue (what the forecast will fit):")
    for month in sorted(monthly):
        bar = "#" * int(40 * monthly[month] / max(monthly.values()))
        print("  %s  %14s  %6s baskets  %s"
              % (month, f"{monthly[month]:,.0f}", f"{len(monthly_orders[month]):,}", bar))

    print("\ncategory mix:")
    for name, count in categories.most_common(12):
        print("  %-28s %10s  %5.1f%%" % (name, f"{count:,}", 100.0 * count / rows))

    if len(monthly) < 12:
        print("\nNote: %d monthly points. Fit weekly buckets rather than monthly, or pair "
              "this with Online Retail II for the forecasting chapter." % len(monthly))


# --------------------------------------------------------------------------


def main(argv=None):
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="command", required=True)

    def shared(parser):
        parser.add_argument("--months", default=",".join(ALL_MONTHS),
                            help="comma-separated, e.g. 2019-Oct,2019-Nov (default: all seven)")
        parser.add_argument("--source", default=None,
                            help="folder holding already-downloaded .csv.gz files; "
                                 "omit to stream from data.rees46.com")
        parser.add_argument("--max-bytes", default=None,
                            help="stop after this much compressed data per month, "
                                 "e.g. 500MB - for trial runs")
        parser.add_argument("--prefixes", default=",".join(DEFAULT_PREFIXES),
                            help="category_code prefixes to keep "
                                 "(default: computers.,electronics.)")

    p_tax = sub.add_parser("taxonomy", help="report what is in the file, write nothing")
    shared(p_tax)
    p_tax.add_argument("-o", "--out", default=None, help="also save the counts as JSON")
    p_tax.set_defaults(func=cmd_taxonomy)

    p_ext = sub.add_parser("extract", help="write the filtered rows to CSV")
    shared(p_ext)
    p_ext.add_argument("-o", "--out", required=True,
                       help="output .csv or .csv.gz")
    p_ext.add_argument("--events", default="purchase",
                       help="'purchase' (default), 'all', or a comma list "
                            "such as view,cart,purchase")
    p_ext.set_defaults(func=cmd_extract)

    p_pro = sub.add_parser("profile", help="measure a filtered CSV: repeat rate, monthly revenue")
    p_pro.add_argument("file", help="a CSV written by extract")
    p_pro.set_defaults(func=cmd_profile)

    args = ap.parse_args(argv)
    if hasattr(args, "months"):
        args.months = [m.strip() for m in args.months.split(",") if m.strip()]
        unknown = [m for m in args.months if m not in ALL_MONTHS]
        if unknown and not args.source:
            raise SystemExit("unknown month(s): %s (expected any of %s)"
                             % (", ".join(unknown), ", ".join(ALL_MONTHS)))
        args.prefixes = tuple(p.strip() for p in args.prefixes.split(",") if p.strip())
    return args.func(args)


if __name__ == "__main__":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.exit(main())
