# Chapter 14: Partitioning

> *"The art of being wise is the art of knowing what to overlook."*
> — William James

---

## The Fundamental Problem

### Why Does This Exist?

Your e-commerce platform has grown. You now have:
- 5 years of order history
- 2 billion rows in the orders table
- Queries that range from "show me today's orders" to "show me orders from 2019"

Every query—whether it needs one day's data or five years'—must scan the same massive table. Your 2019 analytics query holds locks that slow down today's real-time order processing. Your indexes are enormous. Backups take forever.

One giant table is becoming unmanageable.

The raw, primitive problem is this: **How do you organize a large dataset so that queries can access only the subset of data they actually need?**

### The Real-World Analogy

Consider a filing system for a busy accounting firm. You could put all invoices from all years in one massive filing cabinet. Every search would require digging through decades of paper.

Or you could organize: one cabinet per year, with folders for each month, with tabs for each client. Now, finding "March 2023 invoices for Client X" means going directly to one drawer, one folder, one tab. You don't touch 2019's invoices at all.

Partitioning is this organization applied to databases. You divide data into logical sections so that queries can skip irrelevant sections entirely.

---

## The Naive Solution

### What Would a Beginner Try First?

"Let's just add more indexes!"

If queries are slow, more indexes should help, right? Index on order_date, index on customer_id, composite indexes everywhere.

### Why Does It Break Down?

**1. Indexes still touch the whole table**

An index helps find rows faster, but the underlying table is still one massive structure. Maintenance operations (VACUUM, ANALYZE) affect the whole table.

**2. Index size becomes problematic**

An index on 2 billion rows is itself enormous. It might not fit in memory, causing index scans to hit disk.

**3. Different query patterns conflict**

Your real-time dashboard queries today's data. Your analytics queries historical data. Both compete for the same resources on the same table.

**4. Operational challenges**

Backing up 2TB takes hours. Restoring takes hours. Schema changes take hours. Everything takes hours.

### The Flawed Assumption

The naive approach assumes **all data should live together and indexes are sufficient to find it.** Partitioning challenges this: **data that isn't queried together doesn't need to live together.**

---

## The Core Insight

### The "Aha" Moment

Here's the fundamental realization:

> **If you can predict which subset of data a query needs based on the query itself, you can skip loading irrelevant subsets entirely.**

This is called "partition pruning." A query for `WHERE order_date = '2024-01-15'` on a date-partitioned table goes directly to the January 2024 partition. The 23 other months of 2024? Never touched. The 60 months of prior years? Never touched.

The query reads 1/60th of the data it would otherwise read.

### The Trade-off Acceptance

Partitioning requires accepting that **your partition key constrains your query patterns**. If you partition by date:

- ✅ `WHERE order_date = ?` benefits from pruning
- ❌ `WHERE customer_id = ?` must scan all partitions

You're optimizing for certain query patterns at the expense of others.

### The Sticky Metaphor

**Partitioning is like organizing a library by genre.**

Fiction, non-fiction, children's, reference—each in its own section. If you want a mystery novel, you go to Fiction → Mystery. You don't wander through Children's or Reference.

But what if you want "all books by Author X" and that author writes across genres? Now you must visit every section. The organization that helps genre-based queries hurts author-based queries.

The best partition scheme is the one that matches how people actually search.

---

## The Mechanism

### Building Partitioning From Scratch

**Step 1: Choose a partition key**

The partition key determines how data is divided. Common choices:
- **Date/time**: For time-series data, logs, events
- **Geography**: For location-based data
- **Customer/tenant**: For multi-tenant applications
- **Category**: For type-based access patterns

```sql
-- Partitioning orders by month
CREATE TABLE orders (
    id BIGINT,
    customer_id BIGINT,
    order_date DATE,
    total DECIMAL(10,2)
) PARTITION BY RANGE (order_date);

CREATE TABLE orders_2024_01 PARTITION OF orders
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE orders_2024_02 PARTITION OF orders
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
-- ... more partitions
```

**Step 2: Let the database prune**

```sql
-- This query ONLY touches orders_2024_01
SELECT * FROM orders WHERE order_date = '2024-01-15';

-- Query planner output:
-- Seq Scan on orders_2024_01
-- (Partitions pruned: orders_2024_02, orders_2024_03, ...)
```

**Step 3: Implement in application code (if needed)**

Some databases/systems require application-level partition awareness:

```java
public class PartitionedOrderRepository {
    private final Map<String, Database> partitions;

    // Application explicitly routes to correct partition
    public List<Order> findByDate(LocalDate date) {
        String partitionKey = date.format(DateTimeFormatter.ofPattern("yyyy_MM"));
        Database partition = partitions.get("orders_" + partitionKey);
        return partition.query("SELECT * FROM orders WHERE order_date = ?", date);
    }

    // Cross-partition query requires scatter-gather
    public List<Order> findByCustomer(long customerId) {
        return partitions.values().parallelStream()
            .flatMap(db -> db.query("SELECT * FROM orders WHERE customer_id = ?", customerId).stream())
            .collect(Collectors.toList());
    }
}
```

### Partitioning Strategies

**Range Partitioning**

Divide by ranges of values:

```
Partition 1: order_date < 2023-01-01
Partition 2: order_date >= 2023-01-01 AND < 2024-01-01
Partition 3: order_date >= 2024-01-01
```

Good for: Time-series data, sequential IDs
Problem: Can create hotspots (all new data hits latest partition)

**List Partitioning**

Divide by specific values:

```sql
CREATE TABLE orders PARTITION BY LIST (region);

CREATE TABLE orders_na PARTITION OF orders FOR VALUES IN ('US', 'CA', 'MX');
CREATE TABLE orders_eu PARTITION OF orders FOR VALUES IN ('UK', 'DE', 'FR');
CREATE TABLE orders_apac PARTITION OF orders FOR VALUES IN ('JP', 'AU', 'SG');
```

Good for: Categorical data, multi-tenant
Problem: Uneven distribution if categories have different sizes

**Hash Partitioning**

Divide by hash of value:

```sql
CREATE TABLE orders PARTITION BY HASH (customer_id);

CREATE TABLE orders_p0 PARTITION OF orders FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE orders_p1 PARTITION OF orders FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE orders_p2 PARTITION OF orders FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE orders_p3 PARTITION OF orders FOR VALUES WITH (MODULUS 4, REMAINDER 3);
```

Good for: Even distribution, no natural ranges
Problem: Range queries scan all partitions

**Composite Partitioning**

Combine strategies:

```
orders
├── orders_2024 (range by year)
│   ├── orders_2024_na (list by region)
│   ├── orders_2024_eu
│   └── orders_2024_apac
├── orders_2023
│   ├── orders_2023_na
│   └── ...
```

### Partitioning vs. Sharding

These concepts are related but distinct:

| Aspect | Partitioning | Sharding |
|--------|--------------|----------|
| Location | Single database, multiple tables | Multiple databases |
| Query | Database handles routing | Application may handle routing |
| Scale | Limited by single machine | Scales across machines |
| Use case | Manage large tables | Scale beyond one machine |

Often combined: each shard is partitioned.

```
Shard 1 (customers A-M)          Shard 2 (customers N-Z)
├── orders_2024_01               ├── orders_2024_01
├── orders_2024_02               ├── orders_2024_02
└── orders_2024_03               └── orders_2024_03
```

### Partition Lifecycle Management

```java
public class PartitionManager {
    // Create new partitions before they're needed
    @Scheduled(cron = "0 0 1 1 * ?")  // First day of each month
    public void createNextMonthPartition() {
        LocalDate nextMonth = LocalDate.now().plusMonths(1);
        String partitionName = "orders_" + nextMonth.format(DateTimeFormatter.ofPattern("yyyy_MM"));

        database.execute("""
            CREATE TABLE %s PARTITION OF orders
            FOR VALUES FROM ('%s') TO ('%s')
            """.formatted(
                partitionName,
                nextMonth.withDayOfMonth(1),
                nextMonth.plusMonths(1).withDayOfMonth(1)
            ));
    }

    // Archive old partitions
    public void archiveOldPartitions(int retentionMonths) {
        LocalDate cutoff = LocalDate.now().minusMonths(retentionMonths);
        // Detach and archive partitions older than cutoff
        // Much faster than DELETE WHERE date < cutoff
    }
}
```

---

## The Trade-offs

### What Do We Sacrifice?

**1. Query flexibility**

Queries not aligned with partition key are slower. They must scan multiple (potentially all) partitions.

**2. Constraint complexity**

Unique constraints and foreign keys can be complicated across partitions. Some databases require the partition key in every unique constraint.

**3. Management overhead**

Creating, dropping, archiving partitions requires automation. Misconfigured partition schemes cause problems.

**4. Planning rigidity**

Changing partition strategy on existing data is painful. You're committing to a scheme.

### When NOT To Use This

- **Small tables**: Partitioning overhead isn't worth it for tables under a few million rows.
- **Unpredictable query patterns**: If you can't predict which subset queries need, partitioning doesn't help.
- **Heavy cross-partition queries**: If most queries span all partitions, you've added overhead without benefit.
- **OLTP with unpredictable access**: Traditional OLTP might not benefit if access patterns are random.

### Connection to Other Concepts

- **Sharding** (Chapter 3): Partitioning within a database, sharding across databases
- **Indexing** (Chapter 13): Partitions can be thought of as a coarse-grained index
- **CAP Theorem** (Chapter 5): Partitions in different locations face CAP trade-offs
- **Eventual Consistency** (Chapter 15): Cross-partition operations might have consistency implications

---

## The Evolution

### Brief History

**1990s: Basic table partitioning**

Oracle introduced table partitioning. Initially for very large databases (VLDB) in enterprise settings.

**2000s: Widespread adoption**

PostgreSQL, MySQL, SQL Server all added partitioning. Became a standard DBA tool.

**2010s: Time-series specialization**

TimescaleDB, InfluxDB—databases designed around time-based partitioning. Automatic partition management.

**2020s: Intelligent partitioning**

Auto-partitioning, adaptive schemes, ML-driven partition recommendations.

### Modern Variations

**Native Time-Series Partitioning**

```sql
-- TimescaleDB: automatic chunking by time
SELECT create_hypertable('events', 'time');
-- Automatically creates and manages partitions
```

**Partition-Aware Query Optimization**

Modern databases intelligently route:
```sql
-- PostgreSQL 12+ pushes aggregates to partitions
SELECT date_trunc('month', order_date), SUM(total)
FROM orders
WHERE order_date >= '2024-01-01'
GROUP BY 1;

-- Each partition calculates its sum independently
-- Then results are combined
```

**Dynamic Partitioning**

Add/remove partitions without downtime:
```sql
-- Attach new partition (online)
ALTER TABLE orders ATTACH PARTITION orders_2024_04
    FOR VALUES FROM ('2024-04-01') TO ('2024-05-01');

-- Detach for archival (online)
ALTER TABLE orders DETACH PARTITION orders_2020_01;
```

### Where It's Heading

**Automatic partition management**: Databases that create, rebalance, and archive partitions without human intervention.

**Tiered storage**: Hot partitions on fast storage, cold partitions on cheap storage, automatically managed.

**Cross-system partitioning**: Unified partitioning across databases, object stores, and data lakes.

---

## Interview Lens

### Common Interview Questions

1. **"How would you partition a billion-row table?"**
   - Analyze query patterns first
   - Choose partition key that matches common filters
   - Consider time-based for event/log data
   - Plan for partition lifecycle (creation, archival)

2. **"What's the difference between partitioning and sharding?"**
   - Partitioning: Single database, logical organization
   - Sharding: Multiple databases, physical distribution
   - Partitioning helps manage size; sharding helps scale

3. **"How do you handle queries that span partitions?"**
   - Scatter-gather pattern
   - Discuss performance implications
   - Consider denormalization or secondary data structures

### Red Flags (Shallow Understanding)

❌ Confuses partitioning with sharding

❌ Thinks partitioning is always beneficial

❌ Doesn't mention partition pruning

❌ Can't explain when partitioning hurts performance

### How to Demonstrate Deep Understanding

✅ Explain how partition key choice affects query performance

✅ Discuss partition pruning and how to verify it's working

✅ Mention lifecycle management (creating future partitions, archiving old)

✅ Know the difference between range, list, and hash partitioning

✅ Understand composite partitioning for complex access patterns

---

## Curiosity Hooks

As you continue through this book, consider:

- Partitioning assumes you know query patterns in advance. What if patterns change? What if different users need different views?

- We talked about partition key constraining queries. Is there a way to have multiple "partition keys" for different query types? (Secondary indexes across partitions)

- Partitioning within a database helps with size. What about distribution across machines? (Hint: Chapter 3, Sharding)

- Old partitions are often read-only. Can we treat them differently from hot partitions? (Hint: Tiered storage, archival strategies)

---

## Summary

**The Problem**: Large tables become unmanageable—slow queries, long maintenance operations, conflicting access patterns.

**The Insight**: If queries predictably need subsets of data based on certain attributes, you can organize data so those subsets are physically separate. Queries touch only what they need.

**The Mechanism**: Divide tables by range (dates), list (categories), or hash (even distribution). The database prunes irrelevant partitions from query execution.

**The Trade-off**: Query flexibility. Queries aligned with partition key are faster; misaligned queries are slower.

**The Evolution**: From manual partitioning → declarative partitioning → automatic time-series databases → intelligent, self-managing schemes.

**The First Principle**: Data that isn't accessed together doesn't need to live together. Physical organization should match logical access patterns.

---

*Next: [Chapter 15: Eventual Consistency](./15-eventual-consistency.md)—where we learn that "consistent" and "eventually consistent" are both more nuanced than they sound.*
