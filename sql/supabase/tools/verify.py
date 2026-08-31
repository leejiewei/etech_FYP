"""
Build a per-table fingerprint of the MySQL source, and emit the Postgres
query that fingerprints the copy the same way.

Row counts alone would not catch a value that arrived wrong, so each row
is flattened to text, joined with a separator, and the whole table hashed.
Only 15 hashes have to be compared instead of 3,343 rows.

Both sides have to spell values identically for the hashes to mean
anything, so:

  NULL        becomes the literal \\N, since an empty string is a real
              value that a NULL must not collide with.
  DECIMAL     is compared as text. MySQL gives '3999.00' and Postgres
              NUMERIC(10,2)::text gives '3999.00'; as floats they would
              both be approximations and could differ in the last bit.
  timestamps  are rendered as Asia/Singapore wall clock on both sides.
              Postgres holds them as UTC now, so the raw text would read
              '2026-08-10 16:19:49+00' against MySQL's local
              '2026-08-11 00:19:49' and every row would look wrong.
"""
import hashlib
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from export_pg import TABLES, columns, temporal_columns, run, unmangle

SEP = "|"
NULL = "\\N"


def mysql_fingerprint(table):
    cols = columns(table)
    when = temporal_columns(table)
    payload = ", ".join(f"HEX(CAST(`{c}` AS CHAR))" for c in cols)
    raw = run(f"SELECT JSON_ARRAY({payload}) FROM `{table}` ORDER BY `{cols[0]}`", raw=True)

    rows = []
    for line in raw.splitlines():
        if not line.strip():
            continue
        cells = []
        for col, hexval in zip(cols, json.loads(line)):
            if hexval is None:
                cells.append(NULL)
            else:
                # unmangle so the fingerprint reflects the repaired text
                # that was actually sent, not the cp850 wreckage in MySQL
                cells.append(unmangle(bytes.fromhex(hexval).decode("utf-8")))
        rows.append(SEP.join(cells))

    blob = "\n".join(rows)
    return len(rows), hashlib.md5(blob.encode("utf-8")).hexdigest()


def pg_expression(table):
    cols = columns(table)
    when = temporal_columns(table)
    parts = []
    for c in cols:
        if c in when:
            expr = f"to_char({c} AT TIME ZONE 'Asia/Singapore', 'YYYY-MM-DD HH24:MI:SS')"
        else:
            expr = f"{c}::text"
        parts.append(f"coalesce({expr}, '\\N')")
    concat = ", ".join(parts)
    return (
        f"SELECT '{table}' AS t, count(*) AS n, "
        f"coalesce(md5(string_agg(r, chr(10) ORDER BY k)), 'd41d8cd98f00b204e9800998ecf8427e') AS h "
        f"FROM (SELECT {cols[0]} AS k, concat_ws('{SEP}', {concat}) AS r FROM {table}) s"
    )


expected = {}
queries = []
for t in TABLES:
    n, h = mysql_fingerprint(t)
    expected[t] = (n, h)
    queries.append(pg_expression(t))

with open(sys.argv[1], "w", encoding="utf-8", newline="\n") as f:
    f.write("\nUNION ALL\n".join(queries) + "\nORDER BY t;\n")

with open(sys.argv[2], "w", encoding="utf-8") as f:
    json.dump(expected, f, indent=2)

print("MySQL side (source of truth):")
for t, (n, h) in expected.items():
    print(f"  {t:<22} {n:>5} rows  {h}")
print(f"\nPostgres query written to {sys.argv[1]}")
