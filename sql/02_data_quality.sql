-- ============================================================================
-- 02_data_quality.sql — Cleaning and validation checks, all in SQL
-- ============================================================================
-- Every check returns rows that hold counts. A count of 0 means the
-- check passed. Checks that return rows on purpose (DQ6-DQ10, DQ12) are
-- labelled NOTE: they document real properties of the published data,
-- not errors.
--
-- Run:  sqlite3 labour_warehouse.db < sql/02_data_quality.sql
-- (run_queries.py runs this file and saves the output to
--  results/data_quality.md)
-- ============================================================================

-- CHECK 1: Row counts — did every file load completely?
-- Expected: dim_year 37, dim_province 5, dim_indicator 6, dim_sex 3,
-- dim_age_group 9, dim_education 6, dim_region 4,
-- fact_labour_yearly 210, fact_pbs_province 5, fact_pbs_youth 15,
-- fact_pbs_age 26, fact_pbs_education 18, fact_pbs_neet 30,
-- fact_pbs_province_region 30.
SELECT 'dim_year' AS table_name, COUNT(*) AS row_count FROM dim_year
UNION ALL SELECT 'dim_province', COUNT(*) FROM dim_province
UNION ALL SELECT 'dim_indicator', COUNT(*) FROM dim_indicator
UNION ALL SELECT 'dim_sex', COUNT(*) FROM dim_sex
UNION ALL SELECT 'dim_age_group', COUNT(*) FROM dim_age_group
UNION ALL SELECT 'dim_education', COUNT(*) FROM dim_education
UNION ALL SELECT 'dim_region', COUNT(*) FROM dim_region
UNION ALL SELECT 'fact_labour_yearly', COUNT(*) FROM fact_labour_yearly
UNION ALL SELECT 'fact_pbs_province', COUNT(*) FROM fact_pbs_province
UNION ALL SELECT 'fact_pbs_youth', COUNT(*) FROM fact_pbs_youth
UNION ALL SELECT 'fact_pbs_age', COUNT(*) FROM fact_pbs_age
UNION ALL SELECT 'fact_pbs_education', COUNT(*) FROM fact_pbs_education
UNION ALL SELECT 'fact_pbs_neet', COUNT(*) FROM fact_pbs_neet
UNION ALL SELECT 'fact_pbs_province_region', COUNT(*) FROM fact_pbs_province_region
ORDER BY table_name;

-- CHECK 2: NULLs in measure columns (expect 0 everywhere)
-- Every number in the source files was present, so every count below
-- must be 0.
SELECT 'fact_labour_yearly.value' AS column_name,
       COUNT(*) AS null_count FROM fact_labour_yearly WHERE value IS NULL
UNION ALL SELECT 'fact_pbs_province.unemployment_total',
       COUNT(*) FROM fact_pbs_province WHERE unemployment_total IS NULL
UNION ALL SELECT 'fact_pbs_province.unemployment_male',
       COUNT(*) FROM fact_pbs_province WHERE unemployment_male IS NULL
UNION ALL SELECT 'fact_pbs_province.unemployment_female',
       COUNT(*) FROM fact_pbs_province WHERE unemployment_female IS NULL
UNION ALL SELECT 'fact_pbs_youth.unemployment_rate',
       COUNT(*) FROM fact_pbs_youth WHERE unemployment_rate IS NULL
UNION ALL SELECT 'fact_pbs_youth.labour_force_million',
       COUNT(*) FROM fact_pbs_youth WHERE labour_force_million IS NULL
UNION ALL SELECT 'fact_pbs_youth.youth_population_million',
       COUNT(*) FROM fact_pbs_youth WHERE youth_population_million IS NULL
UNION ALL SELECT 'fact_pbs_age.unemployment_total',
       COUNT(*) FROM fact_pbs_age WHERE unemployment_total IS NULL
UNION ALL SELECT 'fact_pbs_education.unemployment_total',
       COUNT(*) FROM fact_pbs_education WHERE unemployment_total IS NULL
UNION ALL SELECT 'fact_pbs_neet.neet_total',
       COUNT(*) FROM fact_pbs_neet WHERE neet_total IS NULL
UNION ALL SELECT 'fact_pbs_province_region.unemployment_total',
       COUNT(*) FROM fact_pbs_province_region WHERE unemployment_total IS NULL
ORDER BY column_name;

-- CHECK 3: Duplicate keys (expect 0 everywhere)
-- Each fact table has a primary key, so a duplicate would have failed the
-- load — this proves it independently.
SELECT 'fact_labour_yearly' AS table_name,
       COUNT(*) AS duplicate_keys
FROM (SELECT year_label, indicator_key, COUNT(*) AS n
      FROM fact_labour_yearly GROUP BY year_label, indicator_key HAVING n > 1)
UNION ALL SELECT 'fact_pbs_province', COUNT(*)
FROM (SELECT province_key, year_label, framework, COUNT(*) AS n
      FROM fact_pbs_province GROUP BY province_key, year_label, framework HAVING n > 1)
UNION ALL SELECT 'fact_pbs_youth', COUNT(*)
FROM (SELECT province_key, sex_key, year_label, COUNT(*) AS n
      FROM fact_pbs_youth GROUP BY province_key, sex_key, year_label HAVING n > 1)
UNION ALL SELECT 'fact_pbs_age', COUNT(*)
FROM (SELECT age_group, framework, year_label, source_table, COUNT(*) AS n
      FROM fact_pbs_age GROUP BY age_group, framework, year_label, source_table HAVING n > 1)
UNION ALL SELECT 'fact_pbs_education', COUNT(*)
FROM (SELECT education_level, framework, year_label, source_table, COUNT(*) AS n
      FROM fact_pbs_education GROUP BY education_level, framework, year_label, source_table HAVING n > 1)
UNION ALL SELECT 'fact_pbs_neet', COUNT(*)
FROM (SELECT province_key, region_key, year_label, COUNT(*) AS n
      FROM fact_pbs_neet GROUP BY province_key, region_key, year_label HAVING n > 1)
UNION ALL SELECT 'fact_pbs_province_region', COUNT(*)
FROM (SELECT province_key, region_key, year_label, framework, COUNT(*) AS n
      FROM fact_pbs_province_region GROUP BY province_key, region_key, year_label, framework HAVING n > 1)
ORDER BY table_name;

-- CHECK 4: Out-of-range values. Rates must be 0-100, counts must be >= 0.
-- Any row here is a bad value that slipped through.
SELECT 'fact_pbs_province: rate out of 0-100' AS problem, COUNT(*) AS bad_rows
FROM fact_pbs_province
WHERE unemployment_total NOT BETWEEN 0 AND 100
   OR unemployment_male NOT BETWEEN 0 AND 100
   OR unemployment_female NOT BETWEEN 0 AND 100
UNION ALL SELECT 'fact_pbs_youth: rate out of 0-100', COUNT(*)
FROM fact_pbs_youth
WHERE unemployment_rate NOT BETWEEN 0 AND 100
   OR lfpr NOT BETWEEN 0 AND 100
UNION ALL SELECT 'fact_pbs_age: rate out of 0-100', COUNT(*)
FROM fact_pbs_age
WHERE unemployment_total NOT BETWEEN 0 AND 100
UNION ALL SELECT 'fact_pbs_education: rate out of 0-100', COUNT(*)
FROM fact_pbs_education
WHERE unemployment_total NOT BETWEEN 0 AND 100
UNION ALL SELECT 'fact_pbs_neet: rate out of 0-100', COUNT(*)
FROM fact_pbs_neet
WHERE neet_total NOT BETWEEN 0 AND 100
   OR neet_male NOT BETWEEN 0 AND 100
   OR neet_female NOT BETWEEN 0 AND 100
UNION ALL SELECT 'fact_pbs_youth: negative millions', COUNT(*)
FROM fact_pbs_youth
WHERE employed_million < 0 OR unemployed_million < 0
   OR labour_force_million < 0 OR youth_population_million < 0;

-- CHECK 5: Year coverage of the World Bank panel.
-- Expected: 35 distinct years, 1991 to 2025, one row per year.
-- COUNT(*) / 6 is integer division in SQLite (210 / 6 = 35, no decimals),
-- which is what we want here: 210 rows divided by 6 indicators = 35 years.
SELECT COUNT(DISTINCT year_label) AS distinct_years,
       MIN(CAST(year_label AS INTEGER)) AS first_year,
       MAX(CAST(year_label AS INTEGER)) AS last_year,
       COUNT(*) / 6 AS years_with_all_6_indicators
FROM fact_labour_yearly;

-- CHECK 6 (NOTE): Do the four provinces add up to the national total?
-- Youth population, 2024-25, Table 8.7: the provinces should sum to the
-- national figure of 46.3 million. A small gap would mean a rounding or
-- coverage difference in the published table.
SELECT 'sum of 4 provinces' AS what,
       ROUND(SUM(youth_population_million), 1) AS youth_population_million
FROM fact_pbs_youth
WHERE sex_key = 'Total' AND province_key <> 'Pakistan'
UNION ALL
SELECT 'national row (Pakistan)',
       youth_population_million
FROM fact_pbs_youth
WHERE sex_key = 'Total' AND province_key = 'Pakistan';

-- CHECK 7 (NOTE): Employed + unemployed should equal the labour force.
-- PBS rounds everything to 0.1 million, so a gap of 0.1 is rounding,
-- not an error. Anything bigger would be worth investigating.
SELECT province_key,
       employed_million + unemployed_million AS employed_plus_unemployed,
       labour_force_million,
       ROUND(employed_million + unemployed_million - labour_force_million, 1)
           AS gap_million
FROM fact_pbs_youth
WHERE sex_key = 'Total'
ORDER BY province_key;

-- CHECK 8 (NOTE): Recomputed vs published youth rate
-- Recompute the youth unemployment rate from the counts and compare it
-- with the published rate. The counts are rounded to 0.1 million, so the
-- recomputed rate will differ slightly from the published one. The gap
-- shows how much rounding matters.
SELECT province_key,
       unemployment_rate AS published_rate_pct,
       ROUND(100.0 * unemployed_million / labour_force_million, 1)
           AS recomputed_rate_pct,
       ROUND(100.0 * unemployed_million / labour_force_million
             - unemployment_rate, 2) AS gap_pp
FROM fact_pbs_youth
WHERE sex_key = 'Total'
ORDER BY province_key;

-- CHECK 9 (NOTE): Same age group, same year, two frameworks.
-- The 19th and 13th ICLS count unemployment differently, so the numbers
-- differ. These rows are NOT errors — they are the reason framework must
-- always be stated next to a PBS number.
SELECT a19.age_group,
       a19.year_label,
       a19.unemployment_total AS rate_19th_icls,
       a13.unemployment_total AS rate_13th_icls,
       ROUND(a19.unemployment_total - a13.unemployment_total, 1) AS gap_pp
FROM fact_pbs_age a19
JOIN fact_pbs_age a13
  ON a13.age_group = a19.age_group
 AND a13.year_label = a19.year_label
WHERE a19.framework = '19th ICLS'
  AND a13.framework = '13th ICLS'
  AND a19.source_table = 'Table 9.4'
  AND a13.source_table = 'Table 9.5'
ORDER BY a19.age_group;

-- CHECK 10 (NOTE): World Bank vs PBS headline for the same country.
-- World Bank (modelled ILO estimate, 2025): total unemployment 5.42%.
-- PBS survey (LFS 2024-25): total unemployment 7.1%.
-- Different instruments, different answers — both are legitimate, and
-- they must never be quoted as if they were the same number.
SELECT 'World Bank modelled estimate, 2025' AS measure,
       value AS unemployment_total_pct
FROM fact_labour_yearly
WHERE indicator_key = 'unemp_total' AND year_label = '2025'
UNION ALL
SELECT 'PBS LFS 2024-25 survey (Table 9.2)',
       unemployment_total
FROM fact_pbs_province
WHERE province_key = 'Pakistan';

-- CHECK 11: Referential integrity — every fact row must match a dimension.
-- Any row here points at a year/province/indicator that does not exist.
SELECT 'fact_labour_yearly -> dim_year' AS join_check,
       COUNT(*) AS orphan_rows
FROM fact_labour_yearly f
LEFT JOIN dim_year d ON d.year_label = f.year_label
WHERE d.year_label IS NULL
UNION ALL SELECT 'fact_labour_yearly -> dim_indicator', COUNT(*)
FROM fact_labour_yearly f
LEFT JOIN dim_indicator d ON d.indicator_key = f.indicator_key
WHERE d.indicator_key IS NULL
UNION ALL SELECT 'fact_pbs_youth -> dim_province', COUNT(*)
FROM fact_pbs_youth f
LEFT JOIN dim_province d ON d.province_key = f.province_key
WHERE d.province_key IS NULL
UNION ALL SELECT 'fact_pbs_age -> dim_age_group', COUNT(*)
FROM fact_pbs_age f
LEFT JOIN dim_age_group d ON d.age_group = f.age_group
WHERE d.age_group IS NULL
UNION ALL SELECT 'fact_pbs_education -> dim_education', COUNT(*)
FROM fact_pbs_education f
LEFT JOIN dim_education d ON d.education_level = f.education_level
WHERE d.education_level IS NULL
UNION ALL SELECT 'fact_pbs_neet -> dim_region', COUNT(*)
FROM fact_pbs_neet f
LEFT JOIN dim_region d ON d.region_key = f.region_key
WHERE d.region_key IS NULL;

-- CHECK 12 (NOTE): Is female NEET higher than male NEET everywhere?
-- One number: the smallest (female - male) gap across all 30 NEET rows.
-- If it is above 0, the pattern holds in every province, region and year.
-- (Rounded to 1 decimal: raw subtraction of decimals can print long
-- float tails like 24.800000000000004, which is the same number, uglier.)
SELECT ROUND(MIN(neet_female - neet_male), 1) AS smallest_female_minus_male_gap_pp,
       ROUND(MAX(neet_female - neet_male), 1) AS largest_female_minus_male_gap_pp
FROM fact_pbs_neet;
