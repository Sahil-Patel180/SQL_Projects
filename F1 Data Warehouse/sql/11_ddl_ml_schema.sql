/*
===============================================================================
11 - DDL: ML Write-back Tables
===============================================================================
Purpose:
    Tables the Python ML / LLM project writes into, so Power BI can show
    predictions and narratives next to the warehouse facts.
    Created empty here; filled by the Python project.

    ml.model_runs    one row per training run (metrics vs baseline)
    ml.predictions   one row per run x race x driver
    ml.narratives    LLM-written text, one row per subject x type x version

    NOTE: re-running this script drops these tables and their contents.
===============================================================================
*/

USE F1_DB;
GO

IF OBJECT_ID(N'ml.narratives',  N'U') IS NOT NULL DROP TABLE ml.narratives;
IF OBJECT_ID(N'ml.predictions', N'U') IS NOT NULL DROP TABLE ml.predictions;
IF OBJECT_ID(N'ml.model_runs',  N'U') IS NOT NULL DROP TABLE ml.model_runs;
GO

CREATE TABLE ml.model_runs (
    run_id              INT IDENTITY(1,1)   NOT NULL CONSTRAINT pk_ml_model_runs PRIMARY KEY,
    model_name          VARCHAR(50)         NOT NULL,   -- podium | finish_position | dnf | quali_delta | pit_stops
    model_version       VARCHAR(20)         NOT NULL,
    train_from_season   SMALLINT            NOT NULL,
    train_to_season     SMALLINT            NOT NULL,
    test_from_season    SMALLINT            NULL,
    test_to_season      SMALLINT            NULL,
    metrics_json        NVARCHAR(MAX)       NULL,       -- model + baseline metrics
    feature_list_json   NVARCHAR(MAX)       NULL,
    created_at          DATETIME2(0)        NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT ck_ml_model_runs_metrics_json CHECK (metrics_json IS NULL OR ISJSON(metrics_json) = 1)
);
GO

CREATE TABLE ml.predictions (
    run_id              INT                 NOT NULL,
    race_id             INT                 NOT NULL,
    driver_id           INT                 NOT NULL,
    predicted_value     DECIMAL(12,4)       NULL,       -- position, gain, stop count, ms
    predicted_class     NVARCHAR(20)        NULL,       -- e.g. '3+' stops
    probability         DECIMAL(6,5)        NULL,       -- for classifiers
    top_features_json   NVARCHAR(MAX)       NULL,       -- top SHAP contributions
    created_at          DATETIME2(0)        NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT pk_ml_predictions PRIMARY KEY (run_id, race_id, driver_id),
    CONSTRAINT fk_ml_predictions_run FOREIGN KEY (run_id) REFERENCES ml.model_runs (run_id)
);
GO

CREATE TABLE ml.narratives (
    narrative_id        INT IDENTITY(1,1)   NOT NULL CONSTRAINT pk_ml_narratives PRIMARY KEY,
    narrative_type      VARCHAR(30)         NOT NULL,   -- race_recap | driver_season | prediction | model_report
    race_id             INT                 NULL,
    driver_id           INT                 NULL,
    season_year         SMALLINT            NULL,
    run_id              INT                 NULL,
    narrative_text      NVARCHAR(MAX)       NOT NULL,
    llm_model           VARCHAR(50)         NOT NULL,   -- e.g. qwen2.5-coder:3b
    prompt_version      VARCHAR(20)         NOT NULL,
    fact_pack_hash      CHAR(64)            NOT NULL,   -- SHA-256 of the input facts
    is_verified         BIT                 NOT NULL,   -- every number / name traced to the facts
    created_at          DATETIME2(0)        NOT NULL DEFAULT SYSDATETIME()
);
GO

CREATE INDEX ix_ml_narratives_subject
    ON ml.narratives (narrative_type, race_id, driver_id, season_year);
GO
