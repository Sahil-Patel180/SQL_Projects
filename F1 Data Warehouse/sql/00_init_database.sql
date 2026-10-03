/*
===============================================================================
00 - Create Database and Schemas
===============================================================================
Purpose:
    Creates the F1_DB2 database and its five schemas:
        bronze  raw CSV data, loaded as text exactly as delivered
        silver  cleaned, typed, keyed tables
        gold    star-schema views for reporting + ML feature views
        ml      tables the Python ML / LLM project writes results back into
        meta    pipeline run log

WARNING:
    If F1_DB2 already exists it is DROPPED and recreated. All data in it is lost.
    Back it up first if you need anything from it.

Run:
    Execute once, first, in SSMS (any database context).
===============================================================================
*/

USE master;
GO

CREATE DATABASE F1_DB2;
GO

USE F1_DB2;
GO

CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;
GO
CREATE SCHEMA ml;
GO
CREATE SCHEMA meta;
GO
