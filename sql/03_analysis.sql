-- ============================================================================
-- 03_analysis.sql — The showcase: one real question per query
-- ============================================================================
-- Every query answers exactly one question, in plain SQL a beginner can
-- read: SELECT the columns you want, FROM the table or view, WHERE to
-- filter, GROUP BY / ORDER BY to shape it.
-- Queries about one year at a time (Q3, Q5, Q10, Q11) read the wide view
-- v_yearly_wide from 01_schema.sql — one row per year, one column per
-- indicator — so they stay short and easy to explain. The pivot lives in
-- the view, not in every query.
-- Window functions (LAG) appear in Q6 and Q11 and are explained where
-- they are used.
--
-- Run:  sqlite3 labour_warehouse.db < sql/03_analysis.sql
-- (run_queries.py runs this file and saves one CSV per query to results/)
-- ============================================================================

-- Q1 — Which province has the highest unemployment? (PBS LFS 2024-25, Table 9.2, 19th ICLS)
SELECT p.province_name AS province,
       f.unemployment_total AS unemployment_pct,
       f.unemployment_male AS male_pct,
       f.unemployment_female AS female_pct
FROM fact_pbs_province f
JOIN dim_province p ON p.province_key = f.province_key
WHERE f.year_label = '2024-25'
ORDER BY f.unemployment_total DESC;

-- Q2 — How does youth (15-24) unemployment differ by province and sex? (PBS LFS 2024-25, Table 8.7)
SELECT p.province_name AS province,
       f.sex_key AS sex,
       f.unemployment_rate AS youth_unemployment_pct,
       f.lfpr AS youth_lfpr_pct,
       f.youth_population_million AS youth_population_millions
FROM fact_pbs_youth f
JOIN dim_province p ON p.province_key = f.province_key
ORDER BY p.is_national DESC, f.unemployment_rate DESC, f.sex_key;

-- Q3 — How much higher is youth unemployment than overall unemployment, year by year? (World Bank, 1991-2025)
-- Reads the wide view, so no pivot is needed here: one row per year,
-- one column per indicator. The gap is youth minus total.
SELECT year,
       ROUND(youth_unemployment_pct, 3) AS youth_unemployment_pct,
       ROUND(total_unemployment_pct, 3) AS total_unemployment_pct,
       ROUND(youth_unemployment_pct - total_unemployment_pct, 3)
           AS youth_minus_total_gap_pp
FROM v_yearly_wide
ORDER BY year;

-- Q4 — What is the trend by decade? Average youth and total unemployment per decade (World Bank, 1991-2025)
SELECT CASE
           WHEN CAST(f.year_label AS INTEGER) BETWEEN 1991 AND 1999 THEN '1991-1999'
           WHEN CAST(f.year_label AS INTEGER) BETWEEN 2000 AND 2009 THEN '2000-2009'
           WHEN CAST(f.year_label AS INTEGER) BETWEEN 2010 AND 2019 THEN '2010-2019'
           ELSE '2020-2025'
       END AS decade,
       COUNT(DISTINCT f.year_label) AS years_in_decade,
       ROUND(AVG(CASE WHEN f.indicator_key = 'youth_unemp_total' THEN f.value END), 2)
           AS avg_youth_unemployment_pct,
       ROUND(AVG(CASE WHEN f.indicator_key = 'unemp_total' THEN f.value END), 2)
           AS avg_total_unemployment_pct,
       ROUND(MIN(CASE WHEN f.indicator_key = 'youth_unemp_total' THEN f.value END), 2)
           AS lowest_youth_pct,
       ROUND(MAX(CASE WHEN f.indicator_key = 'youth_unemp_total' THEN f.value END), 2)
           AS highest_youth_pct
FROM fact_labour_yearly f
GROUP BY decade
ORDER BY decade;

-- Q5 — Is the gender gap in youth unemployment growing? Female minus male, year by year (World Bank, 1991-2025)
-- Reads the wide view: the gap is the female column minus the male column.
SELECT year,
       ROUND(youth_unemployment_male_pct, 3) AS male_youth_pct,
       ROUND(youth_unemployment_female_pct, 3) AS female_youth_pct,
       ROUND(youth_unemployment_female_pct - youth_unemployment_male_pct, 3)
           AS female_minus_male_gap_pp
FROM v_yearly_wide
ORDER BY year;

-- Q6 — In which years did youth unemployment jump the most? Year-over-year change (World Bank, 1991-2025)
-- LAG(value) OVER (ORDER BY year) means "the value from the previous row",
-- so change = this year minus last year. Ordered biggest jump first.
WITH yearly AS (
    SELECT CAST(f.year_label AS INTEGER) AS year,
           MAX(CASE WHEN f.indicator_key = 'youth_unemp_total' THEN f.value END)
               AS youth_pct
    FROM fact_labour_yearly f
    GROUP BY f.year_label
)
SELECT year,
       ROUND(youth_pct, 3) AS youth_unemployment_pct,
       ROUND(youth_pct - LAG(youth_pct) OVER (ORDER BY year), 3)
           AS change_vs_previous_year_pp
FROM yearly
WHERE year > 1991
ORDER BY change_vs_previous_year_pp DESC;

-- Q7 — Does more education mean more unemployment? Unemployment by education level, 2024-25 (PBS, Table 9.7, 19th ICLS)
SELECT e.education_level,
       f.unemployment_total AS unemployment_pct,
       f.unemployment_male AS male_pct,
       f.unemployment_female AS female_pct
FROM fact_pbs_education f
JOIN dim_education e ON e.education_level = f.education_level
WHERE f.year_label = '2024-25' AND f.framework = '19th ICLS'
ORDER BY e.sort_order;

-- Q8 — Did NEET fall or rise? NEET rate change by province, 2020-21 to 2024-25 (PBS, Table 8.8, all areas)
-- A self-join: the same table twice, once per year, matched on province.
SELECT n24.province_key AS province,
       n20.neet_total AS neet_2020_21_pct,
       n24.neet_total AS neet_2024_25_pct,
       ROUND(n24.neet_total - n20.neet_total, 1) AS change_pp,
       n24.neet_female AS female_neet_2024_25_pct,
       n24.neet_male AS male_neet_2024_25_pct
FROM fact_pbs_neet n24
JOIN fact_pbs_neet n20
  ON n20.province_key = n24.province_key
 AND n20.region_key = n24.region_key
WHERE n24.year_label = '2024-25' AND n20.year_label = '2020-21'
  AND n24.region_key = 'All Areas'
ORDER BY change_pp;

-- Q9 — Is unemployment higher in cities or villages? Rural vs urban, 2024-25 (PBS, Table 9.3, 13th ICLS)
SELECT r.province_key AS province,
       r.unemployment_total AS rural_pct,
       u.unemployment_total AS urban_pct,
       ROUND(u.unemployment_total - r.unemployment_total, 1) AS urban_minus_rural_pp,
       u.unemployment_female AS urban_female_pct
FROM fact_pbs_province_region r
JOIN fact_pbs_province_region u
  ON u.province_key = r.province_key
 AND u.year_label = r.year_label
WHERE r.year_label = '2024-25'
  AND r.region_key = 'Rural'
  AND u.region_key = 'Urban'
ORDER BY urban_minus_rural_pp DESC;

-- Q10 — In which years was youth unemployment above 10%? (World Bank, 1991-2025)
-- Reads the wide view and keeps only the years where the youth column
-- is above 10. GDP per person is shown next to it for context.
SELECT year,
       ROUND(youth_unemployment_pct, 3) AS youth_unemployment_pct,
       ROUND(total_unemployment_pct, 3) AS total_unemployment_pct,
       ROUND(gdp_per_capita_usd, 0) AS gdp_per_capita_usd
FROM v_yearly_wide
WHERE youth_unemployment_pct > 10
ORDER BY year;

-- Q11 — Are more people joining the labour force, or fewer? Labour-force participation rate, 1991-2025 (World Bank)
-- The participation rate is the share of people aged 15 and over who are
-- in the labour force — working, or looking for work. LAG() takes last
-- year's value, so the change column is this year minus last year.
-- (The first year, 1991, has no previous year, so its change is empty.)
SELECT year,
       ROUND(lfpr_pct, 2) AS lfpr_pct,
       ROUND(lfpr_pct - LAG(lfpr_pct) OVER (ORDER BY year), 2)
           AS change_vs_previous_year_pp
FROM v_yearly_wide
ORDER BY year;
