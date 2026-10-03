/*
===============================================================================
12 - Run the Pipeline
===============================================================================
Run after scripts 00-11 have created all objects. Re-run this file whenever
the CSVs are refreshed: bronze and silver reload, gold views update at once.

1. Set @source_path to the folder holding the 14 Kaggle CSVs.
2. Execute (F5). Expect a few minutes; lap_times (~620k rows) is the
   largest table.
3. Then run the three files in tests/.
===============================================================================
*/

USE F1_DB;
GO

DECLARE @source_path NVARCHAR(400) = N'C:\f1_data\raw\';   -- <-- change me

EXEC meta.run_pipeline @source_path = @source_path;
GO

-- Quick look at the result: the latest champions from gold.
SELECT TOP (5)
    a.season_year,
    d.full_name,
    a.final_points,
    a.wins,
    a.podiums,
    a.poles
FROM gold.agg_driver_season AS a
JOIN gold.dim_driver        AS d ON d.driver_id = a.driver_id
WHERE a.is_champion = 1
ORDER BY a.season_year DESC;
GO
