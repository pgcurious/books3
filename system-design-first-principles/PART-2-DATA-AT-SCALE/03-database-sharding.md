# Chapter 3: Database Sharding

> *"Divide and conquer."*
> — Ancient military strategy, perfectly applicable to databases

---

## The Fundamental Problem

### Why Does This Exist?

Your application is wildly successful. You've scaled your web servers horizontally—50 of them behind a load balancer, each stateless and interchangeable. But they all talk to... one database.

That database is now the bottleneck. It's handling:
- 50,000 queries per second
- 500GB of data that barely fits in memory
- Growing 10GB per day with no signs of slowing

You could buy a bigger database server. But you've already bought the biggest one money can buy. Now what?

The raw, primitive problem is this: **How do you scale a database beyond what a single machine can handle?**

### The Real-World Analogy

Consider a library with one librarian and one filing system. As the collection grows to millions of books, one person can't possibly manage it. And one room can't hold everything.

What do libraries do? They create branches. The downtown branch has fiction A-M. The uptown branch has fiction N-Z. The science library has all non-fiction. Each branch has its own librarian, its own shelves, its own checkout system.

If you want "To Kill a Mockingbird," you go to the downtown branch (fiction, starts with 'L'). The system routes you to the right location based on a predictable rule.

Sharding is creating branch libraries for your data.

---

## The Naive Solution

### What Would a Beginner Try First?

"Let's add read replicas!"

Read replicas (copies of the database that handle read queries) seem like the answer. Primary handles writes, replicas handle reads. More read capacity!

### Why Does It Break Down?

**1. Only solves read scaling**

If your application is read-heavy (90% reads), replicas help a lot. But writes still go to one place. Social media apps with constant user posts? E-commerce with constant orders? Replicas don't help with writes.

**2. Doesn't solve data size**

Replicas are full copies. If your primary has 2TB of data, each replica needs 2TB. You haven't distributed the data; you've duplicated it.

**3. Replication lag**

Changes on the primary take time to propagate to replicas. Users might see stale data. This gets worse under high write load—exactly when you need help most.

**4. Single point of failure**

The primary is still a single point of failure for writes. If it goes down, no writes happen until failover completes.

### The Flawed Assumption

Replicas assume that **you need more processing capacity for the same data**. Sharding addresses a different assumption: **you need to split the data itself because one machine can't hold/process it all.**

---

## The Core Insight

### The "Aha" Moment

Here's the fundamental realization:

> **If your data can be partitioned such that most operations only need one partition, you can scale linearly by adding partitions.**

The key phrase is "most operations only need one partition." If every query needs to consult every partition, sharding doesn't help. But if you can design your data access patterns so that a query can be routed to a single shard, you've unlocked horizontal scaling for your database.

### The Trade-off Acceptance

Sharding requires accepting that **you give up some query flexibility**. A monolithic database can join any table with any other table, scan all data for complex analytics, and maintain global uniqueness effortlessly.

Sharded databases trade this flexibility for scale. You can no longer trivially join data across shards. Global analytics require aggregating results from all shards. Global uniqueness requires coordination.

### The Sticky Metaphor

**Sharding is like organizing a massive filing cabinet into separate filing cabinets, each handled by a different person.**

Everyone in the office agrees: "Last names A-M go to Alice's cabinet, N-Z go to Bob's cabinet." When someone needs a file, they don't search randomly—they know exactly which cabinet (and which person) handles it.

The tradeoff: you can't easily get a report that spans both cabinets without asking both Alice and Bob. But for most day-to-day work, this system is faster and more scalable than one overworked person with one massive cabinet.

---

## The Mechanism

### Building Sharding From Scratch

**Step 1: Choose a sharding key**

The sharding key determines which shard holds each piece of data. This is the most critical decision in sharding.

Good sharding key properties:
- High cardinality (many distinct values)
- Even distribution (no hot spots)
- Commonly used in queries (so queries can be routed to single shard)

```java
// Example: Sharding users by user_id
public class UserShardRouter {
    private final List<Database> shards;

    // Why hash-based: distributes evenly regardless of key patterns
    // user_id 1, 2, 3... doesn't create hotspots like range-based would
    public Database getShardForUser(long userId) {
        int shardIndex = (int) (Math.abs(userId) % shards.size());
        return shards.get(shardIndex);
    }
}
```

**Step 2: Implement routing logic**

Every query must be routed to the correct shard(s).

```java
public class ShardedUserRepository {
    private final UserShardRouter router;

    // Why single-shard query: O(1) shard access, not O(N)
    public User findById(long userId) {
        Database shard = router.getShardForUser(userId);
        return shard.query("SELECT * FROM users WHERE id = ?", userId);
    }

    // Problem: cross-shard query requires hitting ALL shards
    public List<User> findByEmail(String email) {
        List<User> results = new ArrayList<>();
        // Must query ALL shards because we don't know which has this email
        for (Database shard : router.getAllShards()) {
            results.addAll(shard.query("SELECT * FROM users WHERE email = ?", email));
        }
        return results;
    }
}
```

**Step 3: Handle cross-shard operations**

Some operations inherently span shards. Handle them explicitly.

```java
// Scatter-gather pattern for cross-shard aggregations
public int countActiveUsers() {
    return router.getAllShards().parallelStream()
        .mapToInt(shard -> shard.queryInt("SELECT COUNT(*) FROM users WHERE active = true"))
        .sum();
}

// Cross-shard joins are expensive and complex
// Often better to denormalize or use a different approach
```

### Sharding Strategies

**Hash-based Sharding**

```
shard_id = hash(shard_key) % num_shards

User 123 → hash(123) = 456789 → 456789 % 4 = 1 → Shard 1
User 456 → hash(456) = 234567 → 234567 % 4 = 3 → Shard 3
```

Pros: Even distribution
Cons: Adding shards reshuffles everything (see Consistent Hashing, Chapter 6)

**Range-based Sharding**

```
Shard 0: user_id 1 - 1,000,000
Shard 1: user_id 1,000,001 - 2,000,000
Shard 2: user_id 2,000,001 - 3,000,000
```

Pros: Range queries are efficient
Cons: Hot spots if new data clusters (all new users on one shard)

**Directory-based Sharding**

```
+----------+--------+
| user_id  | shard  |
+----------+--------+
| 123      | 0      |
| 456      | 2      |
| 789      | 1      |
+----------+--------+
```

Pros: Flexible, can move individual keys
Cons: Directory is a single point of failure, adds latency

**Geography-based Sharding**

```
Shard US-East:  Users in US Eastern timezone
Shard US-West:  Users in US Western timezone
Shard EU:       Users in Europe
Shard Asia:     Users in Asia-Pacific
```

Pros: Data locality (users served by nearby shard)
Cons: Uneven distribution if user geography is uneven

### The Rebalancing Problem

What happens when one shard gets too big? You need more shards.

```
Before: 3 shards, each ~33% of data

After: 4 shards, but with hash(key) % num_shards...
       EVERY key might need to move

User 7: hash(7) % 3 = 1  →  hash(7) % 4 = 3  MOVED!
User 8: hash(8) % 3 = 2  →  hash(8) % 4 = 0  MOVED!
```

This is why consistent hashing exists (Chapter 6)—to minimize data movement when adding shards.

### A Complete Sharding Implementation

```java
public class ShardedDatabase {
    private final List<Connection> shards;
    private final Function<Object, Integer> shardKeyExtractor;

    public ShardedDatabase(List<Connection> shards, Function<Object, Integer> keyExtractor) {
        this.shards = shards;
        this.shardKeyExtractor = keyExtractor;
    }

    // Route single-record operations to correct shard
    public <T> T executeOnShard(Object shardKey, Function<Connection, T> operation) {
        int shardIndex = Math.abs(shardKeyExtractor.apply(shardKey).hashCode()) % shards.size();
        Connection shard = shards.get(shardIndex);
        return operation.apply(shard);
    }

    // Scatter-gather for cross-shard queries
    public <T> List<T> executeOnAllShards(Function<Connection, List<T>> operation) {
        return shards.parallelStream()
            .flatMap(shard -> operation.apply(shard).stream())
            .collect(Collectors.toList());
    }

    // Aggregation across shards
    public int aggregateIntFromAllShards(Function<Connection, Integer> operation) {
        return shards.parallelStream()
            .mapToInt(operation::apply)
            .sum();
    }
}
```

---

## The Trade-offs

### What Do We Sacrifice?

**1. Joins become expensive or impossible**

A join between users and orders is trivial in a single database. If users and orders are sharded differently, joining them requires pulling data from multiple shards into memory.

**2. Transactions across shards are hard**

ACID transactions on a single database are straightforward. Across shards, you need distributed transactions (2PC, Saga pattern) which are complex and slower.

**3. Operational complexity**

Backups, schema migrations, monitoring—everything multiplies by number of shards.

**4. Choosing the wrong shard key is painful**

If you shard by user_id but most queries are by timestamp, every query is a scatter-gather. Changing shard keys requires reshuffling all data.

**5. Hotspots can still occur**

If your shard key has skewed distribution (one celebrity with a billion followers), one shard gets all the load.

### When NOT To Use This

- **Small data that fits comfortably on one machine**: The complexity isn't worth it.
- **Heavy cross-entity analytics**: If you need to join everything with everything, sharding will hurt.
- **Low write volume**: Read replicas might be sufficient.
- **When you can use managed solutions**: Cloud databases that handle sharding transparently (like Amazon Aurora, Google Spanner) might be better.

### Connection to Other Concepts

- **Consistent Hashing** (Chapter 6): Minimizes reshuffling when shards change
- **Partitioning** (Chapter 14): Closely related concept
- **Replication** (Chapter 4): Often used together—shard for writes, replicate for reads
- **Eventual Consistency** (Chapter 15): Cross-shard consistency is challenging

---

## The Evolution

### Brief History

**1980s-90s: Oracle RAC, shared-disk**

Early distributed databases shared storage but distributed compute. Limited scalability.

**2000s: Google Bigtable, Amazon Dynamo**

Tech giants published papers showing how to shard at massive scale. Bigtable (2006), Dynamo (2007) influenced everything that followed.

**2010s: NoSQL and NewSQL**

MongoDB, Cassandra, CockroachDB—databases built for horizontal scaling from day one. Sharding went from afterthought to core feature.

**2020s: Serverless and transparent sharding**

Cloud databases hide sharding complexity. You just write queries; the database figures out routing.

### Modern Variations

**Application-Level Sharding**

Application code handles shard routing. Maximum control, maximum complexity.

**Proxy-Based Sharding**

A proxy (Vitess, ProxySQL) sits between application and database. Application thinks it's talking to one database.

```
App → Proxy → Shard 1
           → Shard 2
           → Shard 3
```

**Native Database Sharding**

The database handles everything (CockroachDB, YugabyteDB, MongoDB). Simplest for developers.

### Where It's Heading

**Automatic sharding**: Databases that automatically choose shard keys, detect hotspots, and rebalance.

**Global databases**: Like Google Spanner—sharded globally with strong consistency. The holy grail.

**AI-driven optimization**: ML models that predict query patterns and suggest optimal sharding strategies.

---

## Interview Lens

### Common Interview Questions

1. **"How would you shard a user table?"**
   - Shard by user_id (hash)
   - Ensures user's data is co-located
   - Discuss: what about queries by email? (secondary index or scatter-gather)

2. **"Design a sharded Twitter"**
   - Tweets sharded by user_id (write locality)
   - Timeline might need different approach (fan-out on write vs. read)
   - Handle the celebrity problem

3. **"What happens when you need to add a shard?"**
   - With naive hashing: massive data movement
   - With consistent hashing: minimal movement
   - Double-write strategy during migration

### Red Flags (Shallow Understanding)

❌ "Just shard by user_id" without discussing query patterns

❌ Doesn't mention the cross-shard query problem

❌ Can't explain what happens when adding/removing shards

❌ Ignores the operational complexity

### How to Demonstrate Deep Understanding

✅ Discuss shard key selection criteria (cardinality, distribution, query patterns)

✅ Explain trade-offs between hash vs. range sharding

✅ Mention consistent hashing for rebalancing

✅ Acknowledge that sharding doesn't solve all scaling problems

✅ Discuss co-located data—keeping related data on same shard

---

## Curiosity Hooks

Moving forward, consider these questions:

- Sharding handles capacity, but what about availability? If one shard goes down, that data is unavailable. (Hint: Chapter 4, Replication)

- Hash-based sharding reshuffles everything when shard count changes. Is there a better way? (Hint: Chapter 6, Consistent Hashing)

- We mentioned cross-shard joins are hard. What if we designed our data model to avoid them? (Hint: Chapter 10, Microservices and data ownership)

- How do we keep shards roughly equal in size over time? (Hint: Chapter 14, Partitioning strategies)

---

## Summary

**The Problem**: A single database can't scale beyond the limits of one machine—in storage, compute, or connections.

**The Insight**: If you can partition data so most operations only need one partition, you can scale linearly by adding partitions.

**The Mechanism**: Choose a sharding key, hash or range-partition data across multiple databases, route queries based on shard key. Handle cross-shard queries explicitly.

**The Trade-off**: Query flexibility (joins, transactions) for horizontal scalability.

**The Evolution**: From shared-nothing architectures of the 2000s to today's transparent cloud sharding. The goal is making sharding invisible to developers.

**The First Principle**: Data that must be accessed together should live together. Design your shard key to keep related data co-located.

---

*Next: [Chapter 4: Replication](./04-replication.md)—where we learn that having multiple copies isn't just about backup, it's about availability and performance.*
