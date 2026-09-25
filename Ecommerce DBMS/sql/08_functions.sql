/* ============================================================
   08_functions.sql — 1 scalar + 1 table-valued function
   ============================================================ */

USE ECommerceOrderDB;
GO

/* ------------------------------------------------------------
   FUNCTION 1: ufn_GetOrderTotal (scalar)
   Purpose    : Independently recompute an order's total straight
                from OrderItems — used to cross-check Orders.TotalAmount
                or to compute a total before an order row exists.
   Parameters : @OrderID INT
   Returns    : DECIMAL(12,2)
   Concept    : Scalar user-defined function, SUM aggregate.
   ------------------------------------------------------------ */
IF OBJECT_ID(N'dbo.ufn_GetOrderTotal', N'FN') IS NOT NULL
    DROP FUNCTION dbo.ufn_GetOrderTotal;
GO
CREATE FUNCTION dbo.ufn_GetOrderTotal (@OrderID INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @Total DECIMAL(12,2);

    SELECT @Total = ISNULL(SUM(LineTotal), 0)
    FROM dbo.OrderItems
    WHERE OrderID = @OrderID;

    RETURN @Total;
END;
GO

-- Example execution + expected output: matches Orders.TotalAmount for OrderID 1 (5648.00).
SELECT OrderID, TotalAmount AS StoredTotal, dbo.ufn_GetOrderTotal(OrderID) AS RecomputedTotal
FROM dbo.Orders
WHERE OrderID = 1;
GO

/* ------------------------------------------------------------
   FUNCTION 2: ufn_GetCustomerOrderHistory (inline table-valued)
   Purpose    : Full order history for one customer — order,
                payment and shipment status in a single callable
                result set (e.g. for a "my orders" screen).
   Parameters : @CustomerID INT
   Returns    : TABLE
   Concept    : Table-valued function, reusable parameterized query.
   ------------------------------------------------------------ */
IF OBJECT_ID(N'dbo.ufn_GetCustomerOrderHistory', N'IF') IS NOT NULL
    DROP FUNCTION dbo.ufn_GetCustomerOrderHistory;
GO
CREATE FUNCTION dbo.ufn_GetCustomerOrderHistory (@CustomerID INT)
RETURNS TABLE
AS
RETURN
(
    SELECT
        o.OrderID,
        o.OrderDate,
        o.OrderStatus,
        o.TotalAmount,
        pay.PaymentStatus,
        sh.ShipmentStatus
    FROM dbo.Orders o
    LEFT JOIN dbo.Payments pay ON pay.OrderID = o.OrderID
    LEFT JOIN dbo.Shipments sh ON sh.OrderID = o.OrderID
    WHERE o.CustomerID = @CustomerID
);
GO

-- Example execution + expected output: Aarav Shah's (CustomerID 1) 4 orders, newest first.
SELECT * FROM dbo.ufn_GetCustomerOrderHistory(1) ORDER BY OrderDate DESC;
GO
