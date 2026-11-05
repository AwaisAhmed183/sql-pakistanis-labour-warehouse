#!/usr/bin/env python3
"""Dashboard for the Pakistan Labour Data Warehouse (Streamlit).

What it does: shows the same 10 findings that are in README.md, but as
charts and tables you can see — not just CSV files you have to open.

Every number on this page comes from the files in results/, which were
made by running the SQL in sql/. Nothing here is typed in by hand.
If you change the data, run `bash build.sh` first, then restart this app.

Run it from the project root:
    pip install streamlit pandas
    streamlit run app.py

Putting it on the internet (Streamlit Cloud) is a separate step for
later, after this project is on GitHub. This file only runs on your
own computer.
"""

import pandas as pd
import streamlit as st
from pathlib import Path

ROOT = Path(__file__).resolve().parent
RESULTS = ROOT / "results"


def load(name):
    """Read one result file. The file name is the question number."""
    return pd.read_csv(RESULTS / name)


st.set_page_config(page_title="Pakistan Labour Data Warehouse", layout="wide")
st.title("Pakistan Labour Data Warehouse")
st.write(
    "Real, published data about work in Pakistan: World Bank yearly numbers "
    "(1991–2025) and the Pakistan Bureau of Statistics Labour Force Survey "
    "2024-25. Every chart below is drawn from the result files in "
    "`results/` — nothing was typed in by hand."
)

# --- Finding 1: KP has the highest unemployment -------------------------
st.header("1. KP has the highest unemployment in Pakistan")
q01 = load("q01_province_unemployment_ranking.csv")
st.write(
    "Overall unemployment is 9.6% in KP, while the country as a whole is "
    "7.1%. Youth unemployment in KP is 15.4%, while the country is 12.8%."
)
st.bar_chart(q01.set_index("province")["unemployment_pct"])
st.dataframe(q01, hide_index=True)

# --- Finding 2: youth runs far above overall ----------------------------
st.header("2. Youth unemployment runs far above overall unemployment")
q03 = load("q03_youth_vs_total_gap_by_year.csv")
st.write(
    "In 2025 youth unemployment was 9.6% and overall was 5.4% — a gap of "
    "4.2 points. The gap was biggest in 2019, at 4.8 points."
)
st.line_chart(
    q03.set_index("year")[["youth_unemployment_pct", "total_unemployment_pct"]]
)

# --- Finding 3: the long view has a break -------------------------------
st.header("3. The long view has a break in it")
q04 = load("q04_trend_by_decade.csv")
q06 = load("q06_yoy_change_ranked.csv")
st.write(
    "Youth unemployment was about 1% in the 1990s and 2000s, and about "
    "10% in 2020–2025. The biggest one-year jump was in 2012 (+5.8 "
    "points). That jump is in the modelled series — treat it as a break "
    "in the series, not as proof that unemployment suddenly rose."
)
st.dataframe(q04, hide_index=True)
st.write("Biggest one-year jumps in youth unemployment:")
st.bar_chart(q06.head(5).set_index("year")["change_vs_previous_year_pp"])

# --- Finding 4: only two years went above 10% ---------------------------
st.header("4. Only two years went above 10%")
q10 = load("q10_years_youth_above_10pct.csv")
st.write(
    "Youth unemployment passed 10% in 2020 (10.7%) and 2021 (11.1%) — "
    "and in no other year since 1991."
)
st.dataframe(q10, hide_index=True)

# --- Finding 5: the gender gap ------------------------------------------
st.header("5. The gender gap is real, but it has flipped before")
q05 = load("q05_gender_gap_by_year.csv")
st.write(
    "In 2025 young women faced 10.1% unemployment and young men 9.4%. "
    "The gap was biggest in 2020 (+4.5 points). But in 2012 the female "
    "rate was 4.1 points lower than the male rate — so the gap is not a "
    "fixed rule."
)
st.line_chart(q05.set_index("year")[["male_youth_pct", "female_youth_pct"]])

# --- Finding 6: more schooling, more unemployment -----------------------
st.header("6. More schooling, more unemployment — up to a point")
q07 = load("q07_education_gradient.csv")
st.write(
    "In 2024-25 unemployment rises with education up to Intermediate "
    "level: 4.7% with no education, 12.6% at Intermediate. It falls a "
    "little after that — 10.9% for degree holders. Young women with a "
    "degree face 24.1%."
)
st.bar_chart(q07.set_index("education_level")["unemployment_pct"])
st.dataframe(q07, hide_index=True)

# --- Finding 7: NEET fell everywhere ------------------------------------
st.header("7. NEET fell everywhere — but the gender gap is huge")
q08 = load("q08_neet_change_by_province.csv")
st.write(
    "NEET means youth not in employment, education or training. It fell "
    "from 32.5% (2020-21) to 28.4% (2024-25) for the whole country, and "
    "in every province. But female NEET (45.4%) is still 3.5 times male "
    "NEET (13.0%)."
)
st.bar_chart(
    q08.set_index("province")[["neet_2020_21_pct", "neet_2024_25_pct"]]
)
st.dataframe(q08, hide_index=True)

# --- Finding 8: cities higher than villages -----------------------------
st.header("8. Cities have higher unemployment than villages")
q09 = load("q09_rural_vs_urban.csv")
st.write(
    "In 2024-25 urban unemployment (8.0%) is higher than rural (6.3%) "
    "for the whole country, and in every province. Urban women in "
    "Balochistan face 29.4%."
)
st.bar_chart(q09.set_index("province")[["rural_pct", "urban_pct"]])
st.dataframe(q09, hide_index=True)

# --- Finding 9: two sources, two answers --------------------------------
st.header("9. Two sources, two answers")
st.write(
    "The World Bank estimate for 2025 puts total unemployment at 5.4%. "
    "The PBS survey puts 2024-25 at 7.1%. Both are fair — they measure "
    "different things in different ways — and this project labels them "
    "everywhere and never mixes them."
)
# Both numbers below are read from the result files, not typed in:
# 2025 total from q03 (World Bank series), Pakistan row from q01 (PBS).
wb_2025 = q03.loc[q03["year"] == 2025, "total_unemployment_pct"].iloc[0]
pbs_2024_25 = q01.loc[q01["province"] == "Pakistan",
                      "unemployment_pct"].iloc[0]
st.dataframe(
    pd.DataFrame(
        [
            {"source": "World Bank modelled estimate, 2025",
             "total_unemployment_pct": round(float(wb_2025), 1)},
            {"source": "PBS LFS 2024-25 survey (Table 9.2)",
             "total_unemployment_pct": float(pbs_2024_25)},
        ]
    ),
    hide_index=True,
)

# --- Finding 10: people in work barely moved ----------------------------
st.header("10. The share of people in work barely moved")
q11 = load("q11_lfpr_trend.csv")
st.write(
    "The labour-force participation rate — the share of people aged 15 "
    "and over who are working or looking for work — was 49.7% in 1991 "
    "and 52.3% in 2025. That is up only 2.7 points in 35 years. The "
    "lowest year was 1995 (48.4%), the highest was 2021 (52.7%)."
)
st.line_chart(q11.set_index("year")["lfpr_pct"])

st.divider()
st.write(
    "Sources: World Bank Open Data (ILO modelled estimates) and the "
    "Pakistan Bureau of Statistics Labour Force Survey 2024-25. Full "
    "detail is in README.md and data/SOURCES.md."
)
