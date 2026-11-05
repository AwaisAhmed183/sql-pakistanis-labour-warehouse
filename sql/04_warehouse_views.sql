-- ============================================================================
-- 04_warehouse_views.sql — Ready-made views: fact + dimension joins
-- ============================================================================
-- A view is a saved query. It behaves like a table, but it always shows
-- the current data — if the facts change, the view changes with them.
-- These three are the ones a report or dashboard would read.
--
-- Run:  sqlite3 labour_warehouse.db < sql/04_warehouse_views.sql
-- ============================================================================

-- VIEW 1: Province summary, 2024-25 — one row per province.
-- Joins three fact tables on the province key: overall unemployment
-- (Table 9.2), youth unemployment (Table 8.7, both sexes together) and
-- the NEET rate (Table 8.8, all areas).
CREATE VIEW IF NOT EXISTS v_province_summary AS
SELECT p.province_name AS province,
       p.is_national AS is_national,
       prov.unemployment_total AS overall_unemployment_pct,
       prov.unemployment_female AS overall_female_unemployment_pct,
       y.unemployment_rate AS youth_unemployment_pct,
       y.lfpr AS youth_lfpr_pct,
       yf.unemployment_rate AS youth_female_unemployment_pct,
       n.neet_total AS neet_pct,
       n.neet_female AS neet_female_pct
FROM dim_province p
LEFT JOIN fact_pbs_province prov
       ON prov.province_key = p.province_key
      AND prov.year_label = '2024-25'
LEFT JOIN fact_pbs_youth y
       ON y.province_key = p.province_key
      AND y.sex_key = 'Total'
      AND y.year_label = '2024-25'
LEFT JOIN fact_pbs_youth yf
       ON yf.province_key = p.province_key
      AND yf.sex_key = 'Female'
      AND yf.year_label = '2024-25'
LEFT JOIN fact_pbs_neet n
       ON n.province_key = p.province_key
      AND n.region_key = 'All Areas'
      AND n.year_label = '2024-25';

-- VIEW 2: Youth trend, 1991-2025 — youth vs total unemployment with the
-- gap and the year-over-year change. Reads the wide view, so the columns
-- are plain subtractions. LAG() takes the previous row's value.
CREATE VIEW IF NOT EXISTS v_youth_trend AS
SELECT year,
       ROUND(youth_unemployment_pct, 3) AS youth_unemployment_pct,
       ROUND(total_unemployment_pct, 3) AS total_unemployment_pct,
       ROUND(youth_unemployment_pct - total_unemployment_pct, 3)
           AS youth_minus_total_gap_pp,
       ROUND(youth_unemployment_pct
             - LAG(youth_unemployment_pct) OVER (ORDER BY year), 3)
           AS yoy_change_pp
FROM v_yearly_wide;

-- VIEW 3: Gender gap in youth unemployment, 1991-2025.
-- Reads the wide view: the gap is the female column minus the male column.
CREATE VIEW IF NOT EXISTS v_gender_gap AS
SELECT year,
       ROUND(youth_unemployment_male_pct, 3) AS male_youth_pct,
       ROUND(youth_unemployment_female_pct, 3) AS female_youth_pct,
       ROUND(youth_unemployment_female_pct - youth_unemployment_male_pct, 3)
           AS female_minus_male_gap_pp
FROM v_yearly_wide;
