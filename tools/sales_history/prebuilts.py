# ============================================================
# What is actually inside an E-Tech machine.
#
# eTech sells eleven of its own builds -- ZenForge, Titan Aegis, Inferno
# Apex, the Office PC series, Custom Office CO1 -- and on the website
# they are not really products. Their stock is derived: the site works
# out how many ZenForges it can sell by looking at how many of each part
# is on the shelf, because a ZenForge *is* a pile of parts that somebody
# screwed together. Nobody orders a crate of ZenForges from a supplier.
#
# The sales file was not saying that. A prebuilt sale came out as one
# line reading "E-Tech ZenForge Ryzen 5 5500 RTX 3050 -- RM 2,999", which
# tells you nothing about what left the shelf. Two months of those and
# the stock report is wrong, because eight components moved and the file
# recorded a product that has no supplier.
#
# So a prebuilt is itemised on the receipt, the same way a custom build
# is: one bill, one order id, a line per part. The difference between an
# E-Tech machine and a custom rig is now what it should be -- a rig is
# assembled to order and charged the assembly labour, a prebuilt is
# already built and is not.
#
# ---- Which parts ----
#
# The machine's own name says the two that matter. "E-Tech Inferno Apex
# Ryzen 7 7800X3D RX 9060 XT" names its processor and its card, and both
# are real catalogue products, so those two lines are read off the name
# rather than invented. Everything else -- board, memory, storage, power
# supply, case, cooler -- is picked from the catalogue the way rigs.py
# picks it, constrained to fit the named processor and to a price band
# scaled to what the machine sells for.
#
# An office machine with no card in its name gets none, which is right:
# an Office PC Ryzen 3 3200G runs on the APU's graphics.
#
# ---- The price ----
#
# The parts do not cost what the machine costs. They cost more -- that
# is the whole point of buying a prebuilt -- so the eight catalogue
# prices are scaled by one factor to make the bill total the machine's
# advertised price. Typically that lands around 0.80-0.95, and the
# discount is the same on every line rather than hidden in one of them,
# because a shop discounting a bundle takes it off the bundle.
#
# The machine's price is still the price. Itemising it changes what the
# receipt says, not what the customer paid, so revenue and the trend are
# untouched by this.
# ============================================================

import re

import rigs

# Only eTech's own builds are itemised. A Lenovo IdeaCentre arrives in a
# sealed box and a laptop cannot be broken into shop stock at all, so
# branded desktops, all-in-ones and laptops stay as one line each.
CATEGORIES = ("Prebuilt Gaming PCs", "Office PC Series", "Custom Office CO1")
BRAND = "E-Tech"

# What the name says. Longest-first inside each family, so "Ryzen 5
# 5600GT" is not read as "Ryzen 5 5600".
CPU_PATTERNS = [
    r"Core\s+Ultra\s+\d\s+\d{3}[A-Z]*",
    r"Core\s+i\d-\d{4,5}[A-Z]*",
    r"i\d-\d{4,5}[A-Z]*",
    r"Ryzen\s+\d\s+\d{4}[A-Z0-9]*",
]

# Variant suffixes first: an RX 9060 XT read as an "RX 9060" matches no
# catalogue card at all, because the plain 9060 does not exist.
GPU_PATTERNS = [
    r"RX\s+\d{4}\s+XT",
    r"RTX\s+\d{4}\s+Ti",
    r"RTX\s+\d{4}",
    r"RX\s+\d{4}",
    r"GTX\s+\d{4}",
    r"GT\s+\d{3,4}",
]

# Roughly what fraction of a machine's price each part is worth, used to
# aim the band before the scaling factor is worked out. They do not have
# to add to 1: they are a target to pick near, not a budget to spend.
SHARE = {
    "Motherboard": 0.20, "RAM": 0.16, "Storage": 0.15,
    "PSU": 0.11, "Case": 0.09, "Cooler": 0.06,
}
BAND_WIDTH = 0.6          # +/- 60% around the target, so a band exists


def _find(name, patterns):
    for pattern in patterns:
        match = re.search(pattern, name, re.I)
        if match:
            return match.group(0)
    return None


def _norm(text):
    """Upper case with runs of whitespace flattened, so the two names can
    be compared as plain strings.

    This used to be done by escaping the model and building a regex out
    of it, which was wrong in a way that hid itself: re.escape() escapes
    the space, and the escaped backslash then broke the substitution
    that was meant to make the space flexible. Every model name with a
    space in it -- which is every Ryzen, every Core Ultra and every
    graphics card -- silently failed to match, so only the one
    space-free "i7-12700" ever resolved. Plain string comparison cannot
    fail that way.
    """
    return re.sub(r"\s+", " ", text).strip().upper()


# Suffixes that make a different, dearer product. "RTX 5060" must not
# match an RTX 5060 Ti and "RX 9060" must not match an RX 9060 XT.
VARIANTS = (" TI", " XT", " SUPER")


def _same_part(model, candidate):
    """Whether a catalogue product is exactly the part the machine names.

    Anchored at the end, so "i5-14400" does not match the i5-14400F --
    the suffix is a different processor at a different price.
    """
    return _norm(candidate).endswith(_norm(model))


def _named_part(model, pool):
    """Every catalogue product that is the named part. More than one is
    normal -- an RTX 3050 comes from two board partners -- and the
    caller picks between them."""
    if model is None:
        return []
    want = _norm(model)

    exact = [item for item in pool if _same_part(want, item["name"])]
    if exact:
        return exact

    # A card's name carries a board-partner suffix the machine's name
    # does not: the catalogue calls it "Asus RTX 3050 Dual OC", not
    # "Asus RTX 3050". Match inside the name, but refuse a match that is
    # really a higher variant.
    found = []
    for item in pool:
        name = _norm(item["name"])
        at = name.find(want)
        if at < 0:
            continue
        rest = name[at + len(want):]
        if rest[:1].isdigit() or any(rest.startswith(v) for v in VARIANTS):
            continue
        found.append(item)
    return found


def _band(price, category):
    target = price * SHARE[category]
    return target * (1.0 - BAND_WIDTH), target * (1.0 + BAND_WIDTH)


def components(rng, machine, stock, year, month):
    """The parts inside one E-Tech machine, as [{item, quantity}] whose
    prices still need scaling, or None if the machine's own processor is
    not in the catalogue this month."""
    grouped = {}
    for item in stock:
        grouped.setdefault(item["category"], []).append(item)

    name = machine["name"]
    price = machine["price"]

    cpus = _named_part(_find(name, CPU_PATTERNS), grouped.get("CPU", []))
    if not cpus:
        return None
    cpu = rng.choice(cpus)

    platform = rigs.cpu_platform(cpu["name"])
    boards = [item for item in grouped.get("Motherboard", [])
              if rigs.board_platform(item["name"]) == platform]
    if not boards:
        return None
    board = rigs._pick(rng, boards, _band(price, "Motherboard"))

    wanted = rigs.board_memory(board["name"])
    memory = [item for item in grouped.get("RAM", [])
              if rigs.memory_generation(item["name"]) == wanted]
    if not memory:
        return None

    parts = [cpu, board, rigs._pick(rng, memory, _band(price, "RAM"))]
    for category in ("Storage", "PSU", "Case", "Cooler"):
        pool = grouped.get(category, [])
        if category == "Cooler":
            # An Intel stock cooler does not go on a Ryzen.
            pool = rigs.coolers_for(pool, platform)
        chosen = rigs._pick(rng, pool, _band(price, category))
        if chosen is None:
            return None
        parts.append(chosen)

    # The card, if the machine's name has one. An office machine runs on
    # the processor's own graphics and gets no line.
    cards = _named_part(_find(name, GPU_PATTERNS), grouped.get("GPU", []))
    if cards:
        parts.append(rng.choice(cards))

    return [{"item": item, "quantity": 1} for item in parts]


def scale_factor(machine_price, lines):
    """One multiplier that makes the itemised bill total the machine's
    price. Under 1 nearly always, because a prebuilt costs less than its
    parts bought separately."""
    total = sum(line["item"]["price"] * line["quantity"] for line in lines)
    if total <= 0:
        return 1.0
    return machine_price / total


def is_own_build(item):
    return item["category"] in CATEGORIES and item["brand"] == BRAND
