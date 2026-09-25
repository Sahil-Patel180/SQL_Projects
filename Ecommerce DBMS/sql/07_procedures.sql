/* ============================================================
   07_procedures.sql — 2 stored procedures
   ============================================================ */

USE ECommerceOrderDB;
GO

/* ------------------------------------------------------------
   PROCEDURE 1: usp_CreateOrder
   Purpose    : Places a new single-item order end-to-end —
                validates stock, inserts Orders + OrderItems,
                decrements Products.StockQuantity — as one
                atomic transaction.
   Parameters : @CustomerID  INT    — buyer
                @ProductID   INT    — item being bought
                @Quantity    INT    — quantity requested
                @NewOrderID  INT OUTPUT — returns generated OrderID
   Concept    : Parameterized procedure, business validation,
                explicit transaction, TRY...CATCH error handling.
   ------------------------------------------------------------ */
IF OBJECT_ID(N'dbo.usp_CreateOrder', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_CreateOrder;
GO
CREATE PROCEDURE dbo.usp_CreateOrder
    @CustomerID  INT,
    @ProductID   INT,
    @Quantity    INT,
    @NewOrderID  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE CustomerID = @CustomerID)
            THROW 50001, 'Invalid CustomerID.', 1;

        IF @Quantity IS NULL OR @Quantity <= 0
            THROW 50002, 'Quantity must be greater than zero.', 1;

        BEGIN TRANSACTION;

            DECLARE @Price DECIMAL(10,2), @Stock INT;

            SELECT @Price = UnitPrice, @Stock = StockQuantity
            FROM dbo.Products WITH (UPDLOCK, ROWLOCK)
            WHERE ProductID = @ProductID AND IsActive = 1;

            IF @Price IS NULL
                THROW 50003, 'Product not found or inactive.', 1;

            IF @Stock < @Quantity
                THROW 50004, 'Insufficient stock for requested quantity.', 1;

            INSERT INTO dbo.Orders (CustomerID, OrderStatus, TotalAmount)
            VALUES (@CustomerID, 'Pending', 0);

            SET @NewOrderID = SCOPE_IDENTITY();

            INSERT INTO dbo.OrderItems (OrderID, ProductID, Quantity, UnitPrice)
            VALUES (@NewOrderID, @ProductID, @Quantity, @Price);

            UPDATE dbo.Products
            SET StockQuantity = StockQuantity - @Quantity
            WHERE ProductID = @ProductID;

            UPDATE dbo.Orders
            SET TotalAmount = @Quantity * @Price
            WHERE OrderID = @NewOrderID;

        COMMIT TRANSACTION;

        PRINT CONCAT('Order ', @NewOrderID, ' created successfully.');
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 50000, @ErrMsg, 1;
    END CATCH
END;
GO

-- Example execution + expected output: new order created, stock reduced by 2.
DECLARE @OutOrderID INT;
EXEC dbo.usp_CreateOrder @CustomerID = 4, @ProductID = 9, @Quantity = 2, @NewOrderID = @OutOrderID OUTPUT;
SELECT @OutOrderID AS GeneratedOrderID;
GO

/* ------------------------------------------------------------
   PROCEDURE 2: usp_UpdatePaymentStatus
   Purpose    : Records/updates a payment for an order and moves
                the order to 'Confirmed' once fully paid.
   Parameters : @OrderID        INT
                @PaymentMethod  VARCHAR(20)
                @AmountPaid     DECIMAL(12,2)
   Concept    : Parameterized procedure, validation, conditional
                logic driving a second table's state, TRY...CATCH.
   ------------------------------------------------------------ */
IF OBJECT_ID(N'dbo.usp_UpdatePaymentStatus', N'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_UpdatePaymentStatus;
GO
CREATE PROCEDURE dbo.usp_UpdatePaymentStatus
    @OrderID       INT,
    @PaymentMethod VARCHAR(20),
    @AmountPaid    DECIMAL(12,2)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Orders WHERE OrderID = @OrderID)
            THROW 51001, 'Invalid OrderID.', 1;

        IF @AmountPaid IS NULL OR @AmountPaid <= 0
            THROW 51002, 'AmountPaid must be greater than zero.', 1;

        DECLARE @OrderTotal DECIMAL(12,2) =
            (SELECT TotalAmount FROM dbo.Orders WHERE OrderID = @OrderID);
        DECLARE @NewStatus VARCHAR(20) =
            CASE WHEN @AmountPaid >= @OrderTotal THEN 'Completed' ELSE 'Pending' END;

        BEGIN TRANSACTION;

            IF EXISTS (SELECT 1 FROM dbo.Payments WHERE OrderID = @OrderID)
                UPDATE dbo.Payments
                SET PaymentMethod = @PaymentMethod,
                    AmountPaid = @AmountPaid,
                    PaymentStatus = @NewStatus,
                    PaymentDate = SYSDATETIME()
                WHERE OrderID = @OrderID;
            ELSE
                INSERT INTO dbo.Payments (OrderID, PaymentMethod, AmountPaid, PaymentStatus)
                VALUES (@OrderID, @PaymentMethod, @AmountPaid, @NewStatus);

            IF @NewStatus = 'Completed'
                UPDATE dbo.Orders SET OrderStatus = 'Confirmed' WHERE OrderID = @OrderID;

        COMMIT TRANSACTION;

        PRINT CONCAT('Payment for order ', @OrderID, ' recorded as ', @NewStatus, '.');
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 51000, @ErrMsg, 1;
    END CATCH
END;
GO

-- Example execution + expected output: Payments row upserted, Orders.OrderStatus -> 'Confirmed'.
EXEC dbo.usp_UpdatePaymentStatus @OrderID = 7, @PaymentMethod = 'UPI', @AmountPaid = 450.00;
SELECT * FROM dbo.vw_OrderSummary WHERE OrderID = 7;
GO
