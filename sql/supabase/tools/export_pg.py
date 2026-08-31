"""
Dump the live MariaDB `etech` database as PostgreSQL INSERT statements.

Rows come out of MySQL as JSON_ARRAY(...), one JSON array per line. That
matters because product descriptions and chatbot answers contain newlines,
and JSON escapes them inside the string rather than breaking the line.

Values are then re-quoted the Postgres way: a single quote is doubled, and
nothing else is escaped, because standard_conforming_strings is on by
default there (a backslash is just a backslash).
"""
import json
import subprocess
import sys

MYSQL = r"C:\xampp\mysql\bin\mysql.exe"
DB = "etech"

# Load order matters: parents before children, so every foreign key
# has something to point at while the file is running.
TABLES = [
    "brands",
    "categories",
    "products",
    "product_attributes",
    "customers",
    "admins",
    "coupons",
    "orders",
    "order_items",
    "order_status_history",
    "cart_items",
    "wishlist_items",
    "events",
    "chatbot_logs",
    "login_attempts",
]

# categories.parent_id points at categories, so the rows have to go in
# parents-first or the self-referencing key fails mid-file.
ORDER_BY = {
    "categories": "parent_id IS NOT NULL, category_id",
}


def run(sql, raw=False):
    args = [MYSQL, "-u", "root", "--default-character-set=utf8mb4", "-N", "--batch", DB, "-e", sql]
    if raw:
        args.insert(-2, "--raw")
    out = subprocess.run(args, capture_output=True)
    if out.returncode != 0:
        sys.exit(f"mysql failed on: {sql}\n{out.stderr.decode('utf-8', 'replace')}")
    return out.stdout.decode("utf-8")


def columns(table):
    sql = (
        "SELECT COLUMN_NAME FROM information_schema.COLUMNS "
        f"WHERE TABLE_SCHEMA='{DB}' AND TABLE_NAME='{table}' ORDER BY ORDINAL_POSITION"
    )
    return [c for c in run(sql).splitlines() if c]


def temporal_columns(table):
    """Names of the DATETIME / TIMESTAMP columns on this table."""
    sql = (
        "SELECT COLUMN_NAME FROM information_schema.COLUMNS "
        f"WHERE TABLE_SCHEMA='{DB}' AND TABLE_NAME='{table}' "
        "AND DATA_TYPE IN ('datetime','timestamp')"
    )
    return {c for c in run(sql).splitlines() if c}


repairs = 0


def unmangle(text):
    """
    Undo the cp850 damage done when the seed files were first imported.

    The .sql files hold correct UTF-8 — 03_seed.sql really does contain the
    bytes for a laptop emoji. But `mysql.exe < 03_seed.sql` on Windows read
    the file as cp850, so what landed in the table was the cp850 reading of
    those bytes, stored back out as UTF-8. Every product icon is that kind
    of wreckage, and so is the degree sign in two descriptions.

    Encoding back to cp850 and reading the result as UTF-8 reverses it
    exactly. Anything that is plain ASCII, that cp850 cannot represent, or
    that does not come out as valid UTF-8 was never mangled in the first
    place, and is returned untouched.
    """
    global repairs
    if all(ord(c) < 128 for c in text):
        return text
    try:
        fixed = text.encode("cp850").decode("utf-8")
    except (UnicodeEncodeError, UnicodeDecodeError):
        return text
    if fixed != text:
        repairs += 1
    return fixed


def quote(value, temporal=False):
    """
    value is hex of the UTF-8 bytes MySQL holds, or None.

    Temporal values get an explicit +08 stapled on. MySQL kept these as
    Asia/Singapore wall clock and hands them over with no zone at all, so
    a bare '2026-08-11 00:19:49' would be read at whatever TimeZone the
    receiving session happens to have — UTC on Supabase — and every
    order would slide eight hours. Writing the offset into the literal
    makes each row mean one instant no matter who runs it.
    """
    if value is None:
        return "NULL"
    text = unmangle(bytes.fromhex(value).decode("utf-8"))
    if temporal:
        return "'" + text + "+08'"
    return "'" + text.replace("'", "''") + "'"


def dump(table, out):
    cols = columns(table)
    # Every column comes back as HEX of its UTF-8 bytes, for two reasons.
    #
    # First, mysql.exe on Windows re-encodes its output into the console
    # code page on the way out, which turned the emoji in products.icon
    # into cp437 mojibake. Hex is plain ASCII, so nothing can touch it.
    #
    # Second, CAST(... AS CHAR) keeps DECIMAL exact. Left as a JSON
    # number, 1099.90 comes back as 1099.9000000000001; as text the
    # digits are what MySQL stored, and Postgres parses the literal
    # straight back into NUMERIC(10,2).
    payload = ", ".join(f"HEX(CAST(`{c}` AS CHAR))" for c in cols)
    order = ORDER_BY.get(table, cols[0])
    rows = run(f"SELECT JSON_ARRAY({payload}) FROM `{table}` ORDER BY {order}", raw=True)

    lines = [ln for ln in rows.splitlines() if ln.strip()]
    out.write(f"\n-- ---------- {table} ({len(lines)} rows) ----------\n")
    if not lines:
        out.write(f"-- (empty in the source database)\n")
        return 0

    when = temporal_columns(table)
    collist = ", ".join(cols)
    out.write(f"INSERT INTO {table} ({collist}) VALUES\n")
    tuples = []
    for ln in lines:
        values = json.loads(ln)
        cells = [quote(v, c in when) for c, v in zip(cols, values)]
        tuples.append("  (" + ", ".join(cells) + ")")
    out.write(",\n".join(tuples))
    out.write(";\n")
    return len(lines)


def split_by_size(tuples, budget):
    """
    Group rows into pieces of roughly `budget` bytes.

    Splitting on a row count instead would be misleading: 400 product
    rows carry long descriptions and come to 80 KB, while 400 event rows
    are four short columns and come to 23 KB. What has to stay bounded
    is the size of each tool argument, so the byte total is what decides
    where to cut. A single row that exceeds the budget still gets its
    own piece rather than being broken up.
    """
    parts, current, size = [], [], 0
    for row in tuples:
        if current and size + len(row) > budget:
            parts.append(current)
            current, size = [], 0
        current.append(row)
        size += len(row)
    if current:
        parts.append(current)
    return parts


def chunk_files(chunk_dir, budget=24_000):
    """
    Write the same INSERTs again, split small enough to hand over one
    tool call at a time.

    The single 02_data.sql is the artefact to keep and to run with psql.
    These pieces exist only because the load is going through the MCP
    server, where each statement travels as a tool argument rather than
    as a file read off disk.
    """
    import os

    os.makedirs(chunk_dir, exist_ok=True)
    for old in os.listdir(chunk_dir):
        os.remove(os.path.join(chunk_dir, old))

    index = []
    for seq, table in enumerate(TABLES, start=1):
        cols = columns(table)
        when = temporal_columns(table)
        payload = ", ".join(f"HEX(CAST(`{c}` AS CHAR))" for c in cols)
        order = ORDER_BY.get(table, cols[0])
        raw = run(f"SELECT JSON_ARRAY({payload}) FROM `{table}` ORDER BY {order}", raw=True)

        tuples = []
        for ln in raw.splitlines():
            if not ln.strip():
                continue
            values = json.loads(ln)
            cells = [quote(v, c in when) for c, v in zip(cols, values)]
            tuples.append("  (" + ", ".join(cells) + ")")

        if not tuples:
            continue

        collist = ", ".join(cols)
        parts = split_by_size(tuples, budget)
        for n, part in enumerate(parts, start=1):
            name = f"{seq:02d}_{table}_{n:02d}.sql"
            body = f"INSERT INTO {table} ({collist}) VALUES\n" + ",\n".join(part) + ";\n"
            with open(os.path.join(chunk_dir, name), "w", encoding="utf-8", newline="\n") as f:
                f.write(body)
            index.append((name, len(part), len(body) / 1024))

    for name, rows, kb in index:
        print(f"  {name:<34} {rows:>5} rows  {kb:7.1f} KB")


def main():
    target = sys.argv[1]
    total = {}
    with open(target, "w", encoding="utf-8", newline="\n") as out:
        out.write(HEADER)
        for t in TABLES:
            total[t] = dump(t, out)
        out.write(FOOTER)
    for t, n in total.items():
        print(f"{t:<22} {n}")
    print(f"total rows: {sum(total.values())}")
    print(f"mojibake values repaired: {repairs}")

    if len(sys.argv) > 2:
        print("\nchunks:")
        chunk_files(sys.argv[2])


HEADER = """-- ============================================================
-- eTech — data transferred out of the local MariaDB `etech` database.
--
-- Generated by scratchpad/export_pg.py, straight from the live tables.
-- Do not hand-edit; re-run the exporter instead.
--
-- Run after 01_schema.sql:
--     psql "$SUPABASE_DB_URL" -f 02_data.sql
--
-- Two things are set up front and matter:
--
--   Every timestamp carries an explicit +08. MySQL held these as
--   Asia/Singapore wall clock and exports them with no zone, so a bare
--   literal would be read at the receiving session's TimeZone — UTC on
--   Supabase — and every order would slide eight hours. The offset is
--   written into each literal instead of set once at the top, so the
--   rows mean the same instant however they are loaded, including one
--   statement at a time over a connection that does not persist a
--   session setting.
--
--   BEGIN / COMMIT      the whole load is one transaction. A foreign key
--                       or type failure anywhere rolls the lot back, so
--                       the database is never left half-migrated.
--
-- The tables are written parents-first so every foreign key has a row to
-- point at by the time it is checked.
-- ============================================================

BEGIN;
"""

FOOTER = """
COMMIT;
"""

if __name__ == "__main__":
    main()
