# System Design Interview Cheatsheet

A quick reference for system design interviews, synthesizing all 20 concepts.

---

## The Framework (5-Step Approach)

### Step 1: Clarify Requirements (2-3 min)
- **Functional**: What does it do?
- **Non-functional**: Scale, latency, availability, consistency
- **Constraints**: Budget, timeline, existing systems
- **Back-of-envelope**: Estimate traffic, storage, bandwidth

### Step 2: High-Level Design (5 min)
- Draw the architecture
- Show main components and data flow
- Keep it simple—add complexity later

### Step 3: Deep Dive (10-15 min)
- Database design & sharding strategy
- API design
- Critical algorithms
- Scaling approach

### Step 4: Address Trade-offs (3-5 min)
- What are you trading?
- What alternatives exist?
- Why did you choose this approach?

### Step 5: Wrap Up (2 min)
- Summarize the design
- Mention future improvements
- Ask if they want to dive deeper anywhere

---

## Quick Reference: All 20 Concepts

### Load Balancing
**Problem**: Single server can't handle all traffic
**Solution**: Distribute requests across multiple servers
**Algorithms**: Round-robin, least connections, IP hash
**Key trade-off**: Statefulness (sticky sessions vs. stateless)

### Caching
**Problem**: Expensive operations repeated unnecessarily
**Solution**: Store results of expensive operations
**Strategies**: Cache-aside, read-through, write-through
**Key trade-off**: Freshness vs. speed (TTL, invalidation)

### Database Sharding
**Problem**: Single DB can't hold/process all data
**Solution**: Partition data across multiple databases
**Strategies**: Hash-based, range-based, directory-based
**Key trade-off**: Query flexibility (cross-shard joins hard)

### Replication
**Problem**: Single DB is single point of failure
**Solution**: Multiple copies of data
**Types**: Primary-replica, multi-primary, leaderless
**Key trade-off**: Consistency vs. latency (sync vs. async)

### CAP Theorem
**The Law**: During partition, choose Consistency OR Availability
**CP systems**: Refuse requests when consistency uncertain (HBase, Zookeeper)
**AP systems**: Serve requests, accept eventual consistency (Cassandra, DynamoDB)
**Key insight**: Not "pick 2 of 3"—P isn't optional

### Consistent Hashing
**Problem**: Adding/removing nodes reshuffles all data
**Solution**: Ring-based hashing where only neighbors affected
**Virtual nodes**: Multiple positions per physical node for balance
**Key insight**: 1/N keys move vs. nearly 100% with modulo

### Message Queues
**Problem**: Tight coupling, sync blocking, failure cascades
**Solution**: Async communication through buffered queues
**Patterns**: Point-to-point, pub-sub, saga
**Key trade-off**: Latency for decoupling and reliability

### Rate Limiting
**Problem**: Resource exhaustion from excessive use
**Solution**: Limit requests per user/time period
**Algorithms**: Token bucket, leaky bucket, sliding window
**Key insight**: Saying "no" protects ability to say "yes"

### API Gateway
**Problem**: Clients shouldn't know internal architecture
**Solution**: Single entry point handling cross-cutting concerns
**Responsibilities**: Auth, rate limiting, routing, aggregation
**Key trade-off**: Latency and complexity for unified interface

### Microservices
**Problem**: Large teams stepping on each other
**Solution**: Independent services by business capability
**Key principles**: Own your data, smart endpoints, dumb pipes
**Key trade-off**: Operational complexity for team autonomy

### Service Discovery
**Problem**: Service locations change dynamically
**Solution**: Registry where services register and discover
**Patterns**: Client-side, server-side, DNS-based
**Key insight**: Names are stable; addresses are ephemeral

### CDNs
**Problem**: Users far from servers = high latency
**Solution**: Cache content at edge locations near users
**Use cases**: Static assets, API caching, video streaming
**Key trade-off**: Staleness for speed

### Database Indexing
**Problem**: Finding data requires scanning everything
**Solution**: Sorted structures for O(log n) lookup
**Types**: B-tree (range), hash (exact), full-text, spatial
**Key trade-off**: Write speed and storage for read speed

### Partitioning
**Problem**: Large tables slow to query and maintain
**Solution**: Split tables by time, region, or category
**Types**: Range, list, hash, composite
**Key insight**: Queries touching fewer partitions are faster

### Eventual Consistency
**Problem**: Strong consistency is expensive/impossible at scale
**Solution**: Accept temporary divergence, converge eventually
**Strategies**: LWW, vector clocks, CRDTs
**Key insight**: Consistency is a spectrum, not binary

### WebSockets
**Problem**: HTTP is request-response; can't push to client
**Solution**: Persistent bidirectional connection
**Use cases**: Chat, real-time updates, gaming
**Key trade-off**: Stateful connections complicate scaling

### Scalability
**Problem**: System can't grow with demand
**Solution**: Design for horizontal scaling
**Key principles**: Stateless, partition data, async processing
**Key insight**: Scalability is the derivative (how cost grows with capacity)

### Fault Tolerance
**Problem**: Components fail; failures cascade
**Solution**: Expect failure, design for failure
**Patterns**: Redundancy, circuit breaker, bulkhead, retry
**Key insight**: Reliability = how you handle failures

### Monitoring
**Problem**: Can't fix what you can't see
**Solution**: Metrics, logs, traces for observability
**RED method**: Rate, Errors, Duration (for services)
**USE method**: Utilization, Saturation, Errors (for resources)

### AuthN & AuthZ
**Problem**: Verifying identity, controlling access
**AuthN (who are you?)**: Passwords, tokens, OAuth, MFA
**AuthZ (what can you do?)**: RBAC, ABAC, policies
**Key insight**: Trust no one by default

---

## Numbers Everyone Should Know

| Operation | Latency |
|-----------|---------|
| L1 cache reference | 0.5 ns |
| L2 cache reference | 7 ns |
| Main memory reference | 100 ns |
| SSD random read | 16 μs |
| HDD random read | 2 ms |
| Packet roundtrip (same DC) | 500 μs |
| Packet roundtrip (cross-country) | 150 ms |

| Time Period | Seconds |
|-------------|---------|
| 1 day | 86,400 |
| 1 month | 2,592,000 |
| 1 year | 31,536,000 |

| Storage | Bytes |
|---------|-------|
| 1 KB | 1,000 |
| 1 MB | 1,000,000 |
| 1 GB | 1,000,000,000 |
| 1 TB | 1,000,000,000,000 |

---

## Common Calculations

### Traffic Estimates
```
Requests per second = Monthly requests / (30 × 24 × 3600)
100M/month = 100M / 2.6M seconds ≈ 40 RPS
```

### Storage Estimates
```
Total storage = Daily data × Days to retain
100GB/day × 365 days = 36.5 TB
```

### Bandwidth Estimates
```
Bandwidth = RPS × Request size
1000 RPS × 1 KB = 1 MB/s = 8 Mbps
```

### Server Estimates
```
Servers needed = Total RPS / RPS per server
If one server handles 1000 RPS:
40,000 RPS → 40 servers
```

---

## Common Interview Questions

| System | Key Concepts |
|--------|--------------|
| URL Shortener | Hashing, DB design, caching, analytics pipeline |
| Twitter | Fan-out, timeline generation, pub-sub, caching |
| Instagram | Image storage, CDN, news feed, sharding |
| Chat System | WebSockets, presence, message queues |
| Netflix | Video streaming, CDN, recommendation system |
| Uber | Location services, matching algorithm, surge pricing |
| Google Docs | Real-time collaboration, CRDT/OT, WebSockets |
| Search Engine | Crawling, indexing, ranking, caching |
| E-commerce | Product catalog, cart, checkout, inventory |
| Rate Limiter | Token bucket, distributed counting, Redis |

---

## Interview Red Flags to Avoid

❌ Jumping to solution without clarifying requirements
❌ Over-engineering for scale you don't need
❌ Not discussing trade-offs
❌ Ignoring non-functional requirements
❌ Single point of failure without acknowledging it
❌ Not explaining WHY you chose something
❌ Saying "it depends" without following up with the factors

---

## Phrases That Show Deep Understanding

✅ "Given the read:write ratio, we should..."
✅ "The trade-off here is X vs Y, and I chose..."
✅ "For consistency, we could go CP or AP. Given the use case..."
✅ "This is the happy path. For failures, we'd..."
✅ "Initially we could do X, and scale to Y when..."
✅ "An alternative would be... but I chose this because..."

---

## Quick Decision Guides

### SQL vs NoSQL
- **SQL**: Complex queries, ACID transactions, structured data
- **NoSQL**: Scale, flexibility, simple access patterns

### Sync vs Async
- **Sync**: User needs immediate response
- **Async**: Background work, can tolerate delay

### Cache vs Not Cache
- **Cache**: Read-heavy, expensive to compute, tolerates stale
- **Don't cache**: Write-heavy, must be fresh, rarely re-accessed

### Monolith vs Microservices
- **Monolith**: Small team, new product, simple domain
- **Microservices**: Large team, stable domain, need independence

---

## Final Reminders

1. **Start simple**, add complexity when justified
2. **Clarify before designing**—requirements drive architecture
3. **Think aloud**—interviewers want to see your thinking
4. **Trade-offs everywhere**—acknowledge them
5. **First principles**—derive solutions, don't just recite patterns

---

*Good luck with your interviews!*
