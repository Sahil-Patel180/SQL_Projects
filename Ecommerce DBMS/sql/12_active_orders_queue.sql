/* ============================================================
   12_active_orders_queue.sql
   "Real-time" undelivered-order queue: a row appears the moment
   an order is placed, and disappears the moment it's delivered
   (handed to the customer) — pure T-SQL, no polling app needed;
   re-run the SELECT at the bottom any time to see current state.
   ============================================================ */

USE ECommerceOrderDB;
GO

/* ----------------------------------------------------------
   TABLE: ActiveOrders
   One row per order that is placed but not yet delivered or
   cancelled. Never the source of truth (Orders still holds full
   history) — this is a live worklist only.
   ---------------------------------------------------------- */
IF OBJECT_ID(N'dbo.ActiveOrders', N'U') IS NOT NULL
    DROP TABLE dbo.ActiveOrders;
GO
CREATE TABLE dbo.ActiveOrders
(
    OrderID        INT           NOT NULL,
    CustomerID     INT           NOT NULL,
    OrderDate      DATETIME2(0)  NOT NULL,
    OrderStatus    VARCHAR(20)   NOT NULL,
    AddedToQueueAt DATETIME2(0)  NOT NULL DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_ActiveOrders PRIMARY KEY CLUSTERED (OrderID),
    CONSTRAINT FK_ActiveOrders_Orders FOREIGN KEY (OrderID)
        REFERENCES dbo.Orders (OrderID) ON DELETE CASCADE,
    CONSTRAINT FK_ActiveOrders_Customers FOREIGN KEY (CustomerID)
        REFERENCES dbo.Customers (CustomerID)
);
GO

/* Backfill — every order already sitting in a non-final state
   (curated data, and bulk data if 04b was run) joins the queue
   once, right now. New orders after this point are added only
   by the trigger below. */
INSERT INTO dbo.ActiveOrders (OrderID, CustomerID, OrderDate, OrderStatus)
SELECT OrderID, CustomerID, OrderDate, OrderStatus
FROM dbo.Orders
WHERE OrderStatus NOT IN ('Delivered', 'Cancelled');
GO

/* ----------------------------------------------------------
   TRIGGER 1: trg_Orders_AddToActiveQueue
   Event   : AFTER INSERT ON dbo.Orders
   Purpose : The moment a customer places an order, it joins the
             live queue — unless it was inserted already-resolved
             (e.g. a historical/bulk row), which needs no queueing.
   ---------------------------------------------------------- */
IF OBJECT_ID(N'dbo.trg_Orders_AddToActiveQueue', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_Orders_AddToActiveQueue;
GO
CREATE TRIGGER dbo.trg_Orders_AddToActiveQueue
ON dbo.Orders
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.ActiveOrders (OrderID, CustomerID, OrderDate, OrderStatus)
    SELECT i.OrderID, i.CustomerID, i.OrderDate, i.OrderStatus
    FROM inserted i
    WHERE i.OrderStatus NOT IN ('Delivered', 'Cancelled');
END;
GO

/* ----------------------------------------------------------
   TRIGGER 2: trg_Orders_RemoveFromActiveQueue
   Event   : AFTER UPDATE ON dbo.Orders
   Purpose : The moment an order's status flips to Delivered (or
             Cancelled — no longer pending fulfilment either),
             it comes off the queue: "handed to the person".
             Multi-row safe via inserted/deleted joined on OrderID.
   ---------------------------------------------------------- */
IF OBJECT_ID(N'dbo.trg_Orders_RemoveFromActiveQueue', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_Orders_RemoveFromActiveQueue;
GO
CREATE TRIGGER dbo.trg_Orders_RemoveFromActiveQueue
ON dbo.Orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(OrderStatus)
        RETURN;

    DELETE ao
    FROM dbo.ActiveOrders ao
    JOIN inserted i ON i.OrderID = ao.OrderID
    WHERE i.OrderStatus IN ('Delivered', 'Cancelled');
END;
GO

/* ----------------------------------------------------------
   VIEW: vw_ActiveOrdersQueue — readable live worklist.
   ---------------------------------------------------------- */
IF OBJECT_ID(N'dbo.vw_ActiveOrdersQueue', N'V') IS NOT NULL
    DROP VIEW dbo.vw_ActiveOrdersQueue;
GO
CREATE VIEW dbo.vw_ActiveOrdersQueue AS
SELECT
    ao.OrderID,
    c.FirstName + ' ' + c.LastName AS CustomerName,
    ao.OrderStatus,
    ao.OrderDate,
    DATEDIFF(MINUTE, ao.AddedToQueueAt, SYSDATETIME()) AS MinutesInQueue
FROM dbo.ActiveOrders ao
JOIN dbo.Customers c ON c.CustomerID = ao.CustomerID;
GO

/* ============================================================
   TEST — simulate one order's real-time lifecycle
   ============================================================ */

-- Step 1: customer places an order → row appears immediately.
DECLARE @TestOrderID INT;
INSERT INTO dbo.Orders (CustomerID, OrderStatus, TotalAmount)
VALUES (2, 'Pending', 1299.00);
SET @TestOrderID = SCOPE_IDENTITY();

SELECT * FROM dbo.vw_ActiveOrdersQueue WHERE OrderID = @TestOrderID;  -- expected: 1 row

-- Step 2: order gets confirmed/shipped — still in queue, just status changes.
UPDATE dbo.Orders SET OrderStatus = 'Shipped' WHERE OrderID = @TestOrderID; -- replace '@TestOrderID' -> OrderID if needed
SELECT * FROM dbo.vw_ActiveOrdersQueue WHERE OrderID = @TestOrderID;  -- replace '@TestOrderID' -> OrderID if needed; expected: still 1 row, status Shipped

-- Step 3: order is handed to the customer → row disappears.
UPDATE dbo.Orders SET OrderStatus = 'Delivered' WHERE OrderID = @TestOrderID;
SELECT * FROM dbo.vw_ActiveOrdersQueue WHERE OrderID = @TestOrderID;  -- replace '@TestOrderID' -> OrderID if needed; expected: 0 rows
SELECT * FROM dbo.Orders WHERE OrderID = @TestOrderID;                -- still here — full history kept
GO

-- Whole-queue snapshot — re-run this any time to see it live.
SELECT * FROM dbo.vw_ActiveOrdersQueue ORDER BY MinutesInQueue DESC;
GO
