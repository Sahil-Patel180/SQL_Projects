/*
===============================================================================
10 - Gold: ML Feature Views
===============================================================================
Feature views read by the Python ML project. One row per driver per race.

The leakage rule:
    Every feature uses only information known BEFORE the race starts.
    Rolling windows end at "1 PRECEDING", i.e. the driver's previous race.
    Qualifying and grid are allowed: both are set before the start.
    Championship standing comes from the previous round.
    Target columns (target_*) describe the race itself; they are the labels.

    Caveat: for the 85 shared-car results of the 1950s-70s, a driver's second
    row of a race can "see" the first. Train on modern seasons (2010+) and
    this never applies.

gold.ml_driver_race_features   podium, finish position, DNF, positions gained
gold.ml_pit_features           pit-stop count and average stop time (2010+)
===============================================================================
*/

USE F1_DB2;
GO

CREATE OR ALTER VIEW gold.ml_driver_race_features AS
WITH base AS (
    SELECT
        f.result_id,
        f.race_id,
        f.driver_id,
        f.constructor_id,
        r.season_year,
        r.round,
        r.circuit_id,
        r.race_date,
        r.era,
        r.has_sprint,
        d.date_of_birth,
        f.grid_position,
        f.finish_position,
        f.position_order,
        f.points,
        f.is_dnf,
        f.is_podium,
        f.is_win
    FROM gold.fact_results  AS f
    JOIN gold.dim_race      AS r ON r.race_id = f.race_id
    JOIN gold.dim_driver    AS d ON d.driver_id = f.driver_id
    WHERE f.session_type = N'Race'
      AND f.is_started = 1
),
driver_form AS (
    -- Window frames written out per column (WINDOW clause needs SQL Server 2022).
    SELECT
        b.*,
        COUNT(*) OVER (
            PARTITION BY b.driver_id ORDER BY b.race_date, b.race_id, b.result_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)
            AS driver_career_starts_before,
        SUM(b.is_win) OVER (
            PARTITION BY b.driver_id ORDER BY b.race_date, b.race_id, b.result_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)
            AS driver_career_wins_before,
        AVG(CAST(b.position_order AS DECIMAL(6,2))) OVER (
            PARTITION BY b.driver_id ORDER BY b.race_date, b.race_id, b.result_id
            ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING)
            AS driver_avg_finish_last3,
        AVG(CAST(b.position_order AS DECIMAL(6,2))) OVER (
            PARTITION BY b.driver_id ORDER BY b.race_date, b.race_id, b.result_id
            ROWS BETWEEN 5 PRECEDING AND 1 PRECEDING)
            AS driver_avg_finish_last5,
        SUM(b.points) OVER (
            PARTITION BY b.driver_id ORDER BY b.race_date, b.race_id, b.result_id
            ROWS BETWEEN 5 PRECEDING AND 1 PRECEDING)
            AS driver_points_last5,
        SUM(b.is_podium) OVER (
            PARTITION BY b.driver_id ORDER BY b.race_date, b.race_id, b.result_id
            ROWS BETWEEN 5 PRECEDING AND 1 PRECEDING)
            AS driver_podiums_last5,
        AVG(CAST(b.is_dnf AS DECIMAL(6,4))) OVER (
            PARTITION BY b.driver_id ORDER BY b.race_date, b.race_id, b.result_id
            ROWS BETWEEN 10 PRECEDING AND 1 PRECEDING)
            AS driver_dnf_rate_last10,
        AVG(CAST(NULLIF(b.grid_position, 0) AS DECIMAL(6,2))) OVER (
            PARTITION BY b.driver_id ORDER BY b.race_date, b.race_id, b.result_id
            ROWS BETWEEN 5 PRECEDING AND 1 PRECEDING)
            AS driver_avg_grid_last5,
        COUNT(*) OVER (
            PARTITION BY b.driver_id, b.circuit_id ORDER BY b.race_date, b.race_id, b.result_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)
            AS driver_circuit_starts_before,
        AVG(CAST(b.position_order AS DECIMAL(6,2))) OVER (
            PARTITION BY b.driver_id, b.circuit_id ORDER BY b.race_date, b.race_id, b.result_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)
            AS driver_circuit_avg_finish_before
    FROM base AS b
),
constructor_race AS (       -- one row per constructor per race
    SELECT
        race_id,
        constructor_id,
        MIN(race_date)          AS race_date,
        SUM(points)             AS points,
        SUM(is_dnf)             AS dnfs,
        COUNT(*)                AS entries,
        MIN(position_order)     AS best_finish
    FROM base
    GROUP BY race_id, constructor_id
),
constructor_form AS (
    SELECT
        race_id,
        constructor_id,
        SUM(points) OVER (PARTITION BY constructor_id ORDER BY race_date, race_id
                          ROWS BETWEEN 5 PRECEDING AND 1 PRECEDING)     AS constructor_points_last5,
        AVG(CAST(best_finish AS DECIMAL(6,2)))
                    OVER (PARTITION BY constructor_id ORDER BY race_date, race_id
                          ROWS BETWEEN 5 PRECEDING AND 1 PRECEDING)     AS constructor_best_finish_avg_last5,
        CAST(SUM(dnfs) OVER (PARTITION BY constructor_id ORDER BY race_date, race_id
                             ROWS BETWEEN 10 PRECEDING AND 1 PRECEDING) AS DECIMAL(9,4))
        / NULLIF(SUM(entries) OVER (PARTITION BY constructor_id ORDER BY race_date, race_id
                                    ROWS BETWEEN 10 PRECEDING AND 1 PRECEDING), 0)
                                                                        AS constructor_dnf_rate_last10
    FROM constructor_race
),
previous_round AS (
    SELECT cur.race_id, prev.race_id AS prev_race_id
    FROM silver.races AS cur
    JOIN silver.races AS prev
      ON prev.season_year = cur.season_year
     AND prev.round = cur.round - 1
)
SELECT
    -- identifiers (not features)
    df.result_id,
    df.race_id,
    df.driver_id,
    df.constructor_id,
    df.circuit_id,
    df.season_year,
    df.round,
    df.race_date,

    -- context
    df.era,
    df.has_sprint,
    CAST(DATEDIFF(DAY, df.date_of_birth, df.race_date) / 365.25 AS DECIMAL(5,2))
                                                    AS driver_age_years,

    -- set before the start
    NULLIF(df.grid_position, 0)                     AS grid_position,
    CASE WHEN df.grid_position = 0 THEN 1 ELSE 0 END AS is_pit_lane_start,
    q.quali_position,
    q.gap_to_fastest_ms                             AS quali_gap_to_fastest_ms,
    q.reached_q3,

    -- driver form (previous races only)
    df.driver_career_starts_before,
    df.driver_career_wins_before,
    df.driver_avg_finish_last3,
    df.driver_avg_finish_last5,
    df.driver_points_last5,
    df.driver_podiums_last5,
    df.driver_dnf_rate_last10,
    df.driver_avg_grid_last5,
    df.driver_circuit_starts_before,
    df.driver_circuit_avg_finish_before,

    -- championship after the previous round (NULL at round 1)
    ds.championship_position                        AS champ_position_before,
    ds.championship_points                          AS champ_points_before,

    -- constructor form (previous races only)
    cf.constructor_points_last5,
    cf.constructor_best_finish_avg_last5,
    cf.constructor_dnf_rate_last10,

    -- targets (labels)
    df.is_podium                                    AS target_podium,
    df.position_order                               AS target_finish_position,
    df.is_dnf                                       AS target_dnf,
    CASE WHEN df.grid_position > 0 AND df.finish_position IS NOT NULL
         THEN df.grid_position - df.finish_position END
                                                    AS target_positions_gained
FROM driver_form                    AS df
LEFT JOIN gold.fact_qualifying      AS q
       ON q.race_id = df.race_id AND q.driver_id = df.driver_id
LEFT JOIN previous_round            AS pr
       ON pr.race_id = df.race_id
LEFT JOIN gold.fact_driver_standings AS ds
       ON ds.race_id = pr.prev_race_id AND ds.driver_id = df.driver_id
LEFT JOIN constructor_form          AS cf
       ON cf.race_id = df.race_id AND cf.constructor_id = df.constructor_id;
GO

/*
ml_pit_features
    2010 onward: refuelling was banned from 2010, so stop strategy before that
    is a different problem.
    target_stop_count / target_stop_class are given for classified finishers
    only (a retirement cuts the strategy short). target_avg_stop_ms excludes
    stops longer than 120 s (red flags, repairs).
*/
CREATE OR ALTER VIEW gold.ml_pit_features AS
WITH stops AS (
    SELECT
        race_id,
        driver_id,
        COUNT(*)                                                            AS stop_count,
        AVG(CASE WHEN is_long_stop = 0 THEN CAST(duration_ms AS DECIMAL(10,1)) END)
                                                                            AS avg_stop_ms
    FROM gold.fact_pit_stops
    GROUP BY race_id, driver_id
),
base AS (
    SELECT
        f.race_id,
        f.driver_id,
        f.constructor_id,
        r.season_year,
        r.round,
        r.circuit_id,
        r.race_date,
        r.has_sprint,
        f.grid_position,
        f.is_classified,
        f.laps,
        COALESCE(s.stop_count, 0)   AS stop_count,
        s.avg_stop_ms
    FROM gold.fact_results  AS f
    JOIN gold.dim_race      AS r ON r.race_id = f.race_id
    LEFT JOIN stops         AS s ON s.race_id = f.race_id AND s.driver_id = f.driver_id
    WHERE f.session_type = N'Race'
      AND f.is_started = 1
      AND r.season_year >= 2010
),
race_distance AS (          -- laps completed by the winner = scheduled distance in almost all races
    SELECT race_id, MAX(laps) AS race_laps
    FROM base
    GROUP BY race_id
),
circuit_edition AS (        -- average stops among finishers, per race
    SELECT
        race_id,
        circuit_id,
        race_date,
        AVG(CAST(stop_count AS DECIMAL(6,2))) AS avg_stops_finishers
    FROM base
    WHERE is_classified = 1
    GROUP BY race_id, circuit_id, race_date
),
circuit_history AS (
    SELECT
        race_id,
        LAG(avg_stops_finishers) OVER (PARTITION BY circuit_id ORDER BY race_date)
                                                AS circuit_avg_stops_prev_edition
    FROM circuit_edition
),
constructor_race AS (
    SELECT race_id, constructor_id, MIN(race_date) AS race_date, AVG(avg_stop_ms) AS avg_stop_ms
    FROM base
    GROUP BY race_id, constructor_id
),
constructor_history AS (
    SELECT
        race_id,
        constructor_id,
        AVG(avg_stop_ms) OVER (PARTITION BY constructor_id ORDER BY race_date, race_id
                               ROWS BETWEEN 5 PRECEDING AND 1 PRECEDING)
                                                AS constructor_avg_stop_ms_last5
    FROM constructor_race
)
SELECT
    b.race_id,
    b.driver_id,
    b.constructor_id,
    b.circuit_id,
    b.season_year,
    b.round,
    b.race_date,

    -- features
    b.has_sprint,
    NULLIF(b.grid_position, 0)              AS grid_position,
    rd.race_laps,
    ch.circuit_avg_stops_prev_edition,
    cn.constructor_avg_stop_ms_last5,

    -- targets
    CASE WHEN b.is_classified = 1 THEN b.stop_count END         AS target_stop_count,
    CASE WHEN b.is_classified = 0 THEN NULL
         WHEN b.stop_count <= 1 THEN N'0-1'
         WHEN b.stop_count = 2  THEN N'2'
         ELSE                        N'3+' END                  AS target_stop_class,
    b.avg_stop_ms                                               AS target_avg_stop_ms
FROM base                       AS b
JOIN race_distance              AS rd ON rd.race_id = b.race_id
LEFT JOIN circuit_history       AS ch ON ch.race_id = b.race_id
LEFT JOIN constructor_history   AS cn ON cn.race_id = b.race_id AND cn.constructor_id = b.constructor_id;
GO
