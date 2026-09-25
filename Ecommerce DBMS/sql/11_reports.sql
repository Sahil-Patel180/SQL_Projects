/* ============================================================
   11_reports.sql — business reports (screenshot-ready)
   ============================================================ */

USE ECommerceOrderDB;
GO

-- REPORT 1: Revenue and units sold by category.
SELECT cat.CategoryName,
       SUM(oi.Quantity)  AS UnitsSold,
       SUM(oi.LineTotal) AS Revenue
FROM dbo.Categories cat
JOIN dbo.Products p    ON p.CategoryID = cat.CategoryID
JOIN dbo.OrderItems oi ON oi.ProductID = p.ProductID
GROUP BY cat.CategoryName
ORDER BY Revenue DESC;
GO

-- REPORT 2: Top 5 best-selling products by revenue.
SELECT TOP 5 ProductName, CategoryName, UnitsSold, Revenue
FROM dbo.vw_ProductSalesSummary
ORDER BY Revenue DESC;
GO

-- REPORT 3: Low-stock inventory alert (StockQuantity below ReorderLevel).
SELECT ProductName, CategoryName, StockQuantity, ReorderLevel
FROM dbo.vw_ProductSalesSummary
WHERE StockQuantity < ReorderLevel
ORDER BY StockQuantity ASC;
GO

-- REPORT 4: Order status summary (how many orders in each state).
SELECT OrderStatus, COUNT(*) AS OrderCount, SUM(TotalAmount) AS TotalValue
FROM dbo.Orders
GROUP BY OrderStatus
ORDER BY OrderCount DESC;
GO

-- REPORT 5: Customer order-frequency / loyalty report.
SELECT c.FirstName + ' ' + c.LastName AS CustomerName,
       COUNT(o.OrderID)     AS OrdersPlaced,
       SUM(o.TotalAmount)   AS LifetimeSpend
FROM dbo.Customers c
JOIN dbo.Orders o ON o.CustomerID = c.CustomerID
WHERE o.OrderStatus <> 'Cancelled'
GROUP BY c.FirstName, c.LastName
ORDER BY LifetimeSpend DESC;
GO

-- REPORT 6: Payment method distribution.
SELECT PaymentMethod, COUNT(*) AS TimesUsed, SUM(AmountPaid) AS TotalCollected
FROM dbo.Payments
GROUP BY PaymentMethod
ORDER BY TotalCollected DESC;
GO

-- REPORT 7: Shipment / delivery performance — average days from ship to delivery.
SELECT Carrier,
       COUNT(*) AS ShipmentsHandled,
       AVG(DATEDIFF(DAY, ShippedDate, DeliveredDate)) AS AvgDeliveryDays
FROM dbo.Shipments
WHERE DeliveredDate IS NOT NULL
GROUP BY Carrier;
GO

-- REPORT 8: Month-wise revenue trend (via the order summary view).
SELECT FORMAT(OrderDate, 'yyyy-MM') AS OrderMonth,
       COUNT(*) AS OrdersPlaced,
       SUM(TotalAmount) AS MonthlyRevenue
FROM dbo.vw_OrderSummary
WHERE OrderStatus <> 'Cancelled'
GROUP BY FORMAT(OrderDate, 'yyyy-MM')
ORDER BY OrderMonth;
GO
