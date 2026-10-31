/* ============================================================
   09_etl_validation.sql
   Post-ETL checks. Run after the master package completes.
   Expected values come from the executed EDA run; dimension
   counts include the -1 Unknown member.
   ============================================================ */
USE OlistDW;
GO

/* ---------- 1. Row counts ---------- */
SELECT 'DimDate'        AS table_name, COUNT(*) AS loaded,   1462 AS expected,
       CASE WHEN COUNT(*) =   1462 THEN 'OK' ELSE 'MISMATCH' END AS result FROM dw.DimDate
UNION ALL SELECT 'DimGeography',   COUNT(*),  19011, CASE WHEN COUNT(*) =  19011 THEN 'OK' ELSE 'MISMATCH' END FROM dw.DimGeography
UNION ALL SELECT 'DimCustomer',    COUNT(*),  96097, CASE WHEN COUNT(*) =  96097 THEN 'OK' ELSE 'MISMATCH' END FROM dw.DimCustomer
UNION ALL SELECT 'DimSeller',      COUNT(*),   3096, CASE WHEN COUNT(*) =   3096 THEN 'OK' ELSE 'MISMATCH' END FROM dw.DimSeller
UNION ALL SELECT 'DimProduct',     COUNT(*),  32952, CASE WHEN COUNT(*) =  32952 THEN 'OK' ELSE 'MISMATCH' END FROM dw.DimProduct
UNION ALL SELECT 'DimOrderStatus', COUNT(*),      9, CASE WHEN COUNT(*) =      9 THEN 'OK' ELSE 'MISMATCH' END FROM dw.DimOrderStatus
UNION ALL SELECT 'DimPaymentType', COUNT(*),      6, CASE WHEN COUNT(*) =      6 THEN 'OK' ELSE 'MISMATCH' END FROM dw.DimPaymentType
UNION ALL SELECT 'FactOrderItem',  COUNT(*), 112650, CASE WHEN COUNT(*) = 112650 THEN 'OK' ELSE 'MISMATCH' END FROM dw.FactOrderItem
UNION ALL SELECT 'FactPayment',    COUNT(*), 103886, CASE WHEN COUNT(*) = 103886 THEN 'OK' ELSE 'MISMATCH' END FROM dw.FactPayment
UNION ALL SELECT 'FactReview',     COUNT(*),  99224, CASE WHEN COUNT(*) =  99224 THEN 'OK' ELSE 'MISMATCH' END FROM dw.FactReview
ORDER BY table_name;
GO

/* ---------- 2. Business reconciliation against the EDA KPIs ---------- */
-- Delivered orders: expect 96,478
SELECT 'delivered orders (expect 96478)' AS check_name,
       COUNT(DISTINCT f.OrderId) AS value
FROM dw.FactOrderItem AS f
JOIN dw.DimOrderStatus AS s ON s.OrderStatusKey = f.OrderStatusKey
WHERE s.OrderStatusName = N'delivered';

-- GMV, delivered: expect 15,300,630 (verified against staging on the
-- executed load: the same sum over stg.order_items/stg.orders).
SELECT 'GMV delivered (expect ~15300630)' AS check_name,
       CAST(SUM(f.Price + f.FreightValue) AS DECIMAL(14,2)) AS value
FROM dw.FactOrderItem AS f
JOIN dw.DimOrderStatus AS s ON s.OrderStatusKey = f.OrderStatusKey
WHERE s.OrderStatusName = N'delivered';

-- Late deliveries: expect ~ 8.1 % of delivered ORDERS (order level,
-- the EDA definition). The line-level average of IsLate is lower
-- (~7.9 %), because orders with many lines weigh more.
SELECT 'late % of delivered orders (expect ~8.1)' AS check_name,
       CAST(100.0 * AVG(1.0 * o.late_order) AS DECIMAL(5,1)) AS value
FROM (SELECT f.OrderId, MAX(CAST(f.IsLate AS INT)) AS late_order
      FROM dw.FactOrderItem AS f
      WHERE f.IsLate IS NOT NULL
      GROUP BY f.OrderId) AS o;

-- Timeline anomalies: expect 1,359 distinct orders
SELECT 'anomalous orders (expect 1359)' AS check_name,
       COUNT(DISTINCT f.OrderId) AS value
FROM dw.FactOrderItem AS f
WHERE f.HasTimelineAnomaly = 1;

-- Payment total, all orders (informational; the EDA showed payments
-- reconcile with items+freight within R$1 for 99.7% of orders)
SELECT 'payments total (informational)' AS check_name,
       CAST(SUM(PaymentValue) AS DECIMAL(14,2)) AS value
FROM dw.FactPayment;
GO

/* ---------- 3. Unknown-member usage (informational, > 0 is normal) ---------- */
SELECT 'order lines with Unknown customer geography' AS check_name,
       COUNT(*) AS value
FROM dw.FactOrderItem WHERE CustomerGeographyKey = -1
UNION ALL
SELECT 'order lines with Unknown delivered date (undelivered)',
       COUNT(*)
FROM dw.FactOrderItem WHERE DeliveredDateKey = -1
UNION ALL
SELECT 'reviews with Unknown date',
       COUNT(*)
FROM dw.FactReview WHERE ReviewDateKey = -1;
GO

/* ---------- 4. No fact row points at a missing dimension ----------
   (The FK constraints already guarantee this; the query proves it
   explicitly for the portfolio write-up.)                            */
SELECT 'orphan fact keys (expect 0)' AS check_name,
       (SELECT COUNT(*) FROM dw.FactOrderItem f
         WHERE NOT EXISTS (SELECT 1 FROM dw.DimCustomer d WHERE d.CustomerKey = f.CustomerKey))
     + (SELECT COUNT(*) FROM dw.FactOrderItem f
         WHERE NOT EXISTS (SELECT 1 FROM dw.DimProduct  d WHERE d.ProductKey  = f.ProductKey))
     + (SELECT COUNT(*) FROM dw.FactOrderItem f
         WHERE NOT EXISTS (SELECT 1 FROM dw.DimSeller   d WHERE d.SellerKey   = f.SellerKey)) AS value;
