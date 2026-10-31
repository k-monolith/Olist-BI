/* ============================================================
   02_staging_tables.sql
   Staging tables in OlistStaging, schema stg.
   One table per cleaned CSV, columns in the exact CSV order
   (so both SSIS mappings and BULK INSERT line up 1:1).
   Staging is a landing zone: no PKs, no FKs, truncated
   before every load.
   v2: all text columns are Unicode (NCHAR/NVARCHAR) because the
   source files are UTF-8 and the SSIS data flow carries them as
   DT_WSTR; a non-Unicode target would force per-column conversions.
   ============================================================ */
USE OlistStaging;
GO

IF SCHEMA_ID(N'stg') IS NULL
    EXEC(N'CREATE SCHEMA stg');
GO

/* ---------- orders_clean.csv (9 columns) ---------- */
DROP TABLE IF EXISTS stg.orders;
CREATE TABLE stg.orders (
    order_id                      NCHAR(32)      NOT NULL,
    customer_id                   NCHAR(32)      NOT NULL,
    order_status                  NVARCHAR(20)   NOT NULL,
    order_purchase_timestamp      DATETIME2(0)  NOT NULL,
    order_approved_at             DATETIME2(0)  NULL,
    order_delivered_carrier_date  DATETIME2(0)  NULL,
    order_delivered_customer_date DATETIME2(0)  NULL,
    order_estimated_delivery_date DATETIME2(0)  NULL,
    has_timeline_anomaly          TINYINT       NOT NULL
);

/* ---------- order_items_clean.csv (7 columns) ---------- */
DROP TABLE IF EXISTS stg.order_items;
CREATE TABLE stg.order_items (
    order_id            NCHAR(32)      NOT NULL,
    order_item_id       INT           NOT NULL,
    product_id          NCHAR(32)      NOT NULL,
    seller_id           NCHAR(32)      NOT NULL,
    shipping_limit_date DATETIME2(0)  NULL,
    price               DECIMAL(10,2) NOT NULL,
    freight_value       DECIMAL(10,2) NOT NULL
);

/* ---------- customers_clean.csv (5 columns) ---------- */
DROP TABLE IF EXISTS stg.customers;
CREATE TABLE stg.customers (
    customer_id              NCHAR(32)      NOT NULL,
    customer_unique_id       NCHAR(32)      NOT NULL,
    customer_zip_code_prefix NCHAR(5)       NOT NULL,
    customer_city            NVARCHAR(100) NOT NULL,
    customer_state           NCHAR(2)       NOT NULL
);

/* ---------- sellers_clean.csv (4 columns) ---------- */
DROP TABLE IF EXISTS stg.sellers;
CREATE TABLE stg.sellers (
    seller_id              NCHAR(32)      NOT NULL,
    seller_zip_code_prefix NCHAR(5)       NOT NULL,
    seller_city            NVARCHAR(100) NOT NULL,
    seller_state           NCHAR(2)       NOT NULL
);

/* ---------- products_clean.csv (10 columns)
   The four count/size columns arrive as decimals ("40.0")
   because the source has missing values -> FLOAT here,
   cast to integers during the DW load.                  ---------- */
DROP TABLE IF EXISTS stg.products;
CREATE TABLE stg.products (
    product_id                    NCHAR(32)      NOT NULL,
    product_category_name         NVARCHAR(100) NOT NULL,   -- 'unknown' if absent
    product_name_length           FLOAT         NULL,
    product_description_length    FLOAT         NULL,
    product_photos_qty            FLOAT         NULL,
    product_weight_g              FLOAT         NULL,
    product_length_cm             FLOAT         NULL,
    product_height_cm             FLOAT         NULL,
    product_width_cm              FLOAT         NULL,
    product_category_name_english NVARCHAR(100) NOT NULL
);

/* ---------- payments_clean.csv (5 columns) ---------- */
DROP TABLE IF EXISTS stg.payments;
CREATE TABLE stg.payments (
    order_id             NCHAR(32)      NOT NULL,
    payment_sequential   SMALLINT      NOT NULL,
    payment_type         NVARCHAR(20)   NOT NULL,
    payment_installments SMALLINT      NOT NULL,
    payment_value        DECIMAL(10,2) NOT NULL
);

/* ---------- reviews_clean.csv (7 columns) ---------- */
DROP TABLE IF EXISTS stg.reviews;
CREATE TABLE stg.reviews (
    review_id               NCHAR(32)       NOT NULL,
    order_id                NCHAR(32)       NOT NULL,
    review_score            TINYINT        NOT NULL,
    review_comment_title    NVARCHAR(200)  NULL,
    review_comment_message  NVARCHAR(4000) NULL,
    review_creation_date    DATETIME2(0)   NULL,
    review_answer_timestamp DATETIME2(0)   NULL
);

/* ---------- geolocation_clean.csv (5 columns) ---------- */
DROP TABLE IF EXISTS stg.geolocation;
CREATE TABLE stg.geolocation (
    geolocation_zip_code_prefix NCHAR(5)       NOT NULL,
    geolocation_lat             FLOAT         NOT NULL,
    geolocation_lng             FLOAT         NOT NULL,
    geolocation_city            NVARCHAR(100) NULL,
    geolocation_state           NCHAR(2)       NULL
);
GO

PRINT 'Staging tables created in OlistStaging.stg';
