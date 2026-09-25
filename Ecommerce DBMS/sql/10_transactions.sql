/* ============================================================
   10_transactions.sql — transaction management demos
   ============================================================ */

USE ECommerceOrderDB;
GO

/* ------------------------------------------------------------
   DEMO 1: Partial rollback with SAVE TRANSACTION
   Scenario: Customer 8 tries to order two items in one order.
             The first item is fine and gets kept. The second
             item requests far more than is in stock, so only
             the work done since the savepoint is undone —
             the order still commits with the valid first item.
   ------------------------------------------------------------ */
DECLARE @OrderID INT;

BEGIN TRANSACTION;

    INSERT INTO dbo.Orders (CustomerID, OrderStatus, TotalAmount)
    VALUES (8, 'Pending', 0);

    SET @OrderID = SCOPE_IDENTITY();

    -- Item 1: valid (2 units of a 200-unit-stock product).
    INSERT INTO dbo.OrderItems (OrderID, ProductID, Quantity, UnitPrice)
    VALUES (@OrderID, 5, 2, 1299.00);

    SAVE TRANSACTION BeforeSecondItem;

    -- Item 2: 50 units of a product that only has 8 in stock (ProductID 2).
    INSERT INTO dbo.OrderItems (OrderID, ProductID, Quantity, UnitPrice)
    VALUES (@OrderID, 2, 50, 24999.00);

    IF (SELECT StockQuantity FROM dbo.Products WHERE ProductID = 2) < 50
    BEGIN
        ROLLBACK TRANSACTION BeforeSecondItem;
        PRINT 'Item 2 rolled back to savepoint (insufficient stock) — item 1 kept.';
    END

    -- Deduct stock only for what actually stayed committed.
    UPDATE dbo.Products SET StockQuantity = StockQuantity - 2 WHERE ProductID = 5;

COMMIT TRANSACTION;
PRINT 'Transaction committed with 1 line item.';

-- Verify: only the first item survives, trigger already recalculated the total.
SELECT * FROM dbo.OrderItems WHERE OrderID = @OrderID;
SELECT OrderID, TotalAmount FROM dbo.Orders WHERE OrderID = @OrderID;
GO

/* ------------------------------------------------------------
   DEMO 2: Full rollback
   Scenario: Customer 9 tries to order 20 units of "Data Science
             Handbook", which only has 5 in stock. The business
             rule here is "no partial orders" — if the item can't
             be fulfilled, the whole order is discarded, not just
             the line item.
   ------------------------------------------------------------ */
DECLARE @OrderID2 INT;
DECLARE @OrdersBefore INT = (SELECT COUNT(*) FROM dbo.Orders);

BEGIN TRANSACTION;

    INSERT INTO dbo.Orders (CustomerID, OrderStatus, TotalAmount)
    VALUES (9, 'Pending', 0);

    SET @OrderID2 = SCOPE_IDENTITY();

    INSERT INTO dbo.OrderItems (OrderID, ProductID, Quantity, UnitPrice)
    VALUES (@OrderID2, 11, 20, 899.00);

    IF (SELECT StockQuantity FROM dbo.Products WHERE ProductID = 11) < 20
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT 'Entire order rolled back — insufficient stock, no partial orders allowed.';
    END
    ELSE
    BEGIN
        COMMIT TRANSACTION;
        PRINT 'Order committed.';
    END

-- Verify: order count is unchanged — the whole attempt was discarded.
SELECT @OrdersBefore AS OrdersBeforeAttempt, (SELECT COUNT(*) FROM dbo.Orders) AS OrdersAfterAttempt;
GO
