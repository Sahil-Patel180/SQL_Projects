/*
===============================================================================
09 - Gold: Aggregate and Flat Views
===============================================================================
gold.agg_driver_season
    One row per driver per season: entries, starts, wins, podiums, poles,
    DNFs, points, average grid / finish, final championship position.
    Replaces the old rolling_season_stats*.py scripts.

    Poles: qualifying position 1 where qualifying data exists (1994+);
    for earlier races, grid position 1 is used as the best available proxy.

gold.vw_f1_master
    Flat, one row per result, joining the star together. For quick exports
    and ad-hoc analysis only; Power BI should use the star schema.
===============================================================================
*/

USE F1_DB;
GO

CREATE OR ALTER VIEW gold.agg_driver_season AS
WITH res AS (
    SELECT r.season_year, f.*
    FROM gold.fact_results AS f
    JOIN gold.dim_race     AS r ON r.race_id = f.race_id
),
results_by_season AS (
    SELECT
        season_year,
        driver_id,
        SUM(CASE WHEN session_type = N'Race' THEN 1 ELSE 0 END)                  AS race_entries,
        SUM(CASE WHEN session_type = N'Race' THEN is_started ELSE 0 END)         AS race_starts,
        SUM(CASE WHEN session_type = N'Race' THEN is_win ELSE 0 END)             AS wins,
        SUM(CASE WHEN session_type = N'Race' THEN is_podium ELSE 0 END)          AS podiums,
        SUM(CASE WHEN session_type = N'Race' THEN is_dnf ELSE 0 END)             AS dnfs,
        SUM(CASE WHEN session_type = N'Race' THEN is_fastest_lap ELSE 0 END)     AS fastest_laps,
        SUM(CASE WHEN session_type = N'Sprint' THEN is_win ELSE 0 END)           AS sprint_wins,
        SUM(points)                                                              AS points_scored,
        SUM(CASE WHEN session_type = N'Sprint' THEN points ELSE 0 END)           AS sprint_points,
        AVG(CASE WHEN session_type = N'Race' AND grid_position > 0
                 THEN CAST(grid_position AS DECIMAL(6,2)) END)                   AS avg_grid,
        AVG(CASE WHEN session_type = N'Race' AND finish_position IS NOT NULL
                 THEN CAST(finish_position AS DECIMAL(6,2)) END)                 AS avg_finish,
        SUM(CASE WHEN session_type = N'Race' THEN positions_gained ELSE 0 END)   AS positions_gained
    FROM res
    GROUP BY season_year, driver_id
),
races_with_quali AS (
    SELECT DISTINCT race_id FROM silver.qualifying
),
poles AS (
    SELECT q.race_id, q.driver_id
    FROM silver.qualifying AS q
    WHERE q.position = 1
    UNION ALL
    SELECT r.race_id, r.driver_id
    FROM silver.results AS r
    WHERE r.grid = 1
      AND NOT EXISTS (SELECT 1 FROM races_with_quali AS rq WHERE rq.race_id = r.race_id)
),
poles_by_season AS (
    SELECT dr.season_year, p.driver_id, COUNT(*) AS poles
    FROM poles AS p
    JOIN gold.dim_race AS dr ON dr.race_id = p.race_id
    GROUP BY dr.season_year, p.driver_id
),
final_standing AS (
    SELECT season_year, driver_id, championship_position, championship_points, is_season_complete
    FROM gold.fact_driver_standings
    WHERE is_final_round = 1
)
SELECT
    s.season_year,
    s.driver_id,
    s.race_entries,
    s.race_starts,
    s.wins,
    s.podiums,
    COALESCE(p.poles, 0)                                    AS poles,
    s.fastest_laps,
    s.dnfs,
    s.sprint_wins,
    s.points_scored,
    s.sprint_points,
    s.avg_grid,
    s.avg_finish,
    s.positions_gained,
    fs.championship_position                                AS final_position,   -- latest, if season in progress
    fs.championship_points                                  AS final_points,
    fs.is_season_complete,
    CASE WHEN fs.championship_position = 1 AND fs.is_season_complete = 1
         THEN 1 ELSE 0 END                                  AS is_champion
FROM results_by_season       AS s
LEFT JOIN poles_by_season    AS p  ON p.season_year = s.season_year AND p.driver_id = s.driver_id
LEFT JOIN final_standing     AS fs ON fs.season_year = s.season_year AND fs.driver_id = s.driver_id;
GO

CREATE OR ALTER VIEW gold.vw_f1_master AS
WITH pit AS (
    SELECT
        race_id,
        driver_id,
        COUNT(*)                                                        AS pit_stops,
        AVG(CASE WHEN is_long_stop = 0 THEN duration_ms END)            AS avg_pit_ms,
        MIN(duration_ms)                                                AS fastest_pit_ms
    FROM gold.fact_pit_stops
    GROUP BY race_id, driver_id
),
laps AS (
    SELECT
        race_id,
        driver_id,
        COUNT(*)            AS laps_timed,
        AVG(lap_time_ms)    AS avg_lap_ms,
        MIN(lap_time_ms)    AS best_lap_ms
    FROM gold.fact_lap_times
    GROUP BY race_id, driver_id
)
SELECT
    -- race
    r.race_id, r.season_year, r.round, r.race_name, r.race_date, r.era, r.has_sprint,
    -- circuit
    c.circuit_id, c.circuit_name, c.[location], c.country, c.latitude, c.longitude,
    -- driver / team
    d.driver_id, d.driver_code, d.full_name AS driver_name, d.nationality AS driver_nationality,
    d.date_of_birth,
    k.constructor_id, k.constructor_name, k.nationality AS constructor_nationality,
    -- result
    f.session_type, f.result_id, f.grid_position, f.finish_position, f.position_text,
    f.position_order, f.points, f.laps, f.race_time_ms, f.fastest_lap_ms,
    f.fastest_lap_rank, f.fastest_lap_speed_kph,
    st.[status], st.status_group,
    f.is_started, f.is_classified, f.is_dnf, f.is_win, f.is_podium,
    f.is_points_finish, f.is_fastest_lap, f.positions_gained,
    -- qualifying (race session only)
    q.quali_position, q.best_ms AS quali_best_ms, q.gap_to_fastest_ms AS quali_gap_ms, q.is_pole,
    -- pit stops and laps (race session only)
    p.pit_stops, p.avg_pit_ms, p.fastest_pit_ms,
    l.laps_timed, l.avg_lap_ms, l.best_lap_ms
FROM gold.fact_results          AS f
JOIN gold.dim_race              AS r  ON r.race_id = f.race_id
JOIN gold.dim_circuit           AS c  ON c.circuit_id = r.circuit_id
JOIN gold.dim_driver            AS d  ON d.driver_id = f.driver_id
JOIN gold.dim_constructor       AS k  ON k.constructor_id = f.constructor_id
LEFT JOIN gold.dim_status       AS st ON st.status_id = f.status_id
LEFT JOIN gold.fact_qualifying  AS q  ON q.race_id = f.race_id AND q.driver_id = f.driver_id
                                     AND f.session_type = N'Race'
LEFT JOIN pit                   AS p  ON p.race_id = f.race_id AND p.driver_id = f.driver_id
                                     AND f.session_type = N'Race'
LEFT JOIN laps                  AS l  ON l.race_id = f.race_id AND l.driver_id = f.driver_id
                                     AND f.session_type = N'Race';
GO
