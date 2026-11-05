# Data provenance

Every CSV in this folder is a copy of a published public table. Nothing
was typed by hand and no number was invented. The copies are byte-identical
to the files in the author's research project
([pakistan-youth-unemployment-forecasting](https://github.com/AwaisAhmed183/pakistan-youth-unemployment-forecasting),
`data/`), where they were transcribed from the sources below.

## World Bank Open Data — yearly panel (1991–2025)

File: `pakistan_labour_indicators_1991_2025.csv` — 35 rows, 0 missing values.

- Portal: https://data.worldbank.org/ — country PAK, retrieved 23–24 Oct 2026.
- Series are **ILO modelled estimates** (designed for cross-country
  comparability), not raw survey counts.

| CSV column | Meaning | Unit | World Bank code |
|---|---|---|---|
| `year` | Calendar year | year | — |
| `youth_unemployment_total` | Youth unemployment, total, ages 15–24 | % | SL.UEM.1524.ZS |
| `youth_unemployment_male` | Youth unemployment, male, ages 15–24 | % | SL.UEM.1524.MA.ZS |
| `youth_unemployment_female` | Youth unemployment, female, ages 15–24 | % | SL.UEM.1524.FE.ZS |
| `unemployment_total` | Unemployment, total | % | SL.UEM.TOTL.ZS |
| `labour_force_participation_total` | Labour force participation, total, ages 15+ | % | SL.TLF.CACT.ZS |
| `gdp_per_capita_usd` | GDP per capita, current US$ (nominal) | US$ | NY.GDP.PCAP.CD |

## PBS Labour Force Survey 2024-25 — published tables

Publication: Labour Force Survey 2024-25 (37th round, Sep 2025), Pakistan
Bureau of Statistics, Government of Pakistan.
Report: https://www.pbs.gov.pk/wp-content/uploads/2020/07/LFS-2024-25-Annual-Report.pdf

| File | Rows | PBS table | Framework | Contents |
|---|---|---|---|---|
| `pbs_lfs_province_2024_25.csv` | 5 | Table 9.2 | 19th ICLS | Unemployment by province, 2024-25 |
| `pbs_lfs_youth_province_2024_25.csv` | 15 | Table 8.7 | 19th ICLS | Youth (15–24) by province × sex, 2024-25 |
| `pbs_lfs_age_2024_25.csv` | 26 | Tables 9.4, 9.5, 9.6 | 19th + 13th ICLS | Unemployment by age group |
| `pbs_lfs_education_2024_25.csv` | 18 | Tables 9.7, 9.8 | 19th + 13th ICLS | Unemployment by education level |
| `pbs_lfs_neet_2024_25.csv` | 30 | Table 8.8 | — | NEET rate by province × region, 2020-21 vs 2024-25 |
| `pbs_lfs_province_region_2020_21_2024_25.csv` | 30 | Table 9.3 | 13th ICLS | Unemployment by province × region, 2020-21 vs 2024-25 |

Notes on the source files, kept as published:

- In the youth file the national row is labelled `Total` in the province
  column; the loader stores that raw value and uses `Pakistan` as the
  cleaned key.
- The age and education files carry the same group and year under both
  the 19th and 13th ICLS frameworks, with different values. Framework is
  part of the primary key in this warehouse so the two are never mixed
  silently.
- Youth counts are published to 0.1 million. Rates recomputed from those
  rounded counts differ slightly from the published rates (see Check 8 in
  `results/data_quality.md`); published rates are used everywhere else.
