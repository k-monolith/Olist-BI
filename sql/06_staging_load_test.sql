/* ============================================================
   06_staging_load_test.sql  (OPTIONAL)
   Validates the schema + files BEFORE building SSIS: bulk-loads
   the eight cleaned CSVs into staging and checks row counts
   against the figures from the Kaggle run.

   The official, repeatable loader is SSIS (next phase); this
   script only proves that the files and tables line up.

   NOTE: BULK INSERT runs on the SERVER, so the path below must
   be readable by the SQL Server service account. If you get
   "Operation not permitted" / error 5, grant the folder read
   access to the service account (see the Star Schema
   Implementation Guide, section 7).
   ============================================================ */
USE OlistStaging;
GO

DECLARE @dir NVARCHAR(260) =
    N'C:\Users\Windows\Desktop\prjct_prtf\bi\data\clean\';

/* ROWTERMINATOR = 0x0a: the files were written on Linux (Kaggle),
   so lines end with LF, not the Windows default CRLF. Without it,
   the BULK provider fails with Msg 7301 (IID_IColumnsInfo). */
DECLARE @sql NVARCHAR(MAX) = N'';
DECLARE @opts NVARCHAR(200) =
    N'WITH (FORMAT = ''CSV'', FIRSTROW = 2, CODEPAGE = ''65001'', '
  + N'ROWTERMINATOR = ''0x0a'', TABLOCK);';

TRUNCATE TABLE stg.orders;
TRUNCATE TABLE stg.order_items;
TRUNCATE TABLE stg.customers;
TRUNCATE TABLE stg.sellers;
TRUNCATE TABLE stg.products;
TRUNCATE TABLE stg.payments;
TRUNCATE TABLE stg.reviews;
TRUNCATE TABLE stg.geolocation;

SET @sql =
  N'BULK INSERT stg.orders      FROM ''' + @dir + N'orders_clean.csv'' '      + @opts + CHAR(10) +
  N'BULK INSERT stg.order_items FROM ''' + @dir + N'order_items_clean.csv'' ' + @opts + CHAR(10) +
  N'BULK INSERT stg.customers   FROM ''' + @dir + N'customers_clean.csv'' '   + @opts + CHAR(10) +
  N'BULK INSERT stg.sellers     FROM ''' + @dir + N'sellers_clean.csv'' '     + @opts + CHAR(10) +
  N'BULK INSERT stg.products    FROM ''' + @dir + N'products_clean.csv'' '    + @opts + CHAR(10) +
  N'BULK INSERT stg.payments    FROM ''' + @dir + N'payments_clean.csv'' '    + @opts + CHAR(10) +
  N'BULK INSERT stg.reviews     FROM ''' + @dir + N'reviews_clean.csv'' '     + @opts + CHAR(10) +
  N'BULK INSERT stg.geolocation FROM ''' + @dir + N'geolocation_clean.csv'' ' + @opts;

EXEC sys.sp_executesql @sql;
GO

/* ---------- Row-count validation (expected = Kaggle run output) ---------- */
SELECT t.name AS table_name, p.rows AS loaded,
       e.expected,
       CASE WHEN p.rows = e.expected THEN 'OK' ELSE 'MISMATCH' END AS result
FROM sys.tables t
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
JOIN (VALUES ('orders',       99441),
             ('order_items', 112650),
             ('customers',    99441),
             ('sellers',       3095),
             ('products',     32951),
             ('payments',    103886),
             ('reviews',      99224),
             ('geolocation',  19010)) AS e(name, expected)
  ON e.name = t.name
WHERE SCHEMA_NAME(t.schema_id) = 'stg'
ORDER BY t.name;
