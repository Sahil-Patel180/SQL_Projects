/* ============================================================
   01_create_database.sql
   E-Commerce Order Management System — Database creation
   Target: Microsoft SQL Server (SSMS)
   ============================================================ */

USE master;
GO

IF DB_ID(N'ECommerceOrderDB') IS NOT NULL
BEGIN
    ALTER DATABASE ECommerceOrderDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE ECommerceOrderDB;
END
GO

CREATE DATABASE ECommerceOrderDB;
GO

USE ECommerceOrderDB;
GO
