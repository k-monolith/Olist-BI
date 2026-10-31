/* ============================================================
   01_create_databases.sql
   Creates the staging database and the data warehouse.
   Run against: localhost (Database Engine), any database context.
   ============================================================ */

IF DB_ID(N'OlistStaging') IS NULL
    CREATE DATABASE OlistStaging;
GO
IF DB_ID(N'OlistDW') IS NULL
    CREATE DATABASE OlistDW;
GO

-- Development machine: simple recovery keeps the log small during bulk loads.
ALTER DATABASE OlistStaging SET RECOVERY SIMPLE;
ALTER DATABASE OlistDW      SET RECOVERY SIMPLE;
GO

PRINT 'Databases ready: OlistStaging, OlistDW';
