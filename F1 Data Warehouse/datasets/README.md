# Datasets

The CSV files are **not** committed to this repository (about 22 MB, and they are updated during each season). Download them yourself:

1. Open [Formula 1 Race Data](https://www.kaggle.com/datasets/jtrotman/formula-1-race-data) on Kaggle and click **Download**, or use the Kaggle CLI:

   ```
   kaggle datasets download -d jtrotman/formula-1-race-data --unzip -p C:\f1_data\raw
   ```

2. The folder must contain these 14 files, unchanged (do not open and re-save them in Excel; that changes encoding and quoting):

   ```
   circuits.csv              constructor_results.csv   constructor_standings.csv
   constructors.csv          driver_standings.csv      drivers.csv
   lap_times.csv             pit_stops.csv             qualifying.csv
   races.csv                 results.csv               seasons.csv
   sprint_results.csv        status.csv
   ```

3. Pass that folder to the pipeline:

   ```sql
   EXEC meta.run_pipeline @source_path = N'C:\f1_data\raw\';
   ```

The SQL Server service account needs read access to the folder; see the main README's Troubleshooting table.

Missing values in these files are written as `\N`. Bronze keeps them as text; silver turns them into `NULL`.
