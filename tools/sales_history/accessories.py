# ============================================================
# The rack by the door.
#
# eTech's catalogue is a builder's catalogue. It has 34 graphics cards
# and one mouse pad; it has five "Cable Kits", and all five of them are
# sleeved power extensions for the inside of a case. There is no HDMI
# lead in it, no Cat 6, no USB-C, and exactly three input devices.
#
# That is a gap in the export rather than a description of the shop. The
# rack of cables by the door and the shelf of keyboards behind the
# counter are the two things a walk-in customer is most likely to leave
# with, and a sales history that omits them says a computer shop sold
# nothing under RM 40 for five years. The receipts come out wrong in a
# way anyone would notice: no small change, no impulse line, and an
# average basket dragged upward by parts.
#
# So these are invented, on the same footing as services.py -- they are
# not in the database and this file is the only place they exist. Two
# categories:
#
#   Cables       USB, network, display, audio. Cheap, high margin, and
#                the thing most often added to somebody else's purchase.
#                Named "Cables" rather than reusing the catalogue's
#                "Cable Kits", which means something else: a Cable Kit
#                is an RM 89 sleeved PSU set for a build, a Cable is an
#                RM 19 lead somebody walks in for.
#
#   Peripherals  Keyboards, mice, headsets, from an RM 39 office board
#                to an RM 429 mechanical one. Gaming-branded models sit
#                here too rather than in the catalogue's real "Gaming
#                Gear" category, so that the four genuine Gaming Gear
#                rows stay countable as what the database actually
#                holds.
#
# The products are real ones a Malaysian shop stocks, at what they sell
# for locally. They are not eTech's stock and the prices were not taken
# from any of eTech's records.
#
# Margins are shop margins, not component margins: 40% on a cable and
# 24% on a keyboard, against 7% on a graphics card. A rack of cables
# earns more than it looks like it does.
#
# Launch years are mostly 2015, meaning "the shop has always had it" --
# a 1.5m USB-C lead was on the rack in January 2022 and still is. The
# handful of models that genuinely arrived inside or near the window
# carry their real year, so a 2022 receipt cannot list a mouse that was
# announced in 2023.
# ============================================================

# sku, name, brand, price (MYR), launch year, tags
CABLES = [
    ("ACC-C01", "USB Type-C to Type-A Cable 1.5m",             "Ugreen",   19.00, 2015, ("laptop", "phone")),
    ("ACC-C02", "USB Type-C to Type-C Cable 1m (60W)",         "Ugreen",   25.00, 2015, ("laptop", "phone")),
    ("ACC-C03", "USB Type-C to Type-C Cable 2m (100W PD)",     "Baseus",   39.00, 2015, ("laptop", "phone")),
    ("ACC-C04", "USB Type-A Male to Male Cable 3m",            "Vention",  22.00, 2015, ("build",)),
    ("ACC-C05", "USB 2.0 Extension Cable Male to Female 3m",   "Vention",  18.00, 2015, ("build", "printer")),
    ("ACC-C06", "USB 3.0 Extension Cable Male to Female 1.5m", "Orico",    24.00, 2015, ("build",)),
    ("ACC-C07", "USB-A to Micro-B Cable 1m",                   "Generic",  12.00, 2015, ("phone",)),
    ("ACC-C08", "USB 3.0 A-to-B Printer Cable 1.5m",           "Vention",  19.00, 2015, ("printer",)),
    ("ACC-C09", "Cat 6 Network Cable 2m",                      "Ugreen",   15.00, 2015, ("network",)),
    ("ACC-C10", "Cat 6 Network Cable 5m",                      "Ugreen",   25.00, 2015, ("network",)),
    ("ACC-C11", "Cat 6 Network Cable 10m",                     "Ugreen",   42.00, 2015, ("network",)),
    ("ACC-C12", "Cat 6 Network Cable 20m",                     "Vention",  75.00, 2015, ("network",)),
    ("ACC-C13", "Cat 5e Patch Cable 1m",                       "Generic",   9.00, 2015, ("network",)),
    ("ACC-C14", "Cat 6 Flat Network Cable 15m",                "Orico",    58.00, 2015, ("network",)),
    ("ACC-C15", "HDMI 2.0 Cable 1.5m (4K 60Hz)",               "Ugreen",   25.00, 2015, ("monitor",)),
    ("ACC-C16", "HDMI 2.0 Cable 5m (4K 60Hz)",                 "Vention",  55.00, 2015, ("monitor", "projector")),
    ("ACC-C17", "HDMI 2.1 Cable 3m (8K 60Hz)",                 "Ugreen",   69.00, 2017, ("monitor",)),
    ("ACC-C18", "DisplayPort 1.4 Cable 1.5m",                  "Ugreen",   45.00, 2015, ("monitor",)),
    ("ACC-C19", "DisplayPort 1.4 Cable 3m",                    "Vention",  62.00, 2015, ("monitor",)),
    ("ACC-C20", "DisplayPort to HDMI Cable 1.8m",              "Vention",  39.00, 2015, ("monitor",)),
    ("ACC-C21", "USB-C to HDMI Cable 1.8m (4K)",               "Baseus",   59.00, 2015, ("laptop", "monitor")),
    ("ACC-C22", "VGA Cable 1.5m",                              "Generic",  18.00, 2015, ("monitor", "projector")),
    ("ACC-C23", "3.5mm Audio AUX Cable 1.5m",                  "Generic",  12.00, 2015, ("audio",)),
    ("ACC-C24", "SATA 3 Data Cable 50cm (2 pack)",             "Generic",   8.00, 2015, ("build",)),
    ("ACC-C25", "Power Cord IEC C13 1.8m",                     "Generic",  15.00, 2015, ("build",)),
    ("ACC-C26", "USB-C Hub 5-in-1 (HDMI / USB / SD)",          "Orico",   129.00, 2016, ("laptop",)),
]

# sku, name, brand, price (MYR), launch year, tags
PERIPHERALS = [
    ("ACC-P01", "A4Tech KR-85 Wired Keyboard",                     "A4Tech",       39.00, 2015, ("keyboard", "office")),
    ("ACC-P02", "Logitech K120 Wired Keyboard",                    "Logitech",     45.00, 2015, ("keyboard", "office")),
    ("ACC-P03", "Logitech MK220 Wireless Keyboard & Mouse Combo",  "Logitech",     99.00, 2015, ("keyboard", "mouse", "office")),
    ("ACC-P04", "Logitech MK295 Silent Wireless Combo",            "Logitech",    139.00, 2020, ("keyboard", "mouse", "office")),
    ("ACC-P05", "Fantech MaxFit61 Mechanical Keyboard",            "Fantech",     159.00, 2020, ("keyboard", "gaming")),
    ("ACC-P06", "Royal Kludge RK61 Wireless Mechanical Keyboard",  "Royal Kludge", 189.00, 2018, ("keyboard", "gaming")),
    ("ACC-P07", "Keychron K8 Wireless Mechanical Keyboard",        "Keychron",    429.00, 2019, ("keyboard", "gaming")),
    ("ACC-P08", "Logitech B100 Wired Mouse",                       "Logitech",     29.00, 2015, ("mouse", "office")),
    ("ACC-P09", "Logitech M170 Wireless Mouse",                    "Logitech",     49.00, 2015, ("mouse", "office")),
    ("ACC-P10", "Fantech X17 Blake Gaming Mouse",                  "Fantech",      59.00, 2019, ("mouse", "gaming")),
    ("ACC-P11", "Logitech G102 Lightsync Gaming Mouse",            "Logitech",    109.00, 2019, ("mouse", "gaming")),
    ("ACC-P12", "Razer DeathAdder Essential Gaming Mouse",         "Razer",       129.00, 2015, ("mouse", "gaming")),
    ("ACC-P13", "Logitech MX Master 3S Wireless Mouse",            "Logitech",    439.00, 2022, ("mouse", "office")),
    ("ACC-P14", "Generic USB Call Centre Headset",                 "Generic",      45.00, 2015, ("headset", "office")),
    ("ACC-P15", "Logitech H111 Stereo Headset",                    "Logitech",     59.00, 2015, ("headset", "office")),
    ("ACC-P16", "Fantech HG11 Captain 7.1 Gaming Headset",         "Fantech",      89.00, 2016, ("headset", "gaming")),
    ("ACC-P17", "HyperX Cloud Stinger 2 Gaming Headset",           "HyperX",      199.00, 2022, ("headset", "gaming")),
    ("ACC-P18", "Razer Kraken V3 X Gaming Headset",                "Razer",       269.00, 2021, ("headset", "gaming")),
    ("ACC-P19", "SteelSeries Arctis Nova 1 Gaming Headset",        "SteelSeries", 359.00, 2022, ("headset", "gaming")),
    ("ACC-P20", "Fantech MP64 Extended Mouse Pad",                 "Fantech",      35.00, 2015, ("mouse", "gaming")),
]

# Three of these arrived while the window was running, and a year is too
# coarse for those: a headset announced in June cannot be on a January
# receipt. Everything else launched before 2022 and is in stock from the
# first day of the dataset, so only the three need a month.
#
# rigs.py makes the same distinction for the same reason -- see its note
# about AM5 machines turning up five months before the socket existed.
LAUNCH_MONTHS = {
    "ACC-P13": 6,      # Logitech MX Master 3S, June 2022
    "ACC-P17": 6,      # HyperX Cloud Stinger 2, June 2022
    "ACC-P19": 9,      # SteelSeries Arctis Nova 1, September 2022
}

CABLE_CATEGORY = "Cables"
PERIPHERAL_CATEGORY = "Peripherals"

# What a cable costs the shop, and what a keyboard does. Kept here
# rather than in the generator's MARGINS table because these two
# categories do not exist in the database, so nothing else can ask.
CABLE_MARGIN = 0.40
PERIPHERAL_MARGIN = 0.24


def as_items():
    """The same shape load_products() puts the catalogue into, so the
    generator can treat a Cat 6 lead and a graphics card as one list."""
    items = []
    for rows, category, margin in ((CABLES, CABLE_CATEGORY, CABLE_MARGIN),
                                   (PERIPHERALS, PERIPHERAL_CATEGORY, PERIPHERAL_MARGIN)):
        for sku, name, brand, price, year, tags in rows:
            items.append({
                "sku": sku,
                "type": "PRODUCT",
                "name": name,
                "category": category,
                "brand": brand,
                "price": price,
                "margin": margin,
                "launch_year": year,
                # A named month or January, never a month drawn at
                # random. The generator scatters a catalogue part's
                # arrival across its launch year because the year is all
                # launch_years.py can tell it; here the release date is
                # either known or irrelevant, so guessing would only add
                # noise.
                "launch_month": LAUNCH_MONTHS.get(sku, 1),
                "may_repeat": True,
                "tags": set(tags),
            })
    return items


def by_tag(items, tag):
    return [item for item in items if tag in item["tags"]]
