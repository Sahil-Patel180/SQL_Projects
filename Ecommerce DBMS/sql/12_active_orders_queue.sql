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
   Just a marker of "this order is still open" + when it joined
   the queue. Deliberately does NOT store OrderStatus/OrderDate —
   an earlier version did, and it went stale on every status
   change that wasn't Delivered/Cancelled (Pending->Shipped never
   touched the copy). The view below reads status live from
   Orders instead, so there's nothing left to fall out of sync.
   ---------------------------------------------------------- */
IF OBJECT_ID(N'dbo.ActiveOrders', N'U') IS NOT NULL
    DROP TABLE dbo.ActiveOrders;
GO
CREATE TABLE dbo.ActiveOrders
(
    OrderID        INT           NOT NULL,
    AddedToQueueAt DATETIME2(0)  NOT NULL DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_ActiveOrders PRIMARY KEY CLUSTERED (OrderID),
    CONSTRAINT FK_ActiveOrders_Orders FOREIGN KEY (OrderID)
        REFERENCES dbo.Orders (OrderID) ON DELETE CASCADE
);
GO

/* Backfill — every order already sitting in a non-final state
   joins the queue once, right now. */
INSERT INTO dbo.ActiveOrders (OrderID)
SELECT OrderID
FROM dbo.Orders
WHERE OrderStatus NOT IN ('Delivered', 'Cancelled');
GO

/* ----------------------------------------------------------
   TRIGGER 1: trg_Orders_AddToActiveQueue
   Event   : AFTER INSERT ON dbo.Orders
   Purpose : The moment a customer places an order, it joins the
             live queue — unless it was inserted already-resolved.
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

    INSERT INTO dbo.ActiveOrders (OrderID)
    SELECT i.OrderID
    FROM inserted i
    WHERE i.OrderStatus NOT IN ('Delivered', 'Cancelled');
END;
GO

/* ----------------------------------------------------------
   TRIGGER 2: trg_Orders_RemoveFromActiveQueue
   Event   : AFTER UPDATE ON dbo.Orders
   Purpose : The moment an order's status flips to Delivered (or
             Cancelled), it comes off the queue: "handed to the
             person". Any other status change (Pending->Confirmed
             ->Shipped etc.) needs no action here — the row just
             stays, and the view reads the new status live.
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
   OrderStatus/OrderDate come straight from dbo.Orders, so this
   is always current, never a stale copy.
   ---------------------------------------------------------- */
IF OBJECT_ID(N'dbo.vw_ActiveOrdersQueue', N'V') IS NOT NULL
    DROP VIEW dbo.vw_ActiveOrdersQueue;
GO
CREATE VIEW dbo.vw_ActiveOrdersQueue AS
SELECT
    ao.OrderID,
    c.FirstName + ' ' + c.LastName AS CustomerName,
    o.OrderStatus,
    o.OrderDate,
    DATEDIFF(MINUTE, ao.AddedToQueueAt, SYSDATETIME()) AS MinutesInQueue
FROM dbo.ActiveOrders ao
JOIN dbo.Orders o     ON o.OrderID = ao.OrderID
JOIN dbo.Customers c  ON c.CustomerID = o.CustomerID;
GO

/* ============================================================
   TEST — simulate one order's real-time lifecycle
   Run this whole block in one go (one Execute) — splitting it
   into separate selections starts a new batch each time and
   SCOPE_IDENTITY() comes back NULL, which silently no-ops every
   later statement.
   ============================================================ */

DECLARE @TestOrderID INT;

-- Step 1: customer places an order → row appears immediately.
INSERT INTO dbo.Orders (CustomerID, OrderStatus, TotalAmount)
VALUES (2, 'Pending', 1299.00);
SET @TestOrderID = SCOPE_IDENTITY();

SELECT * FROM dbo.vw_ActiveOrdersQueue WHERE OrderID = @TestOrderID;  -- replace '@TestOrderID' -> OrderID if needed; expected: 1 row, status Pending

-- Step 2: order gets shipped — still in queue, status now live-reads as Shipped.
UPDATE dbo.Orders SET OrderStatus = 'Shipped' WHERE OrderID = @TestOrderID; -- replace '@TestOrderID' -> OrderID if needed
SELECT * FROM dbo.vw_ActiveOrdersQueue WHERE OrderID = @TestOrderID;  -- replace '@TestOrderID' -> OrderID if needed; expected: 1 row, status Shipped

-- Step 3: order is handed to the customer → row disappears.
UPDATE dbo.Orders SET OrderStatus = 'Delivered' WHERE OrderID = @TestOrderID; -- replace '@TestOrderID' -> OrderID if needed
SELECT * FROM dbo.vw_ActiveOrdersQueue WHERE OrderID = @TestOrderID;  -- replace '@TestOrderID' -> OrderID if needed; expected: 0 rows
SELECT * FROM dbo.Orders WHERE OrderID = @TestOrderID;                -- replace '@TestOrderID' -> OrderID if needed; still here — full history kept
GO

-- Whole-queue snapshot — re-run this any time to see it live.
SELECT * FROM dbo.vw_ActiveOrdersQueue ORDER BY MinutesInQueue DESC;
GO
