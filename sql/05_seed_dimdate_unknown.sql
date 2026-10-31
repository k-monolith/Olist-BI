/* ============================================================
   05_seed_dimdate_unknown.sql
   Seeds:
     1. The Unknown member (key -1) in every dimension, so fact
        foreign keys are never NULL.
     2. The full DimDate calendar, 2016-01-01 .. 2019-12-31
        (orders span 2016-09 .. 2018-10; a margin on both sides).
   v3: idempotent in EVERY state of the warehouse. Unknown rows
   are inserted if missing and updated otherwise; calendar days
   are inserted only if missing. No DELETE, so re-running after
   the fact tables are loaded cannot hit a foreign-key conflict.
   ============================================================ */
USE OlistDW;
GO
SET LANGUAGE us_english; -- stable English month/weekday names
                         -- (also resets DATEFIRST to 7 = Sunday)
SET DATEFIRST 1;         -- so set Monday = 1 AFTER the language
GO

/* ---------- 1. Unknown members (key -1) ----------
   FullDate stores the sentinel date 1900-01-01, not NULL: the
   Tabular model marks DimDate as its date table on FullDate, and
   that column must contain no blank values. Reports show this
   row under 'Unknown'.                                          */
IF NOT EXISTS (SELECT 1 FROM dw.DimDate WHERE DateKey = -1)
    INSERT INTO dw.DimDate (DateKey, FullDate, [Year], [Quarter], QuarterName,
                            MonthNumber, MonthName, YearMonth, DayOfMonth,
                            DayOfWeekNumber, DayOfWeekName, IsWeekend)
    VALUES (-1, '1900-01-01', 0, 0, 'Unknown', 0, 'Unknown', 'Unknown', 0, 0, 'Unknown', 0);
ELSE
    UPDATE dw.DimDate
    SET FullDate = '1900-01-01', [Year] = 0, [Quarter] = 0,
        QuarterName = 'Unknown', MonthNumber = 0, MonthName = 'Unknown',
        YearMonth = 'Unknown', DayOfMonth = 0, DayOfWeekNumber = 0,
        DayOfWeekName = 'Unknown', IsWeekend = 0
    WHERE DateKey = -1;

IF NOT EXISTS (SELECT 1 FROM dw.DimGeography WHERE GeographyKey = -1)
BEGIN
    SET IDENTITY_INSERT dw.DimGeography ON;
    INSERT INTO dw.DimGeography (GeographyKey, ZipCodePrefix, City, [State], Latitude, Longitude)
    VALUES (-1, '00000', N'Unknown', '??', NULL, NULL);
    SET IDENTITY_INSERT dw.DimGeography OFF;
END
ELSE
    UPDATE dw.DimGeography
    SET ZipCodePrefix = '00000', City = N'Unknown', [State] = '??',
        Latitude = NULL, Longitude = NULL
    WHERE GeographyKey = -1;

IF NOT EXISTS (SELECT 1 FROM dw.DimCustomer WHERE CustomerKey = -1)
BEGIN
    SET IDENTITY_INSERT dw.DimCustomer ON;
    INSERT INTO dw.DimCustomer (CustomerKey, CustomerUniqueId, ZipCodePrefix, City, [State])
    VALUES (-1, REPLICATE('0', 32), '00000', N'Unknown', '??');
    SET IDENTITY_INSERT dw.DimCustomer OFF;
END
ELSE
    UPDATE dw.DimCustomer
    SET CustomerUniqueId = REPLICATE('0', 32), ZipCodePrefix = '00000',
        City = N'Unknown', [State] = '??'
    WHERE CustomerKey = -1;

IF NOT EXISTS (SELECT 1 FROM dw.DimSeller WHERE SellerKey = -1)
BEGIN
    SET IDENTITY_INSERT dw.DimSeller ON;
    INSERT INTO dw.DimSeller (SellerKey, SellerId, ZipCodePrefix, City, [State])
    VALUES (-1, REPLICATE('0', 32), '00000', N'Unknown', '??');
    SET IDENTITY_INSERT dw.DimSeller OFF;
END
ELSE
    UPDATE dw.DimSeller
    SET SellerId = REPLICATE('0', 32), ZipCodePrefix = '00000',
        City = N'Unknown', [State] = '??'
    WHERE SellerKey = -1;

IF NOT EXISTS (SELECT 1 FROM dw.DimProduct WHERE ProductKey = -1)
BEGIN
    SET IDENTITY_INSERT dw.DimProduct ON;
    INSERT INTO dw.DimProduct (ProductKey, ProductId, CategoryPt, CategoryEn)
    VALUES (-1, REPLICATE('0', 32), N'unknown', N'unknown');
    SET IDENTITY_INSERT dw.DimProduct OFF;
END
ELSE
    UPDATE dw.DimProduct
    SET ProductId = REPLICATE('0', 32), CategoryPt = N'unknown',
        CategoryEn = N'unknown'
    WHERE ProductKey = -1;

IF NOT EXISTS (SELECT 1 FROM dw.DimOrderStatus WHERE OrderStatusKey = -1)
BEGIN
    SET IDENTITY_INSERT dw.DimOrderStatus ON;
    INSERT INTO dw.DimOrderStatus (OrderStatusKey, OrderStatusName)
    VALUES (-1, 'unknown');
    SET IDENTITY_INSERT dw.DimOrderStatus OFF;
END
ELSE
    UPDATE dw.DimOrderStatus SET OrderStatusName = 'unknown'
    WHERE OrderStatusKey = -1;

IF NOT EXISTS (SELECT 1 FROM dw.DimPaymentType WHERE PaymentTypeKey = -1)
BEGIN
    SET IDENTITY_INSERT dw.DimPaymentType ON;
    INSERT INTO dw.DimPaymentType (PaymentTypeKey, PaymentTypeName)
    VALUES (-1, 'unknown');
    SET IDENTITY_INSERT dw.DimPaymentType OFF;
END
ELSE
    UPDATE dw.DimPaymentType SET PaymentTypeName = 'unknown'
    WHERE PaymentTypeKey = -1;
GO

/* ---------- 2. DimDate calendar (insert only missing days) ---------- */
DECLARE @start DATE = '2016-01-01',
        @end   DATE = '2019-12-31';

;WITH seq AS (
    SELECT TOP (DATEDIFF(DAY, @start, @end) + 1)
           DATEADD(DAY, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1, @start) AS d
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dw.DimDate (DateKey, FullDate, [Year], [Quarter], QuarterName,
                        MonthNumber, MonthName, YearMonth, DayOfMonth,
                        DayOfWeekNumber, DayOfWeekName, IsWeekend)
SELECT
    CONVERT(INT, FORMAT(d, 'yyyyMMdd')),
    d,
    DATEPART(YEAR, d),
    DATEPART(QUARTER, d),
    CONCAT(DATEPART(YEAR, d), '-Q', DATEPART(QUARTER, d)),
    DATEPART(MONTH, d),
    DATENAME(MONTH, d),
    FORMAT(d, 'yyyy-MM'),
    DATEPART(DAY, d),
    DATEPART(WEEKDAY, d),
    DATENAME(WEEKDAY, d),
    CASE WHEN DATEPART(WEEKDAY, d) IN (6, 7) THEN 1 ELSE 0 END
FROM seq
WHERE NOT EXISTS (SELECT 1 FROM dw.DimDate AS x
                  WHERE x.DateKey = CONVERT(INT, FORMAT(seq.d, 'yyyyMMdd')));
GO

/* ---------- Verification ---------- */
SELECT 'DimDate rows (expect 1462 = 1461 days + Unknown)' AS check_name,
       COUNT(*) AS n FROM dw.DimDate
UNION ALL SELECT 'DimDate range min (expect 20160101)', MIN(DateKey) FROM dw.DimDate WHERE DateKey <> -1
UNION ALL SELECT 'DimDate range max (expect 20191231)', MAX(DateKey) FROM dw.DimDate WHERE DateKey <> -1
UNION ALL SELECT 'Unknown FullDate sentinel (expect 1 row of 1900-01-01)',
       (SELECT COUNT(*) FROM dw.DimDate WHERE DateKey = -1 AND FullDate = '1900-01-01')
UNION ALL SELECT 'Unknown members present (expect 7)',
       (SELECT COUNT(*) FROM dw.DimGeography   WHERE GeographyKey   = -1)
     + (SELECT COUNT(*) FROM dw.DimCustomer    WHERE CustomerKey    = -1)
     + (SELECT COUNT(*) FROM dw.DimSeller      WHERE SellerKey      = -1)
     + (SELECT COUNT(*) FROM dw.DimProduct     WHERE ProductKey     = -1)
     + (SELECT COUNT(*) FROM dw.DimOrderStatus WHERE OrderStatusKey = -1)
     + (SELECT COUNT(*) FROM dw.DimPaymentType WHERE PaymentTypeKey = -1)
     + (SELECT COUNT(*) FROM dw.DimDate        WHERE DateKey        = -1);
