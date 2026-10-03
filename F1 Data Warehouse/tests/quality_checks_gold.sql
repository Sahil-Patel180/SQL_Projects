/*
===============================================================================
Quality Checks: Gold
===============================================================================
Run after the pipeline. Returns one row per check:
    PASS  as expected
    FAIL  something is wrong in the model
    WARN  data is stale or incomplete, not a model error

Points reconciliation is the key business check: for every completed season
from 2010, each driver's race + sprint points summed from gold.fact_results
must equal their final championship points. (Before 2010 several seasons
counted only a driver's best results, so the sums legitimately differ.)
===============================================================================
*/

USE F1_DB;
GO

DROP TABLE IF EXISTS #checks;
CREATE TABLE #checks (
    check_name  NVARCHAR(200),
    actual      BIGINT,
    expected    NVARCHAR(50),
    result      VARCHAR(4)
);

---------------------------------------------------------------------------- 1. dimension keys unique
INSERT INTO #checks
SELECT N'unique key: ' + k.dim, k.dupes, N'0', CASE WHEN k.dupes = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT N'dim_driver.driver_id', COUNT_BIG(*) - COUNT_BIG(DISTINCT driver_id) FROM gold.dim_driver
    UNION ALL
    SELECT N'dim_constructor.constructor_id', COUNT_BIG(*) - COUNT_BIG(DISTINCT constructor_id) FROM gold.dim_constructor
    UNION ALL
    SELECT N'dim_circuit.circuit_id', COUNT_BIG(*) - COUNT_BIG(DISTINCT circuit_id) FROM gold.dim_circuit
    UNION ALL
    SELECT N'dim_race.race_id', COUNT_BIG(*) - COUNT_BIG(DISTINCT race_id) FROM gold.dim_race
    UNION ALL
    SELECT N'dim_status.status_id', COUNT_BIG(*) - COUNT_BIG(DISTINCT status_id) FROM gold.dim_status
    UNION ALL
    SELECT N'dim_date.date_key', COUNT_BIG(*) - COUNT_BIG(DISTINCT date_key) FROM gold.dim_date
) AS k(dim, dupes);

---------------------------------------------------------------------------- 2. no rows lost or duplicated
INSERT INTO #checks
SELECT N'fact_results Race rows = silver.results',
       (SELECT COUNT_BIG(*) FROM gold.fact_results WHERE session_type = N'Race')
     - (SELECT COUNT_BIG(*) FROM silver.results),
       N'0 difference', NULL;
INSERT INTO #checks
SELECT N'fact_results Sprint rows = silver.sprint_results',
       (SELECT COUNT_BIG(*) FROM gold.fact_results WHERE session_type = N'Sprint')
     - (SELECT COUNT_BIG(*) FROM silver.sprint_results),
       N'0 difference', NULL;
INSERT INTO #checks
SELECT N'fact_pit_stops rows = silver.pit_stops',
       (SELECT COUNT_BIG(*) FROM gold.fact_pit_stops) - (SELECT COUNT_BIG(*) FROM silver.pit_stops),
       N'0 difference', NULL;
UPDATE #checks SET result = CASE WHEN actual = 0 THEN 'PASS' ELSE 'FAIL' END WHERE result IS NULL;

---------------------------------------------------------------------------- 3. every fact key finds its dimension
INSERT INTO #checks
SELECT N'unmatched key: ' + m.rel, m.n, N'0', CASE WHEN m.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT N'fact_results -> dim_race', COUNT_BIG(*) FROM gold.fact_results f
        WHERE NOT EXISTS (SELECT 1 FROM gold.dim_race d WHERE d.race_id = f.race_id)
    UNION ALL
    SELECT N'fact_results -> dim_driver', COUNT_BIG(*) FROM gold.fact_results f
        WHERE NOT EXISTS (SELECT 1 FROM gold.dim_driver d WHERE d.driver_id = f.driver_id)
    UNION ALL
    SELECT N'fact_results -> dim_constructor', COUNT_BIG(*) FROM gold.fact_results f
        WHERE NOT EXISTS (SELECT 1 FROM gold.dim_constructor d WHERE d.constructor_id = f.constructor_id)
    UNION ALL
    SELECT N'fact_results -> dim_status', COUNT_BIG(*) FROM gold.fact_results f
        WHERE NOT EXISTS (SELECT 1 FROM gold.dim_status d WHERE d.status_id = f.status_id)
    UNION ALL
    SELECT N'dim_race -> dim_circuit', COUNT_BIG(*) FROM gold.dim_race r
        WHERE NOT EXISTS (SELECT 1 FROM gold.dim_circuit c WHERE c.circuit_id = r.circuit_id)
    UNION ALL
    SELECT N'dim_race -> dim_date', COUNT_BIG(*) FROM gold.dim_race r
        WHERE NOT EXISTS (SELECT 1 FROM gold.dim_date d WHERE d.date_key = r.race_date_key)
    UNION ALL
    SELECT N'fact_pit_stops -> constructor', COUNT_BIG(*) FROM gold.fact_pit_stops
        WHERE constructor_id IS NULL
) AS m(rel, n);

---------------------------------------------------------------------------- 4. business rules
-- 4a. every completed race has a winner
INSERT INTO #checks
SELECT N'completed races without a winner', COUNT_BIG(*), N'0',
       CASE WHEN COUNT_BIG(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM gold.dim_race r
WHERE r.is_completed = 1
  AND NOT EXISTS (SELECT 1 FROM gold.fact_results f
                  WHERE f.race_id = r.race_id AND f.session_type = N'Race' AND f.is_win = 1);

-- 4b. exactly one champion per completed season
INSERT INTO #checks
SELECT N'completed seasons without exactly one champion', COUNT_BIG(*), N'0',
       CASE WHEN COUNT_BIG(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT season_year
    FROM gold.agg_driver_season
    WHERE is_season_complete = 1
    GROUP BY season_year
    HAVING SUM(is_champion) <> 1
) AS x;

-- 4c. driver points reconcile with final standings, 2010+ completed seasons
WITH summed AS (
    SELECT r.season_year, f.driver_id, SUM(f.points) AS pts
    FROM gold.fact_results f
    JOIN gold.dim_race r ON r.race_id = f.race_id
    WHERE r.season_year >= 2010
    GROUP BY r.season_year, f.driver_id
)
INSERT INTO #checks
SELECT N'driver points = final standings (2010+)', COUNT_BIG(*), N'0',
       CASE WHEN COUNT_BIG(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM gold.fact_driver_standings s
JOIN summed m ON m.season_year = s.season_year AND m.driver_id = s.driver_id
WHERE s.is_final_round = 1
  AND s.is_season_complete = 1
  AND m.pts <> s.championship_points;

-- 4d. constructor points reconcile, 2010+ completed seasons.
-- Two known differences are real history, not errors:
--   2018 Force India (constructor_id 10): entry replaced mid-season, its points reset.
--   2020 Racing Point (constructor_id 211): 15-point penalty.
WITH summed AS (
    SELECT r.season_year, f.constructor_id, SUM(f.points) AS pts
    FROM gold.fact_results f
    JOIN gold.dim_race r ON r.race_id = f.race_id
    WHERE r.season_year >= 2010
    GROUP BY r.season_year, f.constructor_id
)
INSERT INTO #checks
SELECT N'constructor points = final standings (2010+, excl. 2 known penalties)', COUNT_BIG(*), N'0',
       CASE WHEN COUNT_BIG(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM gold.fact_constructor_standings s
JOIN summed m ON m.season_year = s.season_year AND m.constructor_id = s.constructor_id
WHERE s.is_final_round = 1
  AND s.is_season_complete = 1
  AND m.pts <> s.championship_points
  AND NOT (s.season_year = 2018 AND s.constructor_id = 10)
  AND NOT (s.season_year = 2020 AND s.constructor_id = 211);

-- 4e. flags are consistent
INSERT INTO #checks
SELECT N'flag conflicts (win but not podium, DNF but classified, ...)', COUNT_BIG(*), N'0',
       CASE WHEN COUNT_BIG(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM gold.fact_results
WHERE (is_win = 1 AND is_podium = 0)
   OR (is_dnf = 1 AND is_classified = 1)
   OR (is_dnf = 1 AND is_started = 0)
   OR (is_podium = 1 AND is_classified = 0);

---------------------------------------------------------------------------- 5. ML features: no leakage
-- Recompute driver_points_last5 for one season from scratch, using only races
-- strictly before each race. Any difference means the window leaks.
INSERT INTO #checks
SELECT N'ml leakage spot check: driver_points_last5 (2023)', COUNT_BIG(*), N'0',
       CASE WHEN COUNT_BIG(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM gold.ml_driver_race_features AS m
WHERE m.season_year = 2023
  AND ISNULL(m.driver_points_last5, -1) <> ISNULL((
        SELECT SUM(prev.points)
        FROM (
            SELECT TOP (5) f.points
            FROM gold.fact_results f
            JOIN gold.dim_race     r ON r.race_id = f.race_id
            WHERE f.driver_id = m.driver_id
              AND f.session_type = N'Race'
              AND f.is_started = 1
              AND r.race_date < m.race_date
            ORDER BY r.race_date DESC
        ) AS prev), -1);

INSERT INTO #checks
SELECT N'ml features: first career start has no history', COUNT_BIG(*), N'0',
       CASE WHEN COUNT_BIG(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM gold.ml_driver_race_features
WHERE driver_career_starts_before = 0
  AND (driver_points_last5 IS NOT NULL OR driver_avg_finish_last5 IS NOT NULL);

---------------------------------------------------------------------------- 6. freshness (WARN only)
INSERT INTO #checks
SELECT N'past races still without results (re-download data?)', COUNT_BIG(*), N'0',
       CASE WHEN COUNT_BIG(*) = 0 THEN 'PASS' ELSE 'WARN' END
FROM gold.dim_race
WHERE is_completed = 0
  AND race_date < CAST(GETDATE() AS DATE);

SELECT check_name, actual, expected, result
FROM #checks
ORDER BY CASE result WHEN 'FAIL' THEN 0 WHEN 'WARN' THEN 1 ELSE 2 END, check_name;
