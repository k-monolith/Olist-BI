# Olist BI Portfolio

End-to-end Microsoft BI pipeline built on the [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (~100,000 orders, 2016–2018).

```
Kaggle CSVs ──> Python EDA & cleaning ──> SSIS (ETL) ──> SQL Server star schema ──> SSAS Tabular model ──> Power BI (live)
```

Every stage is built, run and validated on a local SQL Server 2025 Developer environment (named instance `localhost\MSSQLSERVER01`).

## Repository structure

```
bi/
├── sql/              9 numbered T-SQL scripts (run in order)
│   ├── 01_create_databases.sql        OlistStaging + OlistDW
│   ├── 02_staging_tables.sql          8 staging tables (schema stg, no constraints)
│   ├── 03_dw_dimensions.sql           7 dimension tables (schema dw)
│   ├── 04_dw_facts.sql                3 fact tables, 13 foreign keys
│   ├── 05_seed_dimdate_unknown.sql    calendar 2016–2019 + Unknown rows (key -1), idempotent
│   ├── 06_staging_load_test.sql       bulk-load smoke test
│   ├── 07_load_dimensions.sql         staging -> dimensions (used by SSIS package 02)
│   ├── 08_fact_source_queries.sql     source queries of the fact loads (package 03)
│   └── 09_etl_validation.sql          row counts + business reconciliation
├── etl/
│   └── Olist.ETL/    SSIS project: 4 packages
│                     01_Load_Staging (8 flat-file data flows)
│                     02_Load_Dimensions (6 Execute SQL Tasks)
│                     03_Load_Facts (3 data flows with Lookups)
│                     00_Master (runs 01 -> 02 -> 03)
├── model/
│   └── Olist.Model/  SSAS Tabular project (compatibility level 1700):
│                     10 tables, 13 relationships, date table, 13 DAX measures
├── notebook/         Kaggle EDA & preprocessing notebook (produces the cleaned CSVs)
├── reports/
│   └── Olist_Report.pbix   Power BI report, live connection to the deployed model
└── data/             not versioned
```

## Warehouse design

Star schema in `OlistDW`:

| Fact table | Grain | Rows |
|---|---|---|
| FactOrderItem | one order line | 112,650 |
| FactPayment | one payment record | 103,886 |
| FactReview | one (review, order) pair | 99,224 |

## Validated figures

Every figure is reproduced identically by the warehouse (`sql/09_etl_validation.sql`), the deployed Tabular model and the Power BI report:

| Figure | Value |
|---|---|
| Delivered orders | 96,478 |
| GMV, delivered (price + freight) | R$ 15,300,630 |
| Late delivery rate (per order) | 8.1 % |
| Average order value | R$ 158.59 |
| Average delivery time | 12.41 days |
| Payments total | R$ 15,959,706 |
| Average review score | 4.09 / 5 |
| Orders with timeline anomaly (flagged) | 1,359 |

## Reproduce

1. Install SQL Server 2025 Developer (Database Engine + Analysis Services in Tabular mode + Integration Services), SSMS, Visual Studio with the SSIS and Analysis Services Projects extensions, and Power BI Desktop.
2. Run the Kaggle notebook in `notebook/` against the Olist dataset and download the cleaned CSVs into `data/clean/`.
3. Run `sql/01` to `sql/05` in SSMS, in order.
4. Open `etl/Olist.ETL/Olist.ETL.slnx`, point the project parameter `SourceFolder` at `data/clean/`, and run the package `00_Master.dtsx`.
5. Run `sql/09_etl_validation.sql`: every check must report OK.
6. Deploy `Olist.Model` to the Analysis Services instance.
7. Open `reports/Olist_Report.pbix`; it connects live to the deployed model.

## Toolset

SQL Server 2025 Developer · SSIS · SSAS Tabular (compatibility level 1700) · SSMS · Visual Studio 2026 · Power BI Desktop · Python (pandas) on Kaggle
