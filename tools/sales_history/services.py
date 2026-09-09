# ============================================================
# The half of the shop that is not on a shelf.
#
# eTech's database sells products. It has 39 categories and not one of
# them is a service, because the website only ever needed to take money
# for things with a stock count. A real computer shop earns a large part
# of its living on labour -- installing, cleaning, recovering, repairing
# -- and a sales history without any of it would be describing a
# different business.
#
# So these sixteen are invented. They are not in the database and this
# file is the only place they exist. The names and prices are what a
# small Malaysian shop charges, and they are here as a list rather than
# buried in the generator so that a price can be argued with.
#
# Three things follow from a service not being a product:
#
#   - There is no launch year. Cleaning a PC was possible in 2022 and
#     will be possible after this dataset ends.
#   - The margin is labour, so it is high -- 70-80% against 6-12% on a
#     graphics card. This is why a declining shop's *revenue* can fall
#     faster than its *profit*.
#   - Quantity is nearly always 1. You do not buy two virus removals.
#     The two exceptions are marked.
# ============================================================

# sku, name, price (MYR), margin, may_repeat, tags
SERVICES = [
    ("SVC-001", "PC Assembly & Build Service",        80.00, 0.80, False, ("build",)),
    ("SVC-002", "Operating System Installation",      60.00, 0.85, False, ("build", "laptop")),
    ("SVC-003", "Virus & Malware Removal",            80.00, 0.85, False, ("repair",)),
    ("SVC-004", "Data Backup & Transfer",            100.00, 0.80, False, ("repair", "laptop")),
    ("SVC-005", "Data Recovery (per drive)",         250.00, 0.70, True,  ("repair",)),
    ("SVC-006", "Laptop Screen Replacement (labour)", 150.00, 0.75, False, ("repair",)),
    ("SVC-007", "Laptop Keyboard Replacement (labour)", 120.00, 0.75, False, ("repair",)),
    ("SVC-008", "Thermal Paste Reapplication",         70.00, 0.85, False, ("repair", "build")),
    ("SVC-009", "Full PC Cleaning & Servicing",        90.00, 0.85, False, ("repair",)),
    ("SVC-010", "Component Upgrade Installation",      60.00, 0.85, False, ("build",)),
    ("SVC-011", "Printer Setup & Head Cleaning",       90.00, 0.80, False, ("printer",)),
    ("SVC-012", "Ink Tank Refill Service",             45.00, 0.65, True,  ("printer",)),
    ("SVC-013", "Home / Office Network Setup",        200.00, 0.75, False, ("network",)),
    ("SVC-014", "CCTV Installation (per camera)",     180.00, 0.60, True,  ("network",)),
    ("SVC-015", "On-Site Diagnostic Visit",           120.00, 0.80, False, ("repair", "network")),
    ("SVC-016", "Extended Warranty (1 Year)",         199.00, 0.70, False, ("build", "laptop")),
]


def as_items():
    """The same shape the product catalogue is put into, so the generator
    can treat a repair and a graphics card as one list."""
    items = []
    for sku, name, price, margin, may_repeat, tags in SERVICES:
        items.append({
            "sku": sku,
            "type": "SERVICE",
            "name": name,
            "category": "Services",
            "brand": "eTech",
            "price": price,
            "margin": margin,
            "launch_year": None,       # a service has no release date
            "may_repeat": may_repeat,
            "tags": set(tags),
        })
    return items


def by_tag(items, tag):
    return [item for item in items if tag in item["tags"]]
