# ============================================================
# The stock the shop sold before the stock it sells now.
#
# The catalogue export is a 2026 snapshot, and for most of the shop that
# is close enough: a case or a power supply stays on the shelf for years,
# so dating one by its name puts it in roughly the right span. Whole
# computers do not work like that. A laptop model lives about eighteen
# months and is then replaced, so a snapshot of what eTech stocks today
# contains nothing it stocked in 2022.
#
# Read literally, the export says the shop sold its first laptop in 2023
# and its first branded desktop in 2023 as well. Run that through the
# generator and whole machines climb from 8% of revenue in 2022 to 24% in
# 2026 -- the shop's biggest-ticket line growing as a share of a business
# that is supposed to be shrinking, purely because the catalogue is dated
# from the wrong end. It is the one place where "the catalogue is a 2026
# snapshot" stops being a harmless simplification.
#
# Two ways to fix that, and the obvious one is wrong. Letting the 2023
# models sell in 2022 would flatten the curve, but it would also put a
# Lenovo IdeaCentre 08IRH9 on a 2022 receipt, and launch_years.py exists
# precisely so that nobody can find a part on sale before it was made.
# Buying back the trend with a checkable factual error is a bad trade.
#
# Monitors turned out to have exactly the same problem and to be hiding
# it better. All 21 in the catalogue are 2023 models or newer, but only
# six of them said so in a way the rules could read, so the other
# fifteen were treated as always-stocked and sold from January 2022 --
# an RM 649 27" 180Hz panel three years before it was announced. Dating
# them properly left 2022 with no monitors at all, so they get the same
# treatment as the machines, and for the same reason: a panel line turns
# over every two years.
#
# So the early years get their own stock instead: models that really were
# on sale in Malaysia then, at what they really cost, retired when they
# stopped being sold. Same idea as services.py and accessories.py -- the
# database does not have them, this file is the only place they exist,
# and they are marked.
#
# Three things follow from a machine being dated rather than current:
#
#   - It carries a `last_year`. A 2021 Aspire is not sold new in 2025,
#     so it leaves the shelf the way it did in life. Nothing else in the
#     dataset retires; these are the only items that stop.
#
#   - Its price does not drift. YEAR_PRICE_FACTOR marks the early years
#     up because a catalogue price is a 2026 price, and marking these up
#     would be wrong twice over: the price here is already the price it
#     sold at in its own year, and there is no 2026 price to discount
#     from because the model is long gone. They set `dated_price`.
#
#   - The SKU says M-. Catalogue products are P-<id>, so any analysis
#     that wants only genuine catalogue stock can still drop these, even
#     though they share the real category names -- which they do on
#     purpose, so that "how many laptops did the shop sell" has one
#     answer rather than two.
# ============================================================

# sku, name, brand, price (MYR), category, first year, last year
STOCK = [
    # --- laptops, 2021-2023 -----------------------------------
    ("M-L01", "Acer Aspire 3 A315-58 i3-1115G4 8GB",          "Acer",   2199.00, "Laptops", 2021, 2023),
    ("M-L02", "Asus Vivobook 14 X415EA i3-1115G4 8GB",        "Asus",   2299.00, "Laptops", 2021, 2023),
    ("M-L03", "Lenovo IdeaPad 3 15ITL6 i5-1135G7 8GB",        "Lenovo", 2899.00, "Laptops", 2021, 2023),
    ("M-L04", "HP 14s-dq2606TU i5-1135G7 8GB",                "HP",     2999.00, "Laptops", 2021, 2023),
    ("M-L05", "Dell Inspiron 15 3511 i5-1135G7 8GB",          "Dell",   2699.00, "Laptops", 2021, 2023),
    ("M-L06", "Acer Swift 3 SF314-511 i5-1135G7 16GB",        "Acer",   3299.00, "Laptops", 2021, 2023),
    ("M-L07", "Asus Zenbook 14 UX425EA i5-1135G7 16GB",       "Asus",   3799.00, "Laptops", 2021, 2023),
    ("M-L08", "MSI Modern 14 B11MOU i5-1155G7 8GB",           "MSI",    3199.00, "Laptops", 2021, 2023),
    ("M-L09", "Acer Nitro 5 AN515-57 i5-11400H RTX 3050",     "Acer",   3999.00, "Laptops", 2021, 2023),
    ("M-L10", "Asus TUF Gaming F15 FX506HF i5-11400H RTX 2050", "Asus", 3499.00, "Laptops", 2022, 2024),
    ("M-L11", "HP Victus 16-d1178TX i5-12500H RTX 3050",      "HP",     4199.00, "Laptops", 2022, 2024),
    ("M-L12", "Lenovo LOQ 15IRH8 i5-12450H RTX 4050",         "Lenovo", 3899.00, "Laptops", 2023, 2025),

    # --- branded desktops and all-in-ones, 2020-2022 ----------
    ("M-D01", "Lenovo IdeaCentre 3 07ADA05 Ryzen 3 3250U",    "Lenovo", 1799.00, "Branded Desktops", 2020, 2023),
    ("M-D02", "HP Pavilion Desktop TP01-2020d Ryzen 5 5600G", "HP",     2799.00, "Branded Desktops", 2021, 2023),
    ("M-D03", "Asus ExpertCenter D500SC i5-11400",            "Asus",   2599.00, "Branded Desktops", 2021, 2023),
    ("M-D04", "Dell Vostro 3681 SFF i5-10400",                "Dell",   2499.00, "Branded Desktops", 2020, 2022),
    ("M-A01", "HP All-in-One 22-df0025d i3-1005G1",           "HP",     2499.00, "AIO Desktops", 2020, 2022),
    ("M-A02", "Lenovo IdeaCentre AIO 3 22ADA6 Ryzen 3 3250U", "Lenovo", 2299.00, "AIO Desktops", 2021, 2023),

    # --- the shop's own machines, 2021-2022 -------------------
    # eTech has eleven builds of its own on the website today. It had
    # different ones then, on the cards of the day.
    # Every part named here has to exist in the catalogue, because these
    # machines are itemised on the receipt rather than sold as a name --
    # see prebuilts.py. That is a real constraint: the catalogue's only
    # pre-2025 cards are the GT series, the GTX 1650 and the RTX 3050,
    # so eTech's 2022 flagship is a 3050 machine. It is the same limit
    # that makes a 2022 "high-end" custom build ship a 3050.
    ("M-P01", "E-Tech ZenForge Ryzen 5 5500 GTX 1650",        "E-Tech", 2699.00, "Prebuilt Gaming PCs", 2021, 2023),
    ("M-P02", "E-Tech Titan i7-12700 RTX 3050",               "E-Tech", 4199.00, "Prebuilt Gaming PCs", 2022, 2024),
    ("M-O01", "E-Tech Office PC Ryzen 5 5500",                "E-Tech", 1899.00, "Office PC Series", 2021, 2023),

    # --- monitors, 2019-2023 ----------------------------------
    # The panels a Malaysian shop actually sold in those years: 75Hz
    # office IPS at the bottom, a 144-165Hz gaming panel in the middle,
    # a colour-accurate 24" at the top. Prices are what they cost then,
    # which is why a 27" 144Hz here is RM 999 and the catalogue's 2024
    # equivalent is RM 649 -- panels got cheaper, and the dataset should
    # show that rather than hide it.
    ("M-M01", "AOC 24B2XH 23.8\" FHD 75Hz (Black)",             "AOC",       429.00, "Monitors", 2020, 2023),
    ("M-M02", "LG 24MK600M 23.8\" FHD 75Hz (Black)",            "LG",        479.00, "Monitors", 2019, 2022),
    ("M-M03", "Asus VA24EHE 23.8\" FHD 75Hz (Black)",           "Asus",      499.00, "Monitors", 2020, 2023),
    ("M-M04", "ViewSonic VA2432-H 23.8\" FHD 75Hz (Black)",     "ViewSonic", 449.00, "Monitors", 2021, 2023),
    ("M-M05", "BenQ GW2480 23.8\" FHD 60Hz (Black)",            "BenQ",      559.00, "Monitors", 2019, 2022),
    ("M-M06", "Dell SE2422H 23.8\" FHD 75Hz (Black)",           "Dell",      549.00, "Monitors", 2021, 2023),
    ("M-M07", "Samsung LC27F390 27\" FHD 60Hz Curved (Black)",  "Samsung",   699.00, "Monitors", 2019, 2022),
    ("M-M08", "Asus TUF VG249Q1A 23.8\" FHD 165Hz (Black)",     "Asus",      799.00, "Monitors", 2020, 2023),
    ("M-M09", "MSI Optix G241 23.8\" FHD 144Hz (Black)",        "MSI",       899.00, "Monitors", 2020, 2023),
    ("M-M10", "Acer Nitro VG271 27\" FHD 144Hz (Black)",        "Acer",      999.00, "Monitors", 2020, 2023),
    ("M-M11", "LG 27GL650F 27\" FHD 144Hz (Black)",             "LG",       1299.00, "Monitors", 2019, 2022),
    ("M-M12", "Asus ProArt PA248QV 24\" WUXGA 75Hz (Black)",    "Asus",     1199.00, "Monitors", 2020, 2023),
]

# Thin, like everything else with a whole computer in the box. The
# generator's MARGINS table already says 12% for these categories and
# these are the same goods, so it is read from there rather than
# repeated here.


def as_items(margins, default_margin):
    """The same shape load_products() puts the catalogue into."""
    items = []
    for sku, name, brand, price, category, first, last in STOCK:
        items.append({
            "sku": sku,
            "type": "PRODUCT",
            "name": name,
            "category": category,
            "brand": brand,
            "price": price,
            "margin": margins.get(category, default_margin),
            "launch_year": first,
            # January. A model's exact arrival month is not worth
            # guessing at when the point of the entry is to cover a year
            # the catalogue leaves empty.
            "launch_month": 1,
            "last_year": last,
            "dated_price": True,
            "may_repeat": False,
            "tags": set(),
        })
    return items
