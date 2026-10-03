/*
===============================================================================
03 - Stored Procedure: Load Bronze (CSV -> bronze)
===============================================================================
Purpose:
    Truncates each bronze table and bulk-loads its CSV from @source_path.

Parameters:
    @source_path  Folder holding the 14 Kaggle CSVs, e.g. N'C:\f1_data\raw\'.
                  The SQL Server service account must be able to read it
                  (see README > Troubleshooting).
    @run_id       Optional. Groups the log rows of one pipeline run.

Load options, and why:
    FORMAT = 'CSV', FIELDQUOTE = '"'  Kaggle quotes text fields; a few URLs
                                       contain commas inside the quotes.
    CODEPAGE = '65001'                 Files are UTF-8. Without it accented
                                       names arrive garbled (RÃ¤ikkÃ¶nen).
    ROWTERMINATOR = '0x0a'             Files use LF line endings. If a copy
                                       has CRLF, silver strips the stray CR.
    FIRSTROW = 2                       Skip the header row.

    Requires SQL Server 2017 or later (FORMAT = 'CSV').

Usage:
    EXEC bronze.load_bronze @source_path = N'C:\f1_data\raw\';
===============================================================================
*/

USE F1_DB;
GO

CREATE OR ALTER PROCEDURE bronze.load_bronze
    @source_path    NVARCHAR(400),
    @run_id         UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @run_id IS NULL SET @run_id = NEWID();
    IF RIGHT(@source_path, 1) <> N'\' SET @source_path += N'\';

    DECLARE @files TABLE (
        seq         INT IDENTITY(1,1),
        table_name  SYSNAME,
        file_name   NVARCHAR(100)
    );

    INSERT INTO @files (table_name, file_name)
    VALUES  (N'circuits',              N'circuits.csv'),
            (N'constructors',          N'constructors.csv'),
            (N'drivers',               N'drivers.csv'),
            (N'seasons',               N'seasons.csv'),
            (N'status',                N'status.csv'),
            (N'races',                 N'races.csv'),
            (N'results',               N'results.csv'),
            (N'sprint_results',        N'sprint_results.csv'),
            (N'qualifying',            N'qualifying.csv'),
            (N'lap_times',             N'lap_times.csv'),
            (N'pit_stops',             N'pit_stops.csv'),
            (N'driver_standings',      N'driver_standings.csv'),
            (N'constructor_standings', N'constructor_standings.csv'),
            (N'constructor_results',   N'constructor_results.csv');

    DECLARE @i              INT = 1,
            @n              INT = (SELECT COUNT(*) FROM @files),
            @table_name     SYSNAME,
            @file_path      NVARCHAR(600),
            @sql            NVARCHAR(MAX),
            @rows           INT,
            @started_at     DATETIME2(3),
            @batch_start    DATETIME2(3) = SYSDATETIME();

    PRINT '================================================================';
    PRINT 'Loading bronze layer from ' + @source_path;
    PRINT '================================================================';

    WHILE @i <= @n
    BEGIN
        SELECT  @table_name = table_name,
                @file_path  = @source_path + file_name
        FROM    @files
        WHERE   seq = @i;

        SET @started_at = SYSDATETIME();

        BEGIN TRY
            -- Path is embedded as a literal (BULK INSERT does not accept a variable);
            -- single quotes in the path are escaped.
            SET @sql = N'
                TRUNCATE TABLE bronze.' + QUOTENAME(@table_name) + N';
                BULK INSERT bronze.' + QUOTENAME(@table_name) + N'
                FROM N''' + REPLACE(@file_path, N'''', N'''''') + N'''
                WITH (
                    FORMAT          = ''CSV'',
                    FIRSTROW        = 2,
                    FIELDQUOTE      = ''"'',
                    FIELDTERMINATOR = '','',
                    ROWTERMINATOR   = ''0x0a'',
                    CODEPAGE        = ''65001'',
                    TABLOCK
                );
                SET @rows_out = @@ROWCOUNT;';

            EXEC sys.sp_executesql @sql, N'@rows_out INT OUTPUT', @rows_out = @rows OUTPUT;

            INSERT INTO meta.load_log (run_id, layer, table_name, rows_loaded, started_at, finished_at, status)
            VALUES (@run_id, 'bronze', @table_name, @rows, @started_at, SYSDATETIME(), 'success');

            PRINT '>> bronze.' + @table_name + ': ' + CAST(@rows AS VARCHAR(12)) + ' rows';
        END TRY
        BEGIN CATCH
            INSERT INTO meta.load_log (run_id, layer, table_name, started_at, finished_at, status, error_message)
            VALUES (@run_id, 'bronze', @table_name, @started_at, SYSDATETIME(), 'failed', ERROR_MESSAGE());

            PRINT '!! FAILED bronze.' + @table_name + ' from ' + @file_path;
            PRINT '!! ' + ERROR_MESSAGE();
            THROW;
        END CATCH;

        SET @i += 1;
    END;

    PRINT '================================================================';
    PRINT 'Bronze load complete in '
          + CAST(DATEDIFF(SECOND, @batch_start, SYSDATETIME()) AS VARCHAR(10)) + ' s';
    PRINT '================================================================';
END;
GO
