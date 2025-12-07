# Chapter 13: Database Indexing

> *"Give me six hours to chop down a tree and I will spend the first four sharpening the axe."*
> — Abraham Lincoln

---

## The Fundamental Problem

### Why Does This Exist?

You have a table with 100 million users. You want to find the user with email "alice@example.com".

Without any optimization, the database must scan every single row. One hundred million rows. Even at a blazing 1 million rows per second, that's 100 seconds. For one query. And you have thousands of queries per second.

Now your database is on fire.

The raw, primitive problem is this: **How do you find specific data in a large dataset without examining every single record?**

### The Real-World Analogy

Consider finding a word in a dictionary. A dictionary with 100,000 words.

**Without an index (alphabetical order):** Start at page 1, read every word until you find "zebra." On average, you'll read 50,000 words. For "zebra," you'll read all 100,000.

**With an index (alphabetical order):** Open to 'Z'. Narrow down by second letter. Find "zebra" in seconds. You read maybe 20 words total.

The dictionary's alphabetical order IS the index. It transforms finding a word from reading 100,000 entries (linear search) to reading ~17 entries (binary search). That's 6,000x faster.

A database index does the same thing: it organizes data in a way that makes finding specific entries fast.

---

## The Naive Solution

### What Would a Beginner Try First?

"Just buy faster disks!"

More IOPS (I/O operations per second), more throughput. SSDs instead of HDDs. Maybe even RAM-based storage.

### Why Does It Break Down?

**1. Still linear time**

Scanning 100 million rows 10x faster is still scanning 100 million rows. Linear search (O(n)) remains linear search, just with a smaller constant.

**2. Cost scales with data**

Double your data, double your query time. Data grows faster than hardware budgets.

**3. Wasted work**

If you're looking for one record out of 100 million, reading the other 99,999,999 records is pure waste. No amount of hardware optimization fixes algorithmic inefficiency.

### The Flawed Assumption

The naive approach assumes **the bottleneck is read speed**. The real insight is that **the bottleneck is reading unnecessary data**. Don't read faster; read less.

---

## The Core Insight

### The "Aha" Moment

Here's the fundamental realization:

> **By maintaining a separate, sorted structure of keys, you can locate records in O(log n) time instead of O(n) time.**

For 100 million records:
- O(n) = 100,000,000 operations
- O(log n) = 27 operations

That's not a 2x improvement or even a 100x improvement. It's a **4,000,000x improvement.**

### The Trade-off Acceptance

There's no free lunch. Indexes require:
- **Additional storage**: The index structure needs disk space.
- **Slower writes**: Every INSERT, UPDATE, DELETE must also update the index.
- **Memory**: Indexes are fastest when kept in memory.

You're trading **write speed and storage for read speed**. This trade-off is almost always worth it for frequently-queried columns.

### The Sticky Metaphor

**An index is like the index at the back of a textbook.**

Want to find where "photosynthesis" is discussed? You don't read the entire textbook. You flip to the index, find "photosynthesis: pages 45, 67, 234," and go directly there.

The textbook index takes up a few pages (storage cost), must be updated if the book is revised (write cost), but saves you from reading 500 pages to find one topic (massive read benefit).

---

## The Mechanism

### Building Indexes From First Principles

**The Simplest Index: Sorted File**

```
Original data (unsorted by email):
Row 1: id=7,  email="zach@test.com"
Row 2: id=3,  email="alice@test.com"
Row 3: id=9,  email="bob@test.com"
...

Index on email (sorted):
"alice@test.com" → Row 2
"bob@test.com"   → Row 3
"zach@test.com"  → Row 1
...
```

With sorted keys, binary search works: O(log n).

But sorted files have a problem: inserting in the middle requires rewriting half the file. Enter the B-Tree.

### B-Tree: The Workhorse Index

B-Trees are the most common index structure in databases. They're like a sorted structure that's designed for efficient insertion and deletion.

```
                    ┌───────────────────┐
                    │    [M]            │
                    └─────────┬─────────┘
                              │
           ┌──────────────────┼──────────────────┐
           ▼                  ▼                  ▼
    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
    │  [D, H]     │    │  [P, T]     │    │  [X]        │
    └─────────────┘    └─────────────┘    └─────────────┘
         │                   │                   │
    ┌────┼────┐        ┌────┼────┐         ┌────┼────┐
    ▼    ▼    ▼        ▼    ▼    ▼         ▼    ▼    ▼
[A-C] [E-G] [I-L]   [N-O] [Q-S] [U-W]    [Y-Z]  ...

Each leaf node contains actual row pointers
```

Properties of B-Trees:
- Balanced: All leaf nodes at same depth
- Wide: Each node has many children (reduces tree height)
- Disk-optimized: Node size matches disk page size

```java
public class BTreeIndex<K extends Comparable<K>, V> {
    private static final int ORDER = 100;  // Max children per node
    private Node<K, V> root;

    // Why B-Tree: O(log n) for insert, delete, and search
    // Optimized for disk: minimizes disk seeks
    public V search(K key) {
        return search(root, key);
    }

    private V search(Node<K, V> node, K key) {
        int i = 0;
        while (i < node.numKeys && key.compareTo(node.keys[i]) > 0) {
            i++;
        }

        if (i < node.numKeys && key.compareTo(node.keys[i]) == 0) {
            return node.values[i];  // Found it
        }

        if (node.isLeaf) {
            return null;  // Not found
        }

        return search(node.children[i], key);  // Recurse into child
    }
}
```

### Hash Indexes

For exact-match queries, hash indexes can be O(1):

```java
public class HashIndex<K, V> {
    private final Map<K, V> index = new HashMap<>();

    // Why hash: O(1) for exact lookups
    // Limitation: can't do range queries (>, <, BETWEEN)
    public V get(K key) {
        return index.get(key);
    }

    public void put(K key, V value) {
        index.put(key, value);
    }
}
```

Hash indexes don't support range queries. "WHERE age > 21" can't use a hash index because there's no ordering.

### Types of Indexes

**Primary Index**

Index on the primary key. Usually clustered (data stored in index order).

**Secondary Index**

Index on non-primary columns. Points to primary key or row location.

```sql
-- Table stored in primary key order
CREATE TABLE users (
    id INT PRIMARY KEY,  -- Primary index, clustered
    email VARCHAR(255),
    age INT
);

-- Secondary indexes point to rows
CREATE INDEX idx_email ON users(email);
CREATE INDEX idx_age ON users(age);
```

**Composite Index**

Index on multiple columns:

```sql
CREATE INDEX idx_name ON users(last_name, first_name);

-- This index helps:
SELECT * FROM users WHERE last_name = 'Smith';
SELECT * FROM users WHERE last_name = 'Smith' AND first_name = 'John';

-- This index does NOT help:
SELECT * FROM users WHERE first_name = 'John';  -- Wrong order!
```

The order matters! It's like a phone book sorted by last name, then first name. You can find all "Smiths" quickly, but finding all "Johns" requires scanning everything.

**Covering Index**

An index that contains all columns needed for a query:

```sql
CREATE INDEX idx_covering ON users(email, name, created_at);

-- This query is "covered"—no need to fetch the actual row
SELECT name, created_at FROM users WHERE email = 'alice@test.com';
```

### How Databases Choose Indexes

The query optimizer decides whether to use an index:

```sql
-- Will use idx_email (very selective)
SELECT * FROM users WHERE email = 'alice@test.com';

-- Might NOT use idx_status if 50% of users are 'active'
SELECT * FROM users WHERE status = 'active';

-- Full table scan might be faster for non-selective predicates
```

Low selectivity (many rows match) might make index usage slower than a full scan. Reading 50 million index entries plus 50 million row lookups is slower than just scanning 100 million rows sequentially.

### The Cost of Indexes

```java
public class IndexedTable {
    private final Storage data;
    private final BTreeIndex<String, Long> emailIndex;
    private final BTreeIndex<Integer, Long> ageIndex;

    // Writes must update ALL indexes
    public void insert(User user) {
        long rowId = data.append(user);  // Write data

        // Every index must be updated—this is the write penalty
        emailIndex.put(user.email, rowId);  // O(log n)
        ageIndex.put(user.age, rowId);      // O(log n)
        // More indexes = slower writes
    }

    // Reads benefit from indexes
    public User findByEmail(String email) {
        Long rowId = emailIndex.get(email);  // O(log n)
        return data.read(rowId);              // O(1)
    }
}
```

---

## The Trade-offs

### What Do We Sacrifice?

**1. Write performance**

Every index must be updated on INSERT, UPDATE (if indexed column changes), DELETE. Five indexes means five extra operations per write.

**2. Storage space**

Indexes consume disk space. A large table with many indexes might have indexes larger than the data itself.

**3. Memory pressure**

Indexes are most effective in memory. Large indexes that don't fit in RAM cause disk I/O for index traversal.

**4. Maintenance overhead**

Indexes can become fragmented. Some databases require periodic REINDEX operations.

### The Index Selection Problem

Too few indexes: Queries are slow.
Too many indexes: Writes are slow, storage is wasted.

```sql
-- Anti-pattern: Index everything
CREATE INDEX idx1 ON users(a);
CREATE INDEX idx2 ON users(b);
CREATE INDEX idx3 ON users(c);
CREATE INDEX idx4 ON users(a, b);
CREATE INDEX idx5 ON users(b, c);
CREATE INDEX idx6 ON users(a, b, c);
-- Writes are now 6x slower for minimal read benefit
```

**Rule of thumb**: Index columns that appear in WHERE clauses of frequent queries. Monitor slow queries and add indexes strategically.

### When NOT To Use Indexes

- **Write-heavy workloads**: If you write 100x more than you read, indexes hurt more than help.
- **Small tables**: A 1,000-row table doesn't need indexes. Full scan is fast enough.
- **Low-selectivity columns**: A boolean "is_active" column where 90% are true—index won't help.
- **Temporary/staging tables**: Loaded once, queried once, then dropped.

### Connection to Other Concepts

- **Sharding** (Chapter 3): Each shard has its own indexes
- **Partitioning** (Chapter 14): Partition pruning is like an implicit index
- **Caching** (Chapter 2): Query results can be cached to avoid even hitting indexes

---

## The Evolution

### Brief History

**1970s: B-Trees invented**

Rudolf Bayer and Edward McCreight created B-Trees at Boeing (1972). They became the foundation of database indexing.

**1980s-90s: Commercial databases**

Oracle, DB2, SQL Server all standardized on B-Tree indexes. Hash indexes for specific use cases.

**2000s: Full-text and spatial indexes**

Beyond simple columns: GiST, GIN for PostgreSQL. Specialized indexes for text search, geographic data.

**2010s: LSM Trees and NoSQL**

Log-Structured Merge Trees (LSM) for write-heavy workloads. Used in LevelDB, RocksDB, Cassandra.

**2020s: Learned indexes**

Machine learning models that predict where data lives. Research by Tim Kraska et al. showed ML can replace B-Trees in some cases.

### Modern Variations

**LSM Trees**

Optimized for writes. Data writes to memory first, then merges to disk in batches.

```
Write → MemTable (in-memory, sorted)
              │
              ▼ (flush when full)
         SSTable Level 0
              │
              ▼ (compact/merge)
         SSTable Level 1
              │
              ▼
         SSTable Level 2
```

Reads are slower (might check multiple levels), but writes are sequential and fast.

**Inverted Indexes**

For full-text search:

```
Document 1: "the quick brown fox"
Document 2: "the lazy dog"

Inverted index:
"quick" → [Doc 1]
"brown" → [Doc 1]
"fox"   → [Doc 1]
"lazy"  → [Doc 2]
"dog"   → [Doc 2]
"the"   → [Doc 1, Doc 2]
```

Search "quick fox" → Intersect [Doc 1] ∩ [Doc 1] → [Doc 1]

**Bloom Filters**

Not quite an index, but related. Answers "might this key exist?" in O(1):
- If "no": Definitely not in dataset
- If "yes": Probably in dataset (check the actual index)

Used to avoid unnecessary index lookups.

### Where It's Heading

**Adaptive indexing**: Databases that automatically create indexes based on query patterns.

**Learned indexes**: Neural networks replacing B-Trees. Potentially smaller and faster for read-heavy workloads.

**Hardware-aware indexing**: Indexes optimized for NVMe, persistent memory, CXL.

---

## Interview Lens

### Common Interview Questions

1. **"How does a B-Tree index work?"**
   - Balanced tree with sorted keys
   - O(log n) search, insert, delete
   - Nodes sized for disk pages
   - Supports range queries

2. **"When would you not use an index?"**
   - Write-heavy tables
   - Small tables
   - Low-selectivity columns
   - Columns rarely queried

3. **"Design an index strategy for this schema"**
   - Analyze query patterns
   - Primary key is usually indexed
   - Foreign keys often need indexes
   - Composite indexes for multi-column WHERE clauses
   - Covering indexes for hot queries

### Red Flags (Shallow Understanding)

❌ "Just index everything"

❌ Doesn't know the write penalty of indexes

❌ Can't explain composite index column order

❌ Doesn't mention query optimizer behavior

### How to Demonstrate Deep Understanding

✅ Explain B-Tree vs. Hash index trade-offs

✅ Discuss covering indexes and index-only scans

✅ Mention that query optimizers might ignore indexes

✅ Know about EXPLAIN/EXPLAIN ANALYZE to check index usage

✅ Understand LSM Trees for write-heavy workloads

---

## Curiosity Hooks

As you progress, consider:

- Indexes make single-record lookups fast. What about range scans across huge datasets? (Hint: Chapter 14, Partitioning)

- We can index data within a database. What about data spread across multiple databases? (Hint: Chapter 3, Sharding considerations)

- Indexes help find data. But some queries transform data. Can we pre-compute those transformations? (Hint: Materialized views, Chapter 2 Caching concepts)

---

## Summary

**The Problem**: Finding specific records in large datasets requires examining every record without optimization—O(n) time.

**The Insight**: By maintaining a separate sorted structure, you can locate records in O(log n) time—a massive improvement that scales logarithmically with data size.

**The Mechanism**: B-Trees (balanced, wide trees) for sorted data with range queries. Hash indexes for O(1) exact-match lookups. Various specialized indexes for full-text, spatial, and other data types.

**The Trade-off**: Storage space and write speed for read speed. Every index makes writes slower.

**The Evolution**: From B-Trees (1970s) → specialized indexes (2000s) → LSM Trees for writes (2010s) → learned indexes (research).

**The First Principle**: Don't read faster; read less. An index is a roadmap that lets you skip straight to what you need instead of wandering through everything.

---

*Next: [Chapter 14: Partitioning](./14-partitioning.md)—where we learn that how you divide data determines how you can query it.*
