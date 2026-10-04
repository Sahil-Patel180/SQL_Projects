/*
===============================================================================
Quality Checks: Silver
===============================================================================
Run after EXEC silver.load_silver (or meta.run_pipeline).
Returns one row per check. Every row should show PASS.

Primary keys already block duplicate ids during the load; these checks cover
what keys cannot: lost rows, failed type conversions, orphan references.
===============================================================================
*/

USE F1_DB2;
GO

DROP TABLE IF EXISTS #silver_checks;
CREATE TABLE #silver_checks (
    check_name  NVARCHAR(200),
    actual      BIGINT,
    expected    NVARCHAR(50),
    passed      BIT
);

---------------------------------------------------------------------------- 1. no rows lost bronze -> silver
INSERT INTO #silver_checks
SELECT N'rows bronze (distinct keys) = silver: ' + b.t, s.n - b.n, N'0 difference', CASE WHEN s.n = b.n THEN 1 ELSE 0 END
FROM (VALUES
        (N'circuits',              (SELECT COUNT_BIG(*) FROM bronze.circuits)),
        (N'constructors',          (SELECT COUNT_BIG(*) FROM bronze.constructors)),
        (N'drivers',               (SELECT COUNT_BIG(*) FROM bronze.drivers)),
        (N'seasons',               (SELECT COUNT_BIG(*) FROM bronze.seasons)),
        (N'status',                (SELECT COUNT_BIG(*) FROM bronze.status)),
        (N'races',                 (SELECT COUNT_BIG(*) FROM bronze.races)),
        (N'results',               (SELECT COUNT_BIG(*) FROM bronze.results)),
        (N'sprint_results',        (SELECT COUNT_BIG(*) FROM bronze.sprint_results)),
        (N'qualifying',            (SELECT COUNT_BIG(*) FROM bronze.qualifying)),
        (N'lap_times',             (SELECT COUNT_BIG(*) FROM (SELECT DISTINCT raceId, driverId, lap FROM bronze.lap_times) d)),  -- duplicates dropped on purpose
        (N'pit_stops',             (SELECT COUNT_BIG(*) FROM (SELECT DISTINCT raceId, driverId, [stop] FROM bronze.pit_stops) d)),  -- duplicates dropped on purpose
        (N'driver_standings',      (SELECT COUNT_BIG(*) FROM bronze.driver_standings)),
        (N'constructor_standings', (SELECT COUNT_BIG(*) FROM bronze.constructor_standings)),
        (N'constructor_results',   (SELECT COUNT_BIG(*) FROM bronze.constructor_results))
     ) AS b(t, n)
JOIN (VALUES
        (N'circuits',              (SELECT COUNT_BIG(*) FROM silver.circuits)),
        (N'constructors',          (SELECT COUNT_BIG(*) FROM silver.constructors)),
        (N'drivers',               (SELECT COUNT_BIG(*) FROM silver.drivers)),
        (N'seasons',               (SELECT COUNT_BIG(*) FROM silver.seasons)),
        (N'status',                (SELECT COUNT_BIG(*) FROM silver.status)),
        (N'races',                 (SELECT COUNT_BIG(*) FROM silver.races)),
        (N'results',               (SELECT COUNT_BIG(*) FROM silver.results)),
        (N'sprint_results',        (SELECT COUNT_BIG(*) FROM silver.sprint_results)),
        (N'qualifying',            (SELECT COUNT_BIG(*) FROM silver.qualifying)),
        (N'lap_times',             (SELECT COUNT_BIG(*) FROM silver.lap_times)),
        (N'pit_stops',             (SELECT COUNT_BIG(*) FROM silver.pit_stops)),
        (N'driver_standings',      (SELECT COUNT_BIG(*) FROM silver.driver_standings)),
        (N'constructor_standings', (SELECT COUNT_BIG(*) FROM silver.constructor_standings)),
        (N'constructor_results',   (SELECT COUNT_BIG(*) FROM silver.constructor_results))
     ) AS s(t, n)
  ON s.t = b.t;

---------------------------------------------------------------------------- 2. no value lost in type conversion
-- A source value that was present ('\N' excluded) but became NULL in silver
-- means TRY_CAST could not parse it.
INSERT INTO #silver_checks
SELECT N'type conversion: ' + c.col, c.lost, N'0', CASE WHEN c.lost = 0 THEN 1 ELSE 0 END
FROM (
    SELECT N'results.grid', COUNT_BIG(*) FROM bronze.results b JOIN silver.results s ON s.result_id = CAST(b.resultId AS INT)
        WHERE dbo.fn_clean(b.grid) IS NOT NULL AND s.grid IS NULL
    UNION ALL
    SELECT N'results.position', COUNT_BIG(*) FROM bronze.results b JOIN silver.results s ON s.result_id = CAST(b.resultId AS INT)
        WHERE dbo.fn_clean(b.position) IS NOT NULL AND s.position IS NULL
          AND TRY_CAST(dbo.fn_clean(b.positionText) AS INT) IS NOT NULL   -- retirements are nulled on purpose
    UNION ALL
    SELECT N'results.race_time_ms', COUNT_BIG(*) FROM bronze.results b JOIN silver.results s ON s.result_id = CAST(b.resultId AS INT)
        WHERE dbo.fn_clean(b.milliseconds) IS NOT NULL AND s.race_time_ms IS NULL
    UNION ALL
    SELECT N'results.fastest_lap_ms', COUNT_BIG(*) FROM bronze.results b JOIN silver.results s ON s.result_id = CAST(b.resultId AS INT)
        WHERE dbo.fn_clean(b.fastestLapTime) IS NOT NULL AND s.fastest_lap_ms IS NULL
    UNION ALL
    SELECT N'results.fastest_lap_speed_kph', COUNT_BIG(*) FROM bronze.results b JOIN silver.results s ON s.result_id = CAST(b.resultId AS INT)
        WHERE dbo.fn_clean(b.fastestLapSpeed) IS NOT NULL AND s.fastest_lap_speed_kph IS NULL
    UNION ALL
    SELECT N'qualifying.q1_ms', COUNT_BIG(*) FROM bronze.qualifying b JOIN silver.qualifying s ON s.qualify_id = CAST(b.qualifyId AS INT)
        WHERE dbo.fn_clean(b.q1) IS NOT NULL AND s.q1_ms IS NULL
    UNION ALL
    SELECT N'qualifying.q3_ms', COUNT_BIG(*) FROM bronze.qualifying b JOIN silver.qualifying s ON s.qualify_id = CAST(b.qualifyId AS INT)
        WHERE dbo.fn_clean(b.q3) IS NOT NULL AND s.q3_ms IS NULL
    UNION ALL
    SELECT N'races.race_datetime_utc', COUNT_BIG(*) FROM silver.races
        WHERE race_time_utc IS NOT NULL AND race_datetime_utc IS NULL
    UNION ALL
    SELECT N'drivers.date_of_birth', COUNT_BIG(*) FROM bronze.drivers b JOIN silver.drivers s ON s.driver_id = CAST(b.driverId AS INT)
        WHERE dbo.fn_clean(b.dob) IS NOT NULL AND s.date_of_birth IS NULL
    UNION ALL
    SELECT N'lap_times.lap_time_ms', COUNT_BIG(*) FROM silver.lap_times WHERE lap_time_ms IS NULL
) AS c(col, lost);

---------------------------------------------------------------------------- 3. parsed times agree with the source
-- lap_times has both a text time and milliseconds in the source: the parser
-- must reproduce the source milliseconds exactly.
INSERT INTO #silver_checks
-- The source rounds a few hundred laps differently in its two columns (always
-- off by exactly 1 ms, e.g. '2:08.081' vs 128080), so 1 ms is tolerated.
-- More than that, or a time the parser cannot read, is a parser bug.
SELECT N'fn_time_to_ms matches source ms (lap_times, +/-1 ms)', COUNT_BIG(*), N'0', CASE WHEN COUNT_BIG(*) = 0 THEN 1 ELSE 0 END
FROM bronze.lap_times
WHERE ABS(dbo.fn_time_to_ms([time]) - TRY_CAST(dbo.fn_clean(milliseconds) AS INT)) > 1
   OR (dbo.fn_time_to_ms([time]) IS NULL AND dbo.fn_clean([time]) IS NOT NULL);

---------------------------------------------------------------------------- 4. orphan references
INSERT INTO #silver_checks
SELECT N'orphans: ' + o.rel, o.n, N'0', CASE WHEN o.n = 0 THEN 1 ELSE 0 END
FROM (
    SELECT N'races.circuit_id', COUNT_BIG(*) FROM silver.races x
        WHERE NOT EXISTS (SELECT 1 FROM silver.circuits c WHERE c.circuit_id = x.circuit_id)
    UNION ALL
    SELECT N'races.season_year', COUNT_BIG(*) FROM silver.races x
        WHERE NOT EXISTS (SELECT 1 FROM silver.seasons s WHERE s.season_year = x.season_year)
    UNION ALL
    SELECT N'results.race_id', COUNT_BIG(*) FROM silver.results x
        WHERE NOT EXISTS (SELECT 1 FROM silver.races r WHERE r.race_id = x.race_id)
    UNION ALL
    SELECT N'results.driver_id', COUNT_BIG(*) FROM silver.results x
        WHERE NOT EXISTS (SELECT 1 FROM silver.drivers d WHERE d.driver_id = x.driver_id)
    UNION ALL
    SELECT N'results.constructor_id', COUNT_BIG(*) FROM silver.results x
        WHERE NOT EXISTS (SELECT 1 FROM silver.constructors c WHERE c.constructor_id = x.constructor_id)
    UNION ALL
    SELECT N'results.status_id', COUNT_BIG(*) FROM silver.results x
        WHERE x.status_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM silver.status s WHERE s.status_id = x.status_id)
    UNION ALL
    SELECT N'sprint_results.race_id', COUNT_BIG(*) FROM silver.sprint_results x
        WHERE NOT EXISTS (SELECT 1 FROM silver.races r WHERE r.race_id = x.race_id)
    UNION ALL
    SELECT N'sprint_results.status_id', COUNT_BIG(*) FROM silver.sprint_results x
        WHERE x.status_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM silver.status s WHERE s.status_id = x.status_id)
    UNION ALL
    SELECT N'qualifying.race_id+driver_id', COUNT_BIG(*) FROM silver.qualifying x
        WHERE NOT EXISTS (SELECT 1 FROM silver.races r WHERE r.race_id = x.race_id)
           OR NOT EXISTS (SELECT 1 FROM silver.drivers d WHERE d.driver_id = x.driver_id)
    UNION ALL
    SELECT N'lap_times.race_id+driver_id', COUNT_BIG(*) FROM silver.lap_times x
        WHERE NOT EXISTS (SELECT 1 FROM silver.races r WHERE r.race_id = x.race_id)
           OR NOT EXISTS (SELECT 1 FROM silver.drivers d WHERE d.driver_id = x.driver_id)
    UNION ALL
    SELECT N'pit_stops.race_id+driver_id', COUNT_BIG(*) FROM silver.pit_stops x
        WHERE NOT EXISTS (SELECT 1 FROM silver.races r WHERE r.race_id = x.race_id)
           OR NOT EXISTS (SELECT 1 FROM silver.drivers d WHERE d.driver_id = x.driver_id)
    UNION ALL
    SELECT N'driver_standings.race_id+driver_id', COUNT_BIG(*) FROM silver.driver_standings x
        WHERE NOT EXISTS (SELECT 1 FROM silver.races r WHERE r.race_id = x.race_id)
           OR NOT EXISTS (SELECT 1 FROM silver.drivers d WHERE d.driver_id = x.driver_id)
    UNION ALL
    SELECT N'constructor_standings.race_id+constructor_id', COUNT_BIG(*) FROM silver.constructor_standings x
        WHERE NOT EXISTS (SELECT 1 FROM silver.races r WHERE r.race_id = x.race_id)
           OR NOT EXISTS (SELECT 1 FROM silver.constructors c WHERE c.constructor_id = x.constructor_id)
) AS o(rel, n);

---------------------------------------------------------------------------- 5. value sanity
INSERT INTO #silver_checks
SELECT N'sanity: ' + v.rule_name, v.n, N'0', CASE WHEN v.n = 0 THEN 1 ELSE 0 END
FROM (
    SELECT N'no ''\N'' left in text columns', COUNT_BIG(*) FROM silver.results
        WHERE position_text = N'\N' OR race_time_text = N'\N'
    UNION ALL
    SELECT N'points >= 0', COUNT_BIG(*) FROM silver.results WHERE points < 0
    UNION ALL
    SELECT N'classified position matches position_text', COUNT_BIG(*) FROM silver.results
        WHERE position IS NOT NULL AND position_text <> CAST(position AS NVARCHAR(3))
    UNION ALL
    SELECT N'lap times between 30 s and 3 h', COUNT_BIG(*) FROM silver.lap_times
        WHERE lap_time_ms NOT BETWEEN 30000 AND 10800000
    UNION ALL
    SELECT N'race dates between 1950 and 2030', COUNT_BIG(*) FROM silver.races
        WHERE race_date NOT BETWEEN '1950-01-01' AND '2030-12-31'
    UNION ALL
    SELECT N'circuit coordinates in range', COUNT_BIG(*) FROM silver.circuits
        WHERE latitude NOT BETWEEN -90 AND 90 OR longitude NOT BETWEEN -180 AND 180
) AS v(rule_name, n);

---------------------------------------------------------------------------- 6. accents survived
INSERT INTO #silver_checks
-- Raikkonen with a-umlaut and o-umlaut, built with NCHAR so the script's own file encoding cannot break it
SELECT N'Raikkonen spelled with umlauts', COUNT_BIG(*), N'1', CASE WHEN COUNT_BIG(*) = 1 THEN 1 ELSE 0 END
FROM silver.drivers
WHERE driver_ref = N'raikkonen' AND surname = N'R' + NCHAR(228) + N'ikk' + NCHAR(246) + N'nen';

SELECT
    check_name,
    actual,
    expected,
    CASE WHEN passed = 1 THEN 'PASS' ELSE 'FAIL' END AS status
FROM #silver_checks
ORDER BY passed, check_name;
