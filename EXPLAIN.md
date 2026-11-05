# EXPLAIN.md — How to explain this project

A plain-words guide. Read this before an interview, or before showing the
project to anyone. Every hard word is explained the first time it appears.

## The files

### README.md

What it does: the front page of the project. It says what the project is,
what it proves, how to run it, what it found, and where the data came
from. Why it exists: it is the first thing a recruiter reads. It must make
sense on its own, without opening any other file.
Say it like this: "The README is the shop window — it tells you what the
project is, what I found, and how to run it in one command."

### sql/01_schema.sql

What it does: makes all the tables — 7 dimension tables (the labels) and
7 fact tables (the numbers) — plus an index on every join key and one
wide view called `v_yearly_wide`. Why it exists: the shape of the tables
decides how easy the questions are. This file is the design of the whole
warehouse.
Say it like this: "This file is the design. I shaped the data as a star
schema — facts in the middle, labels around them — so every question is
one simple query, and I indexed every join key like a real warehouse
would."

### sql/02_data_quality.sql

What it does: 12 checks on the loaded data — missing values, double
rows, numbers out of range, broken links, and checks that show the quirks
of real published data (rounding, two counting rules). Why it exists: to
prove the data is clean before any question is asked. A finding means
nothing if the data behind it is broken.
Say it like this: "Before I trusted any number, I checked the data in SQL
— no missing values, no duplicates, no broken links — and I wrote down
the quirks I found instead of hiding them."

### sql/03_analysis.sql

What it does: 11 questions, one query each, about jobs in Pakistan —
which province is worst, the youth gap, the gender gap, NEET, cities
versus villages, and more. Why it exists: this is the showcase. Each
query is one real question, written so a beginner can read it.
Say it like this: "This file is the work itself — eleven real questions,
one query each, and every answer is saved as a file in results."

### sql/04_warehouse_views.sql

What it does: makes 3 views — saved queries that act like tables. One is
a one-row-per-province summary; two are year-by-year trends. Why it
exists: in real work, reports and dashboards read views, not raw tables.
These three are the ones a report would use.
Say it like this: "These are the ready-made answers — a province summary
and two trend views — the kind of thing a dashboard would read."

### load_data.py

What it does: reads the seven CSV files in `data/` and loads them into
the database — it makes the tables from `01_schema.sql`, then fills them
row by row. It deletes the old database first, so every build starts
clean. Why it exists: loading data by hand would be slow and full of
typos. This script does it the same way every time.
Say it like this: "This script loads the data. It reads the CSV files,
cleans the labels — like turning the national row's 'Total' into
'Pakistan' — and puts everything in the database. No number was typed by
hand."

### run_queries.py

What it does: runs the check file and the question file, and saves every
output — the checks as a Markdown table, each question as one CSV file,
and the three views as Markdown. Why it exists: results must come from
running the SQL, not from typing numbers into files. This script is the
proof of that.
Say it like this: "This script runs the SQL and saves the answers. Nothing
in the results folder was typed by hand — it all came out of the database."

### build.sh

What it does: one command that does everything — deletes the old
database, runs `load_data.py`, then runs `run_queries.py`, then runs
`verify.py` to check the numbers. Why it exists:
so anyone can rebuild the whole project from scratch with one command
and get the same results.
Say it like this: "One command rebuilds everything from scratch. If you
run it, you get the same database and the same results I got."

### verify.py

What it does: opens the finished database and checks the 7 headline
numbers and the row counts (70 dimension rows, 334 fact rows) against
the values checked from the source files. Each check prints PASS or
FAIL. If any check fails, it exits with an error, so the build fails
too. Why it exists: so "the numbers are right" is something you can
prove by running one command, not something anyone has to take on trust.
Say it like this: "This script re-checks the seven headline numbers and
the row counts after every build. If any number is wrong, the build
fails instead of passing quietly."

### app.py

What it does: a small Streamlit dashboard that shows the same 10
findings from the README as charts and tables. It only reads the result
files in `results/` — it never types in a number. Why it exists: so a
recruiter can see the findings at a glance instead of opening CSV
files one by one.
Say it like this: "This is the dashboard. It reads the query results
and draws them as charts — same numbers as the README, just visible."

### requirements.txt

What it does: lists the three Python packages the dashboard needs —
Streamlit, pandas, numpy — pinned to the exact versions this project
was built and checked with. Install with `pip install -r
requirements.txt`. Why it exists: so anyone who clones the repo gets
the same working setup, with no guessing which versions to install.
Say it like this: "This file is the shopping list for the dashboard.
One command installs everything it needs."

## The queries

### Q1 — Which province has the highest unemployment?

What it does: reads the province table for 2024-25 and sorts it from
highest to lowest. Why it exists: it is the simplest question in the
project, and its answer is the headline finding — KP is highest at 9.6%.
Say it like this: "I joined the province fact table to the province
labels, filtered to 2024-25, and ordered by unemployment. KP came out
highest at 9.6 percent."

### Q2 — How does youth unemployment differ by province and sex?

What it does: shows youth unemployment (ages 15–24) for every province,
split into total, male and female. Why it exists: the national number
hides the real story — young women in KP face 25.6%.
Say it like this: "Same idea as Q1, but for young people and split by
sex. That is where the worst number in the whole project shows up — 25.6
percent for young women in KP."

### Q3 — How much higher is youth unemployment than overall unemployment, year by year?

What it does: for each year from 1991 to 2025, it shows youth
unemployment, total unemployment, and the gap between them. It reads the
wide view, so it is just two columns minus each other. Why it exists: the
gap is the heart of the youth-unemployment story.
Say it like this: "I read the wide view, one row per year, and took youth
minus total. In 2025 the gap was 4.2 points — young people are hit much
harder than the workforce as a whole."

### Q4 — What is the trend by decade?

What it does: groups the 35 years into four decades and averages youth
and total unemployment in each. Why it exists: one number per decade
shows the long story at a glance — about 1% in the 1990s, about 10% in
the 2020s.
Say it like this: "I grouped the years into decades with a CASE and
averaged. Youth unemployment averaged about 1 percent in the 1990s and
about 10 percent in the 2020s."

### Q5 — Is the gender gap in youth unemployment growing?

What it does: for each year, it shows male youth unemployment, female
youth unemployment, and female minus male. Why it exists: the gap is not
a fixed rule — it peaked in 2020 and even flipped in 2012 — and this
query shows that year by year.
Say it like this: "Female minus male, year by year, from the wide view.
The gap peaked at 4.5 points in 2020, but in 2012 it was the other way
round — so I never claim it is constant."

### Q6 — In which years did youth unemployment jump the most?

What it does: uses `LAG()` — a window function, which means a function
that looks at other rows — to take last year's value, then shows this
year minus last year, biggest jump first. Why it exists: it finds the
2012 jump of +5.8 points, which is the series break the README warns
about.
Say it like this: "I used LAG to get the previous year's value and
subtracted it. The biggest jump was 2012, plus 5.8 points — and I flagged
it as a break in the series, not a real sudden rise."

### Q7 — Does more education mean more unemployment?

What it does: shows unemployment by education level for 2024-25, ordered
from no education up to a master's degree. Why it exists: the answer
surprises people — unemployment rises with schooling, up to 12.6% at
Intermediate level.
Say it like this: "I joined the education fact table to its labels and
ordered by the sort column. Unemployment rises with education — 4.7
percent with no schooling, 12.6 at Intermediate."

### Q8 — Did NEET fall or rise?

What it does: a self-join — the same NEET table used twice, once for
2020-21 and once for 2024-25, matched on province — to show the change.
NEET means youth not in employment, education or training. Why it
exists: it shows a real improvement (32.5% down to 28.4%) next to a real
problem (female NEET is 3.5 times male NEET).
Say it like this: "I joined the NEET table to itself, one side per year,
to get the change. NEET fell everywhere, but female NEET is still 45.4
percent against 13 for men."

### Q9 — Is unemployment higher in cities or villages?

What it does: another self-join — the province-by-region table used twice,
once for rural and once for urban — to show the gap. Why it exists: cities
are worse than villages in every province, which is the opposite of what
many people expect.
Say it like this: "Same self-join trick as Q8, rural on one side, urban on
the other. Urban is higher everywhere — 8 percent against 6.3 nationally."

### Q10 — In which years was youth unemployment above 10%?

What it does: reads the wide view and keeps only the years where youth
unemployment is above 10, showing GDP per person next to it. Why it
exists: the answer is short and sharp — only 2020 and 2021.
Say it like this: "I filtered the wide view to youth unemployment above
10 percent. Only two years qualify — 2020 and 2021."

### Q11 — Are more people joining the labour force, or fewer?

What it does: shows the labour-force participation rate — the share of
people aged 15 and over who are working or looking for work — year by
year, with the change from last year using `LAG()`. Why it exists: the
participation rate was loaded but never asked about, so this query uses
the last unused number in the data. The answer is plain: mostly flat,
49.7% in 1991 to 52.3% in 2025.
Say it like this: "I used LAG on the participation rate. It barely moved
in 35 years — up only 2.7 points — so I said so plainly instead of
inventing a story."

## The views

### v_yearly_wide (in 01_schema.sql)

What it does: turns the long yearly table into one row per year, with one
column per number — youth, male youth, female youth, total, participation
rate, GDP per person. Why it exists: the pivot (MAX with CASE WHEN) used
to sit inside four different queries. Now it sits here, once, and the
queries read plain columns.
Say it like this: "The yearly table is stored long, which is good for
loading but awkward for year-by-year questions. This view pivots it once,
so Q3, Q5, Q10 and Q11 stay short and easy to read."

### v_province_summary (in 04_warehouse_views.sql)

What it does: one row per province for 2024-25, joining overall
unemployment, youth unemployment, female youth unemployment and NEET
into a single line. Why it exists: it is the one table a report would
print first — the whole province story in five rows.
Say it like this: "This view joins three fact tables on the province key
into one summary row per province — the table a report would show first."

### v_youth_trend (in 04_warehouse_views.sql)

What it does: year by year, youth unemployment, total unemployment, the
gap between them, and the change from last year. Why it exists: it is the
trend a dashboard would draw as a line chart.
Say it like this: "This view is the youth trend in one place — the level,
the gap to total unemployment, and the year-on-year change."

### v_gender_gap (in 04_warehouse_views.sql)

What it does: year by year, male youth unemployment, female youth
unemployment, and the gap. Why it exists: it is the gender story in one
place, ready for a chart.
Say it like this: "This view is the gender gap in youth unemployment,
year by year — female minus male, straight from the wide view."
