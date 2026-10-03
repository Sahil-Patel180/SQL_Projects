/*
===============================================================================
01 - Pipeline Run Log
===============================================================================
Purpose:
    meta.load_log keeps one row per table per load: rows loaded, duration,
    success / failure and the error message. Every load procedure writes here,
    so a failed or partial run is visible after the fact, not only in the
    SSMS Messages tab.

Useful query:
    SELECT TOP (50) * FROM meta.load_log ORDER BY log_id DESC;
===============================================================================
*/

USE F1_DB2;
GO

IF OBJECT_ID(N'meta.load_log', N'U') IS NOT NULL
    DROP TABLE meta.load_log;
GO

CREATE TABLE meta.load_log (
    log_id          INT IDENTITY(1,1)   NOT NULL CONSTRAINT pk_load_log PRIMARY KEY,
    run_id          UNIQUEIDENTIFIER    NOT NULL,
    layer           VARCHAR(10)         NOT NULL,   -- bronze | silver
    table_name      SYSNAME             NOT NULL,
    rows_loaded     INT                 NULL,
    started_at      DATETIME2(3)        NOT NULL,
    finished_at     DATETIME2(3)        NULL,
    duration_sec    AS DATEDIFF(MILLISECOND, started_at, finished_at) / 1000.0,
    status          VARCHAR(10)         NOT NULL,   -- success | failed
    error_message   NVARCHAR(4000)      NULL
);
GO
