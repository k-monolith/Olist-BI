/* ============================================================
   04_dw_facts.sql
   Fact tables in OlistDW, schema dw.
   Run AFTER 03 (dimensions must exist for the FK constraints).

   FactOrderItem  - main fact, grain: one row per order line
   FactPayment    - grain: one row per payment record
   FactReview     - grain: one row per (review, order)
   OrderId is kept on every fact as a degenerate dimension
   (drill-through to the business document).
   v2: id columns are NCHAR(32), matching the Unicode staging/dims.
   ============================================================ */
USE OlistDW;
GO

/* ---------- FactOrderItem ---------- */
DROP TABLE IF EXISTS dw.FactOrderItem;
CREATE TABLE dw.FactOrderItem (
    OrderItemKey             BIGINT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_FactOrderItem PRIMARY KEY,
    -- degenerate dimension
    OrderId                  NCHAR(32)      NOT NULL,
    OrderItemNumber          INT           NOT NULL,
    -- dimension keys (-1 = Unknown, never NULL)
    PurchaseDateKey          INT           NOT NULL,
    DeliveredDateKey         INT           NOT NULL,   -- -1 while not delivered
    EstimatedDeliveryDateKey INT           NOT NULL,
    CustomerKey              INT           NOT NULL,
    CustomerGeographyKey     INT           NOT NULL,
    SellerKey                INT           NOT NULL,
    ProductKey               INT           NOT NULL,
    OrderStatusKey           INT           NOT NULL,
    -- measures
    Price                    DECIMAL(10,2) NOT NULL,
    FreightValue             DECIMAL(10,2) NOT NULL,
    DeliveryDays             SMALLINT      NULL,       -- delivered orders only
    IsLate                   BIT           NULL,       -- delivered orders only
    HasTimelineAnomaly       BIT           NOT NULL,

    CONSTRAINT UQ_FactOrderItem_Line UNIQUE (OrderId, OrderItemNumber),
    CONSTRAINT FK_FOI_PurchaseDate  FOREIGN KEY (PurchaseDateKey)          REFERENCES dw.DimDate (DateKey),
    CONSTRAINT FK_FOI_DeliveredDate FOREIGN KEY (DeliveredDateKey)         REFERENCES dw.DimDate (DateKey),
    CONSTRAINT FK_FOI_EstimatedDate FOREIGN KEY (EstimatedDeliveryDateKey) REFERENCES dw.DimDate (DateKey),
    CONSTRAINT FK_FOI_Customer      FOREIGN KEY (CustomerKey)              REFERENCES dw.DimCustomer (CustomerKey),
    CONSTRAINT FK_FOI_CustGeo       FOREIGN KEY (CustomerGeographyKey)     REFERENCES dw.DimGeography (GeographyKey),
    CONSTRAINT FK_FOI_Seller        FOREIGN KEY (SellerKey)                REFERENCES dw.DimSeller (SellerKey),
    CONSTRAINT FK_FOI_Product       FOREIGN KEY (ProductKey)               REFERENCES dw.DimProduct (ProductKey),
    CONSTRAINT FK_FOI_Status        FOREIGN KEY (OrderStatusKey)           REFERENCES dw.DimOrderStatus (OrderStatusKey)
);

/* ---------- FactPayment ---------- */
DROP TABLE IF EXISTS dw.FactPayment;
CREATE TABLE dw.FactPayment (
    PaymentKey         BIGINT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_FactPayment PRIMARY KEY,
    OrderId            NCHAR(32)      NOT NULL,
    PaymentSequential  SMALLINT      NOT NULL,
    PurchaseDateKey    INT           NOT NULL,
    CustomerKey        INT           NOT NULL,
    PaymentTypeKey     INT           NOT NULL,
    Installments       SMALLINT      NOT NULL,
    PaymentValue       DECIMAL(10,2) NOT NULL,

    CONSTRAINT UQ_FactPayment_Rec UNIQUE (OrderId, PaymentSequential),
    CONSTRAINT FK_FP_PurchaseDate FOREIGN KEY (PurchaseDateKey) REFERENCES dw.DimDate (DateKey),
    CONSTRAINT FK_FP_Customer     FOREIGN KEY (CustomerKey)     REFERENCES dw.DimCustomer (CustomerKey),
    CONSTRAINT FK_FP_PaymentType  FOREIGN KEY (PaymentTypeKey)  REFERENCES dw.DimPaymentType (PaymentTypeKey)
);

/* ---------- FactReview ---------- */
DROP TABLE IF EXISTS dw.FactReview;
CREATE TABLE dw.FactReview (
    ReviewKey      BIGINT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_FactReview PRIMARY KEY,
    ReviewId       NCHAR(32) NOT NULL,
    OrderId        NCHAR(32) NOT NULL,
    ReviewDateKey  INT      NOT NULL,
    CustomerKey    INT      NOT NULL,
    ReviewScore    TINYINT  NOT NULL,
    HasComment     BIT      NOT NULL,

    CONSTRAINT UQ_FactReview_Pair UNIQUE (ReviewId, OrderId),
    CONSTRAINT FK_FR_ReviewDate FOREIGN KEY (ReviewDateKey) REFERENCES dw.DimDate (DateKey),
    CONSTRAINT FK_FR_Customer   FOREIGN KEY (CustomerKey)   REFERENCES dw.DimCustomer (CustomerKey)
);
GO

/* Nonclustered indexes on the most-filtered fact columns. */
CREATE NONCLUSTERED INDEX IX_FOI_PurchaseDate ON dw.FactOrderItem (PurchaseDateKey);
CREATE NONCLUSTERED INDEX IX_FOI_Product      ON dw.FactOrderItem (ProductKey);
CREATE NONCLUSTERED INDEX IX_FOI_Seller       ON dw.FactOrderItem (SellerKey);
CREATE NONCLUSTERED INDEX IX_FOI_Customer     ON dw.FactOrderItem (CustomerKey);
CREATE NONCLUSTERED INDEX IX_FP_PurchaseDate  ON dw.FactPayment  (PurchaseDateKey);
CREATE NONCLUSTERED INDEX IX_FR_ReviewDate    ON dw.FactReview   (ReviewDateKey);
GO

PRINT 'Fact tables created in OlistDW.dw';
