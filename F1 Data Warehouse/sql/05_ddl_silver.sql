/*
===============================================================================
05 - DDL: Silver Tables
===============================================================================
Purpose:
    Cleaned, typed copies of the bronze tables.

Conventions:
    - snake_case names; source ids keep their meaning: race_id = raceId, etc.
    - Times are stored as milliseconds (INT), never as TIME.
    - Missing values are NULL, never '\N' or 'NA'.
    - Primary keys on the natural ids, so a duplicate row fails the load
      instead of silently doubling numbers downstream.
    - dwh_create_date records when the row was loaded.

    No foreign keys: silver is reloaded with TRUNCATE. Referential integrity is
    checked by tests/quality_checks_silver.sql instead.
===============================================================================
*/

USE F1_DB2;
GO

IF OBJECT_ID(N'silver.circuits', N'U') IS NOT NULL DROP TABLE silver.circuits;
CREATE TABLE silver.circuits (
    circuit_id          INT             NOT NULL CONSTRAINT pk_silver_circuits PRIMARY KEY,
    circuit_ref         NVARCHAR(50)    NOT NULL,
    circuit_name        NVARCHAR(100)   NOT NULL,
    [location]          NVARCHAR(100)   NULL,
    country             NVARCHAR(100)   NULL,
    latitude            DECIMAL(9,6)    NULL,
    longitude           DECIMAL(9,6)    NULL,
    altitude_m          INT             NULL,
    wiki_url            NVARCHAR(255)   NULL,
    dwh_create_date     DATETIME2(0)    NOT NULL DEFAULT SYSDATETIME()
);
GO

IF OBJECT_ID(N'silver.constructors', N'U') IS NOT NULL DROP TABLE silver.constructors;
CREATE TABLE silver.constructors (
    constructor_id      INT             NOT NULL CONSTRAINT pk_silver_constructors PRIMARY KEY,
    constructor_ref     NVARCHAR(50)    NOT NULL,
    constructor_name    NVARCHAR(100)   NOT NULL,
    nationality         NVARCHAR(50)    NULL,
    wiki_url            NVARCHAR(255)   NULL,
    dwh_create_date     DATETIME2(0)    NOT NULL DEFAULT SYSDATETIME()
);
GO

IF OBJECT_ID(N'silver.drivers', N'U') IS NOT NULL DROP TABLE silver.drivers;
CREATE TABLE silver.drivers (
    driver_id           INT             NOT NULL CONSTRAINT pk_silver_drivers PRIMARY KEY,
    driver_ref          NVARCHAR(50)    NOT NULL,
    permanent_number    SMALLINT        NULL,       -- only drivers since 2014
    driver_code         NVARCHAR(3)     NULL,       -- 3-letter code, mostly modern era
    forename            NVARCHAR(100)   NOT NULL,
    surname             NVARCHAR(100)   NOT NULL,
    date_of_birth       DATE            NULL,
    nationality         NVARCHAR(50)    NULL,
    wiki_url            NVARCHAR(255)   NULL,
    dwh_create_date     DATETIME2(0)    NOT NULL DEFAULT SYSDATETIME()
);
GO

IF OBJECT_ID(N'silver.seasons', N'U') IS NOT NULL DROP TABLE silver.seasons;
CREATE TABLE silver.seasons (
    season_year         SMALLINT        NOT NULL CONSTRAINT pk_silver_seasons PRIMARY KEY,
    wiki_url            NVARCHAR(255)   NULL,
    dwh_create_date     DATETIME2(0)    NOT NULL DEFAULT SYSDATETIME()
);
GO

IF OBJECT_ID(N'silver.status', N'U') IS NOT NULL DROP TABLE silver.status;
CREATE TABLE silver.status (
    status_id           INT             NOT NULL CONSTRAINT pk_silver_status PRIMARY KEY,
    [status]            NVARCHAR(100)   NOT NULL,
    dwh_create_date     DATETIME2(0)    NOT NULL DEFAULT SYSDATETIME()
);
GO

-- Session times in the source are UTC.
IF OBJECT_ID(N'silver.races', N'U') IS NOT NULL DROP TABLE silver.races;
CREATE TABLE silver.races (
    race_id             INT             NOT NULL CONSTRAINT pk_silver_races PRIMARY KEY,
    season_year         SMALLINT        NOT NULL,
    round               SMALLINT        NOT NULL,
    circuit_id          INT             NOT NULL,
    race_name           NVARCHAR(100)   NOT NULL,
    race_date           DATE            NOT NULL,
    race_time_utc       TIME(0)         NULL,       -- known from 2005 onward
    race_datetime_utc   DATETIME2(0)    NULL,
    fp1_date            DATE            NULL,
    fp1_time_utc        TIME(0)         NULL,
    fp2_date            DATE            NULL,
    fp2_time_utc        TIME(0)         NULL,
    fp3_date            DATE            NULL,
    fp3_time_utc        TIME(0)         NULL,
    quali_date          DATE            NULL,
    quali_time_utc      TIME(0)         NULL,
    sprint_date         DATE            NULL,
    sprint_time_utc     TIME(0)         NULL,
    wiki_url            NVARCHAR(255)   NULL,
    dwh_create_date     DATETIME2(0)    NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT uq_silver_races_season_round UNIQUE (season_year, round)
);
GO

-- position is NULL when the driver was not classified; position_text then holds
-- the reason code: R retired, D disqualified, E excluded, W withdrew,
-- F failed to qualify, N not classified. (From 2025 the source fills position
-- for retirements too; silver sets it back to NULL so it always means
-- "classified finishing position".)
IF OBJECT_ID(N'silver.results', N'U') IS NOT NULL DROP TABLE silver.results;
CREATE TABLE silver.results (
    result_id               INT             NOT NULL CONSTRAINT pk_silver_results PRIMARY KEY,
    race_id                 INT             NOT NULL,
    driver_id               INT             NOT NULL,
    constructor_id          INT             NOT NULL,
    car_number              SMALLINT        NULL,
    grid                    SMALLINT        NULL,   -- 0 = pit-lane start / no grid slot
    position                SMALLINT        NULL,
    position_text           NVARCHAR(3)     NOT NULL,
    position_order          SMALLINT        NOT NULL,
    points                  DECIMAL(5,2)    NOT NULL,
    laps                    SMALLINT        NOT NULL,
    race_time_text          NVARCHAR(20)    NULL,   -- winner: total time; others: gap ('+5.478')
    race_time_ms            INT             NULL,
    fastest_lap             SMALLINT        NULL,
    fastest_lap_rank        SMALLINT        NULL,
    fastest_lap_ms          INT             NULL,
    fastest_lap_speed_kph   DECIMAL(7,3)    NULL,
    status_id               INT             NULL,   -- NULL when the source has no status yet
    dwh_create_date         DATETIME2(0)    NOT NULL DEFAULT SYSDATETIME()
);
GO

IF OBJECT_ID(N'silver.sprint_results', N'U') IS NOT NULL DROP TABLE silver.sprint_results;
CREATE TABLE silver.sprint_results (
    result_id               INT             NOT NULL CONSTRAINT pk_silver_sprint_results PRIMARY KEY,
    race_id                 INT             NOT NULL,
    driver_id               INT             NOT NULL,
    constructor_id          INT             NOT NULL,
    car_number              SMALLINT        NULL,
    grid                    SMALLINT        NULL,
    position                SMALLINT        NULL,
    position_text           NVARCHAR(3)     NOT NULL,
    position_order          SMALLINT        NOT NULL,
    points                  DECIMAL(5,2)    NOT NULL,
    laps                    SMALLINT        NOT NULL,
    race_time_text          NVARCHAR(20)    NULL,
    race_time_ms            INT             NULL,
    fastest_lap             SMALLINT        NULL,
    fastest_lap_rank        SMALLINT        NULL,
    fastest_lap_ms          INT             NULL,
    status_id               INT             NULL,   -- e.g. 2026 withdrawals arrive with '\N'
    dwh_create_date         DATETIME2(0)    NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT uq_silver_sprint_race_driver UNIQUE (race_id, driver_id)
);
GO

IF OBJECT_ID(N'silver.qualifying', N'U') IS NOT NULL DROP TABLE silver.qualifying;
CREATE TABLE silver.qualifying (
    qualify_id          INT             NOT NULL CONSTRAINT pk_silver_qualifying PRIMARY KEY,
    race_id             INT             NOT NULL,
    driver_id           INT             NOT NULL,
    constructor_id      INT             NOT NULL,
    car_number          SMALLINT        NULL,
    position            SMALLINT        NOT NULL,
    q1_ms               INT             NULL,
    q2_ms               INT             NULL,
    q3_ms               INT             NULL,
    dwh_create_date     DATETIME2(0)    NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT uq_silver_qualifying_race_driver UNIQUE (race_id, driver_id)
);
GO

IF OBJECT_ID(N'silver.lap_times', N'U') IS NOT NULL DROP TABLE silver.lap_times;
CREATE TABLE silver.lap_times (
    race_id             INT             NOT NULL,
    driver_id           INT             NOT NULL,
    lap                 SMALLINT        NOT NULL,
    position            SMALLINT        NULL,
    lap_time_ms         INT             NULL,
    dwh_create_date     DATETIME2(0)    NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT pk_silver_lap_times PRIMARY KEY (race_id, driver_id, lap)
);
GO

-- duration_ms above ~2 minutes is a red-flag suspension or a garage repair,
-- not a normal stop. Kept here; flagged in gold.
IF OBJECT_ID(N'silver.pit_stops', N'U') IS NOT NULL DROP TABLE silver.pit_stops;
CREATE TABLE silver.pit_stops (
    race_id             INT             NOT NULL,
    driver_id           INT             NOT NULL,
    stop_number         SMALLINT        NOT NULL,
    lap                 SMALLINT        NOT NULL,
    local_time          TIME(0)         NULL,       -- local clock time at the circuit
    duration_ms         INT             NULL,
    dwh_create_date     DATETIME2(0)    NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT pk_silver_pit_stops PRIMARY KEY (race_id, driver_id, stop_number)
);
GO

-- Standings are a cumulative snapshot after each race. Never sum them.
IF OBJECT_ID(N'silver.driver_standings', N'U') IS NOT NULL DROP TABLE silver.driver_standings;
CREATE TABLE silver.driver_standings (
    driver_standings_id INT             NOT NULL CONSTRAINT pk_silver_driver_standings PRIMARY KEY,
    race_id             INT             NOT NULL,
    driver_id           INT             NOT NULL,
    points              DECIMAL(6,2)    NOT NULL,
    position            SMALLINT        NULL,
    position_text       NVARCHAR(3)     NULL,
    wins                SMALLINT        NOT NULL,
    dwh_create_date     DATETIME2(0)    NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT uq_silver_driver_standings_race_driver UNIQUE (race_id, driver_id)
);
GO

IF OBJECT_ID(N'silver.constructor_standings', N'U') IS NOT NULL DROP TABLE silver.constructor_standings;
CREATE TABLE silver.constructor_standings (
    constructor_standings_id    INT             NOT NULL CONSTRAINT pk_silver_constructor_standings PRIMARY KEY,
    race_id                     INT             NOT NULL,
    constructor_id              INT             NOT NULL,
    points                      DECIMAL(6,2)    NOT NULL,
    position                    SMALLINT        NULL,
    position_text               NVARCHAR(3)     NULL,
    wins                        SMALLINT        NOT NULL,
    dwh_create_date             DATETIME2(0)    NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT uq_silver_constructor_standings_race_cons UNIQUE (race_id, constructor_id)
);
GO

IF OBJECT_ID(N'silver.constructor_results', N'U') IS NOT NULL DROP TABLE silver.constructor_results;
CREATE TABLE silver.constructor_results (
    constructor_results_id  INT             NOT NULL CONSTRAINT pk_silver_constructor_results PRIMARY KEY,
    race_id                 INT             NOT NULL,
    constructor_id          INT             NOT NULL,
    points                  DECIMAL(5,2)    NOT NULL,
    [status]                NVARCHAR(3)     NULL,       -- 'D' = disqualified
    dwh_create_date         DATETIME2(0)    NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT uq_silver_constructor_results_race_cons UNIQUE (race_id, constructor_id)
);
GO
