# ============================================================
# What a whole computer looks like on a receipt.
#
# eTech builds machines. Most of the shop is still someone walking out
# with one stick of RAM, but a builder's busiest day is the one where a
# customer buys eight parts at once and pays to have them put together,
# and a sales history with no such receipt in it is describing a parts
# counter rather than a build shop.
#
# So some orders are a whole rig: CPU, motherboard, memory, storage,
# power supply, case, cooler, usually a graphics card, sometimes a pack
# of fans, plus the labour to assemble it. One order, eight to eleven
# lines, every part sold at the same price it is sold at on its own --
# the shop does not discount a bundle, it charges for the build.
#
# Two things stop those receipts being nonsense:
#
#   1. The parts fit each other. A Ryzen 7 5800X3D goes on a B550, not
#      on a B850, and it takes DDR4 with it. The rules are read off the
#      part names, the same trick launch_years.py uses -- a chipset
#      number tells you the socket, and the socket tells you the memory.
#      An unrecognised part is left out of builds rather than guessed
#      at, so it only ever sells on its own.
#
#      This is name-reading, not a compatibility database. It gets the
#      socket and the memory generation right, which is what anyone
#      looking at the file will check. It says nothing about whether the
#      cooler clears the RAM or the card fits the case.
#
#   2. The parts are of a piece. Three tiers -- an office box, a gaming
#      machine, a high-end build -- each a price band per category, so
#      an RM 429 A620 board does not turn up under an RM 3,699 Ryzen 9.
#      The bands are in 2026 catalogue prices; the generator applies the
#      year factor afterwards.
#
# A year that has no part in a band gets the nearest thing it does have.
# In 2022 that means a "high-end" build ships an RTX 3050, because the
# 5000-series does not exist yet and the catalogue holds nothing else.
# That is the catalogue being a 2026 snapshot, not a claim about 2022.
# ============================================================

import re

import accessories

# ------------------------------------------------------------
# Sockets, read off the name.
#
# Only the platforms the catalogue actually has CPUs for can be built
# on. The legacy boards -- H61, H81, H110, H310, H510 -- match no CPU in
# the shop, so they never appear in a build. That is correct: they are
# the boards you sell to somebody repairing a ten-year-old office PC.
# ------------------------------------------------------------
CHIPSETS = {
    "AM4": ("a320", "b450", "a520", "b550", "x570"),
    "AM5": ("a620", "b650", "b840", "b850", "x670", "x870"),
    "LGA1700": ("h610", "b660", "h670", "b760", "z690", "z790"),
    "LGA1851": ("h810", "b860", "z890"),
}

CHIPSET_PLATFORM = {chip: plat for plat, chips in CHIPSETS.items() for chip in chips}

# When a socket could first be built on. These are the platform launch
# dates, and they are checkable facts rather than the year-level guesses
# launch_years.py makes from a part name.
#
# They are here because the generator gives every part a random month
# inside its launch year, which is close enough when a part sells on its
# own and wrong in a way anyone would spot on a build receipt: it put
# AM5 machines in April 2022, five months before the socket existed. A
# whole computer is dated by its platform, not by whichever month its
# processor happened to draw.
PLATFORM_AVAILABLE = {
    "AM4": (2017, 3),
    "AM5": (2022, 9),
    "LGA1700": (2021, 11),
    "LGA1851": (2024, 10),
}

# Memory generation per socket. LGA1700 is the awkward one: it was sold
# in both flavours and the board name says which, "D4" meaning DDR4.
PLATFORM_MEMORY = {
    "AM4": "DDR4",
    "AM5": "DDR5",
    "LGA1700": "DDR5",
    "LGA1851": "DDR5",
}

CHIPSET_RE = re.compile(r"\b([abhxz])(\d{2,3})[a-z]?\b", re.I)
RYZEN_RE = re.compile(r"ryzen\s+[3579]\s+(\d{4})", re.I)
CORE_I_RE = re.compile(r"core\s+i[3579][- ](\d{4,5})", re.I)
DDR_RE = re.compile(r"\bddr([345])\b", re.I)


def cpu_platform(name):
    """Which socket a processor sits in, or None if the name does not say."""
    low = name.lower()
    if "core ultra" in low:
        return "LGA1851"

    match = CORE_I_RE.search(low)
    if match:
        digits = match.group(1)
        generation = int(digits[:2]) if len(digits) == 5 else int(digits[:1])
        # 12th, 13th and 14th are LGA1700. Anything older is a socket the
        # shop has no processor for, so it is not buildable.
        return "LGA1700" if generation in (12, 13, 14) else None

    match = RYZEN_RE.search(low)
    if match:
        # The model number's first digit is the series: a Ryzen 5 5600 is
        # 5000-series and AM4, a Ryzen 5 7500F is 7000-series and AM5.
        series = int(match.group(1)[0])
        if series in (7, 8, 9):
            return "AM5"
        if series in (1, 2, 3, 4, 5):
            return "AM4"
    return None


def board_platform(name):
    """Which socket a motherboard has, read from its chipset."""
    for match in CHIPSET_RE.finditer(name):
        chipset = (match.group(1) + match.group(2)).lower()
        if chipset in CHIPSET_PLATFORM:
            return CHIPSET_PLATFORM[chipset]
    return None


def board_memory(name):
    """DDR4 or DDR5, for a board whose socket allows both."""
    platform = board_platform(name)
    if platform is None:
        return None
    if platform == "LGA1700" and re.search(r"\bd4\b", name, re.I):
        return "DDR4"
    return PLATFORM_MEMORY[platform]


def memory_generation(name):
    """DDR3 / DDR4 / DDR5 off a memory kit's name."""
    match = DDR_RE.search(name)
    return "DDR" + match.group(1) if match else None


# ------------------------------------------------------------
# The three kinds of machine, as price bands in 2026 ringgit.
# ------------------------------------------------------------
TIERS = [("OFFICE", 0.44), ("GAMING", 0.49), ("HIGH_END", 0.07)]

# Within a band, cheaper parts are likelier, on the same reasoning as the
# generator's PRICE_RESISTANCE: a band is the range a build of this kind
# draws from, not a range it picks from evenly. Without this the average
# part lands at the middle of its band, eight times over, and every
# gaming build comes out a top-of-the-band machine costing half again
# what a shop this size actually assembles.
PRICE_PULL = 0.85

BANDS = {
    "OFFICE": {
        "CPU": (400, 900), "Motherboard": (280, 800), "RAM": (250, 800),
        "Storage": (230, 750), "PSU": (150, 450), "Case": (130, 300),
        "Cooler": (50, 200), "GPU": (280, 1000),
    },
    "GAMING": {
        "CPU": (640, 1800), "Motherboard": (550, 1300), "RAM": (590, 2300),
        "Storage": (430, 1700), "PSU": (350, 950), "Case": (190, 650),
        "Cooler": (110, 700), "GPU": (1300, 4600),
    },
    "HIGH_END": {
        "CPU": (1500, 2700), "Motherboard": (1000, 2100), "RAM": (1800, 2900),
        "Storage": (820, 2000), "PSU": (850, 1900), "Case": (400, 900),
        "Cooler": (370, 800), "GPU": (4000, 9000),
    },
}

# An office machine usually runs on the processor's own graphics. The
# other two always have a card in them.
GPU_CHANCE = {"OFFICE": 0.35, "GAMING": 1.0, "HIGH_END": 1.0}
FAN_CHANCE = {"OFFICE": 0.15, "GAMING": 0.45, "HIGH_END": 0.65}
SECOND_DRIVE_CHANCE = {"OFFICE": 0.08, "GAMING": 0.18, "HIGH_END": 0.34}

# Labour. The assembly is not optional -- that is what makes it a build
# rather than a bag of parts -- and the rest is what gets asked for at
# the counter while the receipt is being written.
OS_INSTALL_CHANCE = 0.72
WARRANTY_CHANCE = 0.24

# What leaves with the machine.
#
# A built PC comes with no keyboard, no mouse and no lead to the
# monitor, so the two commonest additions to a build receipt are a set
# of input devices and a display cable. An office build usually takes
# the RM 99 wireless combo; a gaming build picks its board and its mouse
# separately and often adds a headset.
#
# Not every build takes them, because plenty of customers are replacing
# a machine and keeping the desk it sat on.
PERIPHERAL_CHANCE = {"OFFICE": 0.52, "GAMING": 0.60, "HIGH_END": 0.68}
HEADSET_CHANCE = {"OFFICE": 0.04, "GAMING": 0.32, "HIGH_END": 0.44}
DISPLAY_CABLE_CHANCE = {"OFFICE": 0.38, "GAMING": 0.46, "HIGH_END": 0.54}
COMBO_CHANCE = 0.62               # office builds, when a combo exists

# Price bands for the input devices, on the same 2026-ringgit footing as
# BANDS above. A machine's tier says as much about its keyboard as it
# does about its processor.
PERIPHERAL_BANDS = {
    "OFFICE": (25, 150),
    "GAMING": (55, 270),
    "HIGH_END": (100, 460),
}


def cooler_fits(name, platform):
    """Whether a cooler can go on this socket, as far as its name says.

    Only catches the case the name gives away -- "CPE R120 (Intel stock
    cooler)" was turning up on Ryzen machines, which is the sort of
    thing a reader spots immediately. A tower cooler that names neither
    vendor ships brackets for both and is left alone.
    """
    low = name.lower()
    if "stock cooler" not in low and "boxed" not in low:
        return True
    amd = platform in ("AM4", "AM5")
    if "intel" in low:
        return not amd
    if "amd" in low or "wraith" in low:
        return amd
    return True


def coolers_for(pool, platform):
    return [item for item in pool if cooler_fits(item["name"], platform)] or pool


def _by_category(stock):
    grouped = {}
    for item in stock:
        grouped.setdefault(item["category"], []).append(item)
    return grouped


def _cheap_first(rng, pool):
    """One of them, cheaper being likelier."""
    weights = [1.0 / (item["price"] ** PRICE_PULL) for item in pool]
    roll = rng.random() * sum(weights)
    for item, weight in zip(pool, weights):
        roll -= weight
        if roll <= 0:
            return item
    return pool[-1]


def _pick(rng, pool, band):
    """Something from the band if the year has one, otherwise the nearest
    thing it does have."""
    if not pool:
        return None
    low, high = band
    inside = [item for item in pool if low <= item["price"] <= high]
    if inside:
        return _cheap_first(rng, inside)
    middle = (low + high) / 2.0
    nearest = sorted(pool, key=lambda item: abs(item["price"] - middle))
    return rng.choice(nearest[:3])


def _weighted_tier(rng):
    roll = rng.random()
    running = 0.0
    for name, share in TIERS:
        running += share
        if roll < running:
            return name
    return TIERS[-1][0]


def _input_devices(rng, grouped, tier):
    """The keyboard, mouse and sometimes headset that go home with it."""
    pool = grouped.get(accessories.PERIPHERAL_CATEGORY, [])
    if not pool or rng.random() > PERIPHERAL_CHANCE[tier]:
        return []

    band = PERIPHERAL_BANDS[tier]
    wanted = "office" if tier == "OFFICE" else "gaming"
    lines = []

    # A combo is one box holding both, so it is picked instead of the
    # pair rather than as well as -- and it is excluded from the pair's
    # pools below, or the keyboard and the mouse can be the same line.
    combos = [item for item in pool
              if "keyboard" in item["tags"] and "mouse" in item["tags"]]
    if tier == "OFFICE" and combos and rng.random() < COMBO_CHANCE:
        chosen = _pick(rng, combos, band)
        if chosen is not None:
            lines.append({"item": chosen, "quantity": 1})
    else:
        for role in ("keyboard", "mouse"):
            singles = [item for item in pool
                       if role in item["tags"] and item not in combos]
            preferred = [item for item in singles if wanted in item["tags"]]
            chosen = _pick(rng, preferred or singles, band)
            if chosen is not None:
                lines.append({"item": chosen, "quantity": 1})

    if rng.random() < HEADSET_CHANCE[tier]:
        headsets = [item for item in pool if "headset" in item["tags"]]
        chosen = _pick(rng, headsets, band)
        if chosen is not None:
            lines.append({"item": chosen, "quantity": 1})

    return lines


def _display_cable(rng, grouped, tier):
    """A lead from the new machine to whatever screen it is going on."""
    if rng.random() > DISPLAY_CABLE_CHANCE[tier]:
        return []
    leads = [item for item in grouped.get(accessories.CABLE_CATEGORY, [])
             if "monitor" in item["tags"]]
    chosen = _pick(rng, leads, (15, 70))
    return [{"item": chosen, "quantity": 1}] if chosen is not None else []


def buildable(platform, year, month):
    """Whether a socket existed yet."""
    return platform in PLATFORM_AVAILABLE and \
        PLATFORM_AVAILABLE[platform] <= (year, month)


def assemble(rng, stock, service_items, year, month):
    """One whole machine as a list of {item, quantity}, or None if the
    month cannot supply a processor and a board that fit each other."""
    grouped = _by_category(stock)
    tier = _weighted_tier(rng)
    band = BANDS[tier]

    cpus = [item for item in grouped.get("CPU", [])
            if buildable(cpu_platform(item["name"]), year, month)]
    boards = [item for item in grouped.get("Motherboard", [])
              if buildable(board_platform(item["name"]), year, month)]
    if not cpus or not boards:
        return None

    # Pick the processor, then a board that fits it. A few attempts,
    # because the band may land on a socket this year has no board for.
    cpu = board = None
    for _ in range(6):
        candidate = _pick(rng, cpus, band["CPU"])
        platform = cpu_platform(candidate["name"])
        fitting = [item for item in boards if board_platform(item["name"]) == platform]
        if fitting:
            cpu = candidate
            board = _pick(rng, fitting, band["Motherboard"])
            break
    if cpu is None:
        return None

    wanted = board_memory(board["name"])
    memory_pool = [item for item in grouped.get("RAM", [])
                   if memory_generation(item["name"]) == wanted]
    if not memory_pool:
        return None

    parts = [cpu, board, _pick(rng, memory_pool, band["RAM"])]

    for category in ("Storage", "PSU", "Case", "Cooler"):
        pool = grouped.get(category, [])
        if category == "Cooler":
            pool = coolers_for(pool, platform)
        chosen = _pick(rng, pool, band[category])
        if chosen is None:
            return None
        parts.append(chosen)

    if rng.random() < GPU_CHANCE[tier]:
        card = _pick(rng, grouped.get("GPU", []), band["GPU"])
        if card is not None:
            parts.append(card)

    lines = [{"item": item, "quantity": 1} for item in parts]

    if rng.random() < SECOND_DRIVE_CHANCE[tier]:
        drives = [item for item in grouped.get("Storage", [])
                  if item["sku"] != parts[3]["sku"]]
        extra = _pick(rng, drives, band["Storage"])
        if extra is not None:
            lines.append({"item": extra, "quantity": 1})

    if rng.random() < FAN_CHANCE[tier]:
        fan = _pick(rng, grouped.get("Case Fans", []), (40, 260))
        if fan is not None:
            lines.append({"item": fan, "quantity": rng.randint(2, 6)})

    lines.extend(_input_devices(rng, grouped, tier))
    lines.extend(_display_cable(rng, grouped, tier))

    labour = {item["sku"]: item for item in service_items}
    for sku, chance in (("SVC-001", 1.0),
                        ("SVC-002", OS_INSTALL_CHANCE),
                        ("SVC-016", WARRANTY_CHANCE)):
        if sku in labour and rng.random() < chance:
            lines.append({"item": labour[sku], "quantity": 1})

    return lines
