# Data Catalog — Gold Layer

All gold objects are views over silver. Keys are the source's natural ids. Flags are `INT` 0/1. Durations are milliseconds.

## Dimensions

### gold.dim_driver — one row per driver

| Column | Type | Description |
| --- | --- | --- |
| driver_id | INT | Key |
| driver_ref | NVARCHAR | Short text id, e.g. `hamilton` |
| driver_code | NVARCHAR(3) | 3-letter code, e.g. `HAM` (mostly modern era) |
| permanent_number | SMALLINT | Race number chosen by the driver (2014+) |
| forename, surname, full_name | NVARCHAR | Name parts and `forename surname` |
| date_of_birth | DATE | |
| nationality | NVARCHAR | e.g. `British` |
| wiki_url | NVARCHAR | Wikipedia page |

### gold.dim_constructor — one row per constructor entry

| Column | Type | Description |
| --- | --- | --- |
| constructor_id | INT | Key. A team that changed name or owner usually has a new id |
| constructor_ref, constructor_name | NVARCHAR | e.g. `red_bull`, `Red Bull` |
| nationality | NVARCHAR | |
| wiki_url | NVARCHAR | |

### gold.dim_circuit — one row per circuit

| Column | Type | Description |
| --- | --- | --- |
| circuit_id | INT | Key |
| circuit_ref, circuit_name | NVARCHAR | |
| location, country | NVARCHAR | City / area and country |
| latitude, longitude | DECIMAL(9,6) | For map visuals |
| altitude_m | INT | Metres above sea level |
| wiki_url | NVARCHAR | |

### gold.dim_race — one row per race weekend

| Column | Type | Description |
| --- | --- | --- |
| race_id | INT | Key |
| season_year, round | SMALLINT | Season and round number |
| race_name, race_label | NVARCHAR | `Monaco Grand Prix`, `2024 Monaco Grand Prix` |
| circuit_id | INT | → dim_circuit |
| race_date, race_date_key | DATE, INT | `race_date_key` = yyyymmdd → dim_date |
| race_datetime_utc | DATETIME2 | Start time in UTC (2005+) |
| quali_date, sprint_date | DATE | Session dates where known |
| is_completed | INT | 1 when results exist; 0 for scheduled future races |
| has_sprint | INT | 1 for sprint weekends |
| is_season_final | INT | 1 for the season's last scheduled round |
| decade, era | NVARCHAR | `2020s`; regulation era such as `2014-2021 Turbo-hybrid` |

### gold.dim_status — one row per finishing status

| Column | Type | Description |
| --- | --- | --- |
| status_id | INT | Key |
| status | NVARCHAR | Raw text, e.g. `Engine`, `+1 Lap` |
| status_group | NVARCHAR | Finished, Lapped, Did not start, Disqualified, Accident / damage, Driver, Not classified, Mechanical |
| is_started | INT | 0 for entries that never started (DNQ, withdrew) |
| is_finish_status | INT | 1 for Finished or Lapped |

### gold.dim_date — one row per day

| Column | Type | Description |
| --- | --- | --- |
| date_key | INT | yyyymmdd, key |
| date | DATE | |
| year, quarter, month, day_of_month, iso_week | INT | |
| month_name, day_name | NVARCHAR | Language of the SQL Server login |
| is_weekend | INT | |

## Facts

### gold.fact_results — one row per result per session (`Race` or `Sprint`)

| Column | Type | Description |
| --- | --- | --- |
| session_type | NVARCHAR | `Race` or `Sprint` |
| result_id | INT | Unique together with session_type |
| race_id, driver_id, constructor_id, status_id | INT | → dimensions |
| car_number | SMALLINT | |
| grid_position | SMALLINT | 0 = pit-lane start or no grid slot |
| finish_position | SMALLINT | NULL when not classified |
| position_text | NVARCHAR | Number, or R retired / D disqualified / E excluded / W withdrew / F failed to qualify / N not classified |
| position_order | SMALLINT | Order of the result sheet, never NULL; use for sorting |
| points | DECIMAL(5,2) | Points scored in this session |
| laps | SMALLINT | Laps completed |
| race_time_ms | INT | Total race time (finishers on the lead lap) |
| fastest_lap_number, fastest_lap_rank, fastest_lap_ms, fastest_lap_speed_kph | | Fastest lap details (2004+) |
| is_started | INT | Took the start |
| is_classified | INT | Has a finishing position |
| is_dnf | INT | Started, not classified, not disqualified |
| is_disqualified | INT | |
| is_win, is_podium | INT | Classified P1 / P1–P3 |
| is_points_finish | INT | `points > 0` |
| is_fastest_lap | INT | Fastest lap of the session |
| is_pit_lane_start | INT | Started from the pit lane |
| positions_gained | INT | `grid - finish`, classified starters with a grid slot only |

### gold.fact_qualifying — one row per driver per race (1994+)

| Column | Type | Description |
| --- | --- | --- |
| qualify_id | INT | |
| race_id, driver_id, constructor_id | INT | |
| quali_position | SMALLINT | |
| q1_ms, q2_ms, q3_ms | INT | Session times; NULL if not reached / no time |
| best_ms | INT | Fastest of the three |
| gap_to_fastest_ms | INT | `best_ms` minus the fastest `best_ms` of the race |
| is_pole | INT | Qualifying P1 |
| reached_q3 | INT | Has a Q3 time |

### gold.fact_lap_times — one row per driver per lap (1996+)

`race_id`, `driver_id`, `lap`, `position` (running position at the end of the lap), `lap_time_ms`.

### gold.fact_pit_stops — one row per stop (1994+)

| Column | Type | Description |
| --- | --- | --- |
| race_id, driver_id, constructor_id | INT | |
| stop_number, lap | SMALLINT | |
| local_time | TIME | Clock time at the circuit |
| duration_ms | INT | Pit-lane time for the stop |
| is_long_stop | INT | Over 120 s: red flag or repair. Exclude from averages |

### gold.fact_constructor_results — one row per constructor per race

`constructor_results_id`, `race_id`, `constructor_id`, `points`, `is_disqualified`.

### gold.fact_driver_standings / gold.fact_constructor_standings — one row per driver (constructor) per race

Cumulative **snapshot after that race**. Never `SUM` these columns.

| Column | Type | Description |
| --- | --- | --- |
| race_id, driver_id / constructor_id | INT | |
| season_year, round | SMALLINT | |
| championship_points | DECIMAL(6,2) | Season total so far |
| championship_position | SMALLINT | Position so far |
| position_text | NVARCHAR | |
| season_wins | SMALLINT | Wins so far |
| is_final_round | INT | Latest round of the season with standings |
| is_season_complete | INT | All scheduled rounds have standings |

## Aggregates

### gold.agg_driver_season — one row per driver per season

`race_entries`, `race_starts`, `wins`, `podiums`, `poles`, `fastest_laps`, `dnfs`, `sprint_wins`, `points_scored` (race + sprint), `sprint_points`, `avg_grid`, `avg_finish`, `positions_gained`, `final_position`, `final_points`, `is_season_complete`, `is_champion`.

Poles use qualifying P1 from 1994 and grid P1 before that (no qualifying data).

### gold.vw_f1_master — one row per result

Flat join of all dimensions with result, qualifying, pit-stop and lap summaries. For exports and ad-hoc queries; use the star schema in Power BI.

## ML feature views

### gold.ml_driver_race_features — one row per started race result

Only information available **before** the race. Rolling windows end at the driver's previous race.

| Group | Columns |
| --- | --- |
| Identifiers | result_id, race_id, driver_id, constructor_id, circuit_id, season_year, round, race_date |
| Context | era, has_sprint, driver_age_years |
| Set before the start | grid_position, is_pit_lane_start, quali_position, quali_gap_to_fastest_ms, reached_q3 |
| Driver form | driver_career_starts_before, driver_career_wins_before, driver_avg_finish_last3, driver_avg_finish_last5, driver_points_last5, driver_podiums_last5, driver_dnf_rate_last10, driver_avg_grid_last5, driver_circuit_starts_before, driver_circuit_avg_finish_before |
| Championship | champ_position_before, champ_points_before (after the previous round) |
| Constructor form | constructor_points_last5, constructor_best_finish_avg_last5, constructor_dnf_rate_last10 |
| **Targets** | target_podium, target_finish_position, target_dnf, target_positions_gained |

### gold.ml_pit_features — one row per started race result, 2010+

| Group | Columns |
| --- | --- |
| Identifiers | race_id, driver_id, constructor_id, circuit_id, season_year, round, race_date |
| Features | has_sprint, grid_position, race_laps, circuit_avg_stops_prev_edition, constructor_avg_stop_ms_last5 |
| **Targets** | target_stop_count, target_stop_class (`0-1`, `2`, `3+`), target_avg_stop_ms |
