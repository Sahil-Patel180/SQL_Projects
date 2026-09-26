/* ============================================================
   05_queries.sql — 20 business queries
   Each block: business question + concept demonstrated
   ============================================================ */

USE ECommerceOrderDB;
GO

-- Q1 [Basic SELECT] Full active product catalog.
SELECT ProductID, ProductName, UnitPrice, StockQuantity
FROM dbo.Products
WHERE IsActive = 1;
GO

-- Q2 [WHERE filtering] Customers located in Gujarat.
SELECT CustomerID, FirstName, LastName, City, State
FROM dbo.Customers
WHERE State = 'Gujarat';
GO

-- Q3 [ORDER BY] Products from most to least expensive.
SELECT ProductName, UnitPrice
FROM dbo.Products
ORDER BY UnitPrice DESC;
GO

-- Q4 [DISTINCT] Which payment methods are actually in use?
SELECT DISTINCT PaymentMethod
FROM dbo.Payments;
GO

-- Q5 [Calculated column] Product price including 18% GST.
SELECT ProductName, UnitPrice,
       CAST(UnitPrice * 1.18 AS DECIMAL(10,2)) AS PriceWithGST
FROM dbo.Products
WHERE IsActive = 1;
GO

-- Q6 [INNER JOIN] Orders with the customer who placed them.
-- TOP(20) — preview only, at 100k+ orders; drop it for the real report.
SELECT TOP (20) o.OrderID, c.FirstName + ' ' + c.LastName AS CustomerName,
       o.OrderDate, o.OrderStatus, o.TotalAmount
FROM dbo.Orders o
INNER JOIN dbo.Customers c ON c.CustomerID = o.CustomerID
ORDER BY o.OrderDate;
GO

-- Q7 [LEFT JOIN] Every product with units sold so far (0 if never ordered).
SELECT p.ProductID, p.ProductName,
       ISNULL(SUM(oi.Quantity), 0) AS UnitsSold
FROM dbo.Products p
LEFT JOIN dbo.OrderItems oi ON oi.ProductID = p.ProductID
GROUP BY p.ProductID, p.ProductName
ORDER BY UnitsSold DESC;
GO

-- Q8 [Multi-table / complex JOIN] Full order-line detail: customer, product, category.
-- TOP(20) — preview only, at ~250k order lines; drop it for the real report.
SELECT TOP (20) o.OrderID, c.FirstName + ' ' + c.LastName AS Customer,
       p.ProductName, cat.CategoryName, oi.Quantity, oi.UnitPrice, oi.LineTotal
FROM dbo.Orders o
JOIN dbo.Customers c   ON c.CustomerID = o.CustomerID
JOIN dbo.OrderItems oi ON oi.OrderID = o.OrderID
JOIN dbo.Products p    ON p.ProductID = oi.ProductID
JOIN dbo.Categories cat ON cat.CategoryID = p.CategoryID
ORDER BY o.OrderID;
GO

-- Q9 [GROUP BY] Total revenue generated per category.
SELECT cat.CategoryName, SUM(oi.LineTotal) AS CategoryRevenue
FROM dbo.Categories cat
JOIN dbo.Products p    ON p.CategoryID = cat.CategoryID
JOIN dbo.OrderItems oi ON oi.ProductID = p.ProductID
GROUP BY cat.CategoryName
ORDER BY CategoryRevenue DESC;
GO

-- Q10 [HAVING] Categories that have earned more than 5,000 in revenue.
SELECT cat.CategoryName, SUM(oi.LineTotal) AS CategoryRevenue
FROM dbo.Categories cat
JOIN dbo.Products p    ON p.CategoryID = cat.CategoryID
JOIN dbo.OrderItems oi ON oi.ProductID = p.ProductID
GROUP BY cat.CategoryName
HAVING SUM(oi.LineTotal) > 5000
ORDER BY CategoryRevenue DESC;
GO

-- Q11 [Aggregates: COUNT/SUM/AVG/MIN/MAX] Overall order statistics.
SELECT COUNT(*) AS TotalOrders,
       SUM(TotalAmount) AS TotalRevenue,
       AVG(TotalAmount) AS AvgOrderValue,
       MIN(TotalAmount) AS SmallestOrder,
       MAX(TotalAmount) AS LargestOrder
FROM dbo.Orders
WHERE OrderStatus <> 'Cancelled';
GO

-- Q12 [Subquery] Customers who have placed more orders than the average customer.
SELECT c.FirstName + ' ' + c.LastName AS CustomerName, oc.OrderCount
FROM dbo.Customers c
JOIN (
    SELECT CustomerID, COUNT(*) AS OrderCount
    FROM dbo.Orders
    GROUP BY CustomerID
) oc ON oc.CustomerID = c.CustomerID
WHERE oc.OrderCount > (
    SELECT AVG(CountPerCustomer * 1.0)
    FROM (SELECT COUNT(*) AS CountPerCustomer FROM dbo.Orders GROUP BY CustomerID) t
);
GO

-- Q13 [Correlated subquery] Products priced above the average price of their own category.
SELECT p.ProductName, cat.CategoryName, p.UnitPrice
FROM dbo.Products p
JOIN dbo.Categories cat ON cat.CategoryID = p.CategoryID
WHERE p.UnitPrice > (
    SELECT AVG(p2.UnitPrice)
    FROM dbo.Products p2
    WHERE p2.CategoryID = p.CategoryID
);
GO

-- Q14 [EXISTS] Customers who have at least one delivered order.
SELECT c.CustomerID, c.FirstName, c.LastName
FROM dbo.Customers c
WHERE EXISTS (
    SELECT 1 FROM dbo.Orders o
    WHERE o.CustomerID = c.CustomerID AND o.OrderStatus = 'Delivered'
);
GO

-- Q15 [NOT EXISTS] Products that have never been ordered.
SELECT p.ProductID, p.ProductName
FROM dbo.Products p
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.OrderItems oi WHERE oi.ProductID = p.ProductID
);
GO

-- Q16 [IN] Orders paid via digital methods (UPI or NetBanking).
SELECT o.OrderID, pay.PaymentMethod, pay.AmountPaid
FROM dbo.Orders o
JOIN dbo.Payments pay ON pay.OrderID = o.OrderID
WHERE pay.PaymentMethod IN ('UPI', 'NetBanking');
GO

-- Q17 [NOT IN] Customers who have never ordered anything from the Books category.
SELECT c.CustomerID, c.FirstName, c.LastName
FROM dbo.Customers c
WHERE c.CustomerID NOT IN (
    SELECT o.CustomerID
    FROM dbo.Orders o
    JOIN dbo.OrderItems oi ON oi.OrderID = o.OrderID
    JOIN dbo.Products p    ON p.ProductID = oi.ProductID
    WHERE p.CategoryID = (SELECT CategoryID FROM dbo.Categories WHERE CategoryName = 'Books')
);
GO

-- Q18 [CASE expression] Classify orders by size.
-- TOP(20) — preview only, at 100k+ orders; drop it for the real report.
SELECT TOP (20) OrderID, TotalAmount,
       CASE
           WHEN TotalAmount >= 10000 THEN 'Large'
           WHEN TotalAmount >= 2000  THEN 'Medium'
           ELSE 'Small'
       END AS OrderSize
FROM dbo.Orders
ORDER BY TotalAmount DESC;
GO

-- Q19 [Date-based filtering] Orders placed in August 2026.
SELECT OrderID, CustomerID, OrderDate, OrderStatus, TotalAmount
FROM dbo.Orders
WHERE OrderDate >= '2026-08-01' AND OrderDate < '2026-09-01'
ORDER BY OrderDate;
GO

-- Q20 [Aggregate-based business report] Month-wise revenue trend.
SELECT FORMAT(OrderDate, 'yyyy-MM') AS OrderMonth,
       COUNT(*) AS OrdersPlaced,
       SUM(TotalAmount) AS MonthlyRevenue
FROM dbo.Orders
WHERE OrderStatus <> 'Cancelled'
GROUP BY FORMAT(OrderDate, 'yyyy-MM')
ORDER BY OrderMonth;
GO
