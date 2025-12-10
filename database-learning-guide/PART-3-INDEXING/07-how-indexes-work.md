# Chapter 7: How Indexes Work

> *"An index is like the index in a book—instead of reading every page to find 'photosynthesis,' you look it up and jump directly to page 247."*

---

## The Fundamental Problem

You have a table with 10 million users. You need to find `email = 'alice@example.com'`.

Without an index, the database must:
1. Read every row from disk
2. Check each row's email column
3. Return matches

This is called a **sequential scan** (or full table scan). With 10 million rows, it takes seconds.

With an index, the database:
1. Looks up 'alice@example.com' in the index structure
2. Finds the exact disk location
3. Reads that one row

This takes milliseconds.

**First Principle:** Indexes trade write speed and storage space for read speed.

---

## B-Tree: The Default Index

Almost every database index is a B-Tree (balanced tree). Here's why:

### The Problem B-Trees Solve

Given sorted data, binary search finds items in O(log n) time. But binary search requires:
- Random access (arrays, not linked lists)
- All data in memory

B-Trees give us O(log n) search with:
- Disk-friendly access patterns (read in pages)
- Only keeping some nodes in memory

### B-Tree Structure

```
                    [M]
                   /   \
            [D, H]     [R, X]
           /  |  \     /  |  \
        [A-C][E-G][I-L][N-Q][S-W][Y-Z]
              ↓
           Leaf nodes point to actual rows
```

**Properties:**
- Balanced: All leaf nodes at same depth
- Sorted: Keys in order within and across nodes
- Wide: Many keys per node (fits disk pages)
- Self-balancing: Stays efficient as data changes

### Why B-Trees Are Everywhere

```
Binary tree depth for 1M items: ~20 levels
B-tree depth for 1M items: ~3 levels (with branching factor ~100)

Each level = 1 disk read
3 reads vs 20 reads = massive speedup
```

---

## Creating Indexes

### Basic Index

```sql
-- Create index on email column
CREATE INDEX idx_users_email ON users(email);

-- PostgreSQL will use B-tree by default
-- Equivalent to:
CREATE INDEX idx_users_email ON users USING btree(email);
```

### Unique Index

```sql
-- Enforces uniqueness + enables fast lookups
CREATE UNIQUE INDEX idx_users_email ON users(email);

-- Often created implicitly with UNIQUE constraint
ALTER TABLE users ADD CONSTRAINT unique_email UNIQUE (email);
```

### Composite Index

```sql
-- Index on multiple columns
CREATE INDEX idx_orders_customer_date
ON orders(customer_id, order_date);

-- Order matters! This index helps:
-- WHERE customer_id = 123
-- WHERE customer_id = 123 AND order_date > '2024-01-01'

-- But NOT:
-- WHERE order_date > '2024-01-01' (can't skip first column)
```

### Partial Index

```sql
-- Index only some rows
CREATE INDEX idx_orders_pending
ON orders(created_at)
WHERE status = 'pending';

-- Smaller index, faster for common queries
```

### Expression Index

```sql
-- Index on computed values
CREATE INDEX idx_users_lower_email
ON users(LOWER(email));

-- Now this query uses the index:
SELECT * FROM users WHERE LOWER(email) = 'alice@example.com';
```

---

## When Indexes Are Used

### Index Scan Conditions

The database uses an index when:

1. **Equality on indexed column**
   ```sql
   WHERE email = 'alice@example.com'  -- Uses index
   ```

2. **Range on indexed column**
   ```sql
   WHERE created_at > '2024-01-01'  -- Uses index
   WHERE age BETWEEN 18 AND 65      -- Uses index
   ```

3. **Prefix match (B-tree only)**
   ```sql
   WHERE name LIKE 'Ali%'  -- Uses index
   WHERE name LIKE '%ice'  -- Does NOT use index (suffix)
   ```

4. **Sorting**
   ```sql
   SELECT * FROM users ORDER BY created_at  -- Uses index
   ```

5. **Composite index leftmost prefix**
   ```sql
   -- Index on (a, b, c)
   WHERE a = 1                      -- Uses index
   WHERE a = 1 AND b = 2           -- Uses index
   WHERE a = 1 AND b = 2 AND c = 3 -- Uses index
   WHERE b = 2 AND c = 3           -- Does NOT use index
   ```

### Index Scan Types

```sql
EXPLAIN SELECT * FROM users WHERE email = 'alice@example.com';
```

- **Index Scan**: Read index, then fetch rows from table
- **Index Only Scan**: All needed data is in the index (best!)
- **Bitmap Index Scan**: For multiple conditions, combines indexes

---

## When Indexes Are NOT Used

### Low Selectivity

```sql
-- If 50% of users are active, index won't help
SELECT * FROM users WHERE active = true;
-- Full scan may be faster than 50% index lookups
```

### Small Tables

```sql
-- Table fits in one disk page? Sequential scan wins
SELECT * FROM tiny_config_table WHERE key = 'setting';
```

### Functions That Don't Match

```sql
-- Index on email, but:
SELECT * FROM users WHERE UPPER(email) = 'ALICE@EXAMPLE.COM';
-- Index not used! Create expression index instead.
```

### Type Mismatch

```sql
-- Index on integer id, but:
SELECT * FROM users WHERE id = '123';
-- Type conversion may prevent index use
```

---

## Index Types Beyond B-Tree

### Hash Index

```sql
CREATE INDEX idx_hash ON users USING hash(email);
```

- Only equality operations (=)
- Faster than B-tree for equality (in theory)
- No range queries, no ordering
- Rarely better than B-tree in practice

### GiST (Generalized Search Tree)

```sql
-- For geometric data, full-text search, etc.
CREATE INDEX idx_location ON places USING gist(coordinates);

-- Range queries on geometric data
SELECT * FROM places WHERE coordinates && box '((0,0),(1,1))';
```

### GIN (Generalized Inverted Index)

```sql
-- For array/JSONB containment, full-text search
CREATE INDEX idx_tags ON posts USING gin(tags);

-- Query
SELECT * FROM posts WHERE tags @> ARRAY['postgresql'];
```

### BRIN (Block Range Index)

```sql
-- For large, naturally ordered data (like time-series)
CREATE INDEX idx_events_time ON events USING brin(created_at);

-- Much smaller than B-tree
-- Works when data is physically ordered
```

---

## Index Costs

### Storage

```sql
-- See index sizes
SELECT
    indexrelname AS index_name,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;
```

### Write Performance

Every INSERT/UPDATE/DELETE must also update indexes:

```sql
-- Table with no indexes: fast writes
-- Table with 10 indexes: 10x write overhead (approximately)
```

### Maintenance

```sql
-- Indexes become fragmented over time
-- REINDEX to rebuild
REINDEX INDEX idx_users_email;

-- Or VACUUM to reclaim space
VACUUM ANALYZE users;
```

---

## Key Takeaways

1. **B-trees dominate** — Default choice for most indexes
2. **Leftmost prefix matters** — Design composite indexes carefully
3. **Not all queries use indexes** — Low selectivity, small tables, type mismatches
4. **Indexes cost writes** — Every index slows down modifications
5. **Monitor and tune** — Use EXPLAIN to verify index usage

---

## What's Next?

Theory is nice, but you need to *feel* the difference. The next chapter is a hands-on lab where you'll:
- Create a table with 1 million rows
- Experience a 30-second query drop to 3 milliseconds
- Learn to read EXPLAIN output
- Identify missing indexes

---

*Next: [Index Performance Lab](./08-index-performance-lab.md)*
