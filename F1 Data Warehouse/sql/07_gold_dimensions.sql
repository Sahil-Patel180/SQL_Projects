/*
===============================================================================
07 - Gold: Dimension Views
===============================================================================
Purpose:
    Descriptive "who / where / when / why" tables of the star schema.

Keys:
    The source's natural ids (driver_id, race_id, ...) are used as keys. They
    are stable across reloads, unlike ROW_NUMBER() surrogates, which renumber
    every time the data changes.

Views:
    gold.dim_driver        one row per driver
    gold.dim_constructor   one row per constructor (team entry)
    gold.dim_circuit       one row per circuit
    gold.dim_race          one row per race weekend (incl. scheduled future races)
    gold.dim_status        one row per finishing status, grouped
    gold.dim_date          one row per calendar day, first to last season
===============================================================================
*/

USE F1_DB;
GO

CREATE OR ALTER VIEW gold.dim_driver AS
SELECT
    d.driver_id,
    d.driver_ref,
    d.driver_code,
    d.permanent_number,
    d.forename,
    d.surname,
    CONCAT(d.forename, N' ', d.surname)     AS full_name,
    d.date_of_birth,
    d.nationality,
    d.wiki_url
FROM silver.drivers AS d;
GO

CREATE OR ALTER VIEW gold.dim_constructor AS
SELECT
    c.constructor_id,
    c.constructor_ref,
    c.constructor_name,
    c.nationality,
    c.wiki_url
FROM silver.constructors AS c;
GO

CREATE OR ALTER VIEW gold.dim_circuit AS
SELECT
    c.circuit_id,
    c.circuit_ref,
    c.circuit_name,
    c.[location],
    c.country,
    c.latitude,
    c.longitude,
    c.altitude_m,
    c.wiki_url
FROM silver.circuits AS c;
GO

/*
dim_race
    is_completed      1 when results exist. Scheduled future races have 0.
    has_sprint        1 when the weekend had (or is scheduled to have) a sprint.
    is_season_final   1 for the last scheduled round of the season.
    era               Broad regulation era, for grouping and as an ML feature.
*/
CREATE OR ALTER VIEW gold.dim_race AS
WITH completed AS (
    SELECT DISTINCT race_id FROM silver.results
),
sprinted AS (
    SELECT DISTINCT race_id FROM silver.sprint_results
),
season_rounds AS (
    SELECT season_year, MAX(round) AS last_round
    FROM silver.races
    GROUP BY season_year
)
SELECT
    r.race_id,
    r.season_year,
    r.round,
    r.race_name,
    CONCAT(r.season_year, N' ', r.race_name)                    AS race_label,
    r.circuit_id,
    r.race_date,
    YEAR(r.race_date) * 10000 + MONTH(r.race_date) * 100 + DAY(r.race_date)
                                                                AS race_date_key,
    r.race_datetime_utc,
    r.quali_date,
    r.sprint_date,
    CASE WHEN c.race_id IS NOT NULL THEN 1 ELSE 0 END           AS is_completed,
    CASE WHEN s.race_id IS NOT NULL OR r.sprint_date IS NOT NULL
         THEN 1 ELSE 0 END                                      AS has_sprint,
    CASE WHEN r.round = sr.last_round THEN 1 ELSE 0 END         AS is_season_final,
    CONCAT(r.season_year / 10 * 10, N's')                       AS decade,
    CASE
        WHEN r.season_year <= 1960 THEN N'1950-1960 Front-engine'
        WHEN r.season_year <= 1976 THEN N'1961-1976 Rear-engine'
        WHEN r.season_year <= 1988 THEN N'1977-1988 Ground effect & turbo'
        WHEN r.season_year <= 2005 THEN N'1989-2005 V10/V12'
        WHEN r.season_year <= 2013 THEN N'2006-2013 V8'
        WHEN r.season_year <= 2021 THEN N'2014-2021 Turbo-hybrid'
        WHEN r.season_year <= 2025 THEN N'2022-2025 Ground effect'
        ELSE                            N'2026+ New power units'
    END                                                         AS era,
    r.wiki_url
FROM silver.races           AS r
LEFT JOIN completed         AS c  ON c.race_id = r.race_id
LEFT JOIN sprinted          AS s  ON s.race_id = r.race_id
LEFT JOIN season_rounds     AS sr ON sr.season_year = r.season_year;
GO

/*
dim_status
    status_group buckets the 140 raw statuses so DNF reasons can be compared:
      Finished, Lapped, Did not start, Disqualified,
      Accident / damage, Driver, Not classified, Mechanical
    is_started = 0 for entries that never took the start (DNQ, withdrew, ...).
*/
CREATE OR ALTER VIEW gold.dim_status AS
WITH grouped AS (
    SELECT
        s.status_id,
        s.[status],
        CASE
            WHEN s.[status] = N'Finished'                         THEN N'Finished'
            WHEN s.[status] LIKE N'+% Lap%'                       THEN N'Lapped'
            WHEN s.[status] IN (N'Did not qualify', N'Did not prequalify',
                                N'107% Rule', N'Withdrew')        THEN N'Did not start'
            WHEN s.[status] IN (N'Disqualified', N'Excluded',
                                N'Underweight')                   THEN N'Disqualified'
            WHEN s.[status] IN (N'Accident', N'Collision', N'Collision damage',
                                N'Spun off', N'Fatal accident', N'Damage',
                                N'Debris', N'Broken wing', N'Front wing',
                                N'Rear wing', N'Puncture', N'Tyre puncture')
                                                                  THEN N'Accident / damage'
            WHEN s.[status] IN (N'Physical', N'Injury', N'Injured', N'Illness',
                                N'Driver unwell', N'Eye injury', N'Safety concerns',
                                N'Safety', N'Safety belt', N'Driver Seat', N'Seat')
                                                                  THEN N'Driver'
            WHEN s.[status] IN (N'Not classified', N'Retired',
                                N'Not restarted')                 THEN N'Not classified'
            ELSE                                                       N'Mechanical'
        END AS status_group
    FROM silver.status AS s
)
SELECT
    g.status_id,
    g.[status],
    g.status_group,
    CASE WHEN g.status_group = N'Did not start' THEN 0 ELSE 1 END     AS is_started,
    CASE WHEN g.status_group IN (N'Finished', N'Lapped') THEN 1 ELSE 0 END
                                                                      AS is_finish_status
FROM grouped AS g;
GO

/*
dim_date
    Generated calendar from 1 Jan of the first season to 31 Dec of the last.
    Joins to dim_race on race_date_key = date_key.
*/
CREATE OR ALTER VIEW gold.dim_date AS
WITH digits AS (
    SELECT n FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS v(n)
),
numbers AS (
    SELECT a.n + b.n * 10 + c.n * 100 + d.n * 1000 + e.n * 10000 AS n
    FROM digits a CROSS JOIN digits b CROSS JOIN digits c
         CROSS JOIN digits d CROSS JOIN digits e
),
bounds AS (
    SELECT DATEFROMPARTS(MIN(season_year), 1, 1)   AS start_date,
           DATEFROMPARTS(MAX(season_year), 12, 31) AS end_date
    FROM silver.races
),
calendar AS (
    SELECT DATEADD(DAY, n.n, b.start_date) AS calendar_date
    FROM numbers AS n
    CROSS JOIN bounds AS b
    WHERE n.n <= DATEDIFF(DAY, b.start_date, b.end_date)
)
SELECT
    YEAR(calendar_date) * 10000 + MONTH(calendar_date) * 100 + DAY(calendar_date)
                                                    AS date_key,
    calendar_date                                   AS [date],
    YEAR(calendar_date)                             AS [year],
    DATEPART(QUARTER, calendar_date)                AS [quarter],
    MONTH(calendar_date)                            AS [month],
    DATENAME(MONTH, calendar_date)                  AS month_name,
    DAY(calendar_date)                              AS day_of_month,
    DATENAME(WEEKDAY, calendar_date)                AS day_name,
    DATEPART(ISO_WEEK, calendar_date)               AS iso_week,
    -- 1900-01-01 was a Monday, so 5 = Saturday and 6 = Sunday, whatever DATEFIRST is set to.
    CASE WHEN DATEDIFF(DAY, '19000101', calendar_date) % 7 IN (5, 6) THEN 1 ELSE 0 END
                                                    AS is_weekend
FROM calendar;
GO
