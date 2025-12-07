# Chapter 4: Replication

> *"Two is one and one is none."*
> — Military saying about redundancy

---

## The Fundamental Problem

### Why Does This Exist?

You have a database. It works. Then one night, the hard drive fails. Or a power surge fries the motherboard. Or someone accidentally runs `DROP TABLE users`.

All your data is gone.

Even if you have backups, restoring from backup takes time. Hours, maybe. During those hours, your service is dead.

Beyond failures, consider this: your database is in Virginia, but half your users are in Tokyo. Their queries travel 15,000 kilometers, adding 100+ milliseconds to every request. They'll never experience "fast."

The raw, primitive problem is this: **How do you protect against data loss AND improve data access from multiple locations, given that a single database is both a single point of failure and geographically limited?**

### The Real-World Analogy

Consider a library with one copy of each book. If that copy is lost, stolen, or damaged—it's gone forever. And if the book is popular, only one person can read it at a time.

Now imagine the library maintains multiple copies of important books. If one is damaged, others exist. If one is checked out, others are available. If demand is high, all copies can be read simultaneously.

Replication is maintaining multiple copies of your data so that:
1. If one copy is lost, others survive
2. Multiple readers can access copies in parallel
3. Copies can be placed closer to where they're needed

---

## The Naive Solution

### What Would a Beginner Try First?

"I'll make a copy of the database manually every night."

This is backup. Export the data, store it somewhere safe, restore when needed.

### Why Does It Break Down?

**1. Recovery Point Objective (RPO)**

If the database dies at 5 PM, your midnight backup is 17 hours old. Those 17 hours of data are lost forever.

**2. Recovery Time Objective (RTO)**

Restoring a large database takes hours. Your service is down the entire time.

**3. No read scaling**

Backups don't help with performance. You still have one database handling all queries.

**4. Geographic distance remains**

Your backup in the cloud doesn't help your Tokyo users access data faster.

### The Flawed Assumption

Backups assume **you can tolerate data loss and downtime**. Replication assumes **you cannot**—that you need continuous data survival and availability.

---

## The Core Insight

### The "Aha" Moment

Here's the fundamental realization:

> **By continuously copying changes to multiple machines, you can survive the loss of any one machine with minimal data loss and near-zero downtime.**

The magic word is "continuously." Unlike nightly backups, replication copies changes as they happen. The copies (replicas) are always nearly in sync with the primary.

But here's the uncomfortable truth: "nearly in sync" isn't "perfectly in sync." The time it takes to copy changes to replicas creates a window where copies might diverge. This is the source of endless complexity.

### The Trade-off Acceptance

Replication forces you to choose:

- **Synchronous replication**: Wait for copies before confirming writes. Data is safe, but writes are slow.
- **Asynchronous replication**: Confirm writes immediately, copy later. Writes are fast, but data might be lost if primary fails before replication completes.

There's no magic option that's both fast and perfectly safe. You must choose your trade-off.

### The Sticky Metaphor

**Replication is like sending important letters via multiple couriers.**

If you send one courier and they're robbed, your message is lost. So you send three couriers taking different routes. Any one can fail, and the message still arrives.

The trade-off: do you wait until you know at least one courier has arrived (synchronous), or do you assume they'll probably make it and move on (asynchronous)?

---

## The Mechanism

### Building Replication From Scratch

**Step 1: Identify changes**

Every database change must be captured and sent to replicas.

```java
public class WriteAheadLog {
    private final List<LogEntry> log = new ArrayList<>();

    // Why WAL: record WHAT changed before applying to data
    // If we crash mid-write, we can replay the log to recover
    public void appendEntry(LogEntry entry) {
        log.add(entry);
        persistToDisk(entry);  // Make it durable
    }

    public List<LogEntry> getEntriesSince(long position) {
        return log.subList((int) position, log.size());
    }
}

public record LogEntry(long position, String operation, byte[] data) {}
```

**Step 2: Send changes to replicas**

The primary sends its log to replicas, which replay the operations.

```java
public class Replica {
    private final Database localDb;
    private long lastAppliedPosition = 0;

    // Why streaming: replicas stay near-real-time with primary
    public void applyChangesFromPrimary(List<LogEntry> entries) {
        for (LogEntry entry : entries) {
            if (entry.position() > lastAppliedPosition) {
                localDb.apply(entry);
                lastAppliedPosition = entry.position();
            }
        }
    }
}
```

**Step 3: Choose sync vs async**

```java
public class ReplicatedDatabase {
    private final Database primary;
    private final List<Replica> replicas;
    private final boolean synchronous;

    public void write(WriteOperation op) {
        // First, write to primary's log
        LogEntry entry = primary.writeToLog(op);

        if (synchronous) {
            // Wait for ALL replicas to confirm
            // Safe but slow: write isn't confirmed until replicas have it
            for (Replica replica : replicas) {
                replica.applyAndConfirm(entry);
            }
        } else {
            // Return immediately, replicate in background
            // Fast but risky: primary might fail before replication
            asyncExecutor.submit(() -> {
                for (Replica replica : replicas) {
                    replica.apply(entry);
                }
            });
        }
    }
}
```

### Replication Topologies

**Single Leader (Primary-Replica)**

```
         Writes
           │
           ▼
      ┌─────────┐
      │ Primary │
      └────┬────┘
           │ Replication
     ┌─────┼─────┐
     ▼     ▼     ▼
┌───────┐ ┌───────┐ ┌───────┐
│Replica│ │Replica│ │Replica│
└───────┘ └───────┘ └───────┘
     ▲     ▲     ▲
     └─────┴─────┘
          Reads
```

- All writes go to primary
- Reads can go to any replica
- Simple to reason about
- Primary is a bottleneck for writes

**Multi-Leader**

```
   Region A              Region B
┌──────────┐          ┌──────────┐
│  Leader  │◄────────►│  Leader  │
└────┬─────┘          └────┬─────┘
     │                     │
┌────┴────┐          ┌────┴────┐
│ Replica │          │ Replica │
└─────────┘          └─────────┘
```

- Multiple leaders accept writes
- Leaders replicate to each other
- Better write latency (write to nearest leader)
- Complex: write conflicts possible

**Leaderless**

```
┌────────┐   ┌────────┐   ┌────────┐
│ Node A │◄─►│ Node B │◄─►│ Node C │
└────────┘   └────────┘   └────────┘

Write: Send to ALL nodes, wait for MAJORITY
Read:  Send to ALL nodes, take MOST RECENT
```

- No single point of failure
- High availability
- Complex consistency model
- Used by Cassandra, DynamoDB

### Handling Failures

**Replica failure:**

Simple—the replica catches up when it comes back online. Other replicas continue serving reads.

```java
public class ReplicaRecovery {
    public void recoverReplica(Replica replica) {
        // Replica was at position 1000 when it crashed
        // Primary is now at position 1500
        List<LogEntry> missedEntries = primary.getEntriesSince(replica.lastAppliedPosition);
        replica.applyChangesFromPrimary(missedEntries);  // Catch up
    }
}
```

**Primary failure (Failover):**

This is the hard problem.

```java
public class FailoverManager {
    private final List<Replica> replicas;

    // Why consensus: multiple replicas might think they should be primary
    // Need agreement to prevent split-brain
    public Replica electNewPrimary() {
        // 1. Detect primary failure (heartbeats stopped)
        if (!isPrimaryResponding()) {

            // 2. Find replica with most recent data
            Replica mostUpToDate = replicas.stream()
                .max(Comparator.comparing(Replica::getLastAppliedPosition))
                .orElseThrow();

            // 3. Promote it to primary
            mostUpToDate.promoteToprimary();

            // 4. Update other replicas to follow new primary
            for (Replica r : replicas) {
                if (r != mostUpToDate) {
                    r.setNewPrimary(mostUpToDate);
                }
            }
            return mostUpToDate;
        }
        return null;
    }
}
```

But wait—what if the "failed" primary isn't actually dead? Network partition might make it unreachable but still running. Now you have two primaries (split-brain). This is why failover needs consensus algorithms like Raft or Paxos.

### Replication Lag

With async replication, replicas are always slightly behind. This creates problems:

```java
// User writes to primary
userService.updateProfile(userId, newEmail);

// Immediately reads from replica—might see OLD data!
User user = userService.getProfile(userId);  // Reads from replica
// user.email might still be old email!
```

Solutions:
- **Read-your-writes consistency**: After a write, route that user's reads to primary
- **Causal consistency**: Track what a user has seen, ensure reads are at least that fresh
- **Synchronous replication**: Eliminate the lag (but pay in latency)

---

## The Trade-offs

### What Do We Sacrifice?

**1. Consistency vs. Latency**

Synchronous replication means every write waits for replicas. Your write latency is now bounded by your slowest replica.

**2. Availability vs. Consistency**

With async replication, replicas can serve reads even if primary is unreachable. But those reads might be stale.

**3. Complexity**

Failover logic, replication lag handling, conflict resolution (in multi-leader)—each adds cognitive and operational complexity.

**4. Cost**

Replicas are full copies. 3 replicas means 3x storage cost. Cross-region replicas add network transfer costs.

### When NOT To Use This

- **Cost-sensitive and loss-tolerant**: If you can afford to lose some data and downtime, backups are cheaper than replicas.
- **Write-heavy with strict consistency**: Synchronous replication might not give you the write throughput you need.
- **Single-datacenter, single-region**: If geographic distribution isn't needed, complexity might not be worth it.

### Connection to Other Concepts

- **CAP Theorem** (Chapter 5): Replication is where CAP trade-offs become real
- **Eventual Consistency** (Chapter 15): Async replication creates eventual consistency
- **Sharding** (Chapter 3): Often combined—each shard is replicated
- **Consistent Hashing** (Chapter 6): Used in leaderless replication

---

## The Evolution

### Brief History

**1970s: Theoretical foundations**

Lamport's work on distributed systems laid groundwork. Concepts like "happens-before" and logical clocks.

**1990s: Oracle DataGuard, MySQL replication**

Traditional databases added replication. Mostly primary-replica with manual failover.

**2000s: Paxos and Raft**

Consensus algorithms made automatic failover reliable. No more split-brain (if implemented correctly).

**2010s: Cloud-native replication**

Amazon RDS Multi-AZ, Google Cloud SQL, Azure SQL. Replication became a checkbox feature.

**2020s: Global databases**

CockroachDB, Google Spanner, YugabyteDB. Synchronous replication across continents with strong consistency.

### Modern Variations

**Quorum-based Replication**

Instead of "all replicas" or "one replica," use quorums:
- Write to W out of N replicas
- Read from R replicas
- Guarantee consistency if W + R > N

```java
// N=3, W=2, R=2
// Any 2 writes and any 2 reads must overlap—at least one read sees latest write
public void quorumWrite(Data data) {
    int successfulWrites = 0;
    for (Node node : nodes) {
        if (node.write(data)) successfulWrites++;
    }
    if (successfulWrites >= WRITE_QUORUM) {
        return success;  // Enough nodes have it
    }
    throw new WriteFailure();
}
```

**Chain Replication**

```
Write → Node A → Node B → Node C → Confirm
                              ↑
                            Read
```

Writes propagate through a chain. Reads come from the tail (most up-to-date). Simple consistency model.

### Where It's Heading

**Active-active multi-region**: Write anywhere, replicate everywhere, resolve conflicts automatically.

**CRDT-based replication**: Conflict-free Replicated Data Types. Data structures that merge without conflicts.

**Zero-downtime failover**: Like hot-swapping a car tire while driving. Systems like Amazon Aurora claim sub-second failover.

---

## Interview Lens

### Common Interview Questions

1. **"Explain primary-replica replication"**
   - Writes go to primary, propagate to replicas
   - Reads can go to replicas (scale reads)
   - Discuss sync vs. async trade-offs

2. **"How do you handle failover?"**
   - Detect failure (heartbeats, health checks)
   - Elect new primary (consensus)
   - Reconfigure replicas
   - Handle the "zombie primary" problem

3. **"What is replication lag and how do you handle it?"**
   - Async replication means replicas are behind
   - Solutions: read-your-writes, causal consistency, sync replication
   - Discuss which to use when

### Red Flags (Shallow Understanding)

❌ "Just use replication" without discussing sync vs. async

❌ Doesn't mention replication lag

❌ Can't explain failover challenges (split-brain)

❌ Confuses replication (availability) with sharding (capacity)

### How to Demonstrate Deep Understanding

✅ Explain the consistency-latency trade-off in replication

✅ Discuss quorum systems and what W + R > N guarantees

✅ Mention specific problems like split-brain and how consensus solves them

✅ Connect to CAP theorem—replication is where you feel CAP

✅ Know when async is acceptable (eventually consistent reads) vs. when sync is needed

---

## Curiosity Hooks

As you progress through this book, consider:

- We've talked about replication lag. Is there a way to reason about when replicas are "consistent enough"? (Hint: Chapter 15, Eventual Consistency)

- CAP theorem says we can't have everything. Where exactly does replication force us to choose? (Hint: Chapter 5, CAP Theorem)

- If sharding splits data and replication copies data, do they work together? (Hint: Each shard can be replicated)

- We mentioned consensus algorithms for failover. What are Raft and Paxos actually doing? (Hint: Chapter 18, Fault Tolerance)

---

## Summary

**The Problem**: A single database is a single point of failure with no geographic distribution.

**The Insight**: By continuously copying changes to multiple machines, you can survive the loss of any one machine while improving read performance and geographic locality.

**The Mechanism**: Write-ahead logs capture changes. Changes stream to replicas. Synchronous replication guarantees consistency but adds latency. Asynchronous replication is faster but allows data loss and lag.

**The Trade-off**: Consistency vs. latency/availability. You must choose whether writes wait for replication or proceed optimistically.

**The Evolution**: From manual failover → automated consensus-based failover → transparent cloud replication → globally distributed databases.

**The First Principle**: Multiple copies enable survival and scale, but "multiple copies" introduces the consistency question: how synchronized must they be?

---

*Next: [Chapter 13: Database Indexing](./13-db-indexing.md)—where we learn that how you organize data determines how fast you can find it.*
