# Chapter 8: Index Performance Lab

> *"The difference between theory and practice is that in theory, there is no difference."*

---

## Lab Overview

In this lab, you will:
1. Create a table with 1 million rows
2. Run queries without indexes (slow)
3. Add indexes and see dramatic speedup
4. Understand when indexes help and when they don't

**Time required:** 30-45 minutes

---

## Setup: Create Test Data

```sql
-- Connect to lab database
\c labdb

-- Create a realistic users table
CREATE TABLE users_large (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255),
    username VARCHAR(50),
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    country VARCHAR(2),
    created_at TIMESTAMP,
    last_login TIMESTAMP,
    is_active BOOLEAN,
    login_count INT
);

-- Insert 1 million rows (takes 1-2 minutes)
INSERT INTO users_large (
    email, username, first_name, last_name,
    country, created_at, last_login, is_active, login_count
)
SELECT
    'user' || i || '@example' || (i % 100) || '.com',
    'user_' || i,
    (ARRAY['John','Jane','Bob','Alice','Charlie','Diana','Eve','Frank'])[1 + (i % 8)],
    (ARRAY['Smith','Jones','Brown','Wilson','Taylor','Davis','Miller','Anderson'])[1 + (i % 8)],
    (ARRAY['US','UK','CA','DE','FR','JP','AU','BR'])[1 + (i % 8)],
    NOW() - (random() * interval '365 days'),
    NOW() - (random() * interval '30 days'),
    random() > 0.2,  -- 80% active
    floor(random() * 1000)::int
FROM generate_series(1, 1000000) AS i;

-- Verify
SELECT COUNT(*) FROM users_large;
-- Should show: 1,000,000

-- Analyze to update statistics
ANALYZE users_large;
```

---

## Experiment 1: Feel the Pain (No Index)

```sql
-- Enable timing
\timing on

-- Search for a specific email
SELECT * FROM users_large WHERE email = 'user500000@example0.com';
```

**Expected result:** ~200-500ms (sequential scan of entire table)

```sql
-- Check the query plan
EXPLAIN ANALYZE SELECT * FROM users_large WHERE email = 'user500000@example0.com';
```

**You'll see something like:**
```
Seq Scan on users_large  (cost=0.00..28856.00 rows=1 width=95)
  (actual time=234.521..487.612 rows=1 loops=1)
  Filter: ((email)::text = 'user500000@example0.com'::text)
  Rows Removed by Filter: 999999
Planning Time: 0.123 ms
Execution Time: 487.789 ms
```

**Key observation:** "Seq Scan" = reading entire table. "Rows Removed by Filter: 999999" = checked 1 million rows to find 1.

---

## Experiment 2: Add an Index

```sql
-- Create index (takes ~10-20 seconds)
CREATE INDEX idx_users_large_email ON users_large(email);

-- Same query
SELECT * FROM users_large WHERE email = 'user500000@example0.com';
```

**Expected result:** ~1-5ms (100x faster!)

```sql
-- Check the query plan
EXPLAIN ANALYZE SELECT * FROM users_large WHERE email = 'user500000@example0.com';
```

**You'll see:**
```
Index Scan using idx_users_large_email on users_large  (cost=0.42..8.44 rows=1 width=95)
  (actual time=0.057..0.059 rows=1 loops=1)
  Index Cond: ((email)::text = 'user500000@example0.com'::text)
Planning Time: 0.321 ms
Execution Time: 0.089 ms
```

**Key observation:** "Index Scan" instead of "Seq Scan". Execution time dropped from ~500ms to ~0.1ms.

---

## Experiment 3: Range Queries

```sql
-- Find users created in the last week (no index yet)
EXPLAIN ANALYZE
SELECT COUNT(*) FROM users_large
WHERE created_at > NOW() - interval '7 days';
```

**Result:** Seq Scan, slow

```sql
-- Add index
CREATE INDEX idx_users_large_created_at ON users_large(created_at);

-- Same query
EXPLAIN ANALYZE
SELECT COUNT(*) FROM users_large
WHERE created_at > NOW() - interval '7 days';
```

**Note:** For COUNT(*), PostgreSQL might still use Seq Scan if the result set is large (>5-10% of table). The optimizer knows it's faster to just scan everything than make millions of index lookups.

```sql
-- But for actual row retrieval:
EXPLAIN ANALYZE
SELECT * FROM users_large
WHERE created_at > NOW() - interval '1 day'
LIMIT 100;
```

**This will use the index** because we're fetching few rows.

---

## Experiment 4: Composite Index Power

```sql
-- Query: Find active US users
EXPLAIN ANALYZE
SELECT COUNT(*) FROM users_large
WHERE country = 'US' AND is_active = true;
```

**Without composite index:** Seq Scan or partial index use

```sql
-- Create composite index
CREATE INDEX idx_users_country_active ON users_large(country, is_active);

-- Same query
EXPLAIN ANALYZE
SELECT COUNT(*) FROM users_large
WHERE country = 'US' AND is_active = true;
```

**Result:** Index Scan or Bitmap Index Scan

### Composite Index Order Matters

```sql
-- This uses the index (leftmost prefix):
EXPLAIN ANALYZE SELECT * FROM users_large WHERE country = 'US';

-- This does NOT use our (country, is_active) index efficiently:
EXPLAIN ANALYZE SELECT * FROM users_large WHERE is_active = true;
```

---

## Experiment 5: The Index-Only Scan

The fastest scan—doesn't even touch the table!

```sql
-- Query that only needs indexed columns
EXPLAIN ANALYZE
SELECT email FROM users_large WHERE email LIKE 'user1%' LIMIT 100;
```

If you see "Index Only Scan," the query was answered entirely from the index.

```sql
-- Create covering index for specific query pattern
CREATE INDEX idx_users_covering ON users_large(country, email)
INCLUDE (first_name, last_name);

-- Query can be answered from index alone:
EXPLAIN ANALYZE
SELECT email, first_name, last_name
FROM users_large
WHERE country = 'US'
LIMIT 100;
```

---

## Experiment 6: When Indexes Don't Help

### Low Selectivity

```sql
-- 80% of users are active - index won't help
EXPLAIN ANALYZE
SELECT * FROM users_large WHERE is_active = true LIMIT 1000;
-- May still use Seq Scan!

-- But for inactive users (20%):
EXPLAIN ANALYZE
SELECT * FROM users_large WHERE is_active = false LIMIT 1000;
-- More likely to use index
```

### Function Usage

```sql
-- Index on email, but:
EXPLAIN ANALYZE
SELECT * FROM users_large WHERE LOWER(email) = 'user500000@example0.com';
-- Seq Scan! Index not used.

-- Fix with expression index:
CREATE INDEX idx_users_lower_email ON users_large(LOWER(email));

EXPLAIN ANALYZE
SELECT * FROM users_large WHERE LOWER(email) = 'user500000@example0.com';
-- Now uses index
```

### LIKE with Leading Wildcard

```sql
-- Uses index (prefix match):
EXPLAIN ANALYZE
SELECT * FROM users_large WHERE email LIKE 'user500%';

-- Does NOT use index (suffix match):
EXPLAIN ANALYZE
SELECT * FROM users_large WHERE email LIKE '%@example0.com';
```

---

## Experiment 7: Write Performance Impact

```sql
-- Check index sizes
SELECT
    indexrelname AS index_name,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE relname = 'users_large'
ORDER BY pg_relation_size(indexrelid) DESC;

-- Time an insert (with all indexes)
\timing on
INSERT INTO users_large (email, username, first_name, last_name, country, created_at, is_active, login_count)
VALUES ('new@test.com', 'newuser', 'New', 'User', 'US', NOW(), true, 0);

-- Drop all non-PK indexes
DROP INDEX idx_users_large_email;
DROP INDEX idx_users_large_created_at;
DROP INDEX idx_users_country_active;
DROP INDEX idx_users_covering;
DROP INDEX idx_users_lower_email;

-- Time an insert (no indexes)
INSERT INTO users_large (email, username, first_name, last_name, country, created_at, is_active, login_count)
VALUES ('new2@test.com', 'newuser2', 'New2', 'User2', 'UK', NOW(), true, 0);
```

**Observation:** Inserts are faster without indexes (especially noticeable in bulk operations).

---

## Experiment 8: Finding Missing Indexes

```sql
-- Queries with sequential scans (potential missing indexes)
SELECT
    schemaname,
    relname AS table_name,
    seq_scan,
    seq_tup_read,
    idx_scan,
    idx_tup_fetch,
    CASE WHEN seq_scan > 0
         THEN round(seq_tup_read::numeric / seq_scan, 2)
         ELSE 0
    END AS avg_rows_per_seq_scan
FROM pg_stat_user_tables
WHERE seq_scan > 0
ORDER BY seq_tup_read DESC;

-- Tables with high sequential scan / index scan ratio
SELECT
    relname,
    seq_scan,
    idx_scan,
    CASE WHEN idx_scan > 0
         THEN round(seq_scan::numeric / idx_scan, 2)
         ELSE seq_scan
    END AS seq_to_idx_ratio
FROM pg_stat_user_tables
WHERE seq_scan > 100
ORDER BY seq_to_idx_ratio DESC;
```

---

## Summary: What You Experienced

| Scenario | Without Index | With Index | Speedup |
|----------|--------------|------------|---------|
| Exact match on 1M rows | ~500ms | ~0.1ms | 5000x |
| Range query | ~300ms | ~10ms | 30x |
| Multi-column filter | ~400ms | ~5ms | 80x |

---

## Cleanup

```sql
-- Recreate essential indexes for further labs
CREATE INDEX idx_users_large_email ON users_large(email);
CREATE INDEX idx_users_large_created_at ON users_large(created_at);

-- Keep the table for Part 4 (replication labs)
```

---

## Key Takeaways

1. **Indexes provide dramatic speedup** — 100x-5000x for point queries
2. **EXPLAIN ANALYZE is your friend** — Always verify index usage
3. **Not all queries benefit** — Low selectivity, functions, wildcards
4. **Indexes cost writes** — Balance read speed vs write speed
5. **Monitor and tune** — Use pg_stat_user_tables to find problems

---

*Next: [Query Plans & EXPLAIN](./09-query-plans-explain.md)*
