/*
===============================================================================
08 - Gold: Fact Views
===============================================================================
Views and grain (one row per ...):
    gold.fact_results                 result x session (Race | Sprint)
    gold.fact_qualifying              driver x race
    gold.fact_lap_times               driver x race x lap
    gold.fact_pit_stops               driver x race x stop
    gold.fact_constructor_results     constructor x race
    gold.fact_driver_standings        driver x race       (cumulative snapshot)
    gold.fact_constructor_standings   constructor x race  (cumulative snapshot)

Rules (each fixes a bug in the earlier flat "f1_master" attempt):
    - fact_results keeps every result row. 85 rows from the 1950s-70s are two
      results for the same driver in one race (shared cars); deduplicating
      them deletes real points.
    - Constructor data stays at constructor grain. Joined to driver rows it
      repeats per teammate and Power BI sums it twice.
    - is_points_finish = points > 0. Before 2010 only the top 6 or 8 scored,
      so "position <= 10" is wrong for most of history.
    - Pole comes from qualifying position 1, not grid 1 (grid penalties).
    - Standings are cumulative: use the value at a round, never SUM them.
    - Flags are INT 0/1 (not BIT) so Power BI can SUM them.
===============================================================================
*/

USE F1_DB;
GO

CREATE OR ALTER VIEW gold.fact_results AS
WITH unioned AS (
    SELECT
        N'Race'         AS session_type,
        result_id, race_id, driver_id, constructor_id, status_id,
        car_number, grid, position, position_text, position_order,
        points, laps, race_time_ms,
        fastest_lap, fastest_lap_rank, fastest_lap_ms, fastest_lap_speed_kph
    FROM silver.results
    UNION ALL
    SELECT
        N'Sprint',
        result_id, race_id, driver_id, constructor_id, status_id,
        car_number, grid, position, position_text, position_order,
        points, laps, race_time_ms,
        fastest_lap, fastest_lap_rank, fastest_lap_ms, CAST(NULL AS DECIMAL(7,3))
    FROM silver.sprint_results
)
SELECT
    u.session_type,
    u.result_id,                    -- unique only together with session_type
    u.race_id,
    u.driver_id,
    u.constructor_id,
    u.status_id,
    u.car_number,
    u.grid                                                      AS grid_position,
    u.position                                                  AS finish_position,
    u.position_text,
    u.position_order,
    u.points,
    u.laps,
    u.race_time_ms,
    u.fastest_lap                                               AS fastest_lap_number,
    u.fastest_lap_rank,
    u.fastest_lap_ms,
    u.fastest_lap_speed_kph,
    x.is_started,
    CASE WHEN u.position IS NOT NULL THEN 1 ELSE 0 END          AS is_classified,
    CASE WHEN x.is_started = 1
          AND u.position IS NULL
          AND x.is_disqualified = 0 THEN 1 ELSE 0 END           AS is_dnf,
    x.is_disqualified,
    CASE WHEN u.position = 1  THEN 1 ELSE 0 END                 AS is_win,
    CASE WHEN u.position <= 3 THEN 1 ELSE 0 END                 AS is_podium,
    CASE WHEN u.points > 0    THEN 1 ELSE 0 END                 AS is_points_finish,
    CASE WHEN u.fastest_lap_rank = 1 THEN 1 ELSE 0 END          AS is_fastest_lap,
    CASE WHEN u.grid = 0 AND x.is_started = 1 THEN 1 ELSE 0 END AS is_pit_lane_start,
    CASE WHEN u.grid > 0 AND u.position IS NOT NULL
         THEN u.grid - u.position END                           AS positions_gained
FROM unioned AS u
LEFT JOIN gold.dim_status AS s
       ON s.status_id = u.status_id
CROSS APPLY (
    SELECT
        -- A classified driver started. Otherwise 'W' withdrew, 'F' failed to
        -- qualify and the "did not start" statuses mean no start.
        CASE WHEN u.position IS NOT NULL THEN 1
             WHEN s.is_started = 0 OR u.position_text IN (N'W', N'F') THEN 0
             ELSE 1 END                                         AS is_started,
        CASE WHEN s.status_group = N'Disqualified' OR u.position_text IN (N'D', N'E')
             THEN 1 ELSE 0 END                                  AS is_disqualified
) AS x;
GO

/*
fact_qualifying
    Qualifying data exists from 1994. best_ms = fastest of Q1/Q2/Q3.
    gap_to_fastest_ms compares best times across all sessions of the race,
    which is close to, but not exactly, the official gap to pole.
*/
CREATE OR ALTER VIEW gold.fact_qualifying AS
WITH q AS (
    SELECT
        q.qualify_id,
        q.race_id,
        q.driver_id,
        q.constructor_id,
        q.position,
        q.q1_ms,
        q.q2_ms,
        q.q3_ms,
        b.best_ms
    FROM silver.qualifying AS q
    CROSS APPLY (
        SELECT MIN(v) AS best_ms
        FROM (VALUES (q.q1_ms), (q.q2_ms), (q.q3_ms)) AS t(v)
    ) AS b
)
SELECT
    q.qualify_id,
    q.race_id,
    q.driver_id,
    q.constructor_id,
    q.position                                                      AS quali_position,
    q.q1_ms,
    q.q2_ms,
    q.q3_ms,
    q.best_ms,
    q.best_ms - MIN(q.best_ms) OVER (PARTITION BY q.race_id)        AS gap_to_fastest_ms,
    CASE WHEN q.position = 1 THEN 1 ELSE 0 END                      AS is_pole,
    CASE WHEN q.q3_ms IS NOT NULL THEN 1 ELSE 0 END                 AS reached_q3
FROM q;
GO

-- Lap-by-lap data exists from 1996.
CREATE OR ALTER VIEW gold.fact_lap_times AS
SELECT
    l.race_id,
    l.driver_id,
    l.lap,
    l.position,
    l.lap_time_ms
FROM silver.lap_times AS l;
GO

/*
fact_pit_stops
    Pit-stop data exists from 1994.
    is_long_stop = 1 above 120 s: red-flag suspensions and garage repairs.
    Exclude those when averaging stop times.
*/
CREATE OR ALTER VIEW gold.fact_pit_stops AS
SELECT
    p.race_id,
    p.driver_id,
    r.constructor_id,
    p.stop_number,
    p.lap,
    p.local_time,
    p.duration_ms,
    CASE WHEN p.duration_ms > 120000 THEN 1 ELSE 0 END  AS is_long_stop
FROM silver.pit_stops AS p
OUTER APPLY (
    SELECT TOP (1) res.constructor_id
    FROM silver.results AS res
    WHERE res.race_id = p.race_id
      AND res.driver_id = p.driver_id
    ORDER BY res.result_id
) AS r;
GO

CREATE OR ALTER VIEW gold.fact_constructor_results AS
SELECT
    c.constructor_results_id,
    c.race_id,
    c.constructor_id,
    c.points,
    CASE WHEN c.[status] = N'D' THEN 1 ELSE 0 END   AS is_disqualified
FROM silver.constructor_results AS c;
GO

/*
Standings snapshots
    points / position / wins are totals AFTER that race.
    is_final_round = 1 on the season's latest round that has standings
    (the final table for a finished season, the current table for a season
    in progress). is_season_complete = 1 once every scheduled round is in.
*/
CREATE OR ALTER VIEW gold.fact_driver_standings AS
WITH s AS (
    SELECT
        ds.driver_standings_id,
        ds.race_id,
        ds.driver_id,
        ds.points,
        ds.position,
        ds.position_text,
        ds.wins,
        r.season_year,
        r.round,
        MAX(r.round) OVER (PARTITION BY r.season_year)  AS last_round_with_standings,
        sched.scheduled_rounds
    FROM silver.driver_standings AS ds
    JOIN silver.races            AS r ON r.race_id = ds.race_id
    JOIN (SELECT season_year, MAX(round) AS scheduled_rounds
          FROM silver.races GROUP BY season_year) AS sched
      ON sched.season_year = r.season_year
)
SELECT
    s.driver_standings_id,
    s.race_id,
    s.driver_id,
    s.season_year,
    s.round,
    s.points                                                AS championship_points,
    s.position                                              AS championship_position,
    s.position_text,
    s.wins                                                  AS season_wins,
    CASE WHEN s.round = s.last_round_with_standings THEN 1 ELSE 0 END
                                                            AS is_final_round,
    CASE WHEN s.last_round_with_standings = s.scheduled_rounds THEN 1 ELSE 0 END
                                                            AS is_season_complete
FROM s;
GO

CREATE OR ALTER VIEW gold.fact_constructor_standings AS
WITH s AS (
    SELECT
        cs.constructor_standings_id,
        cs.race_id,
        cs.constructor_id,
        cs.points,
        cs.position,
        cs.position_text,
        cs.wins,
        r.season_year,
        r.round,
        MAX(r.round) OVER (PARTITION BY r.season_year)  AS last_round_with_standings,
        sched.scheduled_rounds
    FROM silver.constructor_standings AS cs
    JOIN silver.races                 AS r ON r.race_id = cs.race_id
    JOIN (SELECT season_year, MAX(round) AS scheduled_rounds
          FROM silver.races GROUP BY season_year) AS sched
      ON sched.season_year = r.season_year
)
SELECT
    s.constructor_standings_id,
    s.race_id,
    s.constructor_id,
    s.season_year,
    s.round,
    s.points                                                AS championship_points,
    s.position                                              AS championship_position,
    s.position_text,
    s.wins                                                  AS season_wins,
    CASE WHEN s.round = s.last_round_with_standings THEN 1 ELSE 0 END
                                                            AS is_final_round,
    CASE WHEN s.last_round_with_standings = s.scheduled_rounds THEN 1 ELSE 0 END
                                                            AS is_season_complete
FROM s;
GO
