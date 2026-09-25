/* ============================================================
   03_indexes.sql
   Non-clustered indexes on FK / filter / sort columns
   ============================================================ */

USE ECommerceOrderDB;
GO

/* Orders.CustomerID — every "orders for this customer" lookup and
   the Customers-Orders JOIN filters/joins on this column. */
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Orders_CustomerID')
    DROP INDEX IX_Orders_CustomerID ON dbo.Orders;
GO
CREATE NONCLUSTERED INDEX IX_Orders_CustomerID ON dbo.Orders (CustomerID);
GO

/* Orders.OrderDate — date-range reports (monthly sales, "last 30 days"). */
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Orders_OrderDate')
    DROP INDEX IX_Orders_OrderDate ON dbo.Orders;
GO
CREATE NONCLUSTERED INDEX IX_Orders_OrderDate ON dbo.Orders (OrderDate);
GO

/* OrderItems.ProductID — product sales / best-seller aggregation joins. */
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_OrderItems_ProductID')
    DROP INDEX IX_OrderItems_ProductID ON dbo.OrderItems;
GO
CREATE NONCLUSTERED INDEX IX_OrderItems_ProductID ON dbo.OrderItems (ProductID);
GO

/* Products.CategoryID — category revenue / catalog browsing joins. */
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Products_CategoryID')
    DROP INDEX IX_Products_CategoryID ON dbo.Products;
GO
CREATE NONCLUSTERED INDEX IX_Products_CategoryID ON dbo.Products (CategoryID);
GO

/* ---- Optional: index-effect demo (run before/after dropping IX_Orders_CustomerID) ---- */
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT OrderID, OrderDate, TotalAmount
FROM dbo.Orders
WHERE CustomerID = 1;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO
