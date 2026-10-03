/*
===============================================================================
04 - Helper Functions (used by silver load)
===============================================================================
dbo.fn_clean(@value)
    Turns a raw bronze text value into a clean value or NULL:
      - removes stray CR / LF (files saved with Windows line endings)
      - trims spaces
      - '\N' (the source's missing-value marker) and '' become NULL
    '-' is NOT nulled: standings use it as a real "not ranked" marker.

dbo.fn_time_to_ms(@value)
    Converts a lap / qualifying time string to milliseconds (INT).
      '26.572'        ->    26572
      '1:26.572'      ->    86572
      '1:05:03.456'   ->  3903456
    Returns NULL for NULL or unparseable input. Never use TIME(3) for these:
    '1:26.572' is minutes:seconds, not hh:mm:ss.
===============================================================================
*/

USE F1_DB2;
GO

CREATE OR ALTER FUNCTION dbo.fn_clean (@value NVARCHAR(4000))
RETURNS NVARCHAR(4000)
WITH SCHEMABINDING, RETURNS NULL ON NULL INPUT
AS
BEGIN
    RETURN NULLIF(
               NULLIF(
                   LTRIM(RTRIM(REPLACE(REPLACE(@value, NCHAR(13), N''), NCHAR(10), N''))),
                   N'\N'),
               N'');
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_time_to_ms (@value NVARCHAR(50))
RETURNS INT
WITH SCHEMABINDING, RETURNS NULL ON NULL INPUT
AS
BEGIN
    DECLARE @t  NVARCHAR(50) = dbo.fn_clean(@value);
    DECLARE @c1 INT = CHARINDEX(N':', @t);
    DECLARE @c2 INT = CASE WHEN @c1 > 0 THEN CHARINDEX(N':', @t, @c1 + 1) ELSE 0 END;
    DECLARE @ms INT;

    IF @t IS NULL
        SET @ms = NULL;
    ELSE IF @c1 = 0                                         -- ss.fff
        SET @ms = CAST(TRY_CAST(@t AS DECIMAL(9,3)) * 1000 AS INT);
    ELSE IF @c2 = 0                                         -- m:ss.fff
        SET @ms = TRY_CAST(LEFT(@t, @c1 - 1) AS INT) * 60000
                + CAST(TRY_CAST(SUBSTRING(@t, @c1 + 1, 20) AS DECIMAL(9,3)) * 1000 AS INT);
    ELSE                                                    -- h:mm:ss.fff
        SET @ms = TRY_CAST(LEFT(@t, @c1 - 1) AS INT) * 3600000
                + TRY_CAST(SUBSTRING(@t, @c1 + 1, @c2 - @c1 - 1) AS INT) * 60000
                + CAST(TRY_CAST(SUBSTRING(@t, @c2 + 1, 20) AS DECIMAL(9,3)) * 1000 AS INT);

    RETURN @ms;
END;
GO
