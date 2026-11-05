#!/usr/bin/env python3
"""Check the built database: are the headline numbers still right?

What it does: opens labour_warehouse.db (it does NOT rebuild anything)
and checks the 7 headline numbers and the row counts against the values
we verified from the source files. Each check prints PASS or FAIL.
If any check fails, the script exits with code 1 — so `bash build.sh`
fails too, and a bad build can never slip through quietly.

Run it from the project root, after a build:
    python3 verify.py

Or just run `bash build.sh` — it runs this check as its last step.
"""

import sqlite3
import sys
from pathlib import Path

DB_PATH = Path(__file__).resolve().parent / "labour_warehouse.db"

# (label, SQL that returns one number, expected value, allowed difference)
# The expected values were checked against the original source files:
# PBS Labour Force Survey 2024-25 and the World Bank yearly panel.
NUMBER_CHECKS = [
    ("National unemployment, PBS 2024-25 (%)",
     "SELECT unemployment_total FROM fact_pbs_province "
     "WHERE province_key = 'Pakistan'",
     7.1, 0.01),
    ("KP unemployment, PBS 2024-25 (%)",
     "SELECT unemployment_total FROM fact_pbs_province "
     "WHERE province_key = 'KP'",
     9.6, 0.01),
    ("Sindh unemployment, PBS 2024-25 (%)",
     "SELECT unemployment_total FROM fact_pbs_province "
     "WHERE province_key = 'Sindh'",
     5.3, 0.01),
    ("Youth unemployment, national, PBS 2024-25 (%)",
     "SELECT unemployment_rate FROM fact_pbs_youth "
     "WHERE province_key = 'Pakistan' AND sex_key = 'Total'",
     12.8, 0.01),
    ("Youth unemployment, KP young women, PBS 2024-25 (%)",
     "SELECT unemployment_rate FROM fact_pbs_youth "
     "WHERE province_key = 'KP' AND sex_key = 'Female'",
     25.6, 0.01),
    ("NEET, national, PBS 2024-25 (%)",
     "SELECT neet_total FROM fact_pbs_neet "
     "WHERE province_key = 'Pakistan' AND region_key = 'All Areas' "
     "AND year_label = '2024-25'",
     28.4, 0.01),
    ("Youth unemployment, World Bank modelled, 2025 (%)",
     "SELECT value FROM fact_labour_yearly "
     "WHERE year_label = '2025' AND indicator_key = 'youth_unemp_total'",
     9.594, 0.001),
]

# (label, SQL that returns one count, expected count)
DIM_TABLES = ["dim_year", "dim_province", "dim_indicator", "dim_sex",
              "dim_age_group", "dim_education", "dim_region"]
FACT_TABLES = ["fact_labour_yearly", "fact_pbs_province", "fact_pbs_youth",
               "fact_pbs_age", "fact_pbs_education", "fact_pbs_neet",
               "fact_pbs_province_region"]


def main():
    if not DB_PATH.exists():
        print(f"FAIL: {DB_PATH} not found — run bash build.sh first.")
        return 1

    con = sqlite3.connect(DB_PATH)
    failures = 0

    for label, sql, expected, tol in NUMBER_CHECKS:
        (actual,) = con.execute(sql).fetchone()
        ok = actual is not None and abs(actual - expected) <= tol
        print(f"{'PASS' if ok else 'FAIL'}: {label}: "
              f"got {actual}, expected {expected}")
        failures += 0 if ok else 1

    dim_total = sum(con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
                    for t in DIM_TABLES)
    ok = dim_total == 70
    print(f"{'PASS' if ok else 'FAIL'}: dimension rows: "
          f"got {dim_total}, expected 70")
    failures += 0 if ok else 1

    fact_total = sum(con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
                     for t in FACT_TABLES)
    ok = fact_total == 334
    print(f"{'PASS' if ok else 'FAIL'}: fact rows: "
          f"got {fact_total}, expected 334")
    failures += 0 if ok else 1

    con.close()
    print(f"{'All 9 checks passed.' if failures == 0 else f'{failures} check(s) failed.'}")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
