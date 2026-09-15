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
# Five things were decided before writing it, and they are the five
# things anyone reading the output will ask about:
#
#   1. The shop shrinks. 2022 is the busiest year and each year after it
#      is quieter, ending with a part-year to August 2026. The drift is
#      about -20% a year applied per month, not a step at each January,
#      because a business does not lose customers on New Year's Day. A
#      component price shock from late 2025 steepens it sharply -- see
#      PRICE_SHOCK.
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
#      shop. Service revenue falls with everything else and holds a
#      steady ~8% of turnover throughout.
#
#      That flatness is worth knowing about, because it is not what the
#      settings ask for. SERVICE_ONLY_SHARE_* below raises the proportion
#      of repair-only visits from 14% to 22% across the window, on the
#      usual idea that the repair bench outlives the sales floor. It
#      barely moves the money: a service costs RM 45-250 against an
#      average basket near RM 900, so a lot more repair jobs still add up
#      to very little revenue. Turn those two numbers up hard if the
#      analysis needs a rising service share; the counts will move long
#      before the ringgit do.
#
#      The cable rack and the keyboard shelf are invented for the same
#      reason and in the same way -- see accessories.py. The catalogue
#      export has no HDMI lead, no Cat 6 and three input devices in it,
#      which would have made this a shop that never sold anything under
#      RM 40. They are the opposite of the services in one respect: a
#      lot of receipts, not much money.
#
#      So are the early years' whole computers and monitors -- see
#      dated_stock.py. A laptop or a panel model lives about two years,
#      so a 2026 snapshot holds none of 2022's, and read literally the
#      export says eTech sold its first laptop in 2023 and its first
#      monitor in 2023 as well. Those 34 are the opposite of the cables:
#      not many receipts, a great deal of money.
#
#   4. Prices drift. The catalogue price is today's price, so selling a
#      Ryzen 5 5600 in 2022 at its 2026 price would be wrong in the one
#      direction that matters for revenue. Older years are marked up.
#
#      An E-Tech machine is itemised rather than sold as a name -- see
#      prebuilts.py. Its stock is derived from parts on the live site,
#      so a ZenForge leaving the shop moves eight components and not a
#      product, and the file now says so: one bill, a line per part, and
#      no assembly labour, which is the one thing that separates it from
#      a custom rig.
#
#   5. Every sale is over the counter, and nobody is named. eTech has
#      never traded online -- the web shop in this project is what is
#      being built, not something with five years of orders behind it --
#      so there is no channel column and nothing is marked ONLINE. There
#      is no customer column either: no names, no segments. A sale is a
#      date, a payment method and what was on the receipt.
#
#      A buyer profile is still drawn per order, but only to decide how
#      big the basket is, and it is thrown away before anything is
#      written. See BASKET_PROFILES.
#
# Run it:  python tools/sales_history/generate_sales_xml.py
# It is seeded, so it writes the same four files every time: the XML,
# two CSVs and an Excel workbook, all from one pass over the same rows.
# ============================================================

import csv
import json
import math
import os
import random
import re
import sys
import zipfile
from datetime import date, datetime, timedelta
from xml.sax.saxutils import escape

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import accessories                                 # noqa: E402
import dated_stock                                 # noqa: E402
import prebuilts                                   # noqa: E402
import rigs                                        # noqa: E402
import services                                    # noqa: E402
from launch_years import launch_year               # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
CATALOGUE = os.path.join(HERE, "catalogue_snapshot.json")
OUTPUT = os.path.join(REPO, "docs", "data", "etech_sales_2022_2026.xml")

# The same data as CSV, written alongside the XML.
#
# The XML is the deliverable and the CSVs are a convenience: Excel will
# not simply open a 4.9MB nested XML. It can be made to -- Data > Get
# Data > From File > From XML -- but it asks about a schema and then
# splits the three sections into separate tables, which is a lot of
# clicking to look at a column of numbers. A CSV opens on a double
# click. Both are written from the same rows in one pass, so they cannot
# drift apart.
OUTPUT_CSV = os.path.join(REPO, "docs", "data", "etech_sales_2022_2026.csv")
OUTPUT_MONTHLY_CSV = os.path.join(REPO, "docs", "data", "etech_sales_monthly.csv")

# And the same data again as one Excel workbook.
#
# The three files above are one dataset in three shapes, which is a thing
# people keep having to be told: the sale lines, the monthly totals, and
# an XML that holds both plus the <meta> block. Split across files, the
# two CSVs look like two datasets and neither of them carries the
# warning that none of this happened.
#
# The workbook puts all of it in one place -- a sheet per section and the
# warning on the front sheet, where nobody can open the numbers without
# passing it. Written from the same rows in the same pass as the other
# two, so it cannot drift from them.
OUTPUT_XLSX = os.path.join(REPO, "docs", "data", "etech_sales_2022_2026.xlsx")

# Said in the XML's <meta>, on the workbook's front sheet, and nowhere
# else in two slightly different wordings.
WARNING = ("SYNTHETIC DATA. Generated by tools/sales_history/"
           "generate_sales_xml.py. These are not real transactions "
           "and must not be presented as trading records.")

# Changed three times, and it is worth knowing why before anyone finds it.
#
# The shop's revenue is lumpy at the top: a rig build is worth seven
# counter sales and a prebuilt gaming PC is worth twenty, so a year that
# happens to draw a few extra rises above the trend line. On the
# original dated seed, 20260909, 2025 came in 4% above 2024 while
# selling 11% fewer orders. Seed 3 fixed that, and then whole machines
# went in and left it fixed by only 2% in the tightest year -- true, but
# one unlucky draw from being untrue. Seed 15 was then chosen as the one
# whose *worst* year-on-year fall was largest.
#
# Seed 9 followed the price shock and a doubled ORDERS_AT_START, picked so
# that no month of 2026 collapsed: the late months are the forecast's test
# set, and a seed can pass every yearly test while one 2026 month draws no
# builds and lands at a fifth of its neighbours.
#
# It is 17 since the volume was set to eTech's own counts (see "The
# decline" below). Seeds 1-20 were swept on the settings there and every
# one of them falls in orders every year -- that part is the model, not
# the draw. Seed 17 is the one closest to the shop's figures, all
# receipts counted: 102.7 a week across 2022, 51.5 in September 2025,
# 29.6 across 2026. Its revenue per month falls 12-32% every year, its
# quietest 2026 week still has 19 receipts, and its quietest 2026 month
# still takes 74% of that year's median month by revenue.
SEED = 17

START = date(2022, 1, 1)
END = date(2026, 8, 31)

# ------------------------------------------------------------
# The decline.
#
# The volume comes from the shop, not from a guess. Counting every
# receipt -- parts, cables, repairs and services alike -- eTech's owner
# puts the shop at about 100 a week through 2022, down to about 50 a week
# just before the RAM crisis, and about 30 a week through 2026 once it
# hit. Three settings reproduce that:
#
# ORDERS_AT_START is receipts in the first month. 480 a month is about
# 100 a week across 2022 once the year's own decline is averaged in.
#
# ANNUAL_RETENTION is what fraction of business survives a year. 0.80
# means losing a fifth of it every year, which halves the shop between
# 2022 and September 2025 -- the 100-to-50 fall -- before the price shock
# does anything. Applied per-month as a smooth exponential rather than a
# yearly step.
#
# SHOCK_FOOTFALL_LOSS, below, takes it from 50 to 30.
#
# Earlier versions ran at 100 and then 200 receipts a month with a steeper
# 0.74, which left 2026 at about 11 a week: a third of the shop's figure,
# and too thin for a weekly forecast to score fairly.
# ------------------------------------------------------------
ORDERS_AT_START = 480
ANNUAL_RETENTION = 0.80
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

# ------------------------------------------------------------
# The memory shock.
#
# From late 2025 AI data centres bought up the wafer capacity that makes
# consumer RAM and SSDs, and the price of both roughly tripled through
# 2026; GPUs followed, PC makers raised list prices 15-20% for the second
# half of 2026, and motherboard shipments were forecast to fall 25-30% as
# builders put their upgrades off. That is the reported market; the
# numbers below are this shop's version of it, and are judgement, not
# measurement.
#
# The 2026 catalogue price is the price *after* the shock, so PRICE_SHOCK
# is how many times dearer a category is at the peak than it was before.
# Before SHOCK_START a part sells at catalogue / multiplier (on top of the
# usual YEAR_PRICE_FACTOR); the price climbs in a straight line to the
# catalogue price at SHOCK_PEAK and stays there.
#
# It does three things to the sales, all of which make the fall steeper:
#   - a shocked part costs more, so each one is a bigger line, but
#   - it is picked less often, by the same PRICE_RESISTANCE that makes a
#     dear part rarer than a cheap one, and
#   - fewer people come in at all: SHOCK_FOOTFALL_LOSS of the orders are
#     gone by the peak, on top of ANNUAL_RETENTION. 0.37 is set to the
#     shop's own count -- about 50 receipts a week before the crisis and
#     about 30 across 2026 -- and so is the one number in this block that
#     is not judgement.
# ------------------------------------------------------------
SHOCK_START = (2025, 10)
SHOCK_PEAK = (2026, 6)
PRICE_SHOCK = {
    "RAM": 3.0, "Laptop Memory": 3.0, "Storage": 2.5,
    "GPU": 1.5, "Motherboard": 1.2, "CPU": 1.15,
    "Laptops": 1.15, "Prebuilt Gaming PCs": 1.15, "Branded Desktops": 1.15,
    "AIO Desktops": 1.15, "Office PC Series": 1.15, "Custom Office CO1": 1.15,
}
SHOCK_FOOTFALL_LOSS = 0.37

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
    # The two invented ones carry their margin on the item, from
    # accessories.py; these repeat it so the table is not misleading to
    # read on its own.
    "Cables": accessories.CABLE_MARGIN, "Peripherals": accessories.PERIPHERAL_MARGIN,
    "Prebuilt Gaming PCs": 0.12, "Office PC Series": 0.12,
    "Custom Office CO1": 0.12, "Branded Desktops": 0.12, "AIO Desktops": 0.12,
}
DEFAULT_MARGIN = 0.15

# How often a category turns up on a receipt, relative to the others.
# Storage and memory move constantly; a projector does not.
#
# Cables and Peripherals look far too low here, and are not. The weight
# is divided by price, so a cable is cheap twice over -- RM 19 against a
# RM 400 drive, and 26 of them to draw from -- and it also arrives by
# two other routes the weighting never sees: attach_cable() puts a lead
# on a monitor or router sale, and rigs.py sends a keyboard, a mouse and
# an HDMI cable home with a build. At 4.5 apiece, which is what these
# started at, a lead landed on one receipt line in five on its own and
# the two categories took 29% of all lines between them. These numbers
# put them at 13% and 7%, which is what the rack by the door is worth.
CATEGORY_DEMAND = {
    "Storage": 10.0, "RAM": 9.0, "Case Fans": 7.0, "Cooler": 6.0,
    "Motherboard": 6.0, "CPU": 6.0, "GPU": 6.0, "Monitors": 6.0,
    "PSU": 5.0, "Case": 5.0, "Cable Kits": 4.0,
    "Cables": 1.8, "Peripherals": 2.8,
    "ARGB Lighting": 4.0, "Consumables": 4.0, "Laptop Memory": 3.0,
    "Router": 3.0, "Power Adapters": 3.0, "Gaming Gear": 3.0,
    "Ink Tank": 2.0, "Mounting": 2.0, "Inkjet": 1.5, "Monitor Arms": 1.5,
    "Laser": 1.0, "Mesh WiFi": 1.0, "Projector": 0.6, "Cellular Router": 0.6,
    "Accessory": 0.5, "Screen": 0.4,

    # ------------------------------------------------------------
    # Whole machines, and why these numbers look ridiculous.
    #
    # A number here is not "how popular this category is". It is a
    # per-product multiplier that PRICE_RESISTANCE then divides by the
    # price, and that arithmetic punishes a category twice when
    # everything in it is expensive:
    #
    #   - price. A RM 5,500 prebuilt is 20 times less likely than a
    #     RM 400 drive before demand is even considered.
    #   - shelf width. The category weight is the sum over its products,
    #     and there are 5 prebuilt PCs against 28 drives.
    #
    # Left at the 0.8-1.5 they were first given, the shop sold seven
    # finished machines in five years and not one prebuilt gaming PC --
    # which is not a shop that has eleven of its own builds on the
    # website. These raise them to roughly 210 machines across the
    # window, against 238 custom rig builds: a builder that also moves
    # boxes, which is what eTech is.
    #
    # Prebuilt Gaming PCs needs the largest number because it has the
    # smallest shelf and the dearest stock, and even then it is limited
    # by the catalogue: four of the five are 2025 models, so the early
    # years can only sell the RM 2,999 ZenForge.
    # ------------------------------------------------------------
    "Laptops": 21.0, "Prebuilt Gaming PCs": 55.0, "Office PC Series": 26.0,
    "Branded Desktops": 29.0, "Custom Office CO1": 18.0, "AIO Desktops": 10.0,
}
DEFAULT_DEMAND = 1.0

# How much a high price puts people off, as the exponent in
# weight = demand / price ** PRICE_RESISTANCE.
#
# This started at 0.5 -- a plain square root -- and that was too kind to
# the halo parts. An RM 25,999 RTX 5090 came out only nine times less
# likely than an RM 300 stick of RAM, so the shop sold seven cards over
# RM 6,000 in 2025 and none at all in 2024, and RM 64,000 of lumpy
# revenue landed in one year. It was enough to push 2025 above 2024 and
# break the decline this dataset is supposed to show.
#
# The fix is not a nicer random seed, because the cause is not luck: the
# RTX 5080/5090 tier only exists from 2025, so the late years get an
# injection of expensive stock exactly as volume falls. At 0.85 a card
# that costs eighty times more is about fifty times rarer, which is what
# a shop this size actually sells -- one or two halo cards a year, not
# seven.
PRICE_RESISTANCE = 0.85

# Who is at the counter, which decides how big the basket is: a school
# buying for a lab takes more of everything than somebody replacing one
# fan. This does not reach the output -- there is no customer column in
# the file, by design -- it only shapes the spread of basket sizes, so
# that they are not all one person's shape.
BASKET_PROFILES = [("INDIVIDUAL", 0.78), ("SME", 0.18), ("SCHOOL", 0.04)]

# Share of orders that are a repair job with no hardware on them. Rises
# as the sales floor quietens, so services fall more slowly than boxes.
SERVICE_ONLY_SHARE_START = 0.14
SERVICE_ONLY_SHARE_END = 0.22

# Share of the hardware orders that are a whole machine rather than a
# part or two. One in ten is about a build a week for a shop this size
# at the start of the window, falling with everything else.
#
# It is a small share of the receipts and a large share of the money: a
# build is eight to eleven lines and a few thousand ringgit against a
# counter sale's one line and a few hundred. Turn it up and revenue
# stops tracking footfall; turn it down and the shop stops being a
# builder. See rigs.py for what goes into one.
RIG_BUILD_SHARE = 0.08


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

    # The rack by the door, which the export does not have. It arrives
    # already in this shape and with its own margins and launch years,
    # so it is appended rather than converted.
    products.extend(accessories.as_items())

    # And the stock the shop sold before the stock it sells now, which
    # the export cannot have: a laptop or a monitor model lives about two
    # years, and a 2026 snapshot holds none of 2022's.
    products.extend(dated_stock.as_items(MARGINS, DEFAULT_MARGIN))
    return products


def available(item, year, month):
    if item["type"] == "SERVICE":
        return True
    if (item["launch_year"], item["launch_month"]) > (year, month):
        return False
    # Only the dated stock in dated_stock.py ever stops being sold. A
    # 2021 laptop leaves the shelf around 2023; a case does not, and
    # neither does anything else in the catalogue, because a 2026
    # snapshot cannot say when something was discontinued.
    retired = item.get("last_year")
    return retired is None or year <= retired


def shock_ramp(year, month):
    """0.0 before the memory shock, 1.0 from its peak, linear between."""
    start = SHOCK_START[0] * 12 + SHOCK_START[1]
    peak = SHOCK_PEAK[0] * 12 + SHOCK_PEAK[1]
    now = year * 12 + month
    return min(1.0, max(0.0, (now - start) / float(peak - start)))


def shock_rise(item, year, month):
    """How many times dearer the item is now than before the shock."""
    multiplier = PRICE_SHOCK.get(item["category"])
    if multiplier is None or item["type"] != "PRODUCT" or item.get("dated_price"):
        return 1.0
    return 1.0 + (multiplier - 1.0) * shock_ramp(year, month)


def line_weight(item, year, month):
    """Cheap things sell more often than dear ones, within a category.

    The shock is applied as a rise against the pre-shock price, not by
    swapping in a new price, so every month before SHOCK_START weighs
    exactly as it did before the shock was modelled."""
    return CATEGORY_DEMAND.get(item["category"], DEFAULT_DEMAND) / \
        ((item["price"] * shock_rise(item, year, month)) ** PRICE_RESISTANCE)


def unit_price_in(item, year, month, rng):
    # A dated machine is already priced in its own year's money -- there
    # is no 2026 price to mark up from, because the model stopped being
    # sold years before 2026. Marking it up would charge 2022 prices a
    # 2022 premium twice.
    if item.get("dated_price"):
        factor = 1.0
    else:
        factor = YEAR_PRICE_FACTOR.get(year, 1.0)
        # The catalogue price is post-shock: take it back to what the
        # part cost before, then let the shock carry it up again.
        if item["type"] == "PRODUCT":
            factor *= shock_rise(item, year, month) / PRICE_SHOCK.get(item["category"], 1.0)
    if item["type"] == "PRODUCT" and item["launch_year"] == year:
        factor *= LAUNCH_YEAR_PREMIUM
    jitter = rng.uniform(0.98, 1.02)
    return round(item["price"] * factor * jitter, 2)


def pick_quantity(rng, item, profile):
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

    if profile == "SME":
        top = min(top * 2, 10)
    elif profile == "SCHOOL":
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


def payment_method(rng, year):
    # DuitNow QR keeps taking share off cash and cards through the window.
    # These are all counter payments; a bank transfer is somebody paying
    # from their phone while standing at the till, not a web checkout.
    qr_shift = (year - 2022) * 0.03
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

    # A finished machine is sold, not assembled, so it never draws the
    # RM 80 build labour -- but it is the likeliest thing in the shop to
    # leave with Windows put on it and a year of warranty, which is
    # where a box shifter actually makes its money.
    if categories & MACHINES:
        chance, tag = 0.58, "laptop"
    elif categories & build:
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


# What a hardware purchase drags a lead along for, and how often. A
# monitor without a cable in the box is the classic one -- the customer
# is already at the counter and the rack is behind them -- and a router
# sale means somebody is running a wire across a room.
#
# This is on top of the weighted pick, not instead of it. Cables still
# sell on their own, because a great many of them do: somebody walks in
# for a 5m Cat 6 and buys nothing else.

# The six categories that are a whole computer already built, as opposed
# to the parts for one. Named once because three different rules ask.
MACHINES = {
    "Laptops", "Prebuilt Gaming PCs", "Office PC Series",
    "Custom Office CO1", "Branded Desktops", "AIO Desktops",
}

# A desktop is a box with no screen, no keyboard and no lead, exactly
# like a machine off the bench, so it pulls a cable for the same reason
# a rig build does. A laptop pulls a different sort -- USB-C, a hub, a
# lead to a second screen.
DESKTOPS = MACHINES - {"Laptops"}

CABLE_ATTACH = [
    ({"Monitors", "Projector", "Screen"}, "monitor", 0.42),
    (DESKTOPS, "monitor", 0.50),
    ({"Router", "Mesh WiFi", "Cellular Router"}, "network", 0.45),
    ({"Inkjet", "Laser", "Ink Tank"}, "printer", 0.30),
    ({"Laptops", "Laptop Memory"}, "laptop", 0.28),
]


def cables_by_tag(stock):
    """The month's cables, filed under what they plug into."""
    grouped = {}
    for item in stock:
        if item["category"] != accessories.CABLE_CATEGORY:
            continue
        for tag in item["tags"]:
            grouped.setdefault(tag, []).append(item)
    return grouped


def attach_cable(rng, categories, stock_by_tag):
    """A lead to go with what was just bought, or None."""
    for trigger, tag, chance in CABLE_ATTACH:
        if categories & trigger:
            if rng.random() > chance:
                return None
            pool = stock_by_tag.get(tag)
            return rng.choice(pool) if pool else None
    return None


def itemise_machine(rng, chosen, stock, year, month):
    """If the basket holds an E-Tech machine, make the order *be* that
    machine: its parts, itemised, on one bill.

    Returns (basket, order type, the categories the attachment rules
    should read). None of it happens if the catalogue cannot supply the
    machine's own processor this month, in which case the basket is left
    alone and one honest product line is sold instead.

    The customer's other picks are dropped, and that is the point.
    Somebody carrying out a RM 4,699 computer is not also buying two GT
    730s in the same breath, and while both were on the receipt there
    was no way to tell which storage line belonged to the machine and
    which the customer chose. A prebuilt now reads the way a rig build
    does: one order id, one date, one payment method, and under them the
    parts that actually left the shelf.

    What it does not get is the RM 80 assembly labour. That is the whole
    difference between the two: a rig is built to order, a prebuilt was
    built already.
    """
    machines = [(item, quantity) for item, quantity, override in chosen
                if override is None and prebuilts.is_own_build(item)]
    if not machines:
        return chosen, "RETAIL", {item["category"] for item, _, _ in chosen}

    machine, quantity = machines[0]
    parts = prebuilts.components(rng, machine, stock, year, month)
    if parts is None:
        return chosen, "RETAIL", {item["category"] for item, _, _ in chosen}

    # The machine's price for this year, spread across its parts. Every
    # line takes the same discount, so the bill totals what the machine
    # sells for and no single part carries the whole of it.
    machine_price = unit_price_in(machine, year, month, rng)
    factor = prebuilts.scale_factor(machine_price, parts)

    basket = [(line["item"], line["quantity"] * quantity,
               round(line["item"]["price"] * factor, 2)) for line in parts]
    # The attachment rules see the machine, not the parts, or a prebuilt
    # would look like somebody assembling a computer and be charged the
    # build labour it does not need.
    return basket, "PREBUILT", {machine["category"]}


def build_order(rng, year, month, day, order_id, products, service_items,
                service_only, rig_build):
    profile = weighted_choice(rng, BASKET_PROFILES)
    method = payment_method(rng, year)

    # (item, quantity, price override) throughout. A rig decides its own
    # quantities -- one of everything, a handful of fans -- while a
    # counter sale leaves them to pick_quantity. The override is None
    # for everything except the parts inside an E-Tech machine, which
    # are charged a scaled-down price so the itemised bill still totals
    # what the machine sells for.
    chosen = []
    order_type = "RETAIL"

    if service_only:
        repairs = services.by_tag(service_items, "repair")
        for item in rng.sample(repairs, min(len(repairs), 1 if rng.random() < 0.75 else 2)):
            chosen.append((item, pick_quantity(rng, item, profile), None))
    elif rig_build:
        stock = [item for item in products if available(item, year, month)]
        parts = rigs.assemble(rng, stock, service_items, year, month) if stock else None
        if parts is None:
            # The year cannot supply a processor and a board that fit.
            # Sell parts instead of failing the order.
            return build_order(rng, year, month, day, order_id, products,
                               service_items, False, False)
        order_type = "RIG_BUILD"
        chosen = [(line["item"], line["quantity"], None) for line in parts]
    else:
        stock = [item for item in products if available(item, year, month)]
        if not stock:
            return None
        if profile == "SCHOOL":
            count = rng.randint(2, 6)
        elif profile == "SME":
            count = rng.randint(1, 5)
        else:
            count = weighted_choice(rng, [(1, 0.52), (2, 0.30), (3, 0.13), (4, 0.05)])

        weights = [(item, line_weight(item, year, month)) for item in stock]
        seen = set()
        for _ in range(count):
            item = weighted_choice(rng, weights)
            if item["sku"] in seen:
                continue
            seen.add(item["sku"])
            chosen.append((item, pick_quantity(rng, item, profile), None))

        # An E-Tech machine turns the whole order into that machine,
        # itemised. Done before the attachments so that they read what
        # was bought rather than what it is made of.
        chosen, order_type, bought = itemise_machine(rng, chosen, stock, year, month)
        picked = {item["sku"] for item, _, _ in chosen}

        lead = attach_cable(rng, bought, cables_by_tag(stock))
        if lead is not None and lead["sku"] not in picked:
            # Capped at three. An attached lead is the lead for the thing
            # just bought, so the school-and-SME quantity multipliers do
            # not belong on it: they were putting nine 5m HDMI cables on
            # a single prebuilt PC. Somebody buying leads by the box is
            # buying them through the ordinary weighted pick, where the
            # multipliers still apply.
            chosen.append((lead, min(pick_quantity(rng, lead, profile), 3), None))

        extra = attach_service(rng, bought, service_items)
        if extra is not None:
            chosen.append((extra, pick_quantity(rng, extra, profile), None))

    if not chosen:
        return None

    lines = []
    for item, quantity, override in chosen:
        unit_price = override if override is not None else unit_price_in(item, year, month, rng)
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
        "order_type": order_type,
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
        expected *= 1.0 - SHOCK_FOOTFALL_LOSS * shock_ramp(year, month)
        expected *= rng.lognormvariate(0.0, MONTH_NOISE_SIGMA)
        count = poisson(rng, expected)

        share = SERVICE_ONLY_SHARE_START + \
            (SERVICE_ONLY_SHARE_END - SERVICE_ONLY_SHARE_START) * progress(year, month)

        last_day = days_in_month(year, month)
        if (year, month) == (END.year, END.month):
            last_day = min(last_day, END.day)

        for _ in range(count):
            day = rng.randint(1, last_day)
            order_id = "S-%d-%05d" % (year, len(orders) + 1)
            service_only = rng.random() < share
            rig_build = not service_only and rng.random() < RIG_BUILD_SHARE
            order = build_order(rng, year, month, day, order_id, products,
                                service_items, service_only, rig_build)
            if order is not None:
                orders.append(order)

    orders.sort(key=lambda o: (o["date"], o["order_id"]))
    # Renumber so the ids run in date order, which is what a real system
    # would have done. An invoice number is CINV-NNNN-MMYY: a four-digit
    # counter that starts again at 0001 each month, then the month and
    # the last two digits of the year -- CINV-0001-0122 is the first bill
    # of January 2022. The busiest month has under 600 bills, so four
    # digits never run out.
    per_month = {}
    for order in orders:
        when = order["date"]
        key = (when.year, when.month)
        per_month[key] = per_month.get(key, 0) + 1
        order["order_id"] = "CINV-%04d-%02d%02d" % (per_month[key], when.month,
                                                   when.year % 100)
    return products, service_items, orders


# ------------------------------------------------------------
# Writing it out.
#
# What a sale costs the shop is not in the file. The catalogue carries a
# margin per item and the generator uses it -- main() prints the gross
# profit it implies, as a check that the numbers are sane -- but no cost
# or profit column is written. Publishing lineProfit would publish the
# cost too, since lineTotal minus lineProfit is the cost, and these
# margins are guesses rather than eTech's real buying prices.
#
# Each <sale> is one line of one receipt, with the receipt's details
# repeated onto it. That repetition is deliberate: a flat record loads
# into pandas with a single read_xml() and into Excel as one table,
# which is the whole point of the file.
#
# ---- saleId is the bill, not the line ----
#
# It used to be the line: a running S000001, S000002 counter, with a
# separate orderId holding the receipt. Opened in Excel that reads
# badly, and for the thing this dataset most wants to show. An eleven
# part rig build came out as eleven consecutive rows whose *first*
# column -- the one called saleId -- changed on every one of them, so a
# single RM 6,400 build looked like eleven separate sales unless you
# happened to notice the second column staying still.
#
# So the sale id is the sale. Every line of one build, one prebuilt or
# one counter basket carries the same CINV-NNNN-MMYY, and lineNo counts
# 1..n within it. The pair is still unique per row, so nothing is lost
# as a key, and the old orderId column is gone rather than left sitting
# there holding the identical value under a second name.
# ------------------------------------------------------------
def field(name, value):
    return "      <%s>%s</%s>\n" % (name, escape(str(value)), name)


def write_xml(products, service_items, orders, path):
    per_year = {}
    per_month = {}
    sale_number = 0
    body = []
    flat = []

    for order in orders:
        for line_no, line in enumerate(order["lines"], start=1):
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
            chunk.append(field("saleId", order["order_id"]))
            chunk.append(field("lineNo", line_no))
            chunk.append(field("date", when.isoformat()))
            chunk.append(field("year", when.year))
            chunk.append(field("month", when.month))
            chunk.append(field("orderType", order["order_type"]))
            chunk.append(field("paymentMethod", order["payment_method"]))
            chunk.append(field("sku", line["sku"]))
            chunk.append(field("itemType", line["item_type"]))
            chunk.append(field("itemName", line["name"]))
            chunk.append(field("category", line["category"]))
            chunk.append(field("brand", line["brand"]))
            chunk.append(field("quantity", line["quantity"]))
            chunk.append(field("unitPrice", "%.2f" % line["unit_price"]))
            chunk.append(field("lineTotal", "%.2f" % line["line_total"]))
            chunk.append("    </sale>\n")
            body.append("".join(chunk))

            flat.append([
                order["order_id"], line_no, when.isoformat(),
                when.year, when.month, order["order_type"],
                order["payment_method"], line["sku"], line["item_type"],
                line["name"], line["category"], line["brand"], line["quantity"],
                "%.2f" % line["unit_price"], "%.2f" % line["line_total"],
            ])

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
        out.write(field("warning", WARNING))
        out.write(field("catalogueSource",
                        "eTech live Supabase products table, 389 active products, "
                        "exported 2026-09-09. Product names and 2026 prices are real."))
        out.write(field("servicesSource",
                        "Invented. The database holds no services; the 16 in "
                        "tools/sales_history/services.py were written for this dataset."))
        out.write(field("accessoriesSource",
                        "Invented. The catalogue export has no USB, network or "
                        "display cables and only three input devices; the 26 "
                        "cables and 20 peripherals in "
                        "tools/sales_history/accessories.py were written for "
                        "this dataset. Categories Cables and Peripherals."))
        out.write(field("prebuiltsItemised",
                        "E-Tech's own machines (Prebuilt Gaming PCs, Office PC "
                        "Series, Custom Office CO1) are sold itemised: one bill "
                        "with a line per part, orderType PREBUILT, no assembly "
                        "labour. Their stock is derived from components on the "
                        "live site, so a sale moves parts, not a product. "
                        "Branded desktops, all-in-ones and laptops stay one "
                        "line each -- they arrive in a sealed box."))
        out.write(field("datedStockSource",
                        "Invented. A laptop or monitor model lives about two "
                        "years, so the 2026 catalogue holds nothing the shop "
                        "stocked in 2022; the 34 dated items in "
                        "tools/sales_history/dated_stock.py cover 2019-2023 and "
                        "retire when they stopped being sold. They use the real "
                        "category names and carry sku M-*, against P-* for "
                        "catalogue products."))
        out.write(field("trend",
                        "Declining. Orders fall about 20% per year, smoothly, "
                        "from about 100 receipts a week in 2022 to about 50 a "
                        "week by September 2025; a component price shock (RAM, "
                        "storage, GPU, CPU, motherboard, whole machines) then "
                        "ramps from October 2025 to June 2026, raising prices "
                        "and cutting 2026 to about 30 receipts a week. Part-year "
                        "ending August 2026."))
        out.write(field("seed", SEED))
        out.write("  </meta>\n")

        out.write("  <sales>\n")
        for chunk in body:
            out.write(chunk)
        out.write("  </sales>\n")

        # <monthlyTotal> and <yearlyTotal> rather than <month> and <year>,
        # which is not fussiness: every <sale> already carries a <month>
        # and a <year> child, so pd.read_xml(xpath=".//month") matched
        # every sale as well as the 56 summary rows and returned a frame
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
            out.write("    </yearlyTotal>\n")
        out.write("  </yearlySummary>\n")
        out.write("</salesDataset>\n")

    write_csv(flat, per_month)
    wrote_workbook = write_xlsx(flat, per_month, per_year)

    return per_year, sale_number, wrote_workbook


# The CSVs hold exactly the rows the XML holds, written from the same
# pass so the two files cannot drift apart.
#
# utf-8-sig, not utf-8. The catalogue has names in it that are not plain
# ASCII, and Excel on Windows reads a BOM-less CSV in the system
# codepage, which turns those into mojibake on open with no way to say
# otherwise short of the import wizard. The BOM is three bytes that make
# it open correctly on a double click; pandas.read_csv() handles it
# without being told.
SALE_HEADER = [
    "saleId", "lineNo", "date", "year", "month", "orderType",
    "paymentMethod", "sku", "itemType", "itemName", "category", "brand",
    "quantity", "unitPrice", "lineTotal",
]

MONTH_HEADER = [
    "period", "year", "month", "orders", "lines", "units", "revenue",
    "productRevenue", "serviceRevenue",
]

YEAR_HEADER = [
    "year", "months", "orders", "lines", "units", "revenue",
    "productRevenue", "serviceRevenue",
]


def write_csv(flat, per_month):
    with open(OUTPUT_CSV, "w", encoding="utf-8-sig", newline="") as out:
        writer = csv.writer(out)
        writer.writerow(SALE_HEADER)
        writer.writerows(flat)

    with open(OUTPUT_MONTHLY_CSV, "w", encoding="utf-8-sig", newline="") as out:
        writer = csv.writer(out)
        writer.writerow(MONTH_HEADER)
        for (year, month) in sorted(per_month):
            row = per_month[(year, month)]
            writer.writerow([
                "%04d-%02d" % (year, month), year, month,
                len(row["orders"]), row["lines"], row["units"],
                "%.2f" % row["revenue"],
                "%.2f" % row["product_revenue"],
                "%.2f" % row["service_revenue"],
            ])


# ------------------------------------------------------------
# The workbook.
#
# Four sheets: the warning, the 10,236 sale lines, the 56 monthly totals
# and the 5 yearly ones. Same rows as the CSVs, converted back to real
# types on the way in -- dates as dates and money as numbers rather than
# the two-decimal strings the CSV and the XML carry -- because a column
# of text that looks like money will not sum, chart or pivot, and that is
# the whole reason for opening it in Excel.
#
# openpyxl is not in any requirements file here, so this is optional: no
# openpyxl means no workbook and a line saying so, not a crash. The XML
# is the deliverable and the CSVs are the fallback.
# ------------------------------------------------------------
def write_xlsx(flat, per_month, per_year):
    try:
        from openpyxl import Workbook
        from openpyxl.styles import Alignment, Font, PatternFill
        from openpyxl.utils import get_column_letter
    except ImportError:
        return False

    book = Workbook()

    # A workbook stamps itself with the time it was saved, which would
    # make this the one output of the four that changes on every run --
    # a different file on disk, a dirty `git status`, and a diff saying
    # nothing happened. Pinned to the catalogue export date so the whole
    # set really is byte-identical from one run to the next.
    stamp = datetime(2026, 9, 9)
    book.properties.created = stamp
    book.properties.modified = stamp
    book.properties.creator = "tools/sales_history/generate_sales_xml.py"
    book.properties.title = "eTech synthetic sales history 2022-2026"

    heading = Font(bold=True, color="FFFFFF")
    banner = PatternFill("solid", fgColor="B03030")
    shaded = PatternFill("solid", fgColor="404040")

    # --- the front sheet, which is the warning ---
    about = book.active
    about.title = "Read me first"
    about.column_dimensions["A"].width = 96
    notes = [
        (WARNING, True),
        ("", False),
        ("eTech Computer Accessories, January 2022 - August 2026. Currency MYR.", False),
        ("Every figure in this workbook was generated. eTech's real orders "
         "table holds 37 rows, all from 2026, most of them placed while "
         "testing the checkout.", False),
        ("", False),
        ("Real: the 389 product names, brands, categories and 2026 prices, "
         "exported from eTech's live Supabase catalogue on 9 September 2026.", False),
        ("Invented: the 16 rows under category Services, the 26 under Cables, "
         "the 20 under Peripherals, and 34 dated machines and monitors "
         "carrying sku M-*, which cover the years the 2026 catalogue cannot. "
         "The catalogue holds no services and no USB, network or display "
         "cables; a laptop or panel model lives about two years. "
         "See tools/sales_history/.", False),
        ("", False),
        ("Sales    - one row per line of one receipt, %d rows." % len(flat), False),
        ("Monthly  - %d months, the series to forecast against." % len(per_month), False),
        ("Yearly   - %d years, 2026 being January to August only." % len(per_year), False),
        ("", False),
        ("Regenerate with: python tools/sales_history/generate_sales_xml.py", False),
        ("Seeded, so it writes the same files every time. Full notes in "
         "docs/data/README.md.", False),
    ]
    for index, (text, is_banner) in enumerate(notes, start=1):
        cell = about.cell(row=index, column=1, value=text)
        cell.alignment = Alignment(wrap_text=True, vertical="top")
        if is_banner:
            cell.font = heading
            cell.fill = banner

    # --- the three data sheets ---
    money = '#,##0.00'
    sheets = [
        ("Sales", SALE_HEADER, [
            [row[0], row[1], date.fromisoformat(row[2]), row[3], row[4],
             row[5], row[6], row[7], row[8], row[9], row[10], row[11],
             row[12], float(row[13]), float(row[14])]
            for row in flat
        ], {"C": "yyyy-mm-dd", "N": money, "O": money}),
        ("Monthly", MONTH_HEADER, [
            ["%04d-%02d" % key, key[0], key[1], len(per_month[key]["orders"]),
             per_month[key]["lines"], per_month[key]["units"],
             round(per_month[key]["revenue"], 2),
             round(per_month[key]["product_revenue"], 2),
             round(per_month[key]["service_revenue"], 2)]
            for key in sorted(per_month)
        ], {"G": money, "H": money, "I": money}),
        ("Yearly", YEAR_HEADER, [
            [year, 8 if year == 2026 else 12, len(per_year[year]["orders"]),
             per_year[year]["lines"], per_year[year]["units"],
             round(per_year[year]["revenue"], 2),
             round(per_year[year]["product_revenue"], 2),
             round(per_year[year]["service_revenue"], 2)]
            for year in sorted(per_year)
        ], {"F": money, "G": money, "H": money}),
    ]

    for title, header, rows, formats in sheets:
        sheet = book.create_sheet(title)
        sheet.append(header)
        for cell in sheet[1]:
            cell.font = heading
            cell.fill = shaded
        for row in rows:
            sheet.append(row)

        # Freeze the header and turn on the filter dropdowns, so 10,236
        # rows can be read without scrolling back up to see which column
        # is which.
        sheet.freeze_panes = "A2"
        sheet.auto_filter.ref = sheet.dimensions

        for column, pattern in formats.items():
            for (cell,) in sheet[column + "2":column + str(sheet.max_row)]:
                cell.number_format = pattern

        # Widths off the header and a sample of the rows. Excel's own
        # autofit is not reachable from a written file, so the columns
        # arrive at a default 8.43 and every product name is cut off.
        for index, name in enumerate(header, start=1):
            longest = max([len(name)] +
                          [len(str(row[index - 1])) for row in rows[:400]])
            sheet.column_dimensions[get_column_letter(index)].width = \
                min(max(longest + 2, 9), 52)

    book.save(OUTPUT_XLSX)
    _pin_zip_times(OUTPUT_XLSX, stamp)
    return True


def _pin_zip_times(path, stamp):
    """Make the workbook come out the same on every run.

    Two clocks have to be stopped, not one:

      - An .xlsx is a zip, and a zip stamps every member inside it with
        the time it was added. So it is repacked with one fixed
        timestamp on each, in the order openpyxl wrote them.

      - openpyxl sets dcterms:modified to the current time as it saves,
        which overwrites the pinned value set on the properties before
        the save. There is no setting for it, so it is rewritten here.

    Without both, the workbook is the one output of the four that
    changes on every run: a different file on disk and a `git status`
    saying something happened when nothing did."""
    fixed = stamp.timetuple()[:6]
    when = stamp.strftime("%Y-%m-%dT%H:%M:%SZ").encode("utf-8")
    modified = re.compile(rb"(<dcterms:modified[^>]*>)[^<]*(</dcterms:modified>)")

    temporary = path + ".tmp"
    with zipfile.ZipFile(path) as source:
        members = [(info, source.read(info.filename)) for info in source.infolist()]
    with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED) as target:
        for info, payload in members:
            if info.filename == "docProps/core.xml":
                payload = modified.sub(rb"\g<1>" + when + rb"\g<2>", payload)
            entry = zipfile.ZipInfo(info.filename, date_time=fixed)
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.external_attr = info.external_attr
            target.writestr(entry, payload)
    os.replace(temporary, path)


def main():
    products, service_items, orders = generate()
    per_year, lines, workbook = write_xml(products, service_items, orders, OUTPUT)

    print("wrote %s" % OUTPUT)
    print("wrote %s" % OUTPUT_CSV)
    print("wrote %s" % OUTPUT_MONTHLY_CSV)
    if workbook:
        print("wrote %s" % OUTPUT_XLSX)
    else:
        print("no workbook: openpyxl is not installed (pip install openpyxl)")
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
