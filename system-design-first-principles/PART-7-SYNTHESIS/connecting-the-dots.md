# Connecting the Dots

> *"Everything is connected. The universe is made of stories, not atoms."*
> — Muriel Rukeyser

---

## The Big Picture

You've now studied 20 fundamental concepts. But here's the uncomfortable truth: **in real systems, you never use just one concept. You use all of them together.**

Load balancing isn't separate from caching, which isn't separate from sharding, which isn't separate from monitoring. They're interlocking pieces of a coherent whole.

This chapter shows how the concepts connect—how choices in one area ripple through others.

---

## The Concept Map

```
                           ┌───────────────────┐
                           │    USER REQUEST   │
                           └─────────┬─────────┘
                                     │
                                     ▼
               ┌──────────────────────────────────────────┐
               │              CDN (12)                     │
               │   Static content served from edge         │
               └─────────────────────┬────────────────────┘
                                     │ Cache miss
                                     ▼
               ┌──────────────────────────────────────────┐
               │          API Gateway (9)                  │
               │   AuthN (20) • Rate Limiting (8)          │
               └─────────────────────┬────────────────────┘
                                     │
                                     ▼
               ┌──────────────────────────────────────────┐
               │         Load Balancer (1)                 │
               │   Distributes across instances            │
               └─────────────────────┬────────────────────┘
                                     │
            ┌────────────────────────┼────────────────────────┐
            ▼                        ▼                        ▼
    ┌──────────────┐         ┌──────────────┐         ┌──────────────┐
    │  Service A   │         │  Service B   │         │  Service C   │
    │(Microservice)│◄───────►│(Microservice)│◄───────►│(Microservice)│
    │     (10)     │   Msg    │     (10)     │   Msg    │     (10)     │
    └──────┬───────┘  Queue   └──────┬───────┘  Queue   └──────┬───────┘
           │          (7)            │          (7)            │
           │                         │                         │
           ▼                         ▼                         ▼
    ┌──────────────┐         ┌──────────────┐         ┌──────────────┐
    │    Cache     │         │    Cache     │         │    Cache     │
    │      (2)     │         │      (2)     │         │      (2)     │
    └──────┬───────┘         └──────┬───────┘         └──────┬───────┘
           │                         │                         │
           ▼                         ▼                         ▼
    ┌──────────────┐         ┌──────────────┐         ┌──────────────┐
    │   Database   │         │   Database   │         │   Database   │
    │  Sharded (3) │         │ Replicated(4)│         │  Indexed(13) │
    │Partitioned(14)         │              │         │              │
    └──────────────┘         └──────────────┘         └──────────────┘

    Service Discovery (11) → How services find each other
    Consistent Hashing (6) → How data is distributed
    Fault Tolerance (18) → How failures are handled
    Monitoring (19) → How everything is observed
    Scalability (17) → How everything grows
```

---

## Connection Patterns

### Pattern 1: The Request Journey

Every user request touches multiple concepts:

1. **CDN** serves static assets (or caches API responses)
2. **API Gateway** authenticates and rate-limits
3. **Load Balancer** picks a server
4. **Service** processes the request
5. **Cache** avoids database work
6. **Database** provides persistent storage
7. **Monitoring** records everything

Each step has failure modes. Each step needs to scale. Each step affects latency.

### Pattern 2: Data Flow

Data moves through the system in patterns:

```
Write Path:
Request → Service → Message Queue → Workers → Database → Replicas

Read Path:
Request → Cache (HIT) → Return
       → Cache (MISS) → Database (maybe replica) → Cache → Return
```

The read path should be short and cached. The write path can be longer and asynchronous.

### Pattern 3: Failure Containment

Concepts work together to contain failures:

1. **Load Balancer** detects unhealthy instances, routes around them
2. **Circuit Breaker** (Fault Tolerance) stops cascading failures
3. **Rate Limiting** prevents overload from propagating
4. **Message Queues** buffer requests when downstream is slow
5. **Replication** survives individual node failures
6. **Monitoring** detects problems before users do

### Pattern 4: Scale Together

When you scale one thing, you often need to scale others:

```
More Users
    → More requests → Scale Load Balancers
    → More data → Scale Database (Sharding)
    → More cache entries → Scale Cache
    → More logs → Scale Monitoring infrastructure
    → More services → More complex Service Discovery
```

Scaling is holistic, not point-by-point.

---

## Tension Pairs

Some concepts exist in tension—optimizing for one makes the other harder:

### Consistency vs. Availability (CAP)

- **Replication** provides availability
- But **Eventual Consistency** is the trade-off
- **Caching** adds another consistency challenge

Design choice: Accept eventual consistency where possible, strong consistency where required.

### Latency vs. Reliability

- **Message Queues** increase reliability but add latency
- **Synchronous calls** are faster but riskier
- **Caching** reduces latency but risks stale data

Design choice: Async for background work, sync for user-facing, cache aggressively with TTLs.

### Simplicity vs. Scalability

- **Monolith** is simple but scales as one unit
- **Microservices** scale independently but are complex
- **Sharding** enables scale but complicates queries

Design choice: Start simple, add complexity only when scale demands it.

### Security vs. Usability

- **MFA** is more secure but adds friction
- **Rate Limiting** prevents abuse but might block legitimate users
- **AuthZ** checks on every request add latency

Design choice: Security appropriate to what you're protecting.

---

## Decision Trees

### "Should I cache this?"

```
Is the data read more often than written?
├── No → Caching provides little benefit
└── Yes
    └── Is the data okay to be slightly stale?
        ├── No → Don't cache (or use very short TTL)
        └── Yes
            └── Is the computation/fetch expensive?
                ├── No → Caching overhead might not be worth it
                └── Yes → CACHE IT
```

### "Should I use a message queue?"

```
Does the caller need an immediate response?
├── Yes → Synchronous call (maybe with timeout/retry)
└── No
    └── Is ordering important?
        ├── Yes → Use partitioned queue with ordering
        └── No
            └── Is exactly-once delivery critical?
                ├── Yes → Use transactional queue + idempotency
                └── No → Simple at-least-once queue
```

### "How should I store this data?"

```
Is it relational with complex queries?
├── Yes → SQL database
└── No
    └── Is it key-value access pattern?
        ├── Yes → Redis or DynamoDB
        └── No
            └── Is it document/hierarchical?
                ├── Yes → MongoDB
                └── No
                    └── Is it time-series?
                        ├── Yes → TimescaleDB or InfluxDB
                        └── No → Analyze your access patterns deeper
```

---

## The System Design Checklist

When designing any system, walk through these questions:

### 1. Traffic & Scale
- [ ] What's the expected request rate? (now and future)
- [ ] What's the data size? Growth rate?
- [ ] Where are users geographically?
- [ ] What are the traffic patterns? (steady, spiky, time-of-day?)

### 2. Data
- [ ] What's the read:write ratio?
- [ ] What consistency level is required?
- [ ] How is data accessed? (by key, by query, by time range?)
- [ ] What's the retention period?

### 3. Availability & Reliability
- [ ] What's the target uptime? (99.9%? 99.99%?)
- [ ] What happens during failures? (graceful degradation?)
- [ ] How quickly must we recover?
- [ ] What data can we afford to lose?

### 4. Performance
- [ ] What's the latency requirement? (p99?)
- [ ] Which operations are latency-critical?
- [ ] Where can we cache?
- [ ] Where can we make async?

### 5. Security
- [ ] Who can access what?
- [ ] How do we authenticate?
- [ ] What needs to be encrypted?
- [ ] What needs to be audited?

### 6. Operations
- [ ] How do we deploy?
- [ ] How do we monitor?
- [ ] How do we debug across services?
- [ ] How do we handle config changes?

---

## The First Principles Revisited

Each concept has a first principle. Together, they tell a story:

| Concept | First Principle |
|---------|-----------------|
| Load Balancing | Horizontal scaling through abstraction beats vertical scaling |
| Caching | The fastest work is work you don't do |
| Sharding | Data accessed together should live together |
| Replication | Multiple copies enable survival and scale |
| CAP Theorem | Physical law, not a design choice—partition tolerance isn't optional |
| Consistent Hashing | Stable hashing enables graceful scaling |
| Message Queues | Not all work is equally urgent—separate now from eventually |
| Rate Limiting | Sometimes saying "no" delivers more value |
| API Gateway | External API and internal architecture are different problems |
| Microservices | Architecture should minimize coordination costs |
| Service Discovery | Names are stable; locations are ephemeral |
| CDNs | The fastest request travels the shortest distance |
| DB Indexing | Don't read faster; read less |
| Partitioning | Data that isn't accessed together doesn't need to live together |
| Eventual Consistency | "Consistent" is a spectrum, not binary |
| WebSockets | Request-response isn't the only communication pattern |
| Scalability | Scalability is about the derivative, not the absolute value |
| Fault Tolerance | Design for failure, not despite it |
| Monitoring | You can't fix what you can't see |
| AuthN & AuthZ | Trust no one by default |

---

## The Meta-Principle

If there's one meta-principle that unifies all 20 concepts, it's this:

> **Every system design decision is a trade-off. There are no right answers—only trade-offs appropriate to your constraints.**

The goal of first-principles thinking isn't to find the "correct" architecture. It's to:

1. Understand what you're trading
2. Make the trade consciously
3. Document why you made it
4. Revisit when constraints change

The engineer who says "it depends" isn't being evasive—they're being wise. The wise follow-up is: "...on these specific factors."

---

## What Next?

You now have the conceptual framework. But concepts become skills only through practice. The next chapter presents a comprehensive design exercise where you'll apply everything together.

---

*Next: [Design a System from Scratch](./design-a-system-from-scratch.md)*
