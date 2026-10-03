# Naming Conventions

## Schemas

| Schema | Holds |
| --- | --- |
| `bronze` | Raw CSV tables, all `NVARCHAR` |
| `silver` | Cleaned, typed tables |
| `gold` | Views: star schema, aggregates, ML features |
| `ml` | Tables written by the Python ML / LLM project |
| `meta` | Pipeline log and orchestration |

## Tables and views

- **bronze:** same name as the source file (`results.csv` → `bronze.results`), same column names as the file header (`raceId`, `positionText`, ...).
- **silver:** same table name as bronze, columns in `snake_case`.
- **gold:** `snake_case` with a prefix that says what the object is:

| Prefix | Meaning | Example |
| --- | --- | --- |
| `dim_` | Dimension: descriptive attributes, one row per thing | `gold.dim_driver` |
| `fact_` | Fact: measurable events at a stated grain | `gold.fact_results` |
| `agg_` | Pre-aggregated summary | `gold.agg_driver_season` |
| `vw_` | Convenience flat view, not part of the star | `gold.vw_f1_master` |
| `ml_` | Feature view for model training | `gold.ml_driver_race_features` |

## Columns

| Pattern | Meaning | Example |
| --- | --- | --- |
| `<entity>_id` | Source natural key, also the join key in gold | `race_id`, `driver_id` |
| `is_<condition>` | 0/1 flag stored as `INT` so Power BI can `SUM` it | `is_podium`, `is_dnf` |
| `<measure>_ms` | Duration in milliseconds | `lap_time_ms`, `q1_ms` |
| `<measure>_kph`, `_m`, `_years` | Unit in the name | `fastest_lap_speed_kph`, `altitude_m` |
| `<thing>_text` | Original text kept beside a parsed value | `race_time_text` |
| `<feature>_lastN` | Rolling window over the previous N races (current race excluded) | `driver_points_last5` |
| `<feature>_before` | Total of all races before this one | `driver_career_starts_before` |
| `target_<label>` | ML label describing the race itself | `target_podium` |
| `dwh_create_date` | When the silver row was loaded | |

## Objects

| Object | Pattern | Example |
| --- | --- | --- |
| Load procedure | `<layer>.load_<layer>` | `bronze.load_bronze`, `silver.load_silver` |
| Function | `dbo.fn_<verb>_<noun>` | `dbo.fn_time_to_ms` |
| Primary key | `pk_<schema>_<table>` | `pk_silver_results` |
| Unique constraint | `uq_<schema>_<table>_<columns>` | `uq_silver_races_season_round` |
| Script file | `NN_<what>.sql`, run in number order | `05_ddl_silver.sql` |
