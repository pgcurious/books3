# Chapter 21: Kafka Protocol—Log-Based Messaging

## Rethinking Messaging as a Distributed Commit Log

---

> *"Kafka makes you think about messaging differently. It's not about queues. It's about logs."*
> — Jay Kreps, Kafka creator

---

## The Frustration

It's 2010 at LinkedIn. Data pipelines are a mess:

- User activity streams to analytics
- Database changes replicate to search
- Metrics flow to monitoring
- Events trigger notifications

Each pipeline is custom. Data is lost. Ordering is inconsistent. Scaling is painful. Adding new consumers means modifying producers.

The team asked: "What if every data pipeline used the same infrastructure?"

## The World Before Kafka

Data movement was fragmented:

```
Database → Custom ETL → Analytics
         → Different ETL → Search Index
         → Another pipeline → Recommendations

Each arrow is a different system, different protocol.
Data consistency? Good luck.
```

Traditional message queues didn't fit:
- Messages disappear after consumption
- Multiple consumers see different data
- No replay capability
- Hard to scale to billions of messages

## The Insight: Append-Only Log

Kafka treats messages as an append-only log:

```
Log (partition):
┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
│ 0 │ 1 │ 2 │ 3 │ 4 │ 5 │ 6 │ 7 │ 8 │ 9 │ ← offset
└───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘
  ↑               ↑           ↑
  Consumer A      Consumer B  Consumer C

Each consumer tracks its own position (offset).
Messages persist. Multiple consumers read independently.
```

This is fundamentally different from queues:

```
Queue: Message consumed → Message deleted
Log:   Message consumed → Message still there
```

## Kafka Core Concepts

### Topics
Named streams of messages:

```
Topic: user-events
Topic: order-updates
Topic: page-views
Topic: transactions
```

### Partitions
Topics are split for parallelism:

```
Topic: user-events
  Partition 0: [0][1][2][3][4]...
  Partition 1: [0][1][2][3][4]...
  Partition 2: [0][1][2][3][4]...

Messages with same key → same partition (ordering guaranteed)
Different partitions → parallel processing
```

### Producers
Write messages to topics:

```
Producer → Topic partition

Key determines partition:
  key=user123 → hash(key) % partitions → partition 2
  No key → round-robin across partitions
```

### Consumers
Read messages from topics:

```
Consumer → Poll for messages → Process → Commit offset

Offset = "I've processed up to here"
Consumer crash → Resume from last committed offset
```

### Consumer Groups
Parallel consumption with coordination:

```
Consumer Group: analytics-pipeline
  Consumer 1 ← Partition 0
  Consumer 2 ← Partition 1
  Consumer 3 ← Partition 2

Each partition has exactly one consumer in the group.
Add consumers → rebalance partitions.
```

## Why Logs Are Powerful

### 1. Replay
New consumer? Start from the beginning:

```
New analytics service deployed
Subscribe to user-events, offset=0
Process all historical data
Caught up to present
```

No data loss. Complete history available.

### 2. Multiple Consumers
Same data, different purposes:

```
Topic: orders
  Consumer group: billing → Process for invoices
  Consumer group: analytics → Build reports
  Consumer group: shipping → Trigger shipments

Each group has independent offset tracking.
Same messages, different processing.
```

### 3. Time Travel
Something wrong? Go back:

```
Bug discovered in processing.
Reset consumer offset to yesterday.
Reprocess with fix.
```

### 4. Decoupling
Producers don't know consumers:

```
Order service produces to "orders" topic.
Add a new fraud detection service → subscribes to "orders".
Order service doesn't change.
```

## Kafka's Protocol

The Kafka protocol is binary, optimized for throughput:

### Request Format
```
┌────────────────────────────────────────────────────┐
│ Size (4 bytes)                                      │
├────────────────────────────────────────────────────┤
│ API Key (2 bytes) - Which operation                │
├────────────────────────────────────────────────────┤
│ API Version (2 bytes) - Protocol version           │
├────────────────────────────────────────────────────┤
│ Correlation ID (4 bytes) - Request tracking        │
├────────────────────────────────────────────────────┤
│ Client ID (string)                                 │
├────────────────────────────────────────────────────┤
│ Request payload (varies by API)                    │
└────────────────────────────────────────────────────┘
```

### Batching
Produce requests batch messages:

```
Without batching:
  Request 1: message A
  Request 2: message B
  Request 3: message C
  3 network round trips

With batching:
  Request 1: messages A, B, C
  1 network round trip
```

Producers buffer and batch for efficiency.

### Zero-Copy
Kafka uses zero-copy for sending to consumers:

```
Traditional:
  Disk → Kernel buffer → User buffer → Kernel buffer → Network

Kafka:
  Disk → Kernel buffer → Network

sendfile() system call. No copying through user space.
```

## Replication and Durability

Kafka replicates for fault tolerance:

```
Topic: orders, partition 0
  Leader: Broker 1  ← All reads/writes
  Replica: Broker 2 ← Sync copy
  Replica: Broker 3 ← Sync copy

Broker 1 dies → Broker 2 becomes leader
No data loss. Automatic failover.
```

### Acknowledgment Levels

```
acks=0:  Fire and forget (fast, lossy)
acks=1:  Leader acknowledges (balanced)
acks=all: All replicas acknowledge (slow, safe)
```

## Kafka vs Traditional Queues

| Aspect | Kafka | Traditional Queue |
|--------|-------|-------------------|
| Consumed messages | Retained | Deleted |
| Multiple consumers | Independent offsets | Competing consumers |
| Replay | Yes | No |
| Ordering | Per partition | Per queue |
| Throughput | Millions/sec | Thousands/sec |
| Primary use | Data streaming | Task distribution |

## Common Patterns

### Event Sourcing
Store events, not state:

```
Topic: account-events
  AccountCreated(id=123)
  MoneyDeposited(id=123, amount=100)
  MoneyWithdrawn(id=123, amount=50)

Current state = replay all events
Complete audit trail.
```

### Change Data Capture (CDC)
Stream database changes:

```
Database → CDC connector → Kafka topic

INSERT → topic: {"op":"c", "after":{...}}
UPDATE → topic: {"op":"u", "before":{...}, "after":{...}}
DELETE → topic: {"op":"d", "before":{...}}

Downstream systems stay synchronized.
```

### Stream Processing
Transform data in motion:

```
Input: raw-clickstream
  → Filter bots
  → Enrich with user data
  → Aggregate by session
Output: session-analytics
```

Kafka Streams, Apache Flink, Spark Streaming.

## The Tradeoffs

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| Log retention | Replay, history | Storage costs |
| Partitions | Parallelism | Ordering complexity |
| Consumer offsets | Independence | Coordination overhead |
| Batching | Throughput | Latency (small) |
| No message delete | Simplicity | Space (compaction helps) |

## The Principle

> **Kafka reimagined messaging as a distributed log. This simple change—treating messages as data rather than transient events—enables replay, multiple consumers, and stream processing that traditional queues cannot provide.**

Kafka isn't a better queue. It's a different paradigm.

## When to Use Kafka

**Use Kafka when:**
- High throughput needed (millions of messages/sec)
- Multiple consumers need the same data
- Replay capability is valuable
- Stream processing is required
- Event sourcing architecture
- Data integration across systems

**Consider alternatives when:**
- Simple task queues (RabbitMQ, Redis)
- Very low latency needed (sub-millisecond)
- Complex routing (AMQP)
- Simple pub-sub (Redis, MQTT)

---

## Summary

- Kafka is a distributed commit log, not a traditional queue
- Topics are partitioned for parallelism and ordering
- Consumer groups enable independent parallel processing
- Messages persist, enabling replay and multiple consumers
- Zero-copy and batching enable massive throughput
- Common patterns: event sourcing, CDC, stream processing

---

*For simpler needs, STOMP provides text-based messaging. Let's explore it.*
