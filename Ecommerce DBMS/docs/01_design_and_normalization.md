# Database Design — E-Commerce Order Management System

## 1. Project Title
E-Commerce Order Management System (SQL Server / T-SQL, database-only, no frontend).

## 2. Problem Statement
Small online retailers need a reliable way to track customers, catalog, orders, payments and
shipments in one consistent database, with accurate order totals, stock levels, and business
reports — without duplicating data or risking update anomalies.

## 3. Objectives
- Design a normalized (3NF) relational schema for order management.
- Enforce data integrity with PK/FK/CHECK/UNIQUE/DEFAULT constraints.
- Automate derived values (order totals, stock changes) via triggers.
- Provide reusable views, procedures and functions for common operations.
- Demonstrate transaction safety (COMMIT/ROLLBACK/SAVE TRANSACTION).
- Produce management-ready reports (sales, inventory, loyalty, delivery).

## 4. Scope
In scope: customer records, product catalog with categories, order placement and line items,
payment records, shipment tracking, an audit trail, and reporting queries.
Out of scope: any UI/API/application layer, user authentication, real payment gateway
integration, multi-warehouse inventory, returns/refunds workflow beyond a status flag.

## 5. Main Entities
Customers, Categories, Products, Orders, OrderItems, Payments, Shipments, AuditLog.

## 6. Entity Relationship Description
- **Customers 1 : N Orders** — a customer places many orders; each order belongs to one customer.
- **Categories 1 : N Products** — a category groups many products; each product has one category.
- **Orders 1 : N OrderItems** — an order contains many line items; each line item belongs to one order.
- **Products 1 : N OrderItems** — a product can appear on many order lines across different orders.
- **Orders 1 : 1 Payments** — one payment record per order (`UNIQUE` FK).
- **Orders 1 : 1 Shipments** — one shipment record per order (`UNIQUE` FK).
- **AuditLog** — independent log table, populated by triggers; references source rows by
  `RecordID` rather than a formal FK, since it logs against multiple source tables.

## 7. Table Structure, Primary Keys, Foreign Keys, Constraints
See `sql/02_create_tables.sql` for the executable DDL. Summary:

| Table | PK | FK(s) | Notable constraints |
|---|---|---|---|
| Customers | CustomerID | — | UNIQUE(Email), CHECK phone length |
| Categories | CategoryID | — | UNIQUE(CategoryName) |
| Products | ProductID | CategoryID → Categories | CHECK price>0, stock≥0 |
| Orders | OrderID | CustomerID → Customers | CHECK status list, total≥0 |
| OrderItems | OrderItemID | OrderID → Orders (CASCADE), ProductID → Products | CHECK qty>0/price>0, UNIQUE(OrderID,ProductID), computed `LineTotal` |
| Payments | PaymentID | OrderID → Orders (CASCADE, UNIQUE) | CHECK method/status lists |
| Shipments | ShipmentID | OrderID → Orders (CASCADE, UNIQUE) | CHECK status list, delivered≥shipped date |
| AuditLog | AuditID | — | CHECK operation type list |

## 8. Normalization: 1NF, 2NF, 3NF

### 1NF — atomic values, no repeating groups
A naive design might store an order's products as a comma-separated list inside `Orders`
(e.g. `Products = "Earbuds x2, Textbook x1"`). That violates 1NF: the column isn't atomic and
can't be filtered, joined, or aggregated per product. **Fix**: `OrderItems` holds one row per
product per order, each attribute atomic (`ProductID`, `Quantity`, `UnitPrice`).

### 2NF — no partial dependency on part of a composite key
Conceptually, an order line is identified by the pair `(OrderID, ProductID)`. If we had used
that pair as the primary key and also stored `ProductName` or `CategoryName` directly in
`OrderItems`, those columns would depend only on `ProductID` — *part* of the key, not the
whole key — a partial dependency. **Fix**: `OrderItems` keeps only facts that depend on the
whole line (`Quantity`, `UnitPrice`, the surrogate `OrderItemID`), and pulls product identity
by FK (`ProductID`) instead of duplicating product attributes. A `UNIQUE(OrderID, ProductID)`
constraint preserves the original business key without making it the storage key.

### 3NF — no transitive dependency
If `Products` stored `CategoryName` directly instead of `CategoryID`, then
`ProductID → CategoryID → CategoryName` would be a transitive dependency (CategoryName depends
on Category, not directly on the product) — editing a category's name would require updating
every product row in it. **Fix**: `Products.CategoryID` references `Categories`, and
`CategoryName` lives only in `Categories`. The same reasoning keeps `Orders` referencing
`CustomerID` rather than duplicating `CustomerName`/`Email`, and keeps `OrderItems.UnitPrice`
as a deliberate historical snapshot (not a transitive read of `Products.UnitPrice`, which can
change after the sale) — this is the standard "price at time of sale" exception normalization
guides call out explicitly, not an anomaly.

### Result
No table duplicates data owned by another table; every non-key column depends on the whole
key, the whole key, and nothing but the key. Insert/update/delete anomalies are avoided:
renaming a category, repricing a product, or correcting a customer's phone number each touch
exactly one row.
