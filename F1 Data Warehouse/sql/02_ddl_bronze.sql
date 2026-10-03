/*
===============================================================================
02 - DDL: Bronze Tables
===============================================================================
Purpose:
    One table per Kaggle CSV, same name, same column names, same order.

Design:
    Every column is NVARCHAR. Bronze stores the file exactly as delivered,
    including the literal '\N' the source uses for missing values. Typing and
    cleaning happen in silver, so a bad value never stops the raw load and the
    original text is always available for comparison.

    NVARCHAR (not VARCHAR) keeps accented names intact:
    Räikkönen, Pérez, São Paulo, Nürburgring.
===============================================================================
*/

USE F1_DB;
GO

IF OBJECT_ID(N'bronze.circuits', N'U') IS NOT NULL DROP TABLE bronze.circuits;
CREATE TABLE bronze.circuits (
    circuitId       NVARCHAR(10),
    circuitRef      NVARCHAR(50),
    [name]          NVARCHAR(100),
    [location]      NVARCHAR(100),
    country         NVARCHAR(100),
    lat             NVARCHAR(20),
    lng             NVARCHAR(20),
    alt             NVARCHAR(20),
    [url]           NVARCHAR(255)
);
GO

IF OBJECT_ID(N'bronze.constructor_results', N'U') IS NOT NULL DROP TABLE bronze.constructor_results;
CREATE TABLE bronze.constructor_results (
    constructorResultsId    NVARCHAR(10),
    raceId                  NVARCHAR(10),
    constructorId           NVARCHAR(10),
    points                  NVARCHAR(20),
    [status]                NVARCHAR(10)
);
GO

IF OBJECT_ID(N'bronze.constructor_standings', N'U') IS NOT NULL DROP TABLE bronze.constructor_standings;
CREATE TABLE bronze.constructor_standings (
    constructorStandingsId  NVARCHAR(10),
    raceId                  NVARCHAR(10),
    constructorId           NVARCHAR(10),
    points                  NVARCHAR(20),
    position                NVARCHAR(10),
    positionText            NVARCHAR(10),
    wins                    NVARCHAR(10)
);
GO

IF OBJECT_ID(N'bronze.constructors', N'U') IS NOT NULL DROP TABLE bronze.constructors;
CREATE TABLE bronze.constructors (
    constructorId   NVARCHAR(10),
    constructorRef  NVARCHAR(50),
    [name]          NVARCHAR(100),
    nationality     NVARCHAR(50),
    [url]           NVARCHAR(255)
);
GO

IF OBJECT_ID(N'bronze.driver_standings', N'U') IS NOT NULL DROP TABLE bronze.driver_standings;
CREATE TABLE bronze.driver_standings (
    driverStandingsId   NVARCHAR(10),
    raceId              NVARCHAR(10),
    driverId            NVARCHAR(10),
    points              NVARCHAR(20),
    position            NVARCHAR(10),
    positionText        NVARCHAR(10),
    wins                NVARCHAR(10)
);
GO

IF OBJECT_ID(N'bronze.drivers', N'U') IS NOT NULL DROP TABLE bronze.drivers;
CREATE TABLE bronze.drivers (
    driverId        NVARCHAR(10),
    driverRef       NVARCHAR(50),
    number          NVARCHAR(10),
    code            NVARCHAR(10),
    forename        NVARCHAR(100),
    surname         NVARCHAR(100),
    dob             NVARCHAR(20),
    nationality     NVARCHAR(50),
    [url]           NVARCHAR(255)
);
GO

IF OBJECT_ID(N'bronze.lap_times', N'U') IS NOT NULL DROP TABLE bronze.lap_times;
CREATE TABLE bronze.lap_times (
    raceId          NVARCHAR(10),
    driverId        NVARCHAR(10),
    lap             NVARCHAR(10),
    position        NVARCHAR(10),
    [time]          NVARCHAR(20),
    milliseconds    NVARCHAR(20)
);
GO

IF OBJECT_ID(N'bronze.pit_stops', N'U') IS NOT NULL DROP TABLE bronze.pit_stops;
CREATE TABLE bronze.pit_stops (
    raceId          NVARCHAR(10),
    driverId        NVARCHAR(10),
    [stop]          NVARCHAR(10),
    lap             NVARCHAR(10),
    [time]          NVARCHAR(20),
    duration        NVARCHAR(20),
    milliseconds    NVARCHAR(20)
);
GO

IF OBJECT_ID(N'bronze.qualifying', N'U') IS NOT NULL DROP TABLE bronze.qualifying;
CREATE TABLE bronze.qualifying (
    qualifyId       NVARCHAR(10),
    raceId          NVARCHAR(10),
    driverId        NVARCHAR(10),
    constructorId   NVARCHAR(10),
    number          NVARCHAR(10),
    position        NVARCHAR(10),
    q1              NVARCHAR(20),
    q2              NVARCHAR(20),
    q3              NVARCHAR(20)
);
GO

IF OBJECT_ID(N'bronze.races', N'U') IS NOT NULL DROP TABLE bronze.races;
CREATE TABLE bronze.races (
    raceId          NVARCHAR(10),
    [year]          NVARCHAR(10),
    [round]         NVARCHAR(10),
    circuitId       NVARCHAR(10),
    [name]          NVARCHAR(100),
    [date]          NVARCHAR(20),
    [time]          NVARCHAR(20),
    [url]           NVARCHAR(255),
    fp1_date        NVARCHAR(20),
    fp1_time        NVARCHAR(20),
    fp2_date        NVARCHAR(20),
    fp2_time        NVARCHAR(20),
    fp3_date        NVARCHAR(20),
    fp3_time        NVARCHAR(20),
    quali_date      NVARCHAR(20),
    quali_time      NVARCHAR(20),
    sprint_date     NVARCHAR(20),
    sprint_time     NVARCHAR(20)
);
GO

IF OBJECT_ID(N'bronze.results', N'U') IS NOT NULL DROP TABLE bronze.results;
CREATE TABLE bronze.results (
    resultId        NVARCHAR(10),
    raceId          NVARCHAR(10),
    driverId        NVARCHAR(10),
    constructorId   NVARCHAR(10),
    number          NVARCHAR(10),
    grid            NVARCHAR(10),
    position        NVARCHAR(10),
    positionText    NVARCHAR(10),
    positionOrder   NVARCHAR(10),
    points          NVARCHAR(20),
    laps            NVARCHAR(10),
    [time]          NVARCHAR(20),
    milliseconds    NVARCHAR(20),
    fastestLap      NVARCHAR(10),
    [rank]          NVARCHAR(10),
    fastestLapTime  NVARCHAR(20),
    fastestLapSpeed NVARCHAR(20),
    statusId        NVARCHAR(10)
);
GO

IF OBJECT_ID(N'bronze.seasons', N'U') IS NOT NULL DROP TABLE bronze.seasons;
CREATE TABLE bronze.seasons (
    [year]          NVARCHAR(10),
    [url]           NVARCHAR(255)
);
GO

-- Note: sprint_results has no fastestLapSpeed, and its rank column comes last.
IF OBJECT_ID(N'bronze.sprint_results', N'U') IS NOT NULL DROP TABLE bronze.sprint_results;
CREATE TABLE bronze.sprint_results (
    resultId        NVARCHAR(10),
    raceId          NVARCHAR(10),
    driverId        NVARCHAR(10),
    constructorId   NVARCHAR(10),
    number          NVARCHAR(10),
    grid            NVARCHAR(10),
    position        NVARCHAR(10),
    positionText    NVARCHAR(10),
    positionOrder   NVARCHAR(10),
    points          NVARCHAR(20),
    laps            NVARCHAR(10),
    [time]          NVARCHAR(20),
    milliseconds    NVARCHAR(20),
    fastestLap      NVARCHAR(10),
    fastestLapTime  NVARCHAR(20),
    statusId        NVARCHAR(10),
    [rank]          NVARCHAR(10)
);
GO

IF OBJECT_ID(N'bronze.status', N'U') IS NOT NULL DROP TABLE bronze.status;
CREATE TABLE bronze.status (
    statusId        NVARCHAR(10),
    [status]        NVARCHAR(100)
);
GO
