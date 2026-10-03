/*
===============================================================================
06 - Stored Procedure: Load Silver (bronze -> silver)
===============================================================================
Purpose:
    Truncates and reloads every silver table from bronze:
      - dbo.fn_clean      strips CR/LF and spaces, turns '\N' / '' into NULL
      - TRY_CAST          types numbers and dates (bad value -> NULL, and a
                          NULL in a NOT NULL column fails the load loudly)
      - dbo.fn_time_to_ms converts 'm:ss.fff' strings to milliseconds

    Each table is logged to meta.load_log. Any error is logged and re-thrown,
    so a failed load can never look like a success.

Usage:
    EXEC silver.load_silver;
===============================================================================
*/

USE F1_DB;
GO

CREATE OR ALTER PROCEDURE silver.load_silver
    @run_id UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @run_id IS NULL SET @run_id = NEWID();

    DECLARE @table_name     SYSNAME,
            @rows           INT,
            @started_at     DATETIME2(3),
            @batch_start    DATETIME2(3) = SYSDATETIME();

    PRINT '================================================================';
    PRINT 'Loading silver layer';
    PRINT '================================================================';

    BEGIN TRY

        ------------------------------------------------------------------ circuits
        SET @table_name = N'circuits'; SET @started_at = SYSDATETIME();
        TRUNCATE TABLE silver.circuits;
        INSERT INTO silver.circuits
            (circuit_id, circuit_ref, circuit_name, [location], country,
             latitude, longitude, altitude_m, wiki_url)
        SELECT
            TRY_CAST(dbo.fn_clean(circuitId) AS INT),
            dbo.fn_clean(circuitRef),
            dbo.fn_clean([name]),
            dbo.fn_clean([location]),
            dbo.fn_clean(country),
            TRY_CAST(dbo.fn_clean(lat) AS DECIMAL(9,6)),
            TRY_CAST(dbo.fn_clean(lng) AS DECIMAL(9,6)),
            TRY_CAST(dbo.fn_clean(alt) AS INT),
            dbo.fn_clean([url])
        FROM bronze.circuits;
        SET @rows = @@ROWCOUNT;
        INSERT INTO meta.load_log (run_id, layer, table_name, rows_loaded, started_at, finished_at, status)
        VALUES (@run_id, 'silver', @table_name, @rows, @started_at, SYSDATETIME(), 'success');
        PRINT '>> silver.' + @table_name + ': ' + CAST(@rows AS VARCHAR(12)) + ' rows';

        ------------------------------------------------------------------ constructors
        SET @table_name = N'constructors'; SET @started_at = SYSDATETIME();
        TRUNCATE TABLE silver.constructors;
        INSERT INTO silver.constructors
            (constructor_id, constructor_ref, constructor_name, nationality, wiki_url)
        SELECT
            TRY_CAST(dbo.fn_clean(constructorId) AS INT),
            dbo.fn_clean(constructorRef),
            dbo.fn_clean([name]),
            dbo.fn_clean(nationality),
            dbo.fn_clean([url])
        FROM bronze.constructors;
        SET @rows = @@ROWCOUNT;
        INSERT INTO meta.load_log (run_id, layer, table_name, rows_loaded, started_at, finished_at, status)
        VALUES (@run_id, 'silver', @table_name, @rows, @started_at, SYSDATETIME(), 'success');
        PRINT '>> silver.' + @table_name + ': ' + CAST(@rows AS VARCHAR(12)) + ' rows';

        ------------------------------------------------------------------ drivers
        SET @table_name = N'drivers'; SET @started_at = SYSDATETIME();
        TRUNCATE TABLE silver.drivers;
        INSERT INTO silver.drivers
            (driver_id, driver_ref, permanent_number, driver_code, forename, surname,
             date_of_birth, nationality, wiki_url)
        SELECT
            TRY_CAST(dbo.fn_clean(driverId) AS INT),
            dbo.fn_clean(driverRef),
            TRY_CAST(dbo.fn_clean(number) AS SMALLINT),
            dbo.fn_clean(code),
            dbo.fn_clean(forename),
            dbo.fn_clean(surname),
            TRY_CONVERT(DATE, dbo.fn_clean(dob), 23),          -- yyyy-mm-dd
            dbo.fn_clean(nationality),
            dbo.fn_clean([url])
        FROM bronze.drivers;
        SET @rows = @@ROWCOUNT;
        INSERT INTO meta.load_log (run_id, layer, table_name, rows_loaded, started_at, finished_at, status)
        VALUES (@run_id, 'silver', @table_name, @rows, @started_at, SYSDATETIME(), 'success');
        PRINT '>> silver.' + @table_name + ': ' + CAST(@rows AS VARCHAR(12)) + ' rows';

        ------------------------------------------------------------------ seasons
        SET @table_name = N'seasons'; SET @started_at = SYSDATETIME();
        TRUNCATE TABLE silver.seasons;
        INSERT INTO silver.seasons (season_year, wiki_url)
        SELECT
            TRY_CAST(dbo.fn_clean([year]) AS SMALLINT),
            dbo.fn_clean([url])
        FROM bronze.seasons;
        SET @rows = @@ROWCOUNT;
        INSERT INTO meta.load_log (run_id, layer, table_name, rows_loaded, started_at, finished_at, status)
        VALUES (@run_id, 'silver', @table_name, @rows, @started_at, SYSDATETIME(), 'success');
        PRINT '>> silver.' + @table_name + ': ' + CAST(@rows AS VARCHAR(12)) + ' rows';

        ------------------------------------------------------------------ status
        SET @table_name = N'status'; SET @started_at = SYSDATETIME();
        TRUNCATE TABLE silver.status;
        INSERT INTO silver.status (status_id, [status])
        SELECT
            TRY_CAST(dbo.fn_clean(statusId) AS INT),
            dbo.fn_clean([status])
        FROM bronze.status;
        SET @rows = @@ROWCOUNT;
        INSERT INTO meta.load_log (run_id, layer, table_name, rows_loaded, started_at, finished_at, status)
        VALUES (@run_id, 'silver', @table_name, @rows, @started_at, SYSDATETIME(), 'success');
        PRINT '>> silver.' + @table_name + ': ' + CAST(@rows AS VARCHAR(12)) + ' rows';

        ------------------------------------------------------------------ races
        SET @table_name = N'races'; SET @started_at = SYSDATETIME();
        TRUNCATE TABLE silver.races;
        INSERT INTO silver.races
            (race_id, season_year, round, circuit_id, race_name, race_date, race_time_utc,
             race_datetime_utc, fp1_date, fp1_time_utc, fp2_date, fp2_time_utc,
             fp3_date, fp3_time_utc, quali_date, quali_time_utc, sprint_date,
             sprint_time_utc, wiki_url)
        SELECT
            TRY_CAST(dbo.fn_clean(raceId) AS INT),
            TRY_CAST(dbo.fn_clean([year]) AS SMALLINT),
            TRY_CAST(dbo.fn_clean([round]) AS SMALLINT),
            TRY_CAST(dbo.fn_clean(circuitId) AS INT),
            dbo.fn_clean([name]),
            TRY_CONVERT(DATE, dbo.fn_clean([date]), 23),
            TRY_CAST(dbo.fn_clean([time]) AS TIME(0)),
            CASE WHEN dbo.fn_clean([time]) IS NOT NULL
                 THEN TRY_CONVERT(DATETIME2(0),
                                  dbo.fn_clean([date]) + N' ' + dbo.fn_clean([time]), 120)
            END,
            TRY_CONVERT(DATE, dbo.fn_clean(fp1_date), 23),
            TRY_CAST(dbo.fn_clean(fp1_time) AS TIME(0)),
            TRY_CONVERT(DATE, dbo.fn_clean(fp2_date), 23),
            TRY_CAST(dbo.fn_clean(fp2_time) AS TIME(0)),
            TRY_CONVERT(DATE, dbo.fn_clean(fp3_date), 23),
            TRY_CAST(dbo.fn_clean(fp3_time) AS TIME(0)),
            TRY_CONVERT(DATE, dbo.fn_clean(quali_date), 23),
            TRY_CAST(dbo.fn_clean(quali_time) AS TIME(0)),
            TRY_CONVERT(DATE, dbo.fn_clean(sprint_date), 23),
            TRY_CAST(dbo.fn_clean(sprint_time) AS TIME(0)),
            dbo.fn_clean([url])
        FROM bronze.races;
        SET @rows = @@ROWCOUNT;
        INSERT INTO meta.load_log (run_id, layer, table_name, rows_loaded, started_at, finished_at, status)
        VALUES (@run_id, 'silver', @table_name, @rows, @started_at, SYSDATETIME(), 'success');
        PRINT '>> silver.' + @table_name + ': ' + CAST(@rows AS VARCHAR(12)) + ' rows';

        ------------------------------------------------------------------ results
        SET @table_name = N'results'; SET @started_at = SYSDATETIME();
        TRUNCATE TABLE silver.results;
        INSERT INTO silver.results
            (result_id, race_id, driver_id, constructor_id, car_number, grid, position,
             position_text, position_order, points, laps, race_time_text, race_time_ms,
             fastest_lap, fastest_lap_rank, fastest_lap_ms, fastest_lap_speed_kph, status_id)
        SELECT
            TRY_CAST(dbo.fn_clean(resultId) AS INT),
            TRY_CAST(dbo.fn_clean(raceId) AS INT),
            TRY_CAST(dbo.fn_clean(driverId) AS INT),
            TRY_CAST(dbo.fn_clean(constructorId) AS INT),
            TRY_CAST(dbo.fn_clean(number) AS SMALLINT),
            TRY_CAST(dbo.fn_clean(grid) AS SMALLINT),
            -- position only for classified finishers (numeric positionText).
            -- From 2025 the source also numbers retirements ('R', 'W', 'D').
            CASE WHEN TRY_CAST(dbo.fn_clean(positionText) AS INT) IS NOT NULL
                 THEN TRY_CAST(dbo.fn_clean(position) AS SMALLINT) END,
            dbo.fn_clean(positionText),
            TRY_CAST(dbo.fn_clean(positionOrder) AS SMALLINT),
            TRY_CAST(dbo.fn_clean(points) AS DECIMAL(5,2)),
            TRY_CAST(dbo.fn_clean(laps) AS SMALLINT),
            dbo.fn_clean([time]),
            TRY_CAST(dbo.fn_clean(milliseconds) AS INT),
            TRY_CAST(dbo.fn_clean(fastestLap) AS SMALLINT),
            TRY_CAST(dbo.fn_clean([rank]) AS SMALLINT),
            dbo.fn_time_to_ms(fastestLapTime),
            TRY_CAST(dbo.fn_clean(fastestLapSpeed) AS DECIMAL(7,3)),
            TRY_CAST(dbo.fn_clean(statusId) AS INT)
        FROM bronze.results;
        SET @rows = @@ROWCOUNT;
        INSERT INTO meta.load_log (run_id, layer, table_name, rows_loaded, started_at, finished_at, status)
        VALUES (@run_id, 'silver', @table_name, @rows, @started_at, SYSDATETIME(), 'success');
        PRINT '>> silver.' + @table_name + ': ' + CAST(@rows AS VARCHAR(12)) + ' rows';

        ------------------------------------------------------------------ sprint_results
        SET @table_name = N'sprint_results'; SET @started_at = SYSDATETIME();
        TRUNCATE TABLE silver.sprint_results;
        INSERT INTO silver.sprint_results
            (result_id, race_id, driver_id, constructor_id, car_number, grid, position,
             position_text, position_order, points, laps, race_time_text, race_time_ms,
             fastest_lap, fastest_lap_rank, fastest_lap_ms, status_id)
        SELECT
            TRY_CAST(dbo.fn_clean(resultId) AS INT),
            TRY_CAST(dbo.fn_clean(raceId) AS INT),
            TRY_CAST(dbo.fn_clean(driverId) AS INT),
            TRY_CAST(dbo.fn_clean(constructorId) AS INT),
            TRY_CAST(dbo.fn_clean(number) AS SMALLINT),
            TRY_CAST(dbo.fn_clean(grid) AS SMALLINT),
            -- position only for classified finishers (numeric positionText).
            -- From 2025 the source also numbers retirements ('R', 'W', 'D').
            CASE WHEN TRY_CAST(dbo.fn_clean(positionText) AS INT) IS NOT NULL
                 THEN TRY_CAST(dbo.fn_clean(position) AS SMALLINT) END,
            dbo.fn_clean(positionText),
            TRY_CAST(dbo.fn_clean(positionOrder) AS SMALLINT),
            TRY_CAST(dbo.fn_clean(points) AS DECIMAL(5,2)),
            TRY_CAST(dbo.fn_clean(laps) AS SMALLINT),
            dbo.fn_clean([time]),
            TRY_CAST(dbo.fn_clean(milliseconds) AS INT),
            TRY_CAST(dbo.fn_clean(fastestLap) AS SMALLINT),
            TRY_CAST(dbo.fn_clean([rank]) AS SMALLINT),
            dbo.fn_time_to_ms(fastestLapTime),
            TRY_CAST(dbo.fn_clean(statusId) AS INT)
        FROM bronze.sprint_results;
        SET @rows = @@ROWCOUNT;
        INSERT INTO meta.load_log (run_id, layer, table_name, rows_loaded, started_at, finished_at, status)
        VALUES (@run_id, 'silver', @table_name, @rows, @started_at, SYSDATETIME(), 'success');
        PRINT '>> silver.' + @table_name + ': ' + CAST(@rows AS VARCHAR(12)) + ' rows';

        ------------------------------------------------------------------ qualifying
        SET @table_name = N'qualifying'; SET @started_at = SYSDATETIME();
        TRUNCATE TABLE silver.qualifying;
        INSERT INTO silver.qualifying
            (qualify_id, race_id, driver_id, constructor_id, car_number, position,
             q1_ms, q2_ms, q3_ms)
        SELECT
            TRY_CAST(dbo.fn_clean(qualifyId) AS INT),
            TRY_CAST(dbo.fn_clean(raceId) AS INT),
            TRY_CAST(dbo.fn_clean(driverId) AS INT),
            TRY_CAST(dbo.fn_clean(constructorId) AS INT),
            TRY_CAST(dbo.fn_clean(number) AS SMALLINT),
            TRY_CAST(dbo.fn_clean(position) AS SMALLINT),
            dbo.fn_time_to_ms(q1),
            dbo.fn_time_to_ms(q2),
            dbo.fn_time_to_ms(q3)
        FROM bronze.qualifying;
        SET @rows = @@ROWCOUNT;
        INSERT INTO meta.load_log (run_id, layer, table_name, rows_loaded, started_at, finished_at, status)
        VALUES (@run_id, 'silver', @table_name, @rows, @started_at, SYSDATETIME(), 'success');
        PRINT '>> silver.' + @table_name + ': ' + CAST(@rows AS VARCHAR(12)) + ' rows';

        ------------------------------------------------------------------ lap_times
        -- milliseconds is already given, so the 'm:ss.fff' text column is not kept.
        SET @table_name = N'lap_times'; SET @started_at = SYSDATETIME();
        TRUNCATE TABLE silver.lap_times;
        INSERT INTO silver.lap_times (race_id, driver_id, lap, position, lap_time_ms)
        SELECT
            TRY_CAST(dbo.fn_clean(raceId) AS INT),
            TRY_CAST(dbo.fn_clean(driverId) AS INT),
            TRY_CAST(dbo.fn_clean(lap) AS SMALLINT),
            TRY_CAST(dbo.fn_clean(position) AS SMALLINT),
            TRY_CAST(dbo.fn_clean(milliseconds) AS INT)
        FROM bronze.lap_times;
        SET @rows = @@ROWCOUNT;
        INSERT INTO meta.load_log (run_id, layer, table_name, rows_loaded, started_at, finished_at, status)
        VALUES (@run_id, 'silver', @table_name, @rows, @started_at, SYSDATETIME(), 'success');
        PRINT '>> silver.' + @table_name + ': ' + CAST(@rows AS VARCHAR(12)) + ' rows';

        ------------------------------------------------------------------ pit_stops
        -- duration text ('1:09.764' for long stops) is dropped; milliseconds is the truth.
        SET @table_name = N'pit_stops'; SET @started_at = SYSDATETIME();
        TRUNCATE TABLE silver.pit_stops;
        INSERT INTO silver.pit_stops (race_id, driver_id, stop_number, lap, local_time, duration_ms)
        SELECT
            TRY_CAST(dbo.fn_clean(raceId) AS INT),
            TRY_CAST(dbo.fn_clean(driverId) AS INT),
            TRY_CAST(dbo.fn_clean([stop]) AS SMALLINT),
            TRY_CAST(dbo.fn_clean(lap) AS SMALLINT),
            TRY_CAST(dbo.fn_clean([time]) AS TIME(0)),
            TRY_CAST(dbo.fn_clean(milliseconds) AS INT)
        FROM bronze.pit_stops;
        SET @rows = @@ROWCOUNT;
        INSERT INTO meta.load_log (run_id, layer, table_name, rows_loaded, started_at, finished_at, status)
        VALUES (@run_id, 'silver', @table_name, @rows, @started_at, SYSDATETIME(), 'success');
        PRINT '>> silver.' + @table_name + ': ' + CAST(@rows AS VARCHAR(12)) + ' rows';

        ------------------------------------------------------------------ driver_standings
        SET @table_name = N'driver_standings'; SET @started_at = SYSDATETIME();
        TRUNCATE TABLE silver.driver_standings;
        INSERT INTO silver.driver_standings
            (driver_standings_id, race_id, driver_id, points, position, position_text, wins)
        SELECT
            TRY_CAST(dbo.fn_clean(driverStandingsId) AS INT),
            TRY_CAST(dbo.fn_clean(raceId) AS INT),
            TRY_CAST(dbo.fn_clean(driverId) AS INT),
            TRY_CAST(dbo.fn_clean(points) AS DECIMAL(6,2)),
            TRY_CAST(dbo.fn_clean(position) AS SMALLINT),
            dbo.fn_clean(positionText),
            TRY_CAST(dbo.fn_clean(wins) AS SMALLINT)
        FROM bronze.driver_standings;
        SET @rows = @@ROWCOUNT;
        INSERT INTO meta.load_log (run_id, layer, table_name, rows_loaded, started_at, finished_at, status)
        VALUES (@run_id, 'silver', @table_name, @rows, @started_at, SYSDATETIME(), 'success');
        PRINT '>> silver.' + @table_name + ': ' + CAST(@rows AS VARCHAR(12)) + ' rows';

        ------------------------------------------------------------------ constructor_standings
        SET @table_name = N'constructor_standings'; SET @started_at = SYSDATETIME();
        TRUNCATE TABLE silver.constructor_standings;
        INSERT INTO silver.constructor_standings
            (constructor_standings_id, race_id, constructor_id, points, position, position_text, wins)
        SELECT
            TRY_CAST(dbo.fn_clean(constructorStandingsId) AS INT),
            TRY_CAST(dbo.fn_clean(raceId) AS INT),
            TRY_CAST(dbo.fn_clean(constructorId) AS INT),
            TRY_CAST(dbo.fn_clean(points) AS DECIMAL(6,2)),
            TRY_CAST(dbo.fn_clean(position) AS SMALLINT),
            dbo.fn_clean(positionText),
            TRY_CAST(dbo.fn_clean(wins) AS SMALLINT)
        FROM bronze.constructor_standings;
        SET @rows = @@ROWCOUNT;
        INSERT INTO meta.load_log (run_id, layer, table_name, rows_loaded, started_at, finished_at, status)
        VALUES (@run_id, 'silver', @table_name, @rows, @started_at, SYSDATETIME(), 'success');
        PRINT '>> silver.' + @table_name + ': ' + CAST(@rows AS VARCHAR(12)) + ' rows';

        ------------------------------------------------------------------ constructor_results
        SET @table_name = N'constructor_results'; SET @started_at = SYSDATETIME();
        TRUNCATE TABLE silver.constructor_results;
        INSERT INTO silver.constructor_results
            (constructor_results_id, race_id, constructor_id, points, [status])
        SELECT
            TRY_CAST(dbo.fn_clean(constructorResultsId) AS INT),
            TRY_CAST(dbo.fn_clean(raceId) AS INT),
            TRY_CAST(dbo.fn_clean(constructorId) AS INT),
            TRY_CAST(dbo.fn_clean(points) AS DECIMAL(5,2)),
            dbo.fn_clean([status])
        FROM bronze.constructor_results;
        SET @rows = @@ROWCOUNT;
        INSERT INTO meta.load_log (run_id, layer, table_name, rows_loaded, started_at, finished_at, status)
        VALUES (@run_id, 'silver', @table_name, @rows, @started_at, SYSDATETIME(), 'success');
        PRINT '>> silver.' + @table_name + ': ' + CAST(@rows AS VARCHAR(12)) + ' rows';

    END TRY
    BEGIN CATCH
        INSERT INTO meta.load_log (run_id, layer, table_name, started_at, finished_at, status, error_message)
        VALUES (@run_id, 'silver', @table_name, @started_at, SYSDATETIME(), 'failed', ERROR_MESSAGE());

        PRINT '!! FAILED silver.' + @table_name;
        PRINT '!! ' + ERROR_MESSAGE();
        THROW;
    END CATCH;

    PRINT '================================================================';
    PRINT 'Silver load complete in '
          + CAST(DATEDIFF(SECOND, @batch_start, SYSDATETIME()) AS VARCHAR(10)) + ' s';
    PRINT '================================================================';
END;
GO

/*
-------------------------------------------------------------------------------
Pipeline wrapper: bronze + silver in one call, one run_id in the log.
Gold is views, so it is current as soon as silver is.

    EXEC meta.run_pipeline @source_path = N'C:\f1_data\raw\';
-------------------------------------------------------------------------------
*/
CREATE OR ALTER PROCEDURE meta.run_pipeline
    @source_path NVARCHAR(400)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @run_id UNIQUEIDENTIFIER = NEWID();

    EXEC bronze.load_bronze @source_path = @source_path, @run_id = @run_id;
    EXEC silver.load_silver @run_id = @run_id;

    SELECT layer, table_name, rows_loaded, duration_sec, status
    FROM   meta.load_log
    WHERE  run_id = @run_id
    ORDER  BY log_id;
END;
GO
