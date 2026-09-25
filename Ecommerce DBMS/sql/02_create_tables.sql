/* ============================================================
   02_create_tables.sql
   8 tables, dependency-safe CREATE order, safe re-run via DROP
   ============================================================ */

USE ECommerceOrderDB;
GO

/* ---- Drop in reverse dependency order (safe re-execution) ---- */
IF OBJECT_ID(N'dbo.AuditLog', N'U')    IS NOT NULL DROP TABLE dbo.AuditLog;
IF OBJECT_ID(N'dbo.Shipments', N'U')   IS NOT NULL DROP TABLE dbo.Shipments;
IF OBJECT_ID(N'dbo.Payments', N'U')    IS NOT NULL DROP TABLE dbo.Payments;
IF OBJECT_ID(N'dbo.OrderItems', N'U')  IS NOT NULL DROP TABLE dbo.OrderItems;
IF OBJECT_ID(N'dbo.Orders', N'U')      IS NOT NULL DROP TABLE dbo.Orders;
IF OBJECT_ID(N'dbo.Products', N'U')    IS NOT NULL DROP TABLE dbo.Products;
IF OBJECT_ID(N'dbo.Categories', N'U')  IS NOT NULL DROP TABLE dbo.Categories;
IF OBJECT_ID(N'dbo.Customers', N'U')   IS NOT NULL DROP TABLE dbo.Customers;
GO

/* ---- 1. Customers ---- */
CREATE TABLE dbo.Customers
(
    CustomerID      INT IDENTITY(1,1) NOT NULL,
    FirstName       VARCHAR(50)       NOT NULL,
    LastName        VARCHAR(50)       NOT NULL,
    Email           VARCHAR(100)      NOT NULL,
    Phone           VARCHAR(15)       NOT NULL,
    City            VARCHAR(50)       NOT NULL,
    State           VARCHAR(50)       NOT NULL,
    RegisteredDate  DATE              NOT NULL DEFAULT (CAST(GETDATE() AS DATE)),
    CONSTRAINT PK_Customers PRIMARY KEY CLUSTERED (CustomerID),
    CONSTRAINT UQ_Customers_Email UNIQUE (Email),
    CONSTRAINT CK_Customers_Phone CHECK (LEN(Phone) >= 10)
);
GO

/* ---- 2. Categories ---- */
CREATE TABLE dbo.Categories
(
    CategoryID    INT IDENTITY(1,1) NOT NULL,
    CategoryName  VARCHAR(50)       NOT NULL,
    Description   VARCHAR(200)      NULL,
    CONSTRAINT PK_Categories PRIMARY KEY CLUSTERED (CategoryID),
    CONSTRAINT UQ_Categories_Name UNIQUE (CategoryName)
);
GO

/* ---- 3. Products (FK -> Categories) ---- */
CREATE TABLE dbo.Products
(
    ProductID      INT IDENTITY(1,1) NOT NULL,
    ProductName    VARCHAR(100)      NOT NULL,
    CategoryID     INT               NOT NULL,
    UnitPrice      DECIMAL(10,2)     NOT NULL,
    StockQuantity  INT               NOT NULL DEFAULT (0),
    ReorderLevel   INT               NOT NULL DEFAULT (10),
    IsActive       BIT               NOT NULL DEFAULT (1),
    CONSTRAINT PK_Products PRIMARY KEY CLUSTERED (ProductID),
    CONSTRAINT FK_Products_Categories FOREIGN KEY (CategoryID)
        REFERENCES dbo.Categories (CategoryID),
    CONSTRAINT CK_Products_UnitPrice CHECK (UnitPrice > 0),
    CONSTRAINT CK_Products_StockQuantity CHECK (StockQuantity >= 0),
    CONSTRAINT CK_Products_ReorderLevel CHECK (ReorderLevel >= 0)
);
GO

/* ---- 4. Orders (FK -> Customers) ---- */
CREATE TABLE dbo.Orders
(
    OrderID       INT IDENTITY(1,1) NOT NULL,
    CustomerID    INT                NOT NULL,
    OrderDate     DATETIME2(0)       NOT NULL DEFAULT (SYSDATETIME()),
    OrderStatus   VARCHAR(20)        NOT NULL DEFAULT ('Pending'),
    TotalAmount   DECIMAL(12,2)      NOT NULL DEFAULT (0),
    CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED (OrderID),
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerID)
        REFERENCES dbo.Customers (CustomerID),
    CONSTRAINT CK_Orders_Status CHECK (OrderStatus IN
        ('Pending','Confirmed','Shipped','Delivered','Cancelled')),
    CONSTRAINT CK_Orders_TotalAmount CHECK (TotalAmount >= 0)
);
GO

/* ---- 5. OrderItems (FK -> Orders, Products) ---- */
CREATE TABLE dbo.OrderItems
(
    OrderItemID  INT IDENTITY(1,1) NOT NULL,
    OrderID      INT                NOT NULL,
    ProductID    INT                NOT NULL,
    Quantity     INT                NOT NULL,
    UnitPrice    DECIMAL(10,2)      NOT NULL,   -- price at time of sale (history-safe)
    LineTotal    AS (CAST(Quantity AS DECIMAL(12,2)) * UnitPrice) PERSISTED,
    CONSTRAINT PK_OrderItems PRIMARY KEY CLUSTERED (OrderItemID),
    CONSTRAINT FK_OrderItems_Orders FOREIGN KEY (OrderID)
        REFERENCES dbo.Orders (OrderID) ON DELETE CASCADE,
    CONSTRAINT FK_OrderItems_Products FOREIGN KEY (ProductID)
        REFERENCES dbo.Products (ProductID),
    CONSTRAINT CK_OrderItems_Quantity CHECK (Quantity > 0),
    CONSTRAINT CK_OrderItems_UnitPrice CHECK (UnitPrice > 0),
    CONSTRAINT UQ_OrderItems_Order_Product UNIQUE (OrderID, ProductID)
);
GO

/* ---- 6. Payments (1:1 with Orders) ---- */
CREATE TABLE dbo.Payments
(
    PaymentID      INT IDENTITY(1,1) NOT NULL,
    OrderID        INT                NOT NULL,
    PaymentDate    DATETIME2(0)       NOT NULL DEFAULT (SYSDATETIME()),
    PaymentMethod  VARCHAR(20)        NOT NULL,
    AmountPaid     DECIMAL(12,2)      NOT NULL,
    PaymentStatus  VARCHAR(20)        NOT NULL DEFAULT ('Pending'),
    CONSTRAINT PK_Payments PRIMARY KEY CLUSTERED (PaymentID),
    CONSTRAINT FK_Payments_Orders FOREIGN KEY (OrderID)
        REFERENCES dbo.Orders (OrderID) ON DELETE CASCADE,
    CONSTRAINT UQ_Payments_OrderID UNIQUE (OrderID),
    CONSTRAINT CK_Payments_Method CHECK (PaymentMethod IN
        ('CreditCard','DebitCard','UPI','NetBanking','CashOnDelivery')),
    CONSTRAINT CK_Payments_Status CHECK (PaymentStatus IN
        ('Pending','Completed','Failed','Refunded')),
    CONSTRAINT CK_Payments_Amount CHECK (AmountPaid >= 0)
);
GO

/* ---- 7. Shipments (1:1 with Orders) ---- */
CREATE TABLE dbo.Shipments
(
    ShipmentID      INT IDENTITY(1,1) NOT NULL,
    OrderID         INT                NOT NULL,
    Carrier         VARCHAR(50)        NOT NULL DEFAULT ('Standard Courier'),
    ShipmentStatus  VARCHAR(20)        NOT NULL DEFAULT ('Not Shipped'),
    ShippedDate     DATETIME2(0)       NULL,
    DeliveredDate   DATETIME2(0)       NULL,
    TrackingNumber  VARCHAR(30)        NULL,
    CONSTRAINT PK_Shipments PRIMARY KEY CLUSTERED (ShipmentID),
    CONSTRAINT FK_Shipments_Orders FOREIGN KEY (OrderID)
        REFERENCES dbo.Orders (OrderID) ON DELETE CASCADE,
    CONSTRAINT UQ_Shipments_OrderID UNIQUE (OrderID),
    CONSTRAINT CK_Shipments_Status CHECK (ShipmentStatus IN
        ('Not Shipped','In Transit','Delivered','Returned')),
    CONSTRAINT CK_Shipments_Dates CHECK (
        DeliveredDate IS NULL OR ShippedDate IS NULL OR DeliveredDate >= ShippedDate)
);
GO

/* ---- 8. AuditLog (populated by triggers, no FK — generic log) ---- */
CREATE TABLE dbo.AuditLog
(
    AuditID         INT IDENTITY(1,1) NOT NULL,
    TableName       VARCHAR(50)        NOT NULL,
    OperationType   VARCHAR(10)        NOT NULL,
    RecordID        INT                NOT NULL,
    ChangedColumn   VARCHAR(50)        NULL,
    OldValue        VARCHAR(200)       NULL,
    NewValue        VARCHAR(200)       NULL,
    ChangedAt       DATETIME2(0)       NOT NULL DEFAULT (SYSDATETIME()),
    ChangedBy       VARCHAR(50)        NOT NULL DEFAULT (SUSER_SNAME()),
    CONSTRAINT PK_AuditLog PRIMARY KEY CLUSTERED (AuditID),
    CONSTRAINT CK_AuditLog_OpType CHECK (OperationType IN ('INSERT','UPDATE','DELETE'))
);
GO
