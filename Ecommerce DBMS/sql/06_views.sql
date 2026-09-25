/* ============================================================
   06_views.sql — 2 reporting views
   ============================================================ */

USE ECommerceOrderDB;
GO

/* ------------------------------------------------------------
   VIEW 1: vw_OrderSummary
   Purpose : One-row-per-order overview joining Customers, Orders,
             Payments, Shipments — the query every order-status
             screen or support call would need, without repeating
             the 4-table JOIN each time.
   Concept : View simplifying a multi-table JOIN for reuse.
   ------------------------------------------------------------ */
IF OBJECT_ID(N'dbo.vw_OrderSummary', N'V') IS NOT NULL
    DROP VIEW dbo.vw_OrderSummary;
GO
CREATE VIEW dbo.vw_OrderSummary AS
SELECT
    o.OrderID,
    c.CustomerID,
    c.FirstName + ' ' + c.LastName AS CustomerName,
    c.City,
    c.State,
    o.OrderDate,
    o.OrderStatus,
    o.TotalAmount,
    pay.PaymentMethod,
    pay.PaymentStatus,
    sh.ShipmentStatus,
    sh.Carrier,
    sh.TrackingNumber
FROM dbo.Orders o
JOIN dbo.Customers c      ON c.CustomerID = o.CustomerID
LEFT JOIN dbo.Payments pay ON pay.OrderID = o.OrderID
LEFT JOIN dbo.Shipments sh ON sh.OrderID = o.OrderID;
GO

-- Example use + expected result: 18 rows, one per order, Pending/Cancelled
-- orders show NULL PaymentMethod/ShipmentStatus since no row exists yet.
SELECT * FROM dbo.vw_OrderSummary ORDER BY OrderID;
GO

/* ------------------------------------------------------------
   VIEW 2: vw_ProductSalesSummary
   Purpose : Per-product sales performance (units sold, revenue,
             current stock) for merchandising / restock decisions.
   Concept : View aggregating across Products, Categories, OrderItems.
   ------------------------------------------------------------ */
IF OBJECT_ID(N'dbo.vw_ProductSalesSummary', N'V') IS NOT NULL
    DROP VIEW dbo.vw_ProductSalesSummary;
GO
CREATE VIEW dbo.vw_ProductSalesSummary AS
SELECT
    p.ProductID,
    p.ProductName,
    cat.CategoryName,
    p.UnitPrice,
    p.StockQuantity,
    p.ReorderLevel,
    ISNULL(SUM(oi.Quantity), 0)   AS UnitsSold,
    ISNULL(SUM(oi.LineTotal), 0)  AS Revenue
FROM dbo.Products p
JOIN dbo.Categories cat    ON cat.CategoryID = p.CategoryID
LEFT JOIN dbo.OrderItems oi ON oi.ProductID = p.ProductID
GROUP BY p.ProductID, p.ProductName, cat.CategoryName,
         p.UnitPrice, p.StockQuantity, p.ReorderLevel;
GO

-- Example use + expected result: 18 rows; Revenue = 0 for any never-ordered product.
SELECT * FROM dbo.vw_ProductSalesSummary ORDER BY Revenue DESC;
GO
