# Chapter 3: First Principles of Storage

> *"All abstractions leak. The question is when, not if."*

---

## The Fundamental Truth

Every database feature—ACID transactions, indexes, replication—exists because of one fundamental constraint:

**Disk is slow. Memory is fast. Neither is infinite. Both can fail.**

Let's make this visceral.

---

## Experiment 1: Feel the Speed Difference

### Memory vs Disk Access

```bash
# Create a test file (10MB)
dd if=/dev/urandom of=/tmp/testfile bs=1M count=10

# Clear filesystem cache
sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'

# Time disk read (cold)
time cat /tmp/testfile > /dev/null
# Real: ~0.1s (depends on your disk)

# Time disk read again (cached in memory)
time cat /tmp/testfile > /dev/null
# Real: ~0.01s (10x faster!)
```

**What you're seeing:** The second read is from memory cache, not disk. Databases exploit this constantly.

### Database Demonstration

```sql
-- PostgreSQL: Connect and create test data
\c labdb

-- Create a table with substantial data
CREATE TABLE speed_test (
    id SERIAL PRIMARY KEY,
    data TEXT
);

-- Insert 100,000 rows
INSERT INTO speed_test (data)
SELECT md5(random()::text)
FROM generate_series(1, 100000);

-- Force data to disk
VACUUM ANALYZE speed_test;
```

Now restart PostgreSQL to clear its cache:

```bash
sudo systemctl restart postgresql
```

```sql
-- First query (data from disk)
\timing on
SELECT COUNT(*) FROM speed_test;
-- Time: ~50-200ms

-- Second query (data in memory)
SELECT COUNT(*) FROM speed_test;
-- Time: ~5-20ms (much faster!)
```

**First Principle:** Databases try to keep frequently accessed data in memory. This is why RAM matters so much for database performance.

---

## Experiment 2: Understanding Pages

Databases don't read individual rows; they read **pages** (fixed-size blocks).

### PostgreSQL Page Size

```sql
-- Show page size (default 8KB)
SHOW block_size;

-- See how many pages your table uses
SELECT pg_relation_size('speed_test') / 8192 AS pages;
```

### Why Pages Matter

```sql
-- Create a wide table
CREATE TABLE wide_rows (
    id SERIAL PRIMARY KEY,
    col1 VARCHAR(1000),
    col2 VARCHAR(1000),
    col3 VARCHAR(1000)
);

-- Create a narrow table
CREATE TABLE narrow_rows (
    id SERIAL PRIMARY KEY,
    value INT
);

-- Insert same number of rows
INSERT INTO wide_rows (col1, col2, col3)
SELECT repeat('x', 1000), repeat('y', 1000), repeat('z', 1000)
FROM generate_series(1, 10000);

INSERT INTO narrow_rows (value)
SELECT i FROM generate_series(1, 10000) AS i;

-- Compare sizes
SELECT
    'wide_rows' AS table_name,
    pg_size_pretty(pg_relation_size('wide_rows')) AS size,
    pg_relation_size('wide_rows') / 8192 AS pages
UNION ALL
SELECT
    'narrow_rows',
    pg_size_pretty(pg_relation_size('narrow_rows')),
    pg_relation_size('narrow_rows') / 8192;
```

**Output (approximately):**
```
 table_name  |  size   | pages
-------------+---------+-------
 wide_rows   | 31 MB   | 3968
 narrow_rows | 360 KB  | 45
```

**First Principle:** Fewer pages = fewer disk reads = faster queries. This is why you select only needed columns, why proper data types matter, and why normalization trades space for joins.

---

## Experiment 3: Write-Ahead Logging (WAL)

How do databases survive crashes without losing data?

### The Problem

1. You run `INSERT INTO users (name) VALUES ('Alice')`
2. Database acknowledges success
3. Power goes out before data is written to disk
4. Is Alice's data lost?

### The Solution: WAL

```sql
-- Find WAL location
SHOW data_directory;
-- Look in pg_wal subdirectory
```

```bash
# See WAL files
sudo ls -la /var/lib/postgresql/15/main/pg_wal/
```

**How it works:**
1. Before changing data, write the change to WAL (sequential write, fast)
2. Acknowledge to client
3. Later, apply changes to actual data files
4. On crash recovery, replay WAL to recover uncommitted changes

### See WAL in Action

```sql
-- Check WAL position before insert
SELECT pg_current_wal_lsn();

-- Insert data
INSERT INTO users (name, email) VALUES ('WAL Test', 'wal@test.com');

-- Check WAL position after
SELECT pg_current_wal_lsn();
```

The LSN (Log Sequence Number) increases with each write.

**First Principle:** Durability isn't about never failing—it's about recovering correctly when you do. WAL is why databases can promise "committed means committed."

---

## Experiment 4: MVCC Basics

How do databases handle concurrent reads and writes?

### Multi-Version Concurrency Control

```sql
-- Session 1: Start a transaction
BEGIN;
SELECT * FROM users WHERE id = 1;
-- Shows Alice

-- Session 2 (open new terminal):
BEGIN;
UPDATE users SET name = 'Alicia' WHERE id = 1;
COMMIT;

-- Session 1: Read again
SELECT * FROM users WHERE id = 1;
-- Still shows Alice! (depending on isolation level)

COMMIT;

-- Now shows Alicia
SELECT * FROM users WHERE id = 1;
```

**First Principle:** MVCC keeps multiple versions of rows so readers don't block writers. This is the foundation of database concurrency. We'll explore isolation levels deeply in Part 2.

---

## Experiment 5: Physical vs Logical Data

### See Hidden System Columns

```sql
-- PostgreSQL stores hidden columns for MVCC
SELECT ctid, xmin, xmax, * FROM users;
```

**Output:**
```
 ctid  | xmin | xmax | id |  name  |        email
-------+------+------+----+--------+---------------------
 (0,1) | 1234 |    0 |  1 | Alice  | alice@example.com
 (0,2) | 1234 |    0 |  2 | Bob    | bob@example.com
```

- `ctid`: Physical location (page, offset)
- `xmin`: Transaction ID that created this row
- `xmax`: Transaction ID that deleted/updated this row (0 = current)

**First Principle:** What you see in `SELECT *` isn't what's stored on disk. Databases maintain metadata for MVCC, recovery, and more.

---

## The Storage Hierarchy in Databases

```
                    Speed / Cost

    CPU Cache       [====] 1ns      | Hot query results
        ↓                           |
    RAM (Buffer)    [===] 100ns     | Recently accessed pages
        ↓                           |
    SSD             [==] 100µs      | Table data, indexes
        ↓                           |
    HDD             [=] 10ms        | Archival, backups
        ↓                           |
    Network         [ ] 150ms+      | Replication, backups
```

**Everything in database design is about managing this hierarchy:**

- **Indexes**: Keep lookup data in faster tiers
- **Caching**: Keep hot data in memory
- **Partitioning**: Keep relevant data together
- **Replication**: Accept network latency for availability

---

## Key Takeaways

1. **Disk is the bottleneck** — Most optimizations reduce disk I/O
2. **Pages are the unit** — Databases think in pages, not rows
3. **WAL enables durability** — Sequential writes before random writes
4. **MVCC enables concurrency** — Multiple versions avoid locks
5. **Memory is precious** — Cache hit vs miss determines performance

---

## Verification: You Understand When...

- [ ] You can explain why `SELECT *` is often bad (more columns = more pages)
- [ ] You understand why indexes help (fewer pages to read)
- [ ] You know why databases have buffer pools (memory cache)
- [ ] You can explain WAL's purpose (durability via sequential writes)
- [ ] You understand MVCC basics (versions, not locks)

---

## What's Next?

Now we understand the physical foundation. Let's build on it with ACID transactions—the guarantees databases provide and the trade-offs they require.

---

*Next: [Understanding ACID](../PART-2-ACID-TRANSACTIONS/04-understanding-acid.md)*
