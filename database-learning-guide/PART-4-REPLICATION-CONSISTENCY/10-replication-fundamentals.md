# Chapter 10: Replication Fundamentals

> *"Replication is easy. Consistency is hard. That's the entire history of distributed systems in two sentences."*

---

## Why Replicate?

### Three Fundamental Reasons

1. **High Availability**
   - Primary fails → replica takes over
   - No single point of failure

2. **Read Scalability**
   - One writer, many readers
   - Scale reads without scaling writes

3. **Geographic Distribution**
   - Data closer to users
   - Reduced latency worldwide

---

## Replication Types

### Synchronous Replication

```
Client → Primary → [Wait for Replica ACK] → Client ACK

Timeline:
1. Client sends write to Primary
2. Primary writes locally
3. Primary sends to Replica
4. Replica writes and ACKs
5. Primary ACKs to Client
```

**Properties:**
- **Strong consistency**: Replica always has latest data
- **Higher latency**: Every write waits for replica
- **Reduced availability**: If replica is down, writes block

### Asynchronous Replication

```
Client → Primary → Client ACK
                 ↘ [Eventually] → Replica

Timeline:
1. Client sends write to Primary
2. Primary writes locally
3. Primary ACKs to Client (immediately!)
4. Primary sends to Replica (async)
5. Replica applies changes
```

**Properties:**
- **Eventual consistency**: Replica may lag behind
- **Lower latency**: Writes don't wait
- **Higher availability**: Replica issues don't block writes
- **Risk**: Failover may lose recent writes

---

## PostgreSQL Replication Architecture

### Write-Ahead Log (WAL) Shipping

PostgreSQL replication works by shipping WAL records:

```
Primary:
  Transaction → WAL → [Ship to Replica] → Data Files

Replica:
  Receive WAL → Apply → Data Files (eventually consistent)
```

### Streaming Replication

Modern PostgreSQL uses streaming replication:

```
Primary                          Replica
   │                                │
   │ ← TCP Connection (persistent) →│
   │                                │
   │──── WAL Records (streaming) ───→│
   │                                │
   │←─── Acknowledgment ────────────│
```

---

## Replication Lag

### What Is It?

The time difference between when a write happens on Primary and when it appears on Replica.

```
Timeline:
t=0ms: Write committed on Primary
t=1ms: WAL shipped to Replica
t=2ms: Replica applies WAL
t=2ms: Replication lag = 2ms

If network is slow or Replica is busy:
t=0ms: Write committed on Primary
t=100ms: WAL shipped to Replica
t=150ms: Replica applies WAL
t=150ms: Replication lag = 150ms
```

### Why Lag Matters

```sql
-- User creates account on Primary
INSERT INTO users (name) VALUES ('Alice');  -- Returns success

-- User immediately reads (routed to Replica)
SELECT * FROM users WHERE name = 'Alice';   -- Empty! (lag)

-- User thinks signup failed, tries again
-- Now you might have duplicate accounts
```

This is **eventual consistency in action**. The data will appear—eventually.

---

## Consistency Models

### Strong Consistency

> "Every read sees the most recent write."

```
Write(x=1) → Commit
                    Read(x) → Returns 1 (guaranteed)
```

**Implemented via:** Synchronous replication

### Eventual Consistency

> "If no new writes, eventually all reads return the same value."

```
Write(x=1) → Commit
                    Read(x) → Might return old value
                    Read(x) → Might return 1
                    [time passes]
                    Read(x) → Returns 1 (eventually)
```

**Implemented via:** Asynchronous replication

### Read-Your-Writes Consistency

> "A client always sees their own writes."

```
Client A: Write(x=1) → Commit
Client A: Read(x) → Returns 1 (sees own write)
Client B: Read(x) → Might return old value (different client)
```

**Implemented via:** Session affinity or routing logic

---

## PostgreSQL Synchronous Commit Levels

```sql
-- Check current setting
SHOW synchronous_commit;

-- Options:
SET synchronous_commit = 'off';           -- No durability guarantee
SET synchronous_commit = 'local';         -- Wait for local WAL flush
SET synchronous_commit = 'remote_write';  -- Wait for replica to receive
SET synchronous_commit = 'on';            -- Wait for replica to flush WAL
SET synchronous_commit = 'remote_apply';  -- Wait for replica to apply
```

| Level | Durability | Consistency | Latency |
|-------|------------|-------------|---------|
| off | Lowest | None | Fastest |
| local | Local only | None | Fast |
| remote_write | Good | Weak | Medium |
| on | Strong | Strong | Slow |
| remote_apply | Strongest | Strongest | Slowest |

---

## Failover and Promotion

When Primary fails, a Replica becomes the new Primary:

```
Before:
  Primary (read/write) ←→ Replica (read-only)

Primary fails...

Failover:
  Primary (DOWN) ←/→ Replica → Promoted to Primary (read/write)

After:
  New Primary (read/write)
```

### Failover Risks with Async Replication

```
t=0:   Primary: Write A committed
t=1ms: Primary: Write B committed
t=2ms: Primary crashes (B not yet shipped to Replica)
t=3ms: Replica promoted to Primary
       Replica has Write A, but NOT Write B
       Write B is LOST forever!
```

**First Principle:** Asynchronous replication trades durability for performance. In failure scenarios, recent writes may be lost.

---

## Conflict Resolution

### The Split-Brain Problem

```
Network partition:
  Primary (US)  ←/→  Primary (EU)
       ↑                  ↑
    Writes A           Writes B

When network heals:
  Both have different data!
  Which one is "correct"?
```

### Common Resolution Strategies

1. **Last Writer Wins (LWW)**
   - Timestamp-based
   - Simple but can lose data

2. **Application-Level Resolution**
   - App decides how to merge
   - More complex but more correct

3. **Conflict-Free Replicated Data Types (CRDTs)**
   - Data structures that merge automatically
   - No conflicts by design

---

## Monitoring Replication

### PostgreSQL Commands

```sql
-- On Primary: Check connected replicas
SELECT
    client_addr,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
FROM pg_stat_replication;

-- On Replica: Check lag
SELECT
    CASE WHEN pg_is_in_recovery() THEN 'replica' ELSE 'primary' END AS role,
    pg_last_wal_receive_lsn() AS receive_lsn,
    pg_last_wal_replay_lsn() AS replay_lsn,
    pg_last_xact_replay_timestamp() AS last_replay_time,
    NOW() - pg_last_xact_replay_timestamp() AS lag_time;
```

### Key Metrics

| Metric | Meaning | Alert Threshold |
|--------|---------|-----------------|
| lag_bytes | Unprocessed WAL | > 100MB |
| lag_time | Time behind | > 30 seconds |
| state | Connection state | != 'streaming' |

---

## Summary: The Trade-off Triangle

```
            Consistency
                /\
               /  \
              /    \
             /      \
            /        \
           /__________\
   Availability    Performance
```

- **Synchronous**: High consistency, lower availability/performance
- **Asynchronous**: High availability/performance, eventual consistency

**First Principle:** You cannot escape this triangle. Every system chooses a point within it. Understanding where your system sits—and what you sacrifice—is essential.

---

## What's Next?

Theory is useful, but you need to *feel* replication. In the next chapter, we'll set up a multi-node PostgreSQL cluster using Docker and experience replication lag firsthand.

---

*Next: [Docker Multi-Node Lab](./11-docker-multi-node-lab.md)*
