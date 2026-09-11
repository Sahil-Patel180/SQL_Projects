# E-Commerce Order Management System — SQL Server DBMS Mini-Project

Academic DBMS mini-project built entirely in **Microsoft SQL Server (T-SQL)**, executable in **SSMS**. No frontend / application layer — pure database design, DDL, DML, and programmable objects.

## Repo layout

```
ecommerce-dbms-project/
├── docs/
│   ├── 01_design_and_normalization.md   Problem statement, objectives, scope, ER description, 1NF/2NF/3NF
│   └── 02_test_cases_and_checklist.md   Test cases, expected outputs, screenshot plan, requirement checklist
├── sql/
│   ├── 01_create_database.sql           CREATE DATABASE / USE / DROP TABLE (safe re-run)
│   ├── 02_create_tables.sql             8 tables, PK/FK/constraints, dependency-safe order
│   ├── 03_indexes.sql                   Non-clustered indexes + STATISTICS demo
│   ├── 04_sample_data.sql               Curated sample rows (10 cust/18 prod/18 orders)
│   ├── 04b_bulk_data.sql                Optional: scales to ~5k cust / ~500 prod / ~100k orders
│   ├── 05_queries.sql                   20 business queries (SELECT → aggregate reports)
│   ├── 06_views.sql                     2 views
│   ├── 07_procedures.sql                2 stored procedures (TRY...CATCH, transactions)
│   ├── 08_functions.sql                 1 scalar + 1 table-valued function
│   ├── 09_triggers.sql                  2 AFTER triggers (set-based, multi-row safe)
│   ├── 10_transactions.sql              BEGIN TRAN / SAVE TRAN / ROLLBACK / COMMIT demos
│   └── 11_reports.sql                   Reporting queries for screenshots
├── scripts/
│   └── rayso_link.py                    Turns any .sql file (or snippet) into a ray.so share URL
└── .gitignore
```

## Run order (SSMS)

Execute in numeric order, each file in its own query window (or concatenate), `GO` batches respected:

```
01_create_database.sql → 02_create_tables.sql → 03_indexes.sql → 04_sample_data.sql
→ [04b_bulk_data.sql — optional, adds ~100k more orders] →
→ 05_queries.sql → 06_views.sql → 07_procedures.sql → 08_functions.sql
→ 09_triggers.sql → 10_transactions.sql → 11_reports.sql
```

`04b_bulk_data.sql` is additive and idempotent (skips itself if already run) — run it or
skip it, everything after it works either way. IDs 1-10 (customers), 1-18 (products),
1-18 (orders) are always the curated rows, so every worked example in `06`-`10` that
references a specific ID stays valid at any data volume.

## Topic chosen

**E-Commerce Order Management System** — assumed default (topic wasn't specified). Swap-ready design: rename tables and re-run if a different topic from the list is preferred.

## Snippet sharing (ray.so)

`scripts/rayso_link.py` builds a `https://ray.so/#...` URL from any file so a query/proc/trigger can be turned into a shareable code image. See that file's header for usage; two example links are in `docs/02_test_cases_and_checklist.md`.

## Git history

Commits are staged by project phase (schema → data → queries → programmable objects → triggers/transactions → reports/docs) so the history itself documents build order. Push to your own GitHub:

```
git remote add origin https://github.com/<your-username>/ecommerce-dbms-project.git
git branch -M main
git push -u origin main
```
