"""
Load the remaining tables into Supabase through PostgREST.

Why this and not the MCP server: over MCP the SQL travels as a tool
argument, which means the agent has to reproduce all 3,343 rows by hand.
Here the rows go straight from MySQL into an HTTP body without a human
or a model in the middle, so what lands in Postgres is exactly what came
out of MariaDB.

This works right now because the tables were just created and RLS has not
been switched on yet, so Supabase's default grants let the anon key write.
That is the same hole the "RLS disabled in public" advisor warns about,
and it closes the moment the RLS migration runs — which is the next step
after this script, not an optional extra.

Every value is sent as a JSON string and left for Postgres to coerce.
Sending 1099.90 as a JSON number would route it through a float on the
way, and NUMERIC(10,2) should get the digits MySQL actually stored.
"""
import json
import os
import pathlib
import sys
import urllib.error
import urllib.request

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from export_pg import columns, temporal_columns, quote, run, ORDER_BY, unmangle

# Read from the environment rather than sitting in the file. The anon key
# is publishable — it ships inside the Flutter bundle and the site's JS —
# but a key committed to a repo is a key nobody rotates.
#
#   set SUPABASE_URL=https://<ref>.supabase.co
#   set SUPABASE_ANON_KEY=<publishable key>
PROJECT = os.environ.get("SUPABASE_URL", "").rstrip("/")
ANON = os.environ.get("SUPABASE_ANON_KEY", "")

if not PROJECT or not ANON:
    sys.exit("Set SUPABASE_URL and SUPABASE_ANON_KEY before running this.")

# brands and categories are already in. The rest go parents-first, and
# events waits for customers because event.customer_id points at it.
TABLES = [
    "products",
    "customers",
    "admins",
    "coupons",
    "orders",
    "order_items",
    "order_status_history",
    "product_attributes",
    "events",
    "chatbot_logs",
]

BATCH = 500


def rows_for(table):
    cols = columns(table)
    when = temporal_columns(table)
    payload = ", ".join(f"HEX(CAST(`{c}` AS CHAR))" for c in cols)
    order = ORDER_BY.get(table, cols[0])
    raw = run(f"SELECT JSON_ARRAY({payload}) FROM `{table}` ORDER BY {order}", raw=True)

    out = []
    for line in raw.splitlines():
        if not line.strip():
            continue
        record = {}
        for col, hexval in zip(cols, json.loads(line)):
            if hexval is None:
                record[col] = None
                continue
            text = unmangle(bytes.fromhex(hexval).decode("utf-8"))
            # Same +08 as the SQL export, for the same reason: MySQL hands
            # these over with no zone and Supabase would read them as UTC.
            record[col] = text + "+08" if col in when else text
        out.append(record)
    return out


def post(table, batch):
    body = json.dumps(batch, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        f"{PROJECT}/rest/v1/{table}",
        data=body,
        method="POST",
        headers={
            "apikey": ANON,
            "Authorization": f"Bearer {ANON}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return resp.status, ""
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")[:400]


def main():
    grand = 0
    for table in TABLES:
        rows = rows_for(table)
        if not rows:
            print(f"{table:<22} 0 rows (empty in source)")
            continue
        sent = 0
        for i in range(0, len(rows), BATCH):
            batch = rows[i:i + BATCH]
            status, err = post(table, batch)
            if status >= 300:
                print(f"{table:<22} FAILED at row {i} -> HTTP {status}\n{err}")
                sys.exit(1)
            sent += len(batch)
        grand += sent
        print(f"{table:<22} {sent} rows")
    print(f"\nposted {grand} rows")


if __name__ == "__main__":
    main()
