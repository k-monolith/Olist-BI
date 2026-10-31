/* ============================================================
   03_dw_dimensions.sql
   Dimension tables in OlistDW, schema dw.
   Surrogate keys are INT IDENTITY; every dimension also gets an
   Unknown member (key -1, seeded in script 05) so fact foreign
   keys are never NULL.
   ============================================================ */
USE OlistDW;
GO

IF SCHEMA_ID(N'dw') IS NULL
    EXEC(N'CREATE SCHEMA dw');
GO

/* Facts depend on dims: drop facts first so this script can re-run. */
DROP TABLE IF EXISTS dw.FactReview;
DROP TABLE IF EXISTS dw.FactPayment;
DROP TABLE IF EXISTS dw.FactOrderItem;
GO

/* ---------- DimDate ----------
   Smart key yyyymmdd (e.g. 20170825); -1 = Unknown (undated).  */
DROP TABLE IF EXISTS dw.DimDate;
CREATE TABLE dw.DimDate (
    DateKey         INT          NOT NULL CONSTRAINT PK_DimDate PRIMARY KEY,
    FullDate        DATE         NULL,                -- sentinel 1900-01-01 on the Unknown row
    [Year]          SMALLINT     NOT NULL,
    [Quarter]       TINYINT      NOT NULL,
    QuarterName     CHAR(7)      NOT NULL,            -- '2017-Q3'
    MonthNumber     TINYINT      NOT NULL,
    MonthName       VARCHAR(15)  NOT NULL,
    YearMonth       CHAR(7)      NOT NULL,            -- '2017-08'
    DayOfMonth      TINYINT      NOT NULL,
    DayOfWeekNumber TINYINT      NOT NULL,            -- 1 = Monday ... 7 = Sunday
    DayOfWeekName   VARCHAR(15)  NOT NULL,
    IsWeekend       BIT          NOT NULL
);

/* ---------- DimGeography ----------
   Grain: one row per 5-digit zip-code prefix.                  */
DROP TABLE IF EXISTS dw.DimGeography;
CREATE TABLE dw.DimGeography (
    GeographyKey  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimGeography PRIMARY KEY,
    ZipCodePrefix NCHAR(5)       NOT NULL,
    City          NVARCHAR(100) NOT NULL,
    [State]       NCHAR(2)       NOT NULL,
    Latitude      FLOAT         NULL,
    Longitude     FLOAT         NULL,
    CONSTRAINT UQ_DimGeography_Zip UNIQUE (ZipCodePrefix)
);

/* ---------- DimCustomer ----------
   Grain: one row per person (customer_unique_id).
   City/state/zip taken from the person's most recent order.    */
DROP TABLE IF EXISTS dw.DimCustomer;
CREATE TABLE dw.DimCustomer (
    CustomerKey      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimCustomer PRIMARY KEY,
    CustomerUniqueId NCHAR(32)      NOT NULL,
    ZipCodePrefix    NCHAR(5)       NOT NULL,
    City             NVARCHAR(100) NOT NULL,
    [State]          NCHAR(2)       NOT NULL,
    CONSTRAINT UQ_DimCustomer_UniqueId UNIQUE (CustomerUniqueId)
);

/* ---------- DimSeller ---------- */
DROP TABLE IF EXISTS dw.DimSeller;
CREATE TABLE dw.DimSeller (
    SellerKey     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimSeller PRIMARY KEY,
    SellerId      NCHAR(32)      NOT NULL,
    ZipCodePrefix NCHAR(5)       NOT NULL,
    City          NVARCHAR(100) NOT NULL,
    [State]       NCHAR(2)       NOT NULL,
    CONSTRAINT UQ_DimSeller_Id UNIQUE (SellerId)
);

/* ---------- DimProduct ---------- */
DROP TABLE IF EXISTS dw.DimProduct;
CREATE TABLE dw.DimProduct (
    ProductKey        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimProduct PRIMARY KEY,
    ProductId         NCHAR(32)      NOT NULL,
    CategoryPt        NVARCHAR(100) NOT NULL,
    CategoryEn        NVARCHAR(100) NOT NULL,
    NameLength        SMALLINT      NULL,
    DescriptionLength SMALLINT      NULL,
    PhotosQty         TINYINT       NULL,
    WeightG           INT           NULL,
    LengthCm          SMALLINT      NULL,
    HeightCm          SMALLINT      NULL,
    WidthCm           SMALLINT      NULL,
    CONSTRAINT UQ_DimProduct_Id UNIQUE (ProductId)
);

/* ---------- DimOrderStatus ---------- */
DROP TABLE IF EXISTS dw.DimOrderStatus;
CREATE TABLE dw.DimOrderStatus (
    OrderStatusKey  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimOrderStatus PRIMARY KEY,
    OrderStatusName NVARCHAR(20) NOT NULL,
    CONSTRAINT UQ_DimOrderStatus_Name UNIQUE (OrderStatusName)
);

/* ---------- DimPaymentType ---------- */
DROP TABLE IF EXISTS dw.DimPaymentType;
CREATE TABLE dw.DimPaymentType (
    PaymentTypeKey  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimPaymentType PRIMARY KEY,
    PaymentTypeName NVARCHAR(20) NOT NULL,
    CONSTRAINT UQ_DimPaymentType_Name UNIQUE (PaymentTypeName)
);
GO

PRINT 'Dimension tables created in OlistDW.dw';
