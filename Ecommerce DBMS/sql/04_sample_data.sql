/* ============================================================
   04_sample_data.sql
   Realistic sample data, valid PK/FK across all tables
   ============================================================ */

USE ECommerceOrderDB;
GO

/* ---- Customers (10) ---- */
INSERT INTO dbo.Customers (FirstName, LastName, Email, Phone, City, State, RegisteredDate) VALUES
('Aarav',  'Shah',    'aarav.shah@example.com',   '9825011111', 'Surat',       'Gujarat',      '2025-11-02'),
('Priya',  'Nair',    'priya.nair@example.com',   '9840022222', 'Chennai',     'Tamil Nadu',   '2025-12-10'),
('Rohan',  'Mehta',   'rohan.mehta@example.com',  '9820033333', 'Mumbai',      'Maharashtra',  '2026-01-05'),
('Sneha',  'Iyer',    'sneha.iyer@example.com',   '9880044444', 'Bengaluru',   'Karnataka',    '2026-01-18'),
('Karan',  'Verma',   'karan.verma@example.com',  '9810055555', 'Delhi',       'Delhi',        '2026-02-02'),
('Anjali', 'Desai',   'anjali.desai@example.com', '9825066666', 'Ahmedabad',   'Gujarat',      '2026-02-14'),
('Vikram', 'Rao',     'vikram.rao@example.com',   '9848066666', 'Hyderabad',   'Telangana',    '2026-03-01'),
('Neha',   'Kapoor',  'neha.kapoor@example.com',  '9890077777', 'Pune',        'Maharashtra',  '2026-03-20'),
('Arjun',  'Pillai',  'arjun.pillai@example.com', '9847088888', 'Kochi',       'Kerala',       '2026-04-08'),
('Divya',  'Menon',   'divya.menon@example.com',  '9843099999', 'Coimbatore',  'Tamil Nadu',   '2026-04-25');
GO

/* ---- Categories (6) ---- */
INSERT INTO dbo.Categories (CategoryName, Description) VALUES
('Electronics',            'Gadgets, accessories and appliances'),
('Clothing',                'Apparel for men and women'),
('Home & Kitchen',          'Cookware, appliances and decor'),
('Books',                   'Textbooks, fiction and non-fiction'),
('Sports & Fitness',        'Fitness gear and sports equipment'),
('Beauty & Personal Care',  'Skincare, haircare and grooming');
GO

/* ---- Products (18, 3 per category; a couple deliberately below ReorderLevel) ---- */
INSERT INTO dbo.Products (ProductName, CategoryID, UnitPrice, StockQuantity, ReorderLevel, IsActive) VALUES
('Wireless Earbuds Pro',        1, 2499.00, 120, 20, 1),
('Smart LED TV 43-inch',        1, 24999.00,   8, 10, 1),   -- below reorder level
('Fast Charger 65W',            1,  899.00, 300, 30, 1),
('Men''s Cotton T-Shirt',       2,  499.00, 500, 50, 1),
('Women''s Kurti Set',          2, 1299.00, 200, 25, 1),
('Denim Jacket',                2, 1899.00,  80, 15, 1),
('Non-Stick Cookware Set',      3, 2199.00,  60, 10, 1),
('Electric Kettle 1.5L',        3,  899.00, 150, 20, 1),
('LED Table Lamp',              3,  699.00,  90, 15, 1),
('DBMS Concepts Textbook',      4,  650.00,  40, 10, 1),
('Data Science Handbook',       4,  899.00,   5, 10, 1),   -- below reorder level
('Fiction Bestseller Novel',    4,  399.00, 200, 25, 1),
('Yoga Mat Premium',            5,  799.00, 150, 20, 1),
('Adjustable Dumbbell Set',     5, 3499.00,  30, 10, 1),
('Badminton Racket',            5, 1199.00,  70, 15, 1),
('Herbal Face Wash',            6,  299.00, 250, 30, 1),
('Hair Growth Serum',           6,  450.00, 180, 25, 1),
('Sunscreen SPF50',             6,  399.00, 220, 30, 1);
GO

/* ---- Orders (18) — TotalAmount seeded 0, recalculated below from OrderItems ---- */
INSERT INTO dbo.Orders (CustomerID, OrderDate, OrderStatus, TotalAmount) VALUES
(1,  '2026-06-05T10:15:00', 'Delivered', 0),
(2,  '2026-06-10T11:30:00', 'Delivered', 0),
(3,  '2026-06-15T09:00:00', 'Cancelled', 0),
(1,  '2026-06-20T14:45:00', 'Delivered', 0),
(4,  '2026-07-02T16:20:00', 'Shipped',   0),
(5,  '2026-07-05T12:10:00', 'Delivered', 0),
(2,  '2026-07-08T18:05:00', 'Pending',   0),
(6,  '2026-07-12T10:40:00', 'Delivered', 0),
(1,  '2026-07-18T13:25:00', 'Delivered', 0),
(7,  '2026-07-22T15:50:00', 'Shipped',   0),
(8,  '2026-08-01T09:35:00', 'Delivered', 0),
(3,  '2026-08-04T11:15:00', 'Delivered', 0),
(9,  '2026-08-09T17:00:00', 'Confirmed', 0),
(2,  '2026-08-14T12:45:00', 'Delivered', 0),
(10, '2026-08-20T10:05:00', 'Delivered', 0),
(4,  '2026-08-25T14:30:00', 'Pending',   0),
(1,  '2026-09-01T09:50:00', 'Confirmed', 0),
(5,  '2026-09-05T16:10:00', 'Delivered', 0);
GO

/* ---- OrderItems (1-2 line items per order) ---- */
INSERT INTO dbo.OrderItems (OrderID, ProductID, Quantity, UnitPrice) VALUES
(1, 1, 2, 2499.00), (1, 10, 1, 650.00),
(2, 4, 3, 499.00),  (2, 16, 2, 299.00),
(3, 2, 1, 24999.00),
(4, 7, 1, 2199.00), (4, 8, 1, 899.00),
(5, 13, 2, 799.00), (5, 14, 1, 3499.00),
(6, 5, 1, 1299.00), (6, 6, 1, 1899.00),
(7, 17, 1, 450.00),
(8, 11, 1, 899.00), (8, 12, 2, 399.00),
(9, 3, 2, 899.00),
(10, 15, 1, 1199.00), (10, 16, 1, 299.00),
(11, 1, 1, 2499.00),
(12, 10, 2, 650.00), (12, 18, 3, 399.00),
(13, 2, 1, 24999.00),
(14, 13, 1, 799.00), (14, 6, 1, 1899.00),
(15, 4, 5, 499.00),
(16, 14, 1, 3499.00),
(17, 8, 2, 899.00), (17, 17, 1, 450.00),
(18, 3, 1, 899.00), (18, 16, 2, 299.00);
GO

/* Recalculate Orders.TotalAmount from OrderItems (trigger takes over once 09_triggers.sql runs) */
UPDATE o
SET o.TotalAmount = x.SumTotal
FROM dbo.Orders o
CROSS APPLY (
    SELECT ISNULL(SUM(LineTotal), 0) AS SumTotal
    FROM dbo.OrderItems
    WHERE OrderID = o.OrderID
) x;
GO

/* ---- Payments — one per Confirmed/Shipped/Delivered order (set-based, derived from Orders) ---- */
INSERT INTO dbo.Payments (OrderID, PaymentDate, PaymentMethod, AmountPaid, PaymentStatus)
SELECT
    OrderID,
    DATEADD(HOUR, 2, OrderDate),
    CASE OrderID % 5
        WHEN 0 THEN 'CreditCard'
        WHEN 1 THEN 'DebitCard'
        WHEN 2 THEN 'UPI'
        WHEN 3 THEN 'NetBanking'
        ELSE 'CashOnDelivery'
    END,
    TotalAmount,
    'Completed'
FROM dbo.Orders
WHERE OrderStatus IN ('Confirmed', 'Shipped', 'Delivered');
GO

/* ---- Shipments — one per Shipped/Delivered order ---- */
INSERT INTO dbo.Shipments (OrderID, Carrier, ShipmentStatus, ShippedDate, DeliveredDate, TrackingNumber)
SELECT
    OrderID,
    'BlueDart Express',
    CASE OrderStatus WHEN 'Delivered' THEN 'Delivered' ELSE 'In Transit' END,
    DATEADD(DAY, 1, OrderDate),
    CASE OrderStatus WHEN 'Delivered' THEN DATEADD(DAY, 4, OrderDate) ELSE NULL END,
    CONCAT('TRK', FORMAT(OrderID, '00000'))
FROM dbo.Orders
WHERE OrderStatus IN ('Shipped', 'Delivered');
GO
