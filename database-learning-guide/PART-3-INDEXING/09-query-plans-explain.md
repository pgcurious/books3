# Chapter 9: Query Plans & EXPLAIN

> *"Reading an EXPLAIN plan is like reading a medical scan—patterns tell stories if you know what to look for."*

---

## What Is a Query Plan?

Before executing your query, the database creates a **plan**: a step-by-step strategy for retrieving data. Understanding plans lets you:

- Know why a query is slow
- Verify indexes are being used
- Predict query performance
- Identify optimization opportunities

---

## EXPLAIN Variants

```sql
-- Basic plan (estimates only)
EXPLAIN SELECT * FROM users_large WHERE email = 'test@example.com';

-- With execution stats (actually runs the query)
EXPLAIN ANALYZE SELECT * FROM users_large WHERE email = 'test@example.com';

-- Verbose output
EXPLAIN (ANALYZE, VERBOSE) SELECT ...;

-- With buffer/IO stats
EXPLAIN (ANALYZE, BUFFERS) SELECT ...;

-- JSON format (for tooling)
EXPLAIN (FORMAT JSON) SELECT ...;

-- All options
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT TEXT) SELECT ...;
```

---

## Reading EXPLAIN Output

### Basic Structure

```
EXPLAIN ANALYZE SELECT * FROM users_large WHERE email = 'user1@example0.com';

Index Scan using idx_users_large_email on users_large  (cost=0.42..8.44 rows=1 width=95)
  (actual time=0.041..0.042 rows=1 loops=1)
  Index Cond: ((email)::text = 'user1@example0.com'::text)
Planning Time: 0.107 ms
Execution Time: 0.062 ms
```

**Breaking it down:**

| Component | Meaning |
|-----------|---------|
| `Index Scan` | Operation type (how data is accessed) |
| `using idx_users_large_email` | Which index is used |
| `cost=0.42..8.44` | Estimated cost (startup..total) |
| `rows=1` | Estimated rows returned |
| `width=95` | Estimated average row size in bytes |
| `actual time=0.041..0.042` | Real time in milliseconds |
| `rows=1` (actual) | Actual rows returned |
| `loops=1` | How many times this step was executed |

---

## Common Scan Types

### Sequential Scan (Seq Scan)

```
Seq Scan on users_large  (cost=0.00..28856.00 rows=1000000 width=95)
  Filter: (is_active = true)
```

**Meaning:** Reading the entire table, row by row.

**When it happens:**
- No suitable index
- Index exists but not selective enough
- Small table

### Index Scan

```
Index Scan using idx_users_large_email on users_large  (cost=0.42..8.44 rows=1 width=95)
  Index Cond: ((email)::text = 'user1@example0.com'::text)
```

**Meaning:** Using index to find rows, then fetching row data from table.

### Index Only Scan

```
Index Only Scan using idx_covering on users_large  (cost=0.42..5.44 rows=1 width=45)
  Index Cond: (country = 'US'::text)
```

**Meaning:** All needed data is in the index; table not touched (fastest!).

### Bitmap Index Scan

```
Bitmap Heap Scan on users_large  (cost=15.00..2500.00 rows=1000 width=95)
  Recheck Cond: (country = 'US'::text)
  ->  Bitmap Index Scan on idx_users_country  (cost=0.00..14.75 rows=1000 width=0)
        Index Cond: (country = 'US'::text)
```

**Meaning:** First builds a bitmap of matching rows, then fetches them in bulk. Efficient when many rows match.

---

## Join Operations

### Nested Loop

```
Nested Loop  (cost=0.42..16.47 rows=1 width=150)
  ->  Index Scan using idx_orders_user on orders  (cost=0.42..8.44 rows=1 width=50)
  ->  Index Scan using users_pkey on users  (cost=0.42..8.44 rows=1 width=100)
```

**Meaning:** For each row in outer table, scan inner table.

**Good for:** Small outer table, indexed inner table.

### Hash Join

```
Hash Join  (cost=28856.00..58000.00 rows=1000000 width=150)
  Hash Cond: (orders.user_id = users.id)
  ->  Seq Scan on orders  (cost=0.00..15000.00 rows=500000 width=50)
  ->  Hash  (cost=28856.00..28856.00 rows=1000000 width=100)
        ->  Seq Scan on users  (cost=0.00..28856.00 rows=1000000 width=100)
```

**Meaning:** Build hash table from one table, probe with the other.

**Good for:** Large tables, no useful indexes.

### Merge Join

```
Merge Join  (cost=0.85..85000.00 rows=1000000 width=150)
  Merge Cond: (users.id = orders.user_id)
  ->  Index Scan using users_pkey on users  (cost=0.42..40000.00 rows=1000000 width=100)
  ->  Index Scan using idx_orders_user on orders  (cost=0.42..40000.00 rows=500000 width=50)
```

**Meaning:** Both inputs sorted, merge them together.

**Good for:** Large sorted inputs.

---

## Aggregation Operations

### Aggregate

```
Aggregate  (cost=28856.00..28856.01 rows=1 width=8)
  ->  Seq Scan on users_large  (cost=0.00..26356.00 rows=1000000 width=0)
```

**Meaning:** Computing aggregate (COUNT, SUM, AVG, etc.) over results.

### HashAggregate

```
HashAggregate  (cost=28856.00..28856.08 rows=8 width=11)
  Group Key: country
  ->  Seq Scan on users_large  (cost=0.00..26356.00 rows=1000000 width=3)
```

**Meaning:** GROUP BY using a hash table.

### GroupAggregate

```
GroupAggregate  (cost=0.42..50000.00 rows=8 width=11)
  Group Key: country
  ->  Index Scan using idx_country on users_large  (cost=0.42..45000.00 rows=1000000 width=3)
```

**Meaning:** GROUP BY using pre-sorted data.

---

## Filtering Operations

### Filter

```
Seq Scan on users_large  (cost=0.00..28856.00 rows=800000 width=95)
  Filter: is_active
  Rows Removed by Filter: 200000
```

**Meaning:** Post-scan filtering (after reading rows).

**Red flag:** "Rows Removed by Filter" with large numbers indicates potential index opportunity.

### Index Cond vs Filter

```
Index Scan using idx_users_email_active on users_large
  Index Cond: (email = 'test@example.com')
  Filter: (login_count > 100)
  Rows Removed by Filter: 0
```

**Index Cond:** Applied during index scan (efficient).
**Filter:** Applied after fetching row (less efficient).

---

## Understanding Cost

### Cost Units

Cost is in arbitrary units (usually disk page reads), not time:

```
cost=0.42..8.44
      ↑      ↑
   startup  total
```

- **Startup cost:** Work before first row returned
- **Total cost:** Work to return all rows

### Comparing Costs

The optimizer picks the lowest-cost plan:

```sql
-- The optimizer chose Index Scan because:
--   Index Scan cost: 8.44
--   Seq Scan cost: 28856.00

SET enable_indexscan = off;
EXPLAIN SELECT * FROM users_large WHERE email = 'test@example.com';
-- Now shows Seq Scan with higher cost

SET enable_indexscan = on;  -- Reset
```

---

## BUFFERS Output

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM users_large WHERE email = 'user1@example0.com';
```

```
Index Scan using idx_users_large_email on users_large
  (cost=0.42..8.44 rows=1 width=95)
  (actual time=0.041..0.042 rows=1 loops=1)
  Index Cond: ((email)::text = 'user1@example0.com'::text)
  Buffers: shared hit=4
Planning Time: 0.107 ms
Execution Time: 0.062 ms
```

**Buffer meanings:**

| Buffer Type | Meaning |
|-------------|---------|
| shared hit | Pages found in cache (fast) |
| shared read | Pages read from disk (slow) |
| shared dirtied | Pages modified |
| shared written | Pages written to disk |

**First Principle:** High `shared read` with low `shared hit` = cache miss = slow. Consider more RAM or index optimization.

---

## Detecting Problems

### Problem: High Rows Removed by Filter

```
Seq Scan on users_large
  Filter: (status = 'pending')
  Rows Removed by Filter: 999000
  actual rows=1000
```

**Fix:** Add index on `status` column.

### Problem: Estimate vs Actual Mismatch

```
Index Scan (rows=1 estimated) (actual rows=10000)
```

**Fix:** Run `ANALYZE` to update statistics.

```sql
ANALYZE users_large;
```

### Problem: Sort Operations

```
Sort (cost=150000.00..152500.00)
  Sort Key: created_at
  Sort Method: external merge  Disk: 50000kB
```

**Fix:** Add index on sort column, or increase `work_mem`:

```sql
SET work_mem = '256MB';
```

### Problem: Nested Loop with Large Outer

```
Nested Loop (actual loops=1000000)
  ->  Seq Scan on big_table (rows=1000000)
  ->  Index Scan on other_table (loops=1000000)
```

**Fix:** Consider hash join (add index, increase `work_mem`).

---

## Practical Lab: Optimize a Bad Query

```sql
-- Create a query that's intentionally bad
SELECT u.*, COUNT(o.id) as order_count
FROM users_large u
LEFT JOIN (
    SELECT id, user_id
    FROM generate_series(1, 100) AS gs(id)
    CROSS JOIN (SELECT id AS user_id FROM users_large LIMIT 1000) sq
) o ON u.id = o.user_id
WHERE u.country = 'US'
  AND UPPER(u.email) LIKE '%EXAMPLE%'
GROUP BY u.id
ORDER BY u.created_at
LIMIT 100;

-- Analyze it
EXPLAIN (ANALYZE, BUFFERS) <query above>;

-- Identify problems:
-- 1. UPPER() prevents index use
-- 2. LIKE '%...%' prevents index use
-- 3. No index on country
-- 4. Sort without index

-- Fix step by step and re-analyze
```

---

## Quick Reference: EXPLAIN Output Patterns

| Pattern | Indicates | Action |
|---------|-----------|--------|
| `Seq Scan` on large table | Missing index | Add index |
| `Rows Removed by Filter: high` | Unindexed filter | Add index |
| `Sort Method: external merge Disk` | Insufficient work_mem | Increase work_mem |
| `loops=high_number` | Inefficient nested loop | Consider different join |
| `actual rows >> estimated rows` | Stale statistics | Run ANALYZE |
| `shared read >> shared hit` | Cold cache | Need more RAM or better index |

---

## Summary

Reading EXPLAIN is a skill that develops with practice. Key points:

1. **ANALYZE actually runs the query** — Use it to get real numbers
2. **Compare estimated vs actual** — Mismatches indicate stale stats
3. **Watch for Seq Scans on large tables** — Usually means missing index
4. **BUFFERS shows I/O** — High disk reads = slow
5. **Cost is relative** — Compare plans, don't focus on absolute numbers

---

*Next: [Replication Fundamentals](../PART-4-REPLICATION-CONSISTENCY/10-replication-fundamentals.md)*
