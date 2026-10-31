/* ============================================================
   07_load_dimensions.sql
   Dimension loads: staging -> dw.
   Used by SSIS package 02_Load_Dimensions.dtsx (one Execute SQL
   Task per numbered section), and runnable as a whole in SSMS.
   All inserts are idempotent (WHERE NOT EXISTS on the business
   key), so re-running never duplicates rows.
   DimDate is NOT loaded here - it was seeded by script 05.
   ============================================================ */
USE OlistDW;
GO

/* ---------- 1. DimGeography ----------
   One row per zip prefix, straight from the pre-aggregated
   staging table.                                               */
INSERT INTO dw.DimGeography (ZipCodePrefix, City, [State], Latitude, Longitude)
SELECT g.geolocation_zip_code_prefix,
       ISNULL(g.geolocation_city,  N'Unknown'),
       ISNULL(g.geolocation_state, N'??'),
       g.geolocation_lat,
       g.geolocation_lng
FROM OlistStaging.stg.geolocation AS g
WHERE NOT EXISTS (SELECT 1 FROM dw.DimGeography AS d
                  WHERE d.ZipCodePrefix = g.geolocation_zip_code_prefix);
PRINT CONCAT('DimGeography rows: ', (SELECT COUNT(*) FROM dw.DimGeography));
GO

/* ---------- 2. DimOrderStatus ---------- */
INSERT INTO dw.DimOrderStatus (OrderStatusName)
SELECT DISTINCT o.order_status
FROM OlistStaging.stg.orders AS o
WHERE NOT EXISTS (SELECT 1 FROM dw.DimOrderStatus AS d
                  WHERE d.OrderStatusName = o.order_status);
PRINT CONCAT('DimOrderStatus rows: ', (SELECT COUNT(*) FROM dw.DimOrderStatus));
GO

/* ---------- 3. DimPaymentType ---------- */
INSERT INTO dw.DimPaymentType (PaymentTypeName)
SELECT DISTINCT p.payment_type
FROM OlistStaging.stg.payments AS p
WHERE NOT EXISTS (SELECT 1 FROM dw.DimPaymentType AS d
                  WHERE d.PaymentTypeName = p.payment_type);
PRINT CONCAT('DimPaymentType rows: ', (SELECT COUNT(*) FROM dw.DimPaymentType));
GO

/* ---------- 4. DimSeller ---------- */
INSERT INTO dw.DimSeller (SellerId, ZipCodePrefix, City, [State])
SELECT s.seller_id, s.seller_zip_code_prefix, s.seller_city, s.seller_state
FROM OlistStaging.stg.sellers AS s
WHERE NOT EXISTS (SELECT 1 FROM dw.DimSeller AS d
                  WHERE d.SellerId = s.seller_id);
PRINT CONCAT('DimSeller rows: ', (SELECT COUNT(*) FROM dw.DimSeller));
GO

/* ---------- 5. DimProduct ----------
   The count/size columns arrive as FLOAT ("40.0") and are cast
   to their integer types here. Values are whole numbers; CAST
   truncates, which is exact for them.                          */
INSERT INTO dw.DimProduct (ProductId, CategoryPt, CategoryEn, NameLength,
                           DescriptionLength, PhotosQty, WeightG,
                           LengthCm, HeightCm, WidthCm)
SELECT p.product_id,
       p.product_category_name,
       p.product_category_name_english,
       CAST(p.product_name_length        AS SMALLINT),
       CAST(p.product_description_length AS SMALLINT),
       CAST(p.product_photos_qty         AS TINYINT),
       CAST(p.product_weight_g           AS INT),
       CAST(p.product_length_cm          AS SMALLINT),
       CAST(p.product_height_cm          AS SMALLINT),
       CAST(p.product_width_cm           AS SMALLINT)
FROM OlistStaging.stg.products AS p
WHERE NOT EXISTS (SELECT 1 FROM dw.DimProduct AS d
                  WHERE d.ProductId = p.product_id);
PRINT CONCAT('DimProduct rows: ', (SELECT COUNT(*) FROM dw.DimProduct));
GO

/* ---------- 6. DimCustomer ----------
   Person grain: one row per customer_unique_id. A person can
   appear with different zip/city across orders, so the
   attributes are taken from their MOST RECENT order
   (ROW_NUMBER ... ORDER BY purchase timestamp DESC).           */
;WITH latest AS (
    SELECT c.customer_unique_id,
           c.customer_zip_code_prefix,
           c.customer_city,
           c.customer_state,
           ROW_NUMBER() OVER (
               PARTITION BY c.customer_unique_id
               ORDER BY o.order_purchase_timestamp DESC, c.customer_id DESC
           ) AS rn
    FROM OlistStaging.stg.customers AS c
    JOIN OlistStaging.stg.orders    AS o
      ON o.customer_id = c.customer_id
)
INSERT INTO dw.DimCustomer (CustomerUniqueId, ZipCodePrefix, City, [State])
SELECT l.customer_unique_id, l.customer_zip_code_prefix, l.customer_city, l.customer_state
FROM latest AS l
WHERE l.rn = 1
  AND NOT EXISTS (SELECT 1 FROM dw.DimCustomer AS d
                  WHERE d.CustomerUniqueId = l.customer_unique_id);
PRINT CONCAT('DimCustomer rows: ', (SELECT COUNT(*) FROM dw.DimCustomer));
GO

/* ---------- Summary (expected counts include the -1 member) ----------
   DimGeography  19,011   DimCustomer 96,097   DimSeller 3,096
   DimProduct    32,952   DimOrderStatus 9     DimPaymentType 6      */
SELECT 'DimGeography'   AS dim, COUNT(*) AS rows_now, 19011 AS expected FROM dw.DimGeography
UNION ALL SELECT 'DimCustomer',    COUNT(*), 96097 FROM dw.DimCustomer
UNION ALL SELECT 'DimSeller',      COUNT(*),  3096 FROM dw.DimSeller
UNION ALL SELECT 'DimProduct',     COUNT(*), 32952 FROM dw.DimProduct
UNION ALL SELECT 'DimOrderStatus', COUNT(*),     9 FROM dw.DimOrderStatus
UNION ALL SELECT 'DimPaymentType', COUNT(*),     6 FROM dw.DimPaymentType;
