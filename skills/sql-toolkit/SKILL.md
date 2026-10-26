---
name: sql-toolkit
description: 'SQL Server code review and universal SQL performance optimization — security, anti-patterns, indexing, pagination, monitoring. Use when reviewing SQL scripts, stored procedures, Dapper queries, or tuning query performance.'
---

# SQL Toolkit

Review and optimize the provided SQL (or the full file) for security, performance, and quality.

---

## Security

### Injection Prevention
```sql
-- Bad: string concatenation
SET @sql = 'SELECT * FROM Users WHERE Id = ' + @input;

-- Good: parameterized
EXEC sp_executesql N'SELECT * FROM Users WHERE Id = @id', N'@id INT', @id = @input;
```

- All user inputs must be parameterized — no string concatenation in dynamic SQL.
- If dynamic SQL is unavoidable, use `sp_executesql` with typed parameters.
- Use `QUOTENAME()` for dynamic object names (table/column references).

### Access Control
- Grant minimum required permissions. Use roles, not direct user grants.
- Stored procs should use `EXECUTE AS` only when necessary.
- Avoid `WITH GRANT OPTION` unless explicitly required.

---

## Query Optimization

### Index Usage
- Columns in WHERE, JOIN, ORDER BY should have supporting indexes.
- Don't wrap indexed columns in functions — kills index seeks:
```sql
-- Bad: function on column prevents index use
WHERE YEAR(CreatedOn) = 2024

-- Good: range predicate uses index
WHERE CreatedOn >= '2024-01-01' AND CreatedOn < '2025-01-01'
```

### Query Patterns
- Never `SELECT *` — list needed columns explicitly.
- Use `EXISTS` instead of `COUNT(*) > 0` for existence checks.
- Prefer `JOIN` over correlated subqueries when the optimizer can't flatten them.
- Use `OPTION (RECOMPILE)` sparingly — only for parameter-sniffing issues with skewed data.
- Check estimated vs actual row counts in execution plans for cardinality mismatches.

### Subquery Optimization
```sql
-- Bad: correlated subquery
SELECT p.product_name, p.price
FROM products p
WHERE p.price > (SELECT AVG(price) FROM products p2 WHERE p2.category_id = p.category_id);

-- Good: window function
SELECT product_name, price
FROM (
    SELECT product_name, price,
           AVG(price) OVER (PARTITION BY category_id) as avg_category_price
    FROM products
) ranked
WHERE price > avg_category_price;
```

### JOIN Optimization
```sql
-- Bad: LEFT JOIN + WHERE filter on right table (converts to INNER JOIN behavior with scan)
SELECT o.*, c.name FROM orders o
LEFT JOIN customers c ON o.customer_id = c.id
WHERE c.status = 'active';

-- Good: INNER JOIN when you need the filter
SELECT o.id, o.total_amount, c.name FROM orders o
INNER JOIN customers c ON o.customer_id = c.id AND c.status = 'active'
WHERE o.created_at > '2024-01-01';
```

### Pagination
```sql
-- Good: keyset pagination (fast for deep pages)
WHERE Id > @LastId ORDER BY Id FETCH NEXT 50 ROWS ONLY

-- Acceptable: OFFSET for shallow pages
ORDER BY Id OFFSET @Skip ROWS FETCH NEXT @Take ROWS ONLY

-- Bad: OFFSET for deep pages (scans all skipped rows)
ORDER BY created_at DESC OFFSET 10000 ROWS FETCH NEXT 20 ROWS ONLY
```

### Aggregation Optimization
```sql
-- Bad: multiple separate queries
SELECT COUNT(*) FROM orders WHERE status = 'pending';
SELECT COUNT(*) FROM orders WHERE status = 'shipped';

-- Good: conditional aggregation
SELECT
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_count,
    COUNT(CASE WHEN status = 'shipped' THEN 1 END) as shipped_count
FROM orders;
```

### OR vs UNION
```sql
-- Bad: complex OR (optimizer may struggle)
SELECT * FROM products
WHERE (category = 'electronics' AND price < 1000) OR (category = 'books' AND price < 50);

-- Good: UNION ALL for separate index paths
SELECT * FROM products WHERE category = 'electronics' AND price < 1000
UNION ALL
SELECT * FROM products WHERE category = 'books' AND price < 50;
```

---

## Anti-Patterns

### N+1 Queries (via Dapper)
```csharp
// Bad: N+1 — one query per user
foreach (var user in users)
    user.Orders = await conn.QueryAsync<Order>("SELECT * FROM Orders WHERE UserId = @Id", new { user.Id });

// Good: single query + split
var sql = "SELECT u.*, o.* FROM Users u LEFT JOIN Orders o ON u.Id = o.UserId WHERE u.Id IN @Ids";
var result = await conn.QueryAsync<User, Order, User>(sql, (u, o) => { ... }, new { Ids = userIds });
```

### DISTINCT Masking Bad Joins
```sql
-- Bad: DISTINCT hides a missing join condition
SELECT DISTINCT u.Name FROM Users u, Orders o WHERE u.Id = o.UserId

-- Good: proper join, no DISTINCT needed
SELECT u.Name FROM Users u INNER JOIN Orders o ON u.Id = o.UserId GROUP BY u.Name
```

### Implicit Conversions
```sql
-- Bad: varchar param against nvarchar column → implicit conversion + scan
WHERE NVarCharColumn = @VarCharParam

-- Good: match types
WHERE NVarCharColumn = @NVarCharParam
```

### Transaction Scope
- Keep transactions as short as possible — long transactions hold locks.
- Don't do HTTP calls or file I/O inside a transaction.
- Use `SET XACT_ABORT ON` in stored procs so errors auto-rollback.

---

## Index Management

### Covering Indexes
```sql
CREATE INDEX idx_orders_covering
ON orders(customer_id, created_at)
INCLUDE (total_amount, status);
```

### Partial Indexes
```sql
CREATE INDEX idx_orders_active
ON orders(created_at)
WHERE status IN ('pending', 'processing');
```

### Batch Operations
```sql
-- Bad: row-by-row
INSERT INTO products (name, price) VALUES ('A', 10);
INSERT INTO products (name, price) VALUES ('B', 15);

-- Good: batch
INSERT INTO products (name, price) VALUES ('A', 10), ('B', 15);
```

---

## Data Types
- `NVARCHAR` for user-facing text, `VARCHAR` for system/ASCII-only data.
- `DATETIME2` over `DATETIME` — more precision, wider range, smaller storage.
- `DECIMAL(p,s)` for money — never `FLOAT` or `REAL`.
- `BIT` for booleans, not `INT` or `TINYINT`.
- Size columns appropriately — `NVARCHAR(50)` not `NVARCHAR(MAX)` for names.
- `JSON` (SQL 2025+) — native binary type, use over `NVARCHAR(MAX)` for JSON data.
- `VECTOR` (SQL 2025+) — optimized binary format for embeddings/similarity search.

---

## SQL Server 2025 Features

### Regular Expressions (prefer over complex LIKE patterns)
```sql
-- Bad: multiple LIKE patterns
WHERE Email LIKE '%@gmail.com' OR Email LIKE '%@yahoo.com'

-- Good: REGEXP_LIKE (SQL 2025+)
WHERE REGEXP_LIKE(Email, '@(gmail|yahoo)\.com$')

-- Replace substrings with regex
SELECT REGEXP_REPLACE(Phone, '[^0-9]', '') AS CleanPhone FROM Contacts

-- Extract matched substring
SELECT REGEXP_SUBSTR(Description, '\d{4}-\d{2}-\d{2}') AS ExtractedDate FROM Notes
```

### String Concatenation
```sql
-- SQL 2025+: standard || operator (alongside existing +)
SELECT FirstName || ' ' || LastName AS FullName FROM Person
```

### JSON Aggregation
```sql
-- Bad: string manipulation to build JSON
-- Good: native JSON aggregation (SQL 2025+)
SELECT JSON_OBJECTAGG(Code VALUE Name) AS LookupMap FROM StatusType
SELECT JSON_ARRAYAGG(Name) AS NameList FROM Person WHERE IsActive = 1
```

### Fuzzy String Matching (requires PREVIEW_FEATURES)
```sql
-- Find similar names
SELECT Name, EDIT_DISTANCE_SIMILARITY(Name, 'Johnson') AS Similarity
FROM Person
WHERE EDIT_DISTANCE_SIMILARITY(Name, 'Johnson') > 70
ORDER BY Similarity DESC
```

### Other 2025 Additions
- `CURRENT_DATE` — returns date without time (ANSI standard)
- `SUBSTRING(expr, start)` — length parameter now optional
- `DATEADD` — number parameter now supports `bigint`
- `BASE64_ENCODE` / `BASE64_DECODE` — binary ↔ text conversion
- `STRING_AGG` — aggregate strings with separator (available since 2017, use it)

---

## Performance Monitoring

```sql
-- SQL Server: top slow queries
SELECT
    qs.total_elapsed_time/qs.execution_count as avg_elapsed_time,
    qs.execution_count,
    SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(qt.text)
        ELSE qs.statement_end_offset END - qs.statement_start_offset)/2)+1) as query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY avg_elapsed_time DESC;
```

---

## Review Checklist

### Security
- [ ] All inputs parameterized — no string concatenation
- [ ] Dynamic SQL uses `sp_executesql` with typed parameters
- [ ] No `SELECT *` on tables with sensitive columns
- [ ] Appropriate permissions (least privilege)

### Performance
- [ ] Indexed columns not wrapped in functions in WHERE clauses
- [ ] No unnecessary `SELECT *`
- [ ] JOINs use appropriate types (INNER vs LEFT vs EXISTS)
- [ ] Large result sets paginated (keyset preferred)
- [ ] No N+1 query patterns in application code
- [ ] No implicit type conversions on indexed columns
- [ ] Covering indexes for frequently-run queries

### Quality
- [ ] Consistent naming (PascalCase for objects, no prefixes like `tbl_` or `sp_`)
- [ ] Schema-qualified object references (`dbo.Users` not just `Users`)
- [ ] `SET NOCOUNT ON` in stored procedures
- [ ] Error handling with `TRY/CATCH` + `THROW` (not `RAISERROR`)
- [ ] Transactions are short and focused
- [ ] `SET XACT_ABORT ON` in procs with transactions
