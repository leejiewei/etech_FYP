"""
Lay out supabase/ so it matches what is actually deployed.

The remote project records three migrations, applied in this order:

    20260826032147  etech_schema
    20260826032554  etech_sequences
    20260826032609  etech_rls

The local files have to carry those exact version numbers. Supabase
matches migrations by version, so a file named anything else looks like a
new migration and `supabase db push` would try to create the tables a
second time.

The data is not a migration. It went in over PostgREST, straight from
MySQL, and there is no remote row for it — so it belongs in seed.sql,
which is where Supabase expects data rather than structure.

That leaves one ordering trap. `supabase db reset` runs every migration
and then the seed, so on a rebuild etech_sequences would run against
empty tables and set every counter to 1, and the seed would then load
rows with explicit ids that the counters know nothing about. The first
customer to register would collide. So the sequence reset is repeated at
the end of seed.sql, where it runs after the rows exist. setval to
max+1 is idempotent, so having it in both places is harmless.
"""
import pathlib
import re

SRC = pathlib.Path(__file__).resolve().parent.parent          # sql/supabase
SUPA = SRC.parents[1] / "supabase"                            # <repo>/supabase
MIG = SUPA / "migrations"

# version -> source file. These versions are read off the remote project;
# do not renumber them.
DEPLOYED = [
    ("20260826032147_etech_schema.sql",    "01_schema.sql"),
    ("20260826032554_etech_sequences.sql", "03_sequences.sql"),
    ("20260826032609_etech_rls.sql",       "04_rls.sql"),
]

BANNER = """-- Generated from sql/supabase/{src} by sql/supabase/tools/build_migrations.py.
-- Edit the source file and rebuild; do not edit this copy.
--
-- The version number in the filename matches the row this migration has
-- in the remote project's history. Renaming it would make Supabase treat
-- it as a new migration and try to apply it again.
--
-- The outer BEGIN/COMMIT is stripped because `supabase db push` runs each
-- migration inside a transaction of its own.

"""


def strip_tx(text):
    return re.sub(r"(?mi)^\s*(BEGIN|COMMIT)\s*;\s*$\n?", "", text)


MIG.mkdir(parents=True, exist_ok=True)
for stale in MIG.glob("*.sql"):
    stale.unlink()

for dst_name, src_name in DEPLOYED:
    body = strip_tx((SRC / src_name).read_text(encoding="utf-8"))
    (MIG / dst_name).write_text(BANNER.format(src=src_name) + body, encoding="utf-8", newline="\n")
    print(f"migrations/{dst_name}  <- {src_name}")

# seed.sql = the rows, then the counter fix that has to follow them.
data = (SRC / "02_data.sql").read_text(encoding="utf-8")
seqs = strip_tx((SRC / "03_sequences.sql").read_text(encoding="utf-8"))

seed = (
    "-- Generated from sql/supabase/02_data.sql + 03_sequences.sql.\n"
    "-- Edit those and rebuild; do not edit this copy.\n"
    "--\n"
    "-- Loaded by `supabase db reset` after every migration has run. The\n"
    "-- sequence reset is repeated at the bottom because on a rebuild the\n"
    "-- etech_sequences migration runs before these rows exist, and a\n"
    "-- counter left at 1 would collide with the ids loaded here.\n\n"
    + data
    + "\n\n-- ---------- counters, now that the rows are in ----------\n"
    + seqs
)
(SUPA / "seed.sql").write_text(seed, encoding="utf-8", newline="\n")
print(f"seed.sql  <- 02_data.sql + 03_sequences.sql  ({len(seed)/1024:.1f} KB)")
