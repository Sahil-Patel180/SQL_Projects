/*
===============================================================================
Quality Checks: Bronze
===============================================================================
Run after EXEC bronze.load_bronze (or meta.run_pipeline).
Returns one row per check. Every row should show PASS.
===============================================================================
*/

USE F1_DB2;
GO

DROP TABLE IF EXISTS #bronze_checks;
CREATE TABLE #bronze_checks (
    check_name  NVARCHAR(200),
    actual      BIGINT,
    expected    NVARCHAR(50),
    passed      BIT
);

-- 1. Every table loaded something
INSERT INTO #bronze_checks
SELECT N'bronze.' + t.name + N' has rows', p.rows, N'> 0', CASE WHEN p.rows > 0 THEN 1 ELSE 0 END
FROM sys.tables AS t
JOIN sys.partitions AS p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
WHERE SCHEMA_NAME(t.schema_id) = N'bronze';

-- 2. 14 tables present
INSERT INTO #bronze_checks
SELECT N'bronze table count', COUNT(*), N'14', CASE WHEN COUNT(*) = 14 THEN 1 ELSE 0 END
FROM sys.tables WHERE SCHEMA_NAME(schema_id) = N'bronze';

-- 3. UTF-8 decoded correctly (UTF-8 read as ANSI shows up as 'Ã' + another character).
--    BIN2 collation: the default case-insensitive collation would also match a
--    real lowercase 'ã' (São Paulo, Portimão) and report a false failure.
INSERT INTO #bronze_checks
SELECT N'no garbled accents in drivers (mojibake)', COUNT(*), N'0', CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END
FROM bronze.drivers
WHERE forename COLLATE Latin1_General_BIN2 LIKE N'%' + NCHAR(195) + N'%'
   OR surname  COLLATE Latin1_General_BIN2 LIKE N'%' + NCHAR(195) + N'%';

INSERT INTO #bronze_checks
-- Raikkonen with a-umlaut and o-umlaut, built with NCHAR so the script's own file encoding cannot break it
SELECT N'Raikkonen spelled with umlauts', COUNT(*), N'1', CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END
FROM bronze.drivers
WHERE driverRef = N'raikkonen' AND surname = N'R' + NCHAR(228) + N'ikk' + NCHAR(246) + N'nen';

INSERT INTO #bronze_checks
SELECT N'no garbled accents in circuits (mojibake)', COUNT(*), N'0', CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END
FROM bronze.circuits
WHERE [name]     COLLATE Latin1_General_BIN2 LIKE N'%' + NCHAR(195) + N'%'
   OR [location] COLLATE Latin1_General_BIN2 LIKE N'%' + NCHAR(195) + N'%';

-- 4. CSV quoting handled (no leftover quote characters)
INSERT INTO #bronze_checks
SELECT N'no stray quotes in URLs', COUNT(*), N'0', CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END
FROM (
    SELECT [url] FROM bronze.circuits     UNION ALL
    SELECT [url] FROM bronze.drivers      UNION ALL
    SELECT [url] FROM bronze.constructors UNION ALL
    SELECT [url] FROM bronze.races
) AS u
WHERE u.[url] LIKE N'%"%';

-- 5. Header row skipped
INSERT INTO #bronze_checks
SELECT N'no header row loaded as data', COUNT(*), N'0', CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END
FROM (
    SELECT raceId FROM bronze.races   WHERE raceId = N'raceId'
    UNION ALL
    SELECT resultId FROM bronze.results WHERE resultId = N'resultId'
) AS h;

SELECT
    check_name,
    actual,
    expected,
    CASE WHEN passed = 1 THEN 'PASS' ELSE 'FAIL' END AS status
FROM #bronze_checks
ORDER BY passed, check_name;
