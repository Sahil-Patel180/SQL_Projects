# Test Cases, Screenshot Plan & Requirement Checklist

## Test Cases & Expected Outputs

| # | Test | Steps | Expected Result |
|---|---|---|---|
| TC1 | FK enforcement | `INSERT INTO Products (CategoryID=999, ...)` | Statement fails — `FK_Products_Categories` violation |
| TC2 | CHECK enforcement | `INSERT INTO OrderItems (..., Quantity=-1, ...)` | Statement fails — `CK_OrderItems_Quantity` violation |
| TC3 | UNIQUE enforcement | `INSERT INTO Customers` with an existing `Email` | Statement fails — `UQ_Customers_Email` violation |
| TC4 | 1:1 enforcement | Insert a second `Payments` row for the same `OrderID` | Statement fails — `UQ_Payments_OrderID` violation |
| TC5 | Trigger — audit | `UPDATE Products SET StockQuantity = StockQuantity - 1 WHERE ProductID IN (1,4)` | 2 new rows in `AuditLog`, one per `ProductID` |
| TC6 | Trigger — order total | `INSERT` a new `OrderItems` row for `OrderID 7`, then `DELETE` it | `Orders.TotalAmount` rises then returns to its original value |
| TC7 | Procedure — happy path | `EXEC usp_CreateOrder @CustomerID=4, @ProductID=9, @Quantity=2, ...` | New `Orders`/`OrderItems` rows, `Products.StockQuantity` reduced by 2 |
| TC8 | Procedure — validation | `EXEC usp_CreateOrder @CustomerID=4, @ProductID=2, @Quantity=999, ...` | Custom error 50004 "Insufficient stock", no rows written (`XACT_ABORT` + `CATCH` rollback) |
| TC9 | Function — scalar | `SELECT dbo.ufn_GetOrderTotal(1)` | Returns `5648.00`, matches `Orders.TotalAmount` for OrderID 1 |
| TC10 | Transaction — savepoint | Run Demo 1 in `10_transactions.sql` | Order for Customer 8 commits with exactly 1 line item, not 2 |
| TC11 | Transaction — full rollback | Run Demo 2 in `10_transactions.sql` | `Orders` row count unchanged after the attempt |
| TC12 | View | `SELECT * FROM vw_OrderSummary WHERE OrderID = 3` | Cancelled order shows `NULL` `PaymentMethod`/`ShipmentStatus` (no payment/shipment ever created) |
| TC13 | Bulk data idempotency | Run `04b_bulk_data.sql` twice in a row | Second run prints "Bulk data already present — skipping." and row counts don't change |
| TC14 | Bulk data integrity | After `04b_bulk_data.sql`, run `SELECT COUNT(*) FROM OrderItems oi LEFT JOIN Orders o ON o.OrderID=oi.OrderID WHERE o.OrderID IS NULL` | Returns 0 — every generated line item points at a real order (same check for ProductID) |
| TC15 | Live queue — add | `INSERT` a new `Orders` row with status `Pending` | Row instantly appears in `ActiveOrders` / `vw_ActiveOrdersQueue` |
| TC16 | Live queue — remove | `UPDATE` that order's `OrderStatus` to `Delivered` | Row instantly disappears from `ActiveOrders`, but stays in `Orders` (history preserved) |

## Screenshot Evidence Plan
For each numbered script (`01` → `11`), capture in SSMS:
1. The script open in the query editor.
2. **Messages** tab showing successful execution (`Commands completed successfully`, row counts, or `PRINT` output for procedures/transactions).
3. **Results** grid for any `SELECT` used to verify behaviour (sample data counts, view output, trigger test queries, report results).

Suggested screenshot set for a report/submission: table list in Object Explorer (`sys.tables`), one `CREATE TABLE` result, `05_queries.sql` results for Q8/Q12/Q18, both views' output, both procedures' `PRINT` + verification `SELECT`, both function calls, both trigger test blocks, both transaction demos, and all 8 reports in `11_reports.sql`.

At bulk scale (`04b_bulk_data.sql` run), Q6/Q8/Q18 and the `vw_OrderSummary` preview already carry `TOP (20)` for exactly this reason — screenshot those as-is; every other query/report stays small (aggregated or already filtered) regardless of data volume.

## Snippet sharing (ray.so)
Generated with `scripts/rayso_link.py`:
- Trigger 1 (`trg_Products_StockAudit`): https://ray.so/#background=true&darkMode=true&padding=32&theme=midnight&language=sql&title=09_triggers.sql%20%28L15-43%29&code=ICAgICAgICAgICAgICAgIHdoZW4gYW4gVVBEQVRFIHN0YXRlbWVudCB0b3VjaGVzIG1hbnkgcm93cyBhdCBvbmNlLgogICBDb25jZXB0ICAgIDogQUZURVIgdHJpZ2dlciwgYXVkaXQgbG9nZ2luZywgc2V0LWJhc2VkIHBzZXVkby10YWJsZQogICAgICAgICAgICAgICAgaGFuZGxpbmcgKG5vIGFzc3VtcHRpb24gb2Ygc2luZ2xlLXJvdyBETUwpLgogICAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0gKi8KSUYgT0JKRUNUX0lEKE4nZGJvLnRyZ19Qcm9kdWN0c19TdG9ja0F1ZGl0JywgTidUUicpIElTIE5PVCBOVUxMCiAgICBEUk9QIFRSSUdHRVIgZGJvLnRyZ19Qcm9kdWN0c19TdG9ja0F1ZGl0OwpHTwpDUkVBVEUgVFJJR0dFUiBkYm8udHJnX1Byb2R1Y3RzX1N0b2NrQXVkaXQKT04gZGJvLlByb2R1Y3RzCkFGVEVSIFVQREFURQpBUwpCRUdJTgogICAgU0VUIE5PQ09VTlQgT047CgogICAgSUYgTk9UIFVQREFURShTdG9ja1F1YW50aXR5KQogICAgICAgIFJFVFVSTjsKCiAgICBJTlNFUlQgSU5UTyBkYm8uQXVkaXRMb2cgKFRhYmxlTmFtZSwgT3BlcmF0aW9uVHlwZSwgUmVjb3JkSUQsIENoYW5nZWRDb2x1bW4sIE9sZFZhbHVlLCBOZXdWYWx1ZSkKICAgIFNFTEVDVAogICAgICAgICdQcm9kdWN0cycsCiAgICAgICAgJ1VQREFURScsCiAgICAgICAgZC5Qcm9kdWN0SUQsCiAgICAgICAgJ1N0b2NrUXVhbnRpdHknLAogICAgICAgIENBU1QoZC5TdG9ja1F1YW50aXR5IEFTIFZBUkNIQVIoMjAwKSksCiAgICAgICAgQ0FTVChpLlN0b2NrUXVhbnRpdHkgQVMgVkFSQ0hBUigyMDApKQogICAgRlJPTSBkZWxldGVkIGQKICAgIEpPSU4gaW5zZXJ0ZWQgaSBPTiBpLlByb2R1Y3RJRCA9IGQuUHJvZHVjdElECiAgICBXSEVSRSBkLlN0b2NrUXVhbnRpdHkgPD4gaS5TdG9ja1F1YW50aXR5OwpFTkQ7Cg%3D%3D
- Query 18 (`CASE` expression, order sizing): https://ray.so/#background=true&darkMode=true&padding=32&theme=midnight&language=sql&title=05_queries.sql%20%28L157-163%29&code=LS0gUTE4IFtDQVNFIGV4cHJlc3Npb25dIENsYXNzaWZ5IG9yZGVycyBieSBzaXplLgpTRUxFQ1QgT3JkZXJJRCwgVG90YWxBbW91bnQsCiAgICAgICBDQVNFCiAgICAgICAgICAgV0hFTiBUb3RhbEFtb3VudCA%2BPSAxMDAwMCBUSEVOICdMYXJnZScKICAgICAgICAgICBXSEVOIFRvdGFsQW1vdW50ID49IDIwMDAgIFRIRU4gJ01lZGl1bScKICAgICAgICAgICBFTFNFICdTbWFsbCcKICAgICAgIEVORCBBUyBPcmRlclNpemUK

Generate more with: `python3 scripts/rayso_link.py <file> [start_line end_line]`. Open the printed URL — ray.so decodes the `code` hash param client-side and renders it in its editor, ready to theme/export.

## Requirement-Verification Checklist
- [x] 6–10 tables → **8** (`Customers, Categories, Products, Orders, OrderItems, Payments, Shipments, AuditLog`)
- [x] Primary Keys → every table, `IDENTITY` surrogate keys
- [x] Foreign Keys → `Products→Categories`, `Orders→Customers`, `OrderItems→Orders/Products`, `Payments→Orders`, `Shipments→Orders`
- [x] NOT NULL / UNIQUE / CHECK / DEFAULT constraints → present on every table (`sql/02_create_tables.sql`)
- [x] 1NF → `docs/01_design_and_normalization.md` §8
- [x] 2NF → `docs/01_design_and_normalization.md` §8
- [x] 3NF → `docs/01_design_and_normalization.md` §8
- [x] 15+ SQL queries → **20** in `sql/05_queries.sql`
- [x] Simple JOINs → Q6
- [x] Complex JOINs → Q8, Q9, Q10
- [x] Subqueries (incl. correlated) → Q12, Q13
- [x] Aggregate functions → Q11, Q20, reports
- [x] 2 Views → `sql/06_views.sql` (+ 1 bonus: `vw_ActiveOrdersQueue` in `sql/12_active_orders_queue.sql`)
- [x] 2 Stored Procedures → `sql/07_procedures.sql`
- [x] 2 Functions (scalar + TVF) → `sql/08_functions.sql`
- [x] 2 Triggers → `sql/09_triggers.sql` (+ 2 bonus: real-time active-order queue in `sql/12_active_orders_queue.sql`)
- [x] BEGIN TRANSACTION / COMMIT / ROLLBACK / SAVE TRANSACTION → `sql/10_transactions.sql`
- [x] 1+ Index → 4 in `sql/03_indexes.sql`
- [x] Meaningful reports → 8 in `sql/11_reports.sql`
- [x] Sample data → `sql/04_sample_data.sql` (10 customers, 6 categories, 18 products, 18 orders curated) + optional `sql/04b_bulk_data.sql` (scales to ~5,000 customers, 10 categories, ~500 products, ~100,000 orders, ~250,000 order items)
- [x] SSMS execution examples → every `.sql` file has example `EXEC`/`SELECT` calls inline
- [x] Output screenshot evidence → plan above (this file)

## Conclusion
The schema models an e-commerce order pipeline in 3NF with enforced referential integrity,
automated totals and audit logging via triggers, reusable views/procedures/functions, and
transaction-safe order placement — fully expressed in SSMS-executable T-SQL with no
application layer.
