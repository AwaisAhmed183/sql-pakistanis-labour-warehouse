-- ============================================================================
-- 01_schema.sql — Star schema for Pakistan labour data
-- ============================================================================
-- A small, explainable star schema.
--
--   Dimensions (the "who / when / what" tables):
--     dim_year, dim_province, dim_indicator, dim_sex,
--     dim_age_group, dim_education, dim_region
--
--   Facts (the numbers, one row per measurement):
--     fact_labour_yearly        World Bank yearly indicators, long/tidy form
--     fact_pbs_province         PBS province unemployment, LFS 2024-25
--     fact_pbs_youth            PBS youth (15-24) by province and sex
--     fact_pbs_age              PBS unemployment by age group
--     fact_pbs_education        PBS unemployment by education level
--     fact_pbs_neet             PBS NEET rates by province and region
--     fact_pbs_province_region  PBS province x region unemployment, 2020-21 vs 2024-25
--
-- Run:  sqlite3 labour_warehouse.db < sql/01_schema.sql
-- (load_data.py runs this file for you as part of the build.)
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- Dimensions
-- ----------------------------------------------------------------------------

-- One row per time period. Calendar years 1991-2025 come from the World Bank
-- panel; '2020-21' and '2024-25' are PBS survey years (July-June), not
-- calendar years, so they are stored as labels with their own start/end.
CREATE TABLE IF NOT EXISTS dim_year (
    year_label  TEXT PRIMARY KEY,  -- '1991' ... '2025', '2020-21', '2024-25'
    year_start  INTEGER NOT NULL,  -- first calendar year of the period
    year_end    INTEGER NOT NULL,  -- last calendar year of the period
    period_type TEXT NOT NULL      -- 'calendar' or 'survey'
        CHECK (period_type IN ('calendar', 'survey'))
);

-- Provinces. 'Pakistan' is the national row, not a province.
CREATE TABLE IF NOT EXISTS dim_province (
    province_key TEXT PRIMARY KEY,  -- 'Pakistan', 'KP', 'Punjab', 'Sindh', 'Balochistan'
    province_name TEXT NOT NULL,
    is_national INTEGER NOT NULL DEFAULT 0 CHECK (is_national IN (0, 1))
);

-- The six World Bank indicators in the yearly panel.
CREATE TABLE IF NOT EXISTS dim_indicator (
    indicator_key  TEXT PRIMARY KEY,  -- short key, e.g. 'youth_unemp_total'
    indicator_name TEXT NOT NULL,     -- plain-English name
    unit           TEXT NOT NULL,     -- '%' or 'US$'
    source_code    TEXT,              -- World Bank indicator code, e.g. 'SL.UEM.1524.ZS'
    source         TEXT NOT NULL      -- 'World Bank' (all six are World Bank series)
);

CREATE TABLE IF NOT EXISTS dim_sex (
    sex_key   TEXT PRIMARY KEY,  -- 'Total', 'Male', 'Female'
    sex_label TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS dim_age_group (
    age_group TEXT PRIMARY KEY,  -- '10-14', '15-24', ..., '65+', '15-29', '15-64'
    age_label TEXT NOT NULL
);

-- Education levels, kept in the order used by the PBS tables.
CREATE TABLE IF NOT EXISTS dim_education (
    education_level TEXT PRIMARY KEY,
    sort_order      INTEGER NOT NULL
);

-- Regions inside a province. 'Total' and 'All Areas' both mean "the whole
-- province" but come from different PBS tables, so they stay separate keys.
CREATE TABLE IF NOT EXISTS dim_region (
    region_key   TEXT PRIMARY KEY,  -- 'Total', 'Rural', 'Urban', 'All Areas'
    region_label TEXT NOT NULL
);

-- ----------------------------------------------------------------------------
-- Facts
-- ----------------------------------------------------------------------------

-- World Bank yearly panel, stored LONG (tidy): one row per year per
-- indicator. Wide tables are hard to query; long tables are easy:
--   "average youth unemployment by decade" is one GROUP BY.
CREATE TABLE IF NOT EXISTS fact_labour_yearly (
    year_label    TEXT NOT NULL REFERENCES dim_year (year_label),
    indicator_key TEXT NOT NULL REFERENCES dim_indicator (indicator_key),
    value         REAL NOT NULL,
    PRIMARY KEY (year_label, indicator_key),
    -- Keep bad numbers out at the door. Five of the six indicators are
    -- percentages, so they must sit between 0 and 100. The sixth is GDP
    -- per person in dollars, which must be above 0. Every real value in
    -- the data passes this check.
    CHECK (
        (indicator_key = 'gdp_per_capita_usd' AND value > 0)
        OR (indicator_key <> 'gdp_per_capita_usd'
            AND value BETWEEN 0 AND 100)
    )
);

-- PBS LFS 2024-25, Table 9.2 (19th ICLS): unemployment by province.
CREATE TABLE IF NOT EXISTS fact_pbs_province (
    province_key       TEXT NOT NULL REFERENCES dim_province (province_key),
    year_label         TEXT NOT NULL REFERENCES dim_year (year_label),
    framework          TEXT NOT NULL,  -- '19th ICLS'
    unemployment_total REAL NOT NULL CHECK (unemployment_total BETWEEN 0 AND 100),
    unemployment_male  REAL CHECK (unemployment_male BETWEEN 0 AND 100),
    unemployment_female REAL CHECK (unemployment_female BETWEEN 0 AND 100),
    source_table       TEXT NOT NULL,  -- 'Table 9.2'
    PRIMARY KEY (province_key, year_label, framework)
);

-- PBS LFS 2024-25, Table 8.7 (19th ICLS): youth (15-24) by province and sex.
-- province_raw keeps the value exactly as published ('Total' = national row);
-- province_key is the cleaned key ('Pakistan') so joins work.
CREATE TABLE IF NOT EXISTS fact_pbs_youth (
    province_key                  TEXT NOT NULL REFERENCES dim_province (province_key),
    province_raw                  TEXT NOT NULL,
    sex_key                       TEXT NOT NULL REFERENCES dim_sex (sex_key),
    year_label                    TEXT NOT NULL REFERENCES dim_year (year_label),
    framework                     TEXT NOT NULL,  -- '19th ICLS'
    employed_million              REAL CHECK (employed_million >= 0),
    unemployed_million            REAL CHECK (unemployed_million >= 0),
    labour_force_million          REAL CHECK (labour_force_million >= 0),
    out_of_labour_force_million   REAL CHECK (out_of_labour_force_million >= 0),
    youth_population_million      REAL CHECK (youth_population_million >= 0),
    unemployment_rate             REAL CHECK (unemployment_rate BETWEEN 0 AND 100),
    employment_to_population_ratio REAL CHECK (employment_to_population_ratio BETWEEN 0 AND 100),
    lfpr                          REAL CHECK (lfpr BETWEEN 0 AND 100),
    source_table                  TEXT NOT NULL,  -- 'Table 8.7'
    PRIMARY KEY (province_key, sex_key, year_label)
);

-- PBS LFS, Tables 9.4 / 9.5 / 9.6: unemployment by age group.
-- The same age group and year can appear under two frameworks (19th and
-- 13th ICLS) with DIFFERENT values. Framework is part of the key on purpose:
-- never compare across frameworks without saying so.
CREATE TABLE IF NOT EXISTS fact_pbs_age (
    age_group           TEXT NOT NULL REFERENCES dim_age_group (age_group),
    framework           TEXT NOT NULL,  -- '19th ICLS' or '13th ICLS'
    year_label          TEXT NOT NULL REFERENCES dim_year (year_label),
    unemployment_total  REAL CHECK (unemployment_total BETWEEN 0 AND 100),
    unemployment_male   REAL CHECK (unemployment_male BETWEEN 0 AND 100),
    unemployment_female REAL CHECK (unemployment_female BETWEEN 0 AND 100),
    source_table        TEXT NOT NULL,  -- 'Table 9.4', 'Table 9.5' or 'Table 9.6'
    PRIMARY KEY (age_group, framework, year_label, source_table)
);

-- PBS LFS, Tables 9.7 / 9.8: unemployment by education level.
CREATE TABLE IF NOT EXISTS fact_pbs_education (
    education_level     TEXT NOT NULL REFERENCES dim_education (education_level),
    framework           TEXT NOT NULL,  -- '19th ICLS' or '13th ICLS'
    year_label          TEXT NOT NULL REFERENCES dim_year (year_label),
    unemployment_total  REAL CHECK (unemployment_total BETWEEN 0 AND 100),
    unemployment_male   REAL CHECK (unemployment_male BETWEEN 0 AND 100),
    unemployment_female REAL CHECK (unemployment_female BETWEEN 0 AND 100),
    source_table        TEXT NOT NULL,  -- 'Table 9.7' or 'Table 9.8'
    PRIMARY KEY (education_level, framework, year_label, source_table)
);

-- PBS LFS, Table 8.8: NEET rates (youth not in employment, education or
-- training) by province, region and survey year.
CREATE TABLE IF NOT EXISTS fact_pbs_neet (
    province_key TEXT NOT NULL REFERENCES dim_province (province_key),
    region_key   TEXT NOT NULL REFERENCES dim_region (region_key),
    year_label   TEXT NOT NULL REFERENCES dim_year (year_label),
    neet_total   REAL CHECK (neet_total BETWEEN 0 AND 100),
    neet_male    REAL CHECK (neet_male BETWEEN 0 AND 100),
    neet_female  REAL CHECK (neet_female BETWEEN 0 AND 100),
    source_table TEXT NOT NULL,  -- 'Table 8.8'
    PRIMARY KEY (province_key, region_key, year_label)
);

-- PBS LFS, Table 9.3 (13th ICLS): unemployment by province and region,
-- 2020-21 vs 2024-25.
CREATE TABLE IF NOT EXISTS fact_pbs_province_region (
    province_key       TEXT NOT NULL REFERENCES dim_province (province_key),
    region_key         TEXT NOT NULL REFERENCES dim_region (region_key),
    year_label         TEXT NOT NULL REFERENCES dim_year (year_label),
    framework          TEXT NOT NULL,  -- '13th ICLS'
    unemployment_total REAL CHECK (unemployment_total BETWEEN 0 AND 100),
    unemployment_male  REAL CHECK (unemployment_male BETWEEN 0 AND 100),
    unemployment_female REAL CHECK (unemployment_female BETWEEN 0 AND 100),
    source_table       TEXT NOT NULL,  -- 'Table 9.3'
    PRIMARY KEY (province_key, region_key, year_label, framework)
);

-- ----------------------------------------------------------------------------
-- Indexes — one on every join key of every fact table
-- ----------------------------------------------------------------------------
-- An index is like the index at the back of a book: it helps the database
-- find rows fast instead of reading the whole table. Every query in
-- sql/03_analysis.sql joins facts to dimensions on these keys, so each
-- key gets an index. They change nothing about the data — only speed.

CREATE INDEX IF NOT EXISTS idx_fact_yearly_year
    ON fact_labour_yearly (year_label);
CREATE INDEX IF NOT EXISTS idx_fact_yearly_indicator
    ON fact_labour_yearly (indicator_key);
CREATE INDEX IF NOT EXISTS idx_fact_province_province
    ON fact_pbs_province (province_key);
CREATE INDEX IF NOT EXISTS idx_fact_province_year
    ON fact_pbs_province (year_label);
CREATE INDEX IF NOT EXISTS idx_fact_youth_province
    ON fact_pbs_youth (province_key);
CREATE INDEX IF NOT EXISTS idx_fact_youth_sex
    ON fact_pbs_youth (sex_key);
CREATE INDEX IF NOT EXISTS idx_fact_youth_year
    ON fact_pbs_youth (year_label);
CREATE INDEX IF NOT EXISTS idx_fact_age_group
    ON fact_pbs_age (age_group);
CREATE INDEX IF NOT EXISTS idx_fact_age_year
    ON fact_pbs_age (year_label);
CREATE INDEX IF NOT EXISTS idx_fact_education_level
    ON fact_pbs_education (education_level);
CREATE INDEX IF NOT EXISTS idx_fact_education_year
    ON fact_pbs_education (year_label);
CREATE INDEX IF NOT EXISTS idx_fact_neet_province
    ON fact_pbs_neet (province_key);
CREATE INDEX IF NOT EXISTS idx_fact_neet_region
    ON fact_pbs_neet (region_key);
CREATE INDEX IF NOT EXISTS idx_fact_neet_year
    ON fact_pbs_neet (year_label);
CREATE INDEX IF NOT EXISTS idx_fact_province_region_province
    ON fact_pbs_province_region (province_key);
CREATE INDEX IF NOT EXISTS idx_fact_province_region_region
    ON fact_pbs_province_region (region_key);
CREATE INDEX IF NOT EXISTS idx_fact_province_region_year
    ON fact_pbs_province_region (year_label);

-- ----------------------------------------------------------------------------
-- Wide view — the yearly panel, one row per year
-- ----------------------------------------------------------------------------
-- The fact table is LONG: one row per year per indicator. That shape is
-- easy to load, but questions like "youth vs total, year by year" need
-- the numbers side by side. This view pivots the long table into a WIDE
-- one — one row per year, one column per indicator — so Q3, Q5, Q10 and
-- Q11 can read plain columns instead of repeating the pivot. The pivot
-- lives here once, not in every query. A view is a saved query: it looks
-- like a table, but it always shows the newest data.
CREATE VIEW IF NOT EXISTS v_yearly_wide AS
SELECT CAST(year_label AS INTEGER) AS year,
       MAX(CASE WHEN indicator_key = 'youth_unemp_total' THEN value END)
           AS youth_unemployment_pct,
       MAX(CASE WHEN indicator_key = 'youth_unemp_male' THEN value END)
           AS youth_unemployment_male_pct,
       MAX(CASE WHEN indicator_key = 'youth_unemp_female' THEN value END)
           AS youth_unemployment_female_pct,
       MAX(CASE WHEN indicator_key = 'unemp_total' THEN value END)
           AS total_unemployment_pct,
       MAX(CASE WHEN indicator_key = 'lfpr_total' THEN value END)
           AS lfpr_pct,
       MAX(CASE WHEN indicator_key = 'gdp_per_capita_usd' THEN value END)
           AS gdp_per_capita_usd
FROM fact_labour_yearly
GROUP BY year_label;
