# Chapter 43: Gossip Protocols—Epidemic Information

## Spreading Data Like a Rumor

---

> *"Gossip protocols: when you need everyone to eventually know, but not immediately."*
> — Distributed Systems Designer

---

## The Frustration

You have 1000 nodes in a cluster. Node 1 has an update. How do you tell everyone?

**Broadcasting:**
```
Node 1 → All 999 other nodes
Single point of failure
Network bottleneck
```

**Consensus:**
```
Get majority agreement
Expensive for simple updates
Overkill for many cases
```

What if updates spread like rumors in a social network?

## The Insight: Epidemic Spreading

Gossip protocols spread information like disease or rumors:

```
Round 1:
Node 1 knows update
Node 1 tells Node 5 (randomly chosen)

Round 2:
Node 1 tells Node 23
Node 5 tells Node 42

Round 3:
Node 1 tells Node 77
Node 5 tells Node 8
Node 23 tells Node 15
Node 42 tells Node 3

...exponential spread...

After log(N) rounds, everyone knows.
```

## How Gossip Works

### Basic Algorithm

```
Every T seconds:
    1. Pick random peer
    2. Exchange state
    3. Merge (take newer versions)
```

### Anti-Entropy

Exchange full state, reconcile differences:

```
Node A: {x: 1, y: 2, z: 3}
Node B: {x: 4, y: 2, w: 5}

After exchange:
Node A: {x: 4, y: 2, z: 3, w: 5}
Node B: {x: 4, y: 2, z: 3, w: 5}

Both have union of knowledge.
```

### Rumor Mongering

Spread new information aggressively:

```
Node with new update:
    Gossip aggressively until several peers have it
    Then stop (update is "stale")

New information spreads fast.
Old information doesn't waste bandwidth.
```

## Convergence Properties

Gossip has probabilistic guarantees:

```
N nodes, each gossips to k peers per round
After O(log N) rounds:
    All nodes have the information (with high probability)

Even with failures:
    If f nodes fail, update still spreads
    Very fault tolerant
```

## Use Cases

### Membership and Failure Detection

```
Nodes gossip heartbeats:
    "I'm alive, timestamp=123"

No heartbeat from Node X for a while?
    Mark X as suspected
    Gossip the suspicion
    If enough nodes suspect X, mark X as dead
```

Used by: Cassandra, Consul, Serf

### Configuration Distribution

```
Update configuration on one node
Gossip spreads it to all
Eventually consistent configuration
```

### Aggregate Computation

```
Compute cluster-wide average:
    Each node has local value
    Exchange with peers
    Average values on exchange
    Eventually converges to global average
```

## Gossip in Cassandra

```
Each node gossips with 1-3 nodes per second.
Information shared:
    - Heartbeat (aliveness)
    - Schema version
    - Data center/rack
    - Tokens (data ownership)

Nodes quickly learn cluster topology.
```

## Gossip vs Consensus

| Aspect | Gossip | Consensus (Raft/Paxos) |
|--------|--------|------------------------|
| Consistency | Eventual | Strong |
| Latency | Variable | Higher |
| Overhead | Low | Higher |
| Failure tolerance | Very high | Majority needed |
| Ordering | No | Yes |
| Use case | Membership, metrics | Leader election, replication |

## The Math: Why Gossip Converges

```
N nodes, each gossips to 1 random peer per round.

Round 1: 1 node infected
Round 2: ~2 nodes infected
Round 3: ~4 nodes infected
...
Round k: ~2^k nodes infected

After log₂(N) rounds: All infected (expected)

With some redundancy (gossip to 2-3 peers):
    Convergence even faster
    Resilient to message loss
```

## SWIM: Scalable Membership

Optimized gossip for membership:

```
Ping:
    Direct: Ping node X, expect ACK
    Indirect: If X doesn't respond, ask Y to ping X
    If still no response, suspect X

Dissemination:
    Piggyback membership updates on pings
    No separate gossip messages
```

Used by: HashiCorp Serf, Memberlist

## The Tradeoffs

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| Random peer selection | Resilience | Deterministic timing |
| Eventual consistency | Availability | Strong consistency |
| No coordination | Simplicity | Ordering |
| Probabilistic | Efficiency | Guarantees |

## The Principle

> **Gossip protocols trade consistency for resilience. By spreading information probabilistically, they achieve remarkable fault tolerance with minimal coordination. The cost is eventual, not immediate, consistency.**

Use gossip when you need resilient spread of information but don't need immediate consistency.

---

## Summary

- Gossip spreads information like rumors or epidemics
- Each node randomly exchanges state with peers
- Converges in O(log N) rounds
- Extremely fault tolerant
- Used for membership, failure detection, configuration
- Eventually consistent, not strongly consistent
- SWIM optimizes gossip for membership

---

*Finally, let's look at how to track time and causality without clocks.*
