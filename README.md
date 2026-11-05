# Pakistan Labour Data Warehouse
**Live dashboard:** https://sql-pakistanis-labour-warehouse-jnylqffa6jrsjzlkwzmqmk.streamlit.app/

A small SQL project built on real, published data about work in Pakistan.
It uses two public sources: World Bank yearly numbers (1991–2025) and the
Pakistan Bureau of Statistics Labour Force Survey 2024-25. Every number in
this project comes from those two sources. Every result in `results/` was
made by running the SQL in `sql/` — nothing was typed in by hand.

## What is this?

Think of it like a small, tidy store room for numbers.

- The numbers live in **fact tables**. A fact table holds measurements,
  like "youth unemployment in KP was 15.4%".
- The labels live in **dimension tables**. A dimension table holds names,
  like "KP means Khyber Pakhtunkhwa" or "1991 is a year".
- This shape is called a **star schema**: fact tables in the middle,
  dimension tables around them, like points of a star. It makes questions
  easy to ask in SQL.

The project loads the data, checks it for mistakes, and answers 11 real
questions about jobs and unemployment in Pakistan.

## What does it prove?

- **Database design.** 7 dimension tables and 7 fact tables, with
  foreign keys (links that stop a fact row pointing at a label that does
  not exist) and indexes on every join key (an index is like the index at
  the back of a book — it helps the database find rows fast).
- **Loading data (ETL).** `load_data.py` reads the seven source files and
  loads them with Python. ETL means "extract, transform, load": take the
  data out of files, clean it, put it in the database. No number was typed
  in by hand anywhere.
- **Checking data in SQL.** 12 checks (`sql/02_data_quality.sql`): missing
  values, double rows, numbers out of range, broken links, plus checks
  that catch the quirks of real published data (rounding, and two
  different counting rules).
- **Analysis SQL.** 11 questions, one query each (`sql/03_analysis.sql`):
  grouping, pivots, self-joins, and the `LAG()` window function (LAG
  means "the value from the row before this one").
- **Views.** 4 ready-made views (`sql/01_schema.sql` and
  `sql/04_warehouse_views.sql`) that a report or dashboard would read.
  A view is a saved query: it looks like a table, but it always shows the
  newest data.
- **A build you can repeat.** One command rebuilds the database and every
  result from scratch. The database file itself is never saved in the
  project — it is rebuilt every time.
- **A dashboard you can see.** `app.py` shows the same 10 findings as
  charts and tables, drawn from the result files. It is a Streamlit app:
  it runs on your own computer, and putting it on the internet is a
  separate step for later.
- **A check that proves the numbers.** `verify.py` opens the finished
  database and checks the 7 headline numbers and the row counts. If any
  number is wrong, the build fails.

## How to run it

You need Python 3 and the `sqlite3` command-line tool. Nothing to
install, no server to run.

```bash
bash build.sh            # rebuild the database and all results from scratch
sqlite3 labour_warehouse.db
sqlite> SELECT * FROM v_province_summary;
```

To run one step by hand:

```bash
sqlite3 labour_warehouse.db < sql/01_schema.sql      # make the tables
python3 load_data.py                                  # load the files
sqlite3 labour_warehouse.db < sql/02_data_quality.sql # run the checks
sqlite3 labour_warehouse.db < sql/03_analysis.sql     # run the questions
sqlite3 labour_warehouse.db < sql/04_warehouse_views.sql
python3 verify.py                                     # check the numbers
```

`build.sh` runs `verify.py` as its last step, so one command builds the
whole project and proves the numbers at the end.

## See it as a dashboard

```bash
pip install -r requirements.txt
streamlit run app.py
```

This opens the dashboard in your browser: the same 10 findings below,
as charts and tables. Every chart is drawn from the files in `results/`.
Putting the dashboard on the internet (Streamlit Cloud) is a separate
step for later, after this project is on GitHub — nothing is deployed
from here.

New to this project? Read `EXPLAIN.md` next. It explains every file and
every query in plain words, and how to talk about each one in an
interview.

## What did I find?

All numbers below come from the queries in `sql/03_analysis.sql`.
The full outputs are in `results/`.

1. **KP has the highest unemployment in Pakistan.** Overall 9.6%, while
   the country as a whole is 7.1%. Youth (ages 15–24) in KP is 15.4%,
   while the country is 12.8%. Young women in KP face 25.6% youth
   unemployment — the highest rate in the country.
   ([q01](results/q01_province_unemployment_ranking.csv),
   [q02](results/q02_youth_by_province_and_sex.csv))
2. **Youth unemployment is much higher than overall unemployment.** In
   2025 the World Bank series has youth at 9.6% and overall at 5.4% —
   a gap of 4.2 points. The gap was biggest in 2019, at 4.8 points.
   ([q03](results/q03_youth_vs_total_gap_by_year.csv))
3. **The long view has a break in it.** Youth unemployment was about 1%
   in the 1990s and 2000s in the modelled series, and about 10% in
   2020–2025. The biggest one-year jump was in 2012 (+5.8 points). That
   jump is in the modelled series — treat it as a break in the series to
   look into, not as proof that unemployment suddenly rose that year.
   One more check on that jump: the same year reads differently in
   different releases of the same data. In the ILOSTAT data as retrieved
   in December 2019, youth unemployment for 2012 was 3.90%; in the data
   retrieved in October 2026, the same year reads 7.556% — while the
   years around it agree closely (2011: 1.75% vs 1.72%; 2013: 6.07% vs
   5.98%). So the size of the jump itself changed when the model was
   re-run. That is why it stays labelled as a break in the modelled
   series, not a real event. (Source: IndexMundi, ILOSTAT data retrieved
   December 2019 — https://www.indexmundi.com/facts/pakistan/indicator/SL.UEM.1524.ZS)
   This project cannot say why the model changed the number. The data
   files do not record how the model works or what changed in it. To
   explain it, someone would need the ILO's method notes for the two
   model runs, or the survey data behind them.
   ([q04](results/q04_trend_by_decade.csv),
   [q06](results/q06_yoy_change_ranked.csv))
4. **Only two years went above 10%.** Youth unemployment passed 10% in
   2020 (10.7%) and 2021 (11.1%) — and in no other year since 1991.
   ([q10](results/q10_years_youth_above_10pct.csv))
5. **The gender gap is real, but it has flipped before.** In 2025 young
   women faced 10.1% unemployment and young men 9.4%. The gap was
   biggest in 2020 (+4.5 points). But in 2012 the female rate was 4.1
   points *lower* than the male rate — so the gap is not a fixed rule.
   ([q05](results/q05_gender_gap_by_year.csv))
6. **More schooling, more unemployment — up to a point.** In 2024-25
   unemployment rises with education up to Intermediate level: 4.7%
   with no education, 12.6% at Intermediate. After that it falls a
   little: 10.9% for degree holders. Young women with a degree face
   24.1%.
   ([q07](results/q07_education_gradient.csv))
7. **NEET fell everywhere — but the gender gap is huge.** NEET means
   youth not in employment, education or training. It fell from 32.5%
   (2020-21) to 28.4% (2024-25) for the whole country, and in every
   province. But female NEET (45.4%) is still 3.5 times male NEET
   (13.0%).
   ([q08](results/q08_neet_change_by_province.csv))
8. **Cities have higher unemployment than villages.** In 2024-25 urban
   unemployment (8.0%) is higher than rural (6.3%) for the whole
   country, and in every province. Urban women in Balochistan face
   29.4%.
   ([q09](results/q09_rural_vs_urban.csv))
9. **Two sources, two answers.** The World Bank estimate for 2025 puts
   total unemployment at 5.4%. The PBS survey puts 2024-25 at 7.1%.
   Both are fair — they measure different things in different ways — and
   this project labels them everywhere and never mixes them.
10. **The share of people in work barely moved.** The labour-force
    participation rate — the share of people aged 15 and over who are
    working or looking for work — was 49.7% in 1991 and 52.3% in 2025.
    That is up only 2.7 points in 35 years. The lowest year was 1995
    (48.4%), the highest was 2021 (52.7%). No big jumps: the largest
    one-year move was +1.1 points in 2021. Mostly flat.
    ([q11](results/q11_lfpr_trend.csv))

## What is inside

```
.
├── README.md                 this file
├── EXPLAIN.md                plain-words guide: every file, every query
├── LICENSE                   MIT
├── build.sh                  one-command rebuild (database + results)
├── load_data.py              loads the files into the database
├── run_queries.py            runs the SQL files, writes results/
├── verify.py                 checks the 7 headline numbers + row counts
├── app.py                    Streamlit dashboard (charts of the 10 findings)
├── requirements.txt          what the dashboard needs (streamlit, pandas, numpy)
├── labour_warehouse.db       built by build.sh — not saved in the project
├── data/                     the seven source files (public data, see below)
│   └── SOURCES.md            where every file came from
├── sql/
│   ├── 01_schema.sql         tables: 7 dimensions, 7 facts, indexes, 1 view
│   ├── 02_data_quality.sql   12 cleaning / checking queries
│   ├── 03_analysis.sql       11 questions, one query each
│   └── 04_warehouse_views.sql  3 views (province summary, trends, gender gap)
└── results/                  output made by running the SQL — never typed by hand
    ├── data_quality.md       output of all 12 checks
    ├── q01_...q11_*.csv      one file per question
    └── views.md              what the three views hold
```

## The tables, in plain words

```
dim_year ──┐
dim_province ─┤
dim_indicator ├─► fact_labour_yearly        210 rows (35 years × 6 numbers)
dim_sex ──────┤
dim_age_group ┤──► fact_pbs_age              26 rows
dim_education ┤──► fact_pbs_education        18 rows
dim_region ───┤──► fact_pbs_neet             30 rows
              ├──► fact_pbs_province          5 rows
              ├──► fact_pbs_youth            15 rows
              └──► fact_pbs_province_region  30 rows
```

- **Dimensions** hold the labels: years (37 — 1991–2025 plus the survey
  years 2020-21 and 2024-25), provinces (5), indicators (6), sex (3),
  age groups (9), education levels (6), regions (4). 70 rows in total.
- **Facts** hold the numbers. The World Bank panel is stored **long**
  (one row per year per number). Long means: one row for "1991, youth
  unemployment, 0.82", another row for "1991, total unemployment, 0.4",
  and so on. Long tables are easy to query: an average by decade is one
  `GROUP BY`. 334 fact rows in total. A wide view (`v_yearly_wide`, one
  row per year, one column per number) is built on top for the questions
  that need it.
- The PBS youth file calls the national row `Total`. The loader keeps
  that raw word in `province_raw` and stores the clean key `Pakistan`
  in `province_key`, so joins work and nothing is hidden.

## How the data was checked

`sql/02_data_quality.sql` runs 12 checks. The output is in
[results/data_quality.md](results/data_quality.md). What it found:

- **Clean load:** 0 missing values in any number column, 0 double rows,
  0 numbers out of range, 0 broken links (every fact row matches a
  dimension row), 35 years present, 1991–2025, all 6 numbers each year.
- **Provinces add up:** the four provinces' youth populations add to
  46.3 million, exactly the published national number.
- **Rounding is shown, not hidden:** employed + unemployed differs from
  the published labour force by at most 0.1 million (PBS rounds to
  0.1m). Working out the youth rate again from the rounded counts moves
  it by up to 1.6 points for Balochistan, whose youth labour force is
  only about 1.0 million. Published rates are used everywhere; worked-out
  ones are shown only in the check.
- **Counting rules must not be mixed:** the same age group in the same
  year scores differently under the 19th and 13th ICLS (ICLS is the
  international rulebook for how to count work — the 19th and 13th are
  two versions of it). For ages 15–24 in 2024-25: 12.8% vs 12.5%. The
  rule is part of the key, so a query can never mix them without saying
  so.

## Data sources

| Data | Source | Tables used |
|---|---|---|
| Yearly numbers 1991–2025 | World Bank Open Data, ILO modelled estimates — [data.worldbank.org](https://data.worldbank.org/) | SL.UEM.1524.ZS, SL.UEM.1524.MA.ZS, SL.UEM.1524.FE.ZS, SL.UEM.TOTL.ZS, SL.TLF.CACT.ZS, NY.GDP.PCAP.CD |
| Province / youth / age / education / NEET / region | PBS Labour Force Survey 2024-25 (37th round) — [pbs.gov.pk](https://www.pbs.gov.pk/) | Tables 9.2, 8.7, 9.4, 9.5, 9.6, 9.7, 9.8, 8.8, 9.3 |

Full detail, including the exact files and what each column means, is in
[data/SOURCES.md](data/SOURCES.md). The files in `data/` are copies of
the published tables as written down in the author's research project
([pakistan-youth-unemployment-forecasting](https://github.com/AwaisAhmed183/pakistan-youth-unemployment-forecasting)).

## Honest limits

- **Small panel.** The yearly series is 35 rows. That is enough to show
  SQL skill and real findings, not enough for serious forecasting.
- **Modelled, not counted.** The World Bank unemployment and participation
  numbers are ILO modelled estimates. "Modelled" means they are worked
  out from a model, not counted person by person. Values near 1% in the
  early 1990s come from a time when measurement was very different, and
  they are not easy to compare with recent decades.
- **Two instruments.** World Bank modelled estimates and the PBS survey
  answer the same question differently (2025: 5.4% vs 7.1%). This project
  reports both, labelled, and never averages them.
- **Rounded counts.** PBS youth counts are published to 0.1 million, so
  rates worked out from them differ a little from the published rates
  (see Check 8).
- **One survey round.** The PBS detail is a single round (2024-25) plus
  2020-21 for change over time. It is a snapshot with one comparison
  point, not a long series.

## About

Built by Awais Ahmed Shah, final-year BS Data Science student at UET
Peshawar, as a portfolio project for data analyst roles: real public
data, real SQL, results anyone can check. If a number here is wrong, it
is wrong in the open — every result traces back to a query in `sql/` and
a file in `data/`.
