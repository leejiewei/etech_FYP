# ============================================================
# When could this shop have sold this part?
#
# The products table has one date on it -- created_at -- and every one
# of the 389 rows says 2026, because the whole catalogue was imported in
# one go. So the database cannot answer "what did the shop stock in
# 2022?", and something has to.
#
# What it does have is the part names, and a part name is a date. An
# RTX 5070 did not exist in 2022 and an H61 motherboard was old before
# this project started. The rules below read that: they map a name to
# the year the part reached Malaysian retail, and the generator refuses
# to sell anything before its year.
#
# These years are judgement, not records. They are researchable facts
# about the hardware -- release dates are public -- but nobody checked
# them against eTech's own purchase history, because no such history
# exists. Anything the rules do not recognise falls back to
# DEFAULT_LAUNCH_YEAR, which is before the dataset starts, i.e. "assume
# the shop always had it". That is the safe direction to be wrong in:
# it never invents a sale of a part that had not been announced.
#
# ---- On (?!\d) rather than a trailing word boundary ----
#
# The first draft of these rules ended each chipset pattern with \b, and
# it silently matched nothing useful: "B860M" has no word boundary
# between the 0 and the M, so every micro-ATX board fell past its own
# rule onto a later, older one and forty 2025 motherboards were sold in
# 2022. A negative lookahead for a digit is what was meant -- it keeps
# H61 and H610 apart while letting a suffix letter through.
# ============================================================

import re

# Before the window starts, so an unmatched item is available throughout.
DEFAULT_LAUNCH_YEAR = 2018

# Every pattern that matches a name is collected and the LATEST year
# wins, because a product is as new as its newest part. "Lenovo LOQ
# 15ARP10E Ryzen 7 7735HS RTX 3050" matches both the RTX 3050 rule
# (2022) and the mobile Ryzen rule (2023), and it is a 2023 laptop: an
# older graphics chip in a newer machine is normal, and a first-match
# reading would have put it on sale a year before it existed.
#
# Order still matters within a family, because the specific patterns
# have to be tried before the general ones -- 7800X3D before 7xxx.
# Matching is case-insensitive.
RULES = [
    # ---- Nvidia GeForce -------------------------------------------------
    (r"\bRTX\s*50[5-9]0(?!\d)", 2025),      # 5050, 5060, 5070, 5080, 5090
    (r"\bRTX\s*40[5-9]0(?!\d)", 2023),
    (r"\bRTX\s*30[5-9]0(?!\d)", 2022),      # the 3050 desktop was Jan 2022
    (r"\bRTX\s*20[6-8]0(?!\d)", 2019),
    (r"\bGTX\s*16[5-6]0(?!\d)", 2019),
    (r"\bGTX\s*10[5-8]0(?!\d)", 2018),
    (r"\bGT\s*1030(?!\d)", 2018),
    (r"\bGT\s*7[0-3]0(?!\d)", 2018),        # GT 710 / 730, ancient, still sold

    # ---- AMD Radeon -----------------------------------------------------
    (r"\bRX\s*9[0-9]{3}(?!\d)", 2025),      # RX 9060 XT / 9070 XT
    (r"\bRX\s*7[0-9]{3}(?!\d)", 2023),
    (r"\bRX\s*6[0-9]{3}(?!\d)", 2021),

    # ---- AMD Ryzen mobile ----------------------------------------------
    # Above the desktop rules on purpose: a 7520U is not a 7000-series
    # desktop chip, and the desktop pattern would otherwise swallow it.
    (r"Ryzen\s*AI\s*[0-9]", 2025),
    (r"Ryzen\s*[0-9]\s*8[0-9]{2}[05]HS(?!\d)", 2024),   # 8845HS
    (r"Ryzen\s*[0-9]\s*77[0-9]{2}HS(?!\d)", 2023),      # 7735HS
    (r"Ryzen\s*[0-9]\s*7[0-9]{3}U(?!\d)", 2023),        # 7520U, 7730U
    (r"Ryzen\s*[0-9]\s*[0-9]{3,4}[UH]S?(?!\d)", 2023),  # anything else mobile

    # ---- AMD Ryzen desktop ---------------------------------------------
    (r"Ryzen\s*[0-9]\s*9[0-9]{3}X3D(?!\d)", 2025),      # 9800X3D Nov 24, 9950X3D Mar 25
    (r"Ryzen\s*[0-9]\s*9[0-9]{3}(?![0-9UH])", 2024),    # 9600X / 9700X / 9900X
    (r"Ryzen\s*[0-9]\s*7500X3D(?!\d)", 2025),
    (r"Ryzen\s*[0-9]\s*7800X3D(?!\d)", 2023),
    (r"Ryzen\s*[0-9]\s*7500F(?!\d)", 2023),
    (r"Ryzen\s*[0-9]\s*7[0-9]{3}(?![0-9UH])", 2022),    # 7600X, Sep 2022
    (r"Ryzen\s*[0-9]\s*5600GT(?!\d)", 2024),
    (r"Ryzen\s*[0-9]\s*5800X3D(?!\d)", 2022),
    (r"Ryzen\s*[0-9]\s*5[0-9]{3}(?![0-9UH])", 2021),    # 5500 / 5600 / 5700X
    (r"Ryzen\s*[0-9]\s*3[0-9]{3}G?(?![0-9UH])", 2019),  # 3200G / 3400G

    # ---- AMD's 2024-25 laptop renaming (Ryzen 5 150, Ryzen 7 250) -------
    (r"Ryzen\s*[0-9]\s*2[0-9]{2}(?!\d)", 2025),
    (r"Ryzen\s*[0-9]\s*1[0-9]{2}(?!\d)", 2025),
    (r"Ryzen\s*[0-9]\s*30(?!\d)", 2024),

    # ---- Intel ----------------------------------------------------------
    (r"Core\s*Ultra\s*[0-9]\s*2[0-9]{2}", 2025),   # Core Ultra 200 at retail
    (r"Core\s*Ultra\s*[0-9]", 2024),
    (r"\bi[3579]-14[0-9]{3}", 2024),               # 14th gen K Oct 23, rest Jan 24
    (r"\bi[3579]-13[0-9]{3}", 2023),
    (r"\bi[3579]-12[0-9]{3}", 2022),
    (r"\bi[3579]-11[0-9]{3}", 2021),
    (r"\bi[3579]-1[0-9]{3}[A-Z]", 2020),
    (r"\bCore\s*5\s*2[0-9]{2}H(?!\d)", 2025),      # "Core 5 210H"
    (r"\bCore\s*5\s*1[0-9]{2}U(?!\d)", 2024),      # "Core 5 120U"

    # ---- Chipsets: the socket dates the board ---------------------------
    (r"\bX870E?(?!\d)", 2025),
    (r"\bB850(?!\d)", 2025),
    (r"\bB840(?!\d)", 2025),
    (r"\bB860(?!\d)", 2025),
    (r"\bH810(?!\d)", 2025),
    (r"\bZ890(?!\d)", 2024),
    (r"\bA620(?!\d)", 2023),
    (r"\bB760(?!\d)", 2023),
    (r"\bZ790(?!\d)", 2023),
    (r"\bB650(?!\d)", 2022),
    (r"\bX670(?!\d)", 2022),
    (r"\bH610(?!\d)", 2022),
    (r"\bH510(?!\d)", 2021),
    (r"\bB550(?!\d)", 2020),
    (r"\bA520(?!\d)", 2020),
    (r"\bH410(?!\d)", 2020),
    (r"\bX570(?!\d)", 2019),
    (r"\bH310(?!\d)", 2018),
    (r"\bH110(?!\d)", 2018),
    (r"\bH81(?!\d)", 2018),
    (r"\bH61(?!\d)", 2018),

    # ---- Memory ---------------------------------------------------------
    (r"DDR5-6[4-9][0-9]{2}", 2023),     # the faster kits came later
    (r"DDR5-7[0-9]{3}", 2023),
    (r"\bDDR5\b", 2022),                # DDR5 reached normal retail in 2022
    (r"\bDDR4\b", DEFAULT_LAUNCH_YEAR),
    (r"\bDDR3\b", DEFAULT_LAUNCH_YEAR),

    # ---- Storage --------------------------------------------------------
    (r"Gen\s*5(?!\d)", 2024),
    (r"Gen\s*4(?!\d)", 2021),
    (r"Gen\s*3(?!\d)", DEFAULT_LAUNCH_YEAR),

    # ---- Networking -----------------------------------------------------
    #
    # The WiFi 7 / WiFi 6 rules below never fired on this catalogue, and
    # that was worth catching: not one router in it says "WiFi 7" in its
    # name. They say RT-BE58U and Archer BE400, because the generation
    # lives in the model code. Nine routers were falling through to
    # DEFAULT_LAUNCH_YEAR and selling in 2022, five of them WiFi 7
    # hardware that did not exist until 2024.
    #
    # The letter pair is the standard: BE is WiFi 7, AX is WiFi 6, AC is
    # WiFi 5. Kept as its own rule per vendor prefix rather than a bare
    # \bBE\d, which would also match a product code in another category.
    (r"\b(?:RT-|Archer\s*|TUF\s*Gaming\s*|Deco\s*)BE[0-9]{2,4}", 2024),
    (r"\bBE[0-9]{4}\b", 2024),
    (r"\b(?:RT-|Archer\s*|Deco\s*)AX[0-9]{2,4}", 2020),
    (r"\bRT-AX[0-9]+", 2020),
    (r"\bArcher\s*NX[0-9]{3}", 2023),          # 5G CPE, 2023
    (r"\bTL-MR[0-9]{3}", 2021),
    (r"\bDeco\s*X10\b", 2022),
    (r"WiFi\s*7(?!\d)", 2024),
    (r"WiFi\s*6E(?!\d)", 2022),
    (r"WiFi\s*6(?!\d)", 2020),

    # ---- Monitors -------------------------------------------------------
    #
    # Every one of the 21 monitors in the catalogue is a 2023 model or
    # newer -- a panel line turns over every couple of years, so a 2026
    # snapshot holds none of 2022's. Six were dated by the refresh-rate
    # rule below; the other fifteen fell through to "always stocked" and
    # were being sold from January 2022, including an RM 649 27" 180Hz
    # gaming panel and a 34" ultrawide.
    #
    # These are model codes with public announcement dates, which is the
    # same kind of fact as a chipset number, and they are listed one by
    # one because a monitor's name carries no generation marker to read.
    (r"\bXG27ACS\b", 2024),
    (r"\bXV270YM3\b", 2024),
    (r"\bMP251\b", 2024),
    (r"\bMD342CQP\b", 2024),
    (r"\bED270R\b", 2023),
    (r"\bMB169CK\b", 2023),
    (r"\bVY249\b", 2023),
    (r"\bPA279CRV\b", 2023),
    (r"\bMP225V?\b", 2023),
    (r"\bMP273\b", 2023),
    (r"\bG321Q\b", 2023),
    (r"\bL24-4e\b", 2023),
    (r"\b532sf\b", 2023),

    # ---- Projectors -----------------------------------------------------
    (r"\bYaber\b", 2023),
    (r"\bEB-E24\b", 2021),

    # ---- Coolers with a screen on them ----------------------------------
    #
    # A cooler with an LCD or a digital readout on the block is a recent
    # thing: the first mainstream ones landed in 2023. This dates eight
    # of the twenty-one unmatched coolers without naming any of them.
    (r"\b(?:LCD|Digital)\b", 2023),

    # ---- Panels ---------------------------------------------------------
    (r"\bOLED\b", 2023),
    (r"\b(2[0-9]{2}|3[0-9]{2})Hz\b", 2023),   # 220Hz+ panels are recent
]

COMPILED = [(re.compile(pattern, re.IGNORECASE), year) for pattern, year in RULES]


def _matches(name):
    return [(year, pattern.pattern) for pattern, year in COMPILED if pattern.search(name)]


def launch_year(name):
    """The year this item could first be sold: the latest year any of its
    parts allows. Nothing recognised means it was always in stock."""
    found = _matches(name)
    if not found:
        return DEFAULT_LAUNCH_YEAR
    return max(year for year, _ in found)


def explain(name):
    """The year and the rule that set it, for checking these by eye."""
    found = _matches(name)
    if not found:
        return DEFAULT_LAUNCH_YEAR, "(no rule matched -- assumed always stocked)"
    return max(found, key=lambda pair: pair[0])


if __name__ == "__main__":
    # Print the whole catalogue with the year and the rule that decided
    # it, so the judgement can be argued with rather than trusted.
    import json
    import os

    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, "catalogue_snapshot.json"), encoding="utf-8") as handle:
        rows = json.load(handle)

    for row in sorted(rows, key=lambda r: (explain(r["name"])[0], r["name"])):
        year, rule = explain(row["name"])
        print("%d  %-58s  %s" % (year, row["name"][:58], rule))
