/* ============================================================
   09_triggers.sql — 2 AFTER triggers (multi-row safe)
   ============================================================ */

USE ECommerceOrderDB;
GO

/* ------------------------------------------------------------
   TRIGGER 1: trg_Products_StockAudit
   Event      : AFTER UPDATE ON dbo.Products
   Purpose    : Whenever StockQuantity changes (restock, order
                fulfilment, manual correction), write an audit
                row with old/new value. Written against inserted/
                deleted joined on ProductID so it is correct even
                when an UPDATE statement touches many rows at once.
   Concept    : AFTER trigger, audit logging, set-based pseudo-table
                handling (no assumption of single-row DML).
   ------------------------------------------------------------ */
IF OBJECT_ID(N'dbo.trg_Products_StockAudit', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_Products_StockAudit;
GO
CREATE TRIGGER dbo.trg_Products_StockAudit
ON dbo.Products
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(StockQuantity)
        RETURN;

    INSERT INTO dbo.AuditLog (TableName, OperationType, RecordID, ChangedColumn, OldValue, NewValue)
    SELECT
        'Products',
        'UPDATE',
        d.ProductID,
        'StockQuantity',
        CAST(d.StockQuantity AS VARCHAR(200)),
        CAST(i.StockQuantity AS VARCHAR(200))
    FROM deleted d
    JOIN inserted i ON i.ProductID = d.ProductID
    WHERE d.StockQuantity <> i.StockQuantity;
END;
GO

-- Test: update stock for 2 products in a single statement (multi-row).
UPDATE dbo.Products
SET StockQuantity = StockQuantity - 1
WHERE ProductID IN (1, 4);

-- Expected behaviour: 2 new AuditLog rows, one per changed ProductID.
SELECT * FROM dbo.AuditLog WHERE TableName = 'Products' ORDER BY AuditID DESC;
GO

/* ------------------------------------------------------------
   TRIGGER 2: trg_OrderItems_MaintainOrderTotal
   Event      : AFTER INSERT, UPDATE, DELETE ON dbo.OrderItems
   Purpose    : Keeps Orders.TotalAmount in sync with its line
                items automatically — no application code has to
                remember to recalculate it. Recomputes every
                affected OrderID (from inserted AND deleted) in one
                set-based UPDATE, correct for multi-row DML.
   Concept    : AFTER trigger maintaining a derived/denormalized
                value, inserted+deleted combined, no cursors.
   ------------------------------------------------------------ */
IF OBJECT_ID(N'dbo.trg_OrderItems_MaintainOrderTotal', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_OrderItems_MaintainOrderTotal;
GO
CREATE TRIGGER dbo.trg_OrderItems_MaintainOrderTotal
ON dbo.OrderItems
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH AffectedOrders AS (
        SELECT OrderID FROM inserted
        UNION
        SELECT OrderID FROM deleted
    )
    UPDATE o
    SET o.TotalAmount = ISNULL(x.SumTotal, 0)
    FROM dbo.Orders o
    JOIN AffectedOrders ao ON ao.OrderID = o.OrderID
    CROSS APPLY (
        SELECT SUM(LineTotal) AS SumTotal
        FROM dbo.OrderItems
        WHERE OrderID = o.OrderID
    ) x;
END;
GO

-- Test: add an extra item to Order 7 (currently just the 450.00 Hair Serum).
INSERT INTO dbo.OrderItems (OrderID, ProductID, Quantity, UnitPrice)
VALUES (7, 18, 1, 399.00);

-- Expected behaviour: Orders.TotalAmount for OrderID 7 becomes 450 + 399 = 849.00.
SELECT OrderID, TotalAmount FROM dbo.Orders WHERE OrderID = 7;
GO

-- Test: remove that same item and confirm the trigger recalculates back down.
DELETE FROM dbo.OrderItems WHERE OrderID = 7 AND ProductID = 18;
SELECT OrderID, TotalAmount FROM dbo.Orders WHERE OrderID = 7;
GO
