/* ============================================================
   08_fact_source_queries.sql
   The three SELECTs used as "SQL command" in the OLE DB Sources
   of package 03_Load_Facts.dtsx (connection: OlistStaging).
   Safe to run in SSMS to preview the data.

   Date keys are computed here (not looked up): a date maps to
   its DimDate key by pure arithmetic (yyyymmdd), so a Lookup
   transformation would add cost without adding safety.
   ISNULL(..., -1) sends structurally-missing dates to the
   Unknown date member.
   The business keys (customer_unique_id, zip, seller, product,
   status, payment type) ARE resolved by SSIS Lookups against
   the dimensions.
   ============================================================ */
USE OlistStaging;
GO

/* ---------- Q1. FactOrderItem source (112,650 rows) ---------- */
SELECT
    oi.order_id,
    oi.order_item_id,
    ISNULL(CONVERT(INT, CONVERT(CHAR(8), o.order_purchase_timestamp,      112)), -1) AS PurchaseDateKey,
    ISNULL(CONVERT(INT, CONVERT(CHAR(8), o.order_delivered_customer_date, 112)), -1) AS DeliveredDateKey,
    ISNULL(CONVERT(INT, CONVERT(CHAR(8), o.order_estimated_delivery_date, 112)), -1) AS EstimatedDeliveryDateKey,
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    oi.seller_id,
    oi.product_id,
    o.order_status,
    oi.price,
    oi.freight_value,
    CASE WHEN o.order_delivered_customer_date IS NOT NULL
         THEN DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date)
    END AS DeliveryDays,
    CASE WHEN o.order_delivered_customer_date IS NULL THEN NULL
         WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1
         ELSE 0
    END AS IsLate,
    o.has_timeline_anomaly
FROM stg.order_items AS oi
JOIN stg.orders      AS o ON o.order_id    = oi.order_id
JOIN stg.customers   AS c ON c.customer_id = o.customer_id;
GO

/* ---------- Q2. FactPayment source (103,886 rows) ---------- */
SELECT
    p.order_id,
    p.payment_sequential,
    ISNULL(CONVERT(INT, CONVERT(CHAR(8), o.order_purchase_timestamp, 112)), -1) AS PurchaseDateKey,
    c.customer_unique_id,
    p.payment_type,
    p.payment_installments,
    p.payment_value
FROM stg.payments  AS p
JOIN stg.orders    AS o ON o.order_id    = p.order_id
JOIN stg.customers AS c ON c.customer_id = o.customer_id;
GO

/* ---------- Q3. FactReview source (99,224 rows) ---------- */
SELECT
    r.review_id,
    r.order_id,
    ISNULL(CONVERT(INT, CONVERT(CHAR(8), r.review_creation_date, 112)), -1) AS ReviewDateKey,
    c.customer_unique_id,
    r.review_score,
    CASE WHEN r.review_comment_message IS NULL
           OR LTRIM(RTRIM(r.review_comment_message)) = N'' THEN 0
         ELSE 1
    END AS HasComment
FROM stg.reviews   AS r
JOIN stg.orders    AS o ON o.order_id    = r.order_id
JOIN stg.customers AS c ON c.customer_id = o.customer_id;
