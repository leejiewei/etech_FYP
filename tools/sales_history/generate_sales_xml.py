# ============================================================
# Five years of sales that never happened.
#
# eTech's real orders table holds 37 rows, all of them from 2026, most
# of them placed by me while testing. That is not something you can fit
# a trend to. This script writes what a shop of eTech's size and stock
# would plausibly have sold between January 2022 and August 2026, so
# there is something with a shape to analyse.
#
# It is synthetic and says so in its own header. Nothing here is a
# record of a real transaction, and the file must never be described as
# one. What it *is* built from is real: the 389 products are eTech's
# actual live catalogue, exported from Supabase, with their actual
# prices.
#
# Four things were decided before writing it, and they are the four
# things anyone reading the output will ask about:
#
#   1. The shop shrinks. 2022 is the busiest year and each year after it
#      is quieter, ending with a part-year to August 2026. The drift is
#      about -19% a year applied per month, not a step at each January,
#      because a business does not lose customers on New Year's Day.
#      Seasonality and noise sit on top, so an individual year can come
#      in above or below the line -- which is the point, since a series
#      with no noise in it is not worth forecasting.
#
#   2. A year only sells what that year could sell. An RTX 5070 does not
#      appear in 2022. launch_years.py decides this by reading the part
#      name; see the note there about how much that is worth.
#
#   3. Services are in it. Sixteen of them, invented in services.py,
#      because a computer shop that only sells boxes is not a computer
#      shop. Service revenue falls across the window too, but not as
#      steeply as hardware and not in a straight line -- 2023 comes in
#      slightly above 2022. The repair bench outlives the sales floor,
#      which is what usually happens to a shrinking retailer.
#
#   4. Prices drift. The catalogue price is today's price, so selling a
#      Ryzen 5 5600 in 2022 at its 2026 price would be wrong in the one
#      direction that matters for revenue. Older years are marked up.
#
# Run it:  python tools/sales_history/generate_sales_xml.py
# It is seeded, so it writes the same file every time.
# ============================================================

import json
import math
import os
import random
import sys
from datetime import date, timedelta
from xml.sax.saxutils import escape

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import services                                    # noqa: E402
from launch_years import launch_year               # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
CATALOGUE = os.path.join(HERE, "catalogue_snapshot.json")
OUTPUT = os.path.join(REPO, "docs", "data", "etech_sales_2022_2026.xml")

SEED = 20260909

START = date(2022, 1, 1)
END = date(2026, 8, 31)

# ------------------------------------------------------------
# The decline.
#
# ORDERS_AT_START is orders in the first month. ANNUAL_RETENTION is what
# fraction of business survives a year -- 0.81 means losing about a
# fifth of it, every year, for five years. Applied per-month as a smooth
# exponential rather than a yearly step.
# ------------------------------------------------------------
ORDERS_AT_START = 70
ANNUAL_RETENTION = 0.81
MONTHLY_DECAY = ANNUAL_RETENTION ** (1.0 / 12.0)

# Month-of-year multipliers, normalised to average 1.0 below. December
# and November carry year-end and the 11.11/12.12 sales; June is the
# mid-year school holiday; February is the flat month after Chinese New
# Year spending.
SEASONALITY = {
    1: 1.15, 2: 0.88, 3: 0.98, 4: 0.95, 5: 1.02, 6: 1.12,
    7: 0.96, 8: 0.94, 9: 0.97, 10: 1.03, 11: 1.18, 12: 1.32,
}
_season_mean = sum(SEASONALITY.values()) / 12.0
SEASONALITY = {m: v / _season_mean for m, v in SEASONALITY.items()}

# Month-to-month randomness. 0.10 keeps the trend visible through it.
MONTH_NOISE_SIGMA = 0.10

# What a year's prices were, as a multiple of the 2026 catalogue price.
YEAR_PRICE_FACTOR = {2022: 1.28, 2023: 1.20, 2024: 1.12, 2025: 1.05, 2026: 1.00}
LAUNCH_YEAR_PREMIUM = 1.06        # a part costs more in the year it arrives

# Gross margin by category. Components are thin, accessories are not,
# and a laptop is the thinnest thing in the shop.
MARGINS = {
    "Laptops": 0.06, "GPU": 0.07, "CPU": 0.07,
    "Motherboard": 0.10, "RAM": 0.10, "Laptop Memory": 0.12, "Storage": 0.12,
    "Monitors": 0.10, "PSU": 0.14, "Router": 0.14, "Mesh WiFi": 0.14,
    "Cellular Router": 0.14, "Inkjet": 0.10, "Laser": 0.10, "Ink Tank": 0.10,
    "Case": 0.18, "Cooler": 0.18, "Projector": 0.15, "Screen": 0.15,
    "Accessory": 0.20, "Gaming Gear": 0.22, "Case Fans": 0.25,
    "Monitor Arms": 0.25, "Consumables": 0.25, "ARGB Lighting": 0.30,
    "Power Adapters": 0.30, "Mounting": 0.30, "Cable Kits": 0.35,
    "Prebuilt Gaming PCs": 0.12, "Office PC Series": 0.12,
    "Custom Office CO1": 0.12, "Branded Desktops": 0.12, "AIO Desktops": 0.12,
}
DEFAULT_MARGIN = 0.15

# How often a category turns up on a receipt, relative to the others.
# Storage and memory move constantly; a projector does not.
CATEGORY_DEMAND = {
    "Storage": 10.0, "RAM": 9.0, "Case Fans": 7.0, "Cooler": 6.0,
    "Motherboard": 6.0, "CPU": 6.0, "GPU": 6.0, "Monitors": 6.0,
    "PSU": 5.0, "Case": 5.0, "Laptops": 5.0, "Cable Kits": 4.0,
    "ARGB Lighting": 4.0, "Consumables": 4.0, "Laptop Memory": 3.0,
    "Router": 3.0, "Power Adapters": 3.0, "Gaming Gear": 3.0,
    "Ink Tank": 2.0, "Mounting": 2.0, "Inkjet": 1.5, "Monitor Arms": 1.5,
    "Prebuilt Gaming PCs": 1.5, "Office PC Series": 1.5, "Laser": 1.0,
    "Custom Office CO1": 1.0, "Mesh WiFi": 1.0, "Branded Desktops": 1.0,
    "AIO Desktops": 0.8, "Projector": 0.6, "Cellular Router": 0.6,
    "Accessory": 0.5, "Screen": 0.4,
}
DEFAULT_DEMAND = 1.0

CUSTOMER_TYPES = [("INDIVIDUAL", 0.78), ("SME", 0.18), ("SCHOOL", 0.04)]

# Online share of orders: 15% at the start, 45% by the end. The shop is
# shrinking and moving online at the same time, which is the ordinary
# story of a physical retailer in these years.
ONLINE_SHARE_START = 0.15
ONLINE_SHARE_END = 0.45

# Share of orders that are a repair job with no hardware on them. Rises
# as the sales floor quietens, so services fall more slowly than boxes.
SERVICE_ONLY_SHARE_START = 0.14
SERVICE_ONLY_SHARE_END = 0.22


def month_sequence(start, end):
    """Every (year, month) from start to end inclusive."""
    year, month = start.year, start.month
    while (year, month) <= (end.year, end.month):
        yield year, month
        month += 1
        if month == 13:
            year, month = year + 1, 1


def days_in_month(year, month):
    if month == 12:
        return 31
    return (date(year, month + 1, 1) - date(year, month, 1)).days


def poisson(rng, mean):
    """Knuth. Small means only, which is all this needs."""
    if mean <= 0:
        return 0
    limit = math.exp(-mean)
    count, product = 0, rng.random()
    while product > limit:
        count += 1
        product *= rng.random()
    return count


def weighted_choice(rng, pairs):
    """pairs is [(thing, weight), ...] with weights > 0."""
    total = sum(weight for _, weight in pairs)
    threshold = rng.random() * total
    running = 0.0
    for thing, weight in pairs:
        running += weight
        if running >= threshold:
            return thing
    return pairs[-1][0]


def load_products(rng):
    with open(CATALOGUE, encoding="utf-8") as handle:
        rows = json.load(handle)

    products = []
    for row in rows:
        category = row["category"] or "Uncategorised"
        price = float(row["price"])
        if price <= 0:
            continue
        year = launch_year(row["name"])

        # A part released in 2025 was not on the shelf in January 2025.
        # Spread arrivals across the year so availability turns on mid
        # year, except for the long-standing stock, which is always in.
        month = 1 if year <= 2018 else rng.randint(1, 12)

        products.append({
            "sku": "P-%d" % row["product_id"],
            "type": "PRODUCT",
            "name": row["name"],
            "category": category,
            "brand": row["brand"] or "Unbranded",
            "price": price,
            "margin": MARGINS.get(category, DEFAULT_MARGIN),
            "launch_year": year,
            "launch_month": month,
            "may_repeat": price < 300,
            "tags": set(),
        })
    return products


def available(item, year, month):
    if item["type"] == "SERVICE":
        return True
    return (item["launch_year"], item["launch_month"]) <= (year, month)


def line_weight(item):
    """Cheap things sell more often than dear ones, within a category."""
    return CATEGORY_DEMAND.get(item["category"], DEFAULT_DEMAND) / math.sqrt(item["price"])


def unit_price_in(item, year, rng):
    factor = YEAR_PRICE_FACTOR.get(year, 1.0)
    if item["type"] == "PRODUCT" and item["launch_year"] == year:
        factor *= LAUNCH_YEAR_PREMIUM
    jitter = rng.uniform(0.98, 1.02)
    return round(item["price"] * factor * jitter, 2)


def pick_quantity(rng, item, customer_type):
    price = item["price"]
    if item["type"] == "SERVICE":
        top = 3 if item["may_repeat"] else 1
    elif price < 100:
        top = 6
    elif price < 300:
        top = 4
    elif price < 1000:
        top = 2
    else:
        top = 1

    if customer_type == "SME":
        top = min(top * 2, 10)
    elif customer_type == "SCHOOL":
        top = min(top * 3, 20)

    if top == 1:
        return 1
    # Heavily weighted to the low end: most receipts say 1.
    weights = [(n, 1.0 / (n ** 1.6)) for n in range(1, top + 1)]
    return weighted_choice(rng, weights)


def progress(year, month):
    """0.0 at the first month of the window, 1.0 at the last."""
    months = list(month_sequence(START, END))
    return months.index((year, month)) / float(len(months) - 1)


def payment_method(rng, channel, year):
    # DuitNow QR keeps taking share off cash and cards through the window.
    qr_shift = (year - 2022) * 0.03
    if channel == "ONLINE":
        return weighted_choice(rng, [
            ("BANK_TRANSFER", 0.55 - qr_shift),
            ("DUITNOW_QR", 0.35 + qr_shift),
            ("CARD", 0.10),
        ])
    return weighted_choice(rng, [
        ("CASH", 0.55 - qr_shift),
        ("CARD", 0.25),
        ("DUITNOW_QR", 0.15 + qr_shift),
        ("BANK_TRANSFER", 0.05),
    ])


def attach_service(rng, categories, service_items):
    """A hardware order sometimes comes with labour. What kind depends on
    what was bought: a CPU and a motherboard means somebody is building."""
    build = {"CPU", "Motherboard", "GPU", "PSU", "Case", "Cooler", "RAM"}
    laptop = {"Laptops", "Laptop Memory"}
    printer = {"Inkjet", "Laser", "Ink Tank", "Consumables"}
    network = {"Router", "Mesh WiFi", "Cellular Router"}

    if categories & build:
        chance, tag = 0.55, "build"
    elif categories & laptop:
        chance, tag = 0.35, "laptop"
    elif categories & printer:
        chance, tag = 0.30, "printer"
    elif categories & network:
        chance, tag = 0.40, "network"
    else:
        chance, tag = 0.12, "repair"

    if rng.random() > chance:
        return None
    candidates = services.by_tag(service_items, tag) or service_items
    return rng.choice(candidates)


def build_order(rng, year, month, day, order_id, products, service_items, service_only):
    customer_type = weighted_choice(rng, CUSTOMER_TYPES)
    share = ONLINE_SHARE_START + (ONLINE_SHARE_END - ONLINE_SHARE_START) * progress(year, month)
    channel = "ONLINE" if rng.random() < share else "WALK_IN"
    # A repair is handed over a counter; you cannot post a broken laptop
    # to a shop that has no courier account.
    if service_only:
        channel = "WALK_IN"
    method = payment_method(rng, channel, year)

    chosen = []
    if service_only:
        repairs = services.by_tag(service_items, "repair")
        for item in rng.sample(repairs, min(len(repairs), 1 if rng.random() < 0.75 else 2)):
            chosen.append(item)
    else:
        stock = [item for item in products if available(item, year, month)]
        if not stock:
            return None
        if customer_type == "SCHOOL":
            count = rng.randint(2, 6)
        elif customer_type == "SME":
            count = rng.randint(1, 5)
        else:
            count = weighted_choice(rng, [(1, 0.52), (2, 0.30), (3, 0.13), (4, 0.05)])

        weights = [(item, line_weight(item)) for item in stock]
        seen = set()
        for _ in range(count):
            item = weighted_choice(rng, weights)
            if item["sku"] in seen:
                continue
            seen.add(item["sku"])
            chosen.append(item)

        extra = attach_service(rng, {item["category"] for item in chosen}, service_items)
        if extra is not None:
            chosen.append(extra)

    if not chosen:
        return None

    lines = []
    for item in chosen:
        quantity = pick_quantity(rng, item, customer_type)
        unit_price = unit_price_in(item, year, rng)
        unit_cost = round(unit_price * (1.0 - item["margin"]), 2)
        lines.append({
            "sku": item["sku"],
            "item_type": item["type"],
            "name": item["name"],
            "category": item["category"],
            "brand": item["brand"],
            "quantity": quantity,
            "unit_price": unit_price,
            "unit_cost": unit_cost,
            "line_total": round(unit_price * quantity, 2),
            "line_cost": round(unit_cost * quantity, 2),
        })

    return {
        "order_id": order_id,
        "date": date(year, month, day),
        "channel": channel,
        "customer_type": customer_type,
        "payment_method": method,
        "lines": lines,
    }


def generate():
    rng = random.Random(SEED)
    products = load_products(rng)
    service_items = services.as_items()

    orders = []
    months = list(month_sequence(START, END))
    for index, (year, month) in enumerate(months):
        expected = ORDERS_AT_START * (MONTHLY_DECAY ** index) * SEASONALITY[month]
        expected *= rng.lognormvariate(0.0, MONTH_NOISE_SIGMA)
        count = poisson(rng, expected)

        share = SERVICE_ONLY_SHARE_START + \
            (SERVICE_ONLY_SHARE_END - SERVICE_ONLY_SHARE_START) * progress(year, month)

        last_day = days_in_month(year, month)
        if (year, month) == (END.year, END.month):
            last_day = min(last_day, END.day)

        for _ in range(count):
            day = rng.randint(1, last_day)
            order_id = "ORD-%d-%05d" % (year, len(orders) + 1)
            order = build_order(rng, year, month, day, order_id, products,
                                service_items, rng.random() < share)
            if order is not None:
                orders.append(order)

    orders.sort(key=lambda o: (o["date"], o["order_id"]))
    # Renumber so the ids run in date order, which is what a real system
    # would have done.
    for position, order in enumerate(orders, start=1):
        order["order_id"] = "ORD-%d-%05d" % (order["date"].year, position)
    return products, service_items, orders


# ------------------------------------------------------------
# Writing it out.
#
# Each <sale> is one line of one receipt, with the order's details
# repeated onto it. That repetition is deliberate: a flat record loads
# into pandas with a single read_xml() and into Excel as one table,
# which is the whole point of the file.
# ------------------------------------------------------------
def field(name, value):
    return "      <%s>%s</%s>\n" % (name, escape(str(value)), name)


def write_xml(products, service_items, orders, path):
    per_year = {}
    per_month = {}
    sale_number = 0
    body = []

    for order in orders:
        for line in order["lines"]:
            sale_number += 1
            when = order["date"]
            key_y = when.year
            key_m = (when.year, when.month)
            year_row = per_year.setdefault(key_y, dict(orders=set(), lines=0, units=0,
                                                       revenue=0.0, cost=0.0,
                                                       product_revenue=0.0, service_revenue=0.0))
            month_row = per_month.setdefault(key_m, dict(orders=set(), lines=0, units=0,
                                                         revenue=0.0, cost=0.0,
                                                         product_revenue=0.0, service_revenue=0.0))
            for row in (year_row, month_row):
                row["orders"].add(order["order_id"])
                row["lines"] += 1
                row["units"] += line["quantity"]
                row["revenue"] += line["line_total"]
                row["cost"] += line["line_cost"]
                if line["item_type"] == "SERVICE":
                    row["service_revenue"] += line["line_total"]
                else:
                    row["product_revenue"] += line["line_total"]

            chunk = ["    <sale>\n"]
            chunk.append(field("saleId", "S%06d" % sale_number))
            chunk.append(field("orderId", order["order_id"]))
            chunk.append(field("date", when.isoformat()))
            chunk.append(field("year", when.year))
            chunk.append(field("month", when.month))
            chunk.append(field("channel", order["channel"]))
            chunk.append(field("customerType", order["customer_type"]))
            chunk.append(field("paymentMethod", order["payment_method"]))
            chunk.append(field("sku", line["sku"]))
            chunk.append(field("itemType", line["item_type"]))
            chunk.append(field("itemName", line["name"]))
            chunk.append(field("category", line["category"]))
            chunk.append(field("brand", line["brand"]))
            chunk.append(field("quantity", line["quantity"]))
            chunk.append(field("unitPrice", "%.2f" % line["unit_price"]))
            chunk.append(field("lineTotal", "%.2f" % line["line_total"]))
            chunk.append(field("unitCost", "%.2f" % line["unit_cost"]))
            chunk.append(field("lineProfit", "%.2f" % (line["line_total"] - line["line_cost"])))
            chunk.append("    </sale>\n")
            body.append("".join(chunk))

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as out:
        out.write('<?xml version="1.0" encoding="UTF-8"?>\n')
        out.write('<salesDataset>\n')

        out.write("  <meta>\n")
        out.write(field("shop", "eTech Computer Accessories"))
        out.write(field("currency", "MYR"))
        out.write(field("periodStart", START.isoformat()))
        out.write(field("periodEnd", END.isoformat()))
        out.write(field("synthetic", "true"))
        out.write(field("warning",
                        "SYNTHETIC DATA. Generated by tools/sales_history/"
                        "generate_sales_xml.py. These are not real transactions "
                        "and must not be presented as trading records."))
        out.write(field("catalogueSource",
                        "eTech live Supabase products table, 389 active products, "
                        "exported 2026-09-09. Product names and 2026 prices are real."))
        out.write(field("servicesSource",
                        "Invented. The database holds no services; the 16 in "
                        "tools/sales_history/services.py were written for this dataset."))
        out.write(field("trend",
                        "Declining. Orders fall about 19%% per year, smoothly, "
                        "from a peak in 2022 to a part-year ending August 2026."))
        out.write(field("seed", SEED))
        out.write("  </meta>\n")

        out.write("  <sales>\n")
        for chunk in body:
            out.write(chunk)
        out.write("  </sales>\n")

        # <monthlyTotal> and <yearlyTotal> rather than <month> and <year>,
        # which is not fussiness: every <sale> already carries a <month>
        # and a <year> child, so pd.read_xml(xpath=".//month") matched all
        # 5,381 sales as well as the 56 summary rows and returned a frame
        # of mostly NaN. The wrapper names have to be unique in the whole
        # document for the summaries to be readable on their own.
        out.write("  <monthlySummary>\n")
        for (year, month) in sorted(per_month):
            row = per_month[(year, month)]
            out.write("    <monthlyTotal>\n")
            out.write(field("period", "%04d-%02d" % (year, month)))
            out.write(field("year", year))
            out.write(field("month", month))
            out.write(field("orders", len(row["orders"])))
            out.write(field("lines", row["lines"]))
            out.write(field("units", row["units"]))
            out.write(field("revenue", "%.2f" % row["revenue"]))
            out.write(field("productRevenue", "%.2f" % row["product_revenue"]))
            out.write(field("serviceRevenue", "%.2f" % row["service_revenue"]))
            out.write(field("grossProfit", "%.2f" % (row["revenue"] - row["cost"])))
            out.write("    </monthlyTotal>\n")
        out.write("  </monthlySummary>\n")

        out.write("  <yearlySummary>\n")
        for year in sorted(per_year):
            row = per_year[year]
            out.write("    <yearlyTotal>\n")
            out.write(field("year", year))
            out.write(field("months", 8 if year == 2026 else 12))
            out.write(field("orders", len(row["orders"])))
            out.write(field("lines", row["lines"]))
            out.write(field("units", row["units"]))
            out.write(field("revenue", "%.2f" % row["revenue"]))
            out.write(field("productRevenue", "%.2f" % row["product_revenue"]))
            out.write(field("serviceRevenue", "%.2f" % row["service_revenue"]))
            out.write(field("grossProfit", "%.2f" % (row["revenue"] - row["cost"])))
            out.write("    </yearlyTotal>\n")
        out.write("  </yearlySummary>\n")
        out.write("</salesDataset>\n")

    return per_year, sale_number


def main():
    products, service_items, orders = generate()
    per_year, lines = write_xml(products, service_items, orders, OUTPUT)

    print("wrote %s" % OUTPUT)
    print("%d products, %d services, %d orders, %d sale lines"
          % (len(products), len(service_items), len(orders), lines))
    print()
    print("%-6s %8s %8s %14s %14s %14s" %
          ("year", "orders", "lines", "revenue", "services", "gross profit"))
    for year in sorted(per_year):
        row = per_year[year]
        print("%-6d %8d %8d %14.2f %14.2f %14.2f"
              % (year, len(row["orders"]), row["lines"], row["revenue"],
                 row["service_revenue"], row["revenue"] - row["cost"]))


if __name__ == "__main__":
    main()
