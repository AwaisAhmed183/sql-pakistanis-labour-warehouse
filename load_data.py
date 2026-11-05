#!/usr/bin/env python3
"""Load the real Pakistan labour CSVs into labour_warehouse.db (SQLite).

What it does, in order:
  1. Deletes any existing database file, so every build starts clean.
  2. Creates the star schema from sql/01_schema.sql.
  3. Reads the seven CSV files in data/ (copies of the published sources)
     and loads them — no hand-typed data rows anywhere.
  4. Prints the row count of every table, so you can see the load worked.

Run from the project root:
    python3 load_data.py

Everything it loads is public data:
  - World Bank Open Data (ILO modelled estimates), 1991-2025
  - PBS Labour Force Survey 2024-25 (37th round), published tables
See README.md and data/SOURCES.md for the full provenance.
"""

import csv
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DATA = ROOT / "data"
SQL_DIR = ROOT / "sql"
DB_PATH = ROOT / "labour_warehouse.db"

# The six World Bank indicators, from data/DATA_DICTIONARY.md of the source
# project. Keys are short names; the CSV columns use the same order.
WB_COLUMNS = [
    ("youth_unemp_total", "Youth unemployment, total (% of youth labour force, ages 15-24)",
     "%", "SL.UEM.1524.ZS"),
    ("youth_unemp_male", "Youth unemployment, male (% of male youth labour force, ages 15-24)",
     "%", "SL.UEM.1524.MA.ZS"),
    ("youth_unemp_female", "Youth unemployment, female (% of female youth labour force, ages 15-24)",
     "%", "SL.UEM.1524.FE.ZS"),
    ("unemp_total", "Unemployment, total (% of total labour force)",
     "%", "SL.UEM.TOTL.ZS"),
    ("lfpr_total", "Labour force participation rate, total (% of population ages 15+)",
     "%", "SL.TLF.CACT.ZS"),
    ("gdp_per_capita_usd", "GDP per capita (current US$)",
     "US$", "NY.GDP.PCAP.CD"),
]
# CSV column name -> indicator key (same order as WB_COLUMNS above)
WB_CSV_COLUMNS = [
    "youth_unemployment_total",
    "youth_unemployment_male",
    "youth_unemployment_female",
    "unemployment_total",
    "labour_force_participation_total",
    "gdp_per_capita_usd",
]

EDUCATION_ORDER = [
    "No Education",
    "Below Matric",
    "Matric",
    "Intermediate",
    "Degree",
    "Master/M.Phil/PhD",
]


def read_csv(name):
    """Read one CSV from data/ and return a list of dicts."""
    path = DATA / name
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def to_float(text):
    """Empty string means missing (NULL); anything else must be a number."""
    if text is None or text.strip() == "":
        return None
    return float(text)


def main():
    if DB_PATH.exists():
        DB_PATH.unlink()  # fresh build every time; the DB is rebuilt, not edited
    con = sqlite3.connect(DB_PATH)
    con.execute("PRAGMA foreign_keys = ON")
    cur = con.cursor()

    # 1. Schema ---------------------------------------------------------------
    cur.executescript((SQL_DIR / "01_schema.sql").read_text(encoding="utf-8"))

    # 2. Dimensions that come from the data itself ----------------------------
    years = set()       # (year_label, year_start, year_end, period_type)
    provinces = set()   # province keys; 'Pakistan' is the national row
    sexes = set()
    age_groups = set()
    regions = set()

    wb_rows = read_csv("pakistan_labour_indicators_1991_2025.csv")
    pbs_province = read_csv("pbs_lfs_province_2024_25.csv")
    pbs_youth = read_csv("pbs_lfs_youth_province_2024_25.csv")
    pbs_age = read_csv("pbs_lfs_age_2024_25.csv")
    pbs_education = read_csv("pbs_lfs_education_2024_25.csv")
    pbs_neet = read_csv("pbs_lfs_neet_2024_25.csv")
    pbs_province_region = read_csv("pbs_lfs_province_region_2020_21_2024_25.csv")

    for r in wb_rows:
        y = int(r["year"])
        years.add((str(y), y, y, "calendar"))
    for rows in (pbs_province, pbs_youth, pbs_age, pbs_education,
                 pbs_neet, pbs_province_region):
        for r in rows:
            label = r["year"]
            if "-" in label:
                # Survey year like '2024-25': the first part is the full
                # start year (2024); the second part is the 2-digit end
                # year in the same century, so '20' + '25' -> 2025.
                start_part, end_part = label.split("-")
                start = int(start_part)
                end = int(start_part[:2] + end_part)
            else:
                start = end = int(label)
            years.add((label, start, end, "survey"))
    for rows in (pbs_province, pbs_youth, pbs_neet, pbs_province_region):
        for r in rows:
            # The youth file labels the national row 'Total'; everywhere else
            # it is 'Pakistan'. One cleaned key, raw value kept in the fact.
            provinces.add("Pakistan" if r["province"] == "Total" else r["province"])
    for r in pbs_youth:
        sexes.add(r["sex"])
    for r in pbs_age:
        age_groups.add(r["age_group"])
    for r in pbs_neet:
        regions.add(r["region"])
    for r in pbs_province_region:
        regions.add(r["region"])

    cur.executemany(
        "INSERT INTO dim_year VALUES (?, ?, ?, ?)", sorted(years))
    cur.executemany(
        "INSERT INTO dim_province VALUES (?, ?, ?)",
        [(p, p, 1 if p == "Pakistan" else 0) for p in sorted(provinces)])
    cur.executemany(
        "INSERT INTO dim_indicator VALUES (?, ?, ?, ?, ?)",
        [(k, name, unit, code, "World Bank") for k, name, unit, code in WB_COLUMNS])
    cur.executemany(
        "INSERT INTO dim_sex VALUES (?, ?)", [(s, s) for s in sorted(sexes)])
    cur.executemany(
        "INSERT INTO dim_age_group VALUES (?, ?)", [(a, a) for a in sorted(age_groups)])
    cur.executemany(
        "INSERT INTO dim_education VALUES (?, ?)",
        [(level, i + 1) for i, level in enumerate(EDUCATION_ORDER)])
    region_labels = {
        "Total": "Whole province (Table 9.3)",
        "All Areas": "Whole province (Table 8.8)",
        "Rural": "Rural areas",
        "Urban": "Urban areas",
    }
    cur.executemany(
        "INSERT INTO dim_region VALUES (?, ?)",
        [(r, region_labels.get(r, r)) for r in sorted(regions)])

    # 3. Facts ----------------------------------------------------------------
    # 3a. World Bank panel, stored LONG: one row per year per indicator.
    fact_yearly = []
    for r in wb_rows:
        for key, col in zip([k for k, _, _, _ in WB_COLUMNS], WB_CSV_COLUMNS):
            fact_yearly.append((r["year"], key, float(r[col])))
    cur.executemany(
        "INSERT INTO fact_labour_yearly VALUES (?, ?, ?)", fact_yearly)

    # 3b. PBS province unemployment, 2024-25 (Table 9.2, 19th ICLS).
    cur.executemany(
        """INSERT INTO fact_pbs_province
           VALUES (?, ?, ?, ?, ?, ?, ?)""",
        [(r["province"], r["year"], r["framework"],
          to_float(r["unemployment_total"]), to_float(r["unemployment_male"]),
          to_float(r["unemployment_female"]), r["source_table"])
         for r in pbs_province])

    # 3c. PBS youth by province and sex (Table 8.7, 19th ICLS).
    cur.executemany(
        """INSERT INTO fact_pbs_youth
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        [("Pakistan" if r["province"] == "Total" else r["province"],
          r["province"], r["sex"], r["year"], r["framework"],
          to_float(r["employed_million"]), to_float(r["unemployed_million"]),
          to_float(r["labour_force_million"]),
          to_float(r["out_of_labour_force_million"]),
          to_float(r["youth_population_million"]),
          to_float(r["unemployment_rate"]),
          to_float(r["employment_to_population_ratio"]),
          to_float(r["lfpr"]), r["source_table"])
         for r in pbs_youth])

    # 3d. PBS unemployment by age group (Tables 9.4 / 9.5 / 9.6).
    cur.executemany(
        """INSERT INTO fact_pbs_age VALUES (?, ?, ?, ?, ?, ?, ?)""",
        [(r["age_group"], r["framework"], r["year"],
          to_float(r["unemployment_total"]), to_float(r["unemployment_male"]),
          to_float(r["unemployment_female"]), r["source_table"])
         for r in pbs_age])

    # 3e. PBS unemployment by education level (Tables 9.7 / 9.8).
    cur.executemany(
        """INSERT INTO fact_pbs_education VALUES (?, ?, ?, ?, ?, ?, ?)""",
        [(r["education_level"], r["framework"], r["year"],
          to_float(r["unemployment_total"]), to_float(r["unemployment_male"]),
          to_float(r["unemployment_female"]), r["source_table"])
         for r in pbs_education])

    # 3f. PBS NEET rates (Table 8.8).
    cur.executemany(
        """INSERT INTO fact_pbs_neet VALUES (?, ?, ?, ?, ?, ?, ?)""",
        [(r["province"], r["region"], r["year"],
          to_float(r["neet_total"]), to_float(r["neet_male"]),
          to_float(r["neet_female"]), r["source_table"])
         for r in pbs_neet])

    # 3g. PBS province x region unemployment (Table 9.3, 13th ICLS).
    cur.executemany(
        """INSERT INTO fact_pbs_province_region VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
        [(r["province"], r["region"], r["year"], r["framework"],
          to_float(r["unemployment_total"]), to_float(r["unemployment_male"]),
          to_float(r["unemployment_female"]), r["source_table"])
         for r in pbs_province_region])

    con.commit()

    # 4. Report what was loaded ----------------------------------------------
    # (fetch the table list first: running a new query on the same cursor
    #  while iterating over it would stop the loop after the first row.)
    print(f"Database built: {DB_PATH}")
    tables = [name for (name,) in cur.execute(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' ORDER BY name").fetchall()]
    for table in tables:
        (count,) = cur.execute(f"SELECT COUNT(*) FROM {table}").fetchone()
        print(f"  {table:<28} {count} rows")
    con.close()


if __name__ == "__main__":
    main()
