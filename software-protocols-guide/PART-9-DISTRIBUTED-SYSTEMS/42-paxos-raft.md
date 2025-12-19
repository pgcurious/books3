# Chapter 42: Paxos and Raft—Consensus

## Getting Distributed Nodes to Agree

---

> *"The Paxos algorithm is simple, yet many people find it difficult to understand."*
> — Leslie Lamport, 2001

---

## The Frustration

You have five servers replicating the same data. A write comes in. All servers should agree on whether it happened, and in what order.

But:
- Any server might crash
- Network might partition
- Messages might be delayed

How do you get reliable agreement?

## Paxos: The Original Consensus

Leslie Lamport invented Paxos in 1989 (published 1998). It's provably correct but notoriously difficult to understand.

### Basic Paxos: Single Value

Agrees on ONE value, ever.

**Roles:**
- **Proposers**: Suggest values
- **Acceptors**: Vote on proposals
- **Learners**: Learn the chosen value

**The Protocol:**

```
Phase 1: Prepare
Proposer → Acceptors: Prepare(n)
    "I'm proposer n, may I propose?"
Acceptors → Proposer: Promise(n, prior_accepted)
    "I won't accept proposals < n"
    "Here's what I've already accepted"

Phase 2: Accept
Proposer → Acceptors: Accept(n, value)
    "Accept this value with proposal n"
Acceptors → Proposer: Accepted(n)
    "I accept"

Value chosen when majority accepts.
```

### Why It Works

**Safety**: Once a value is chosen, it can't be changed.
**Liveness**: Progress is made if a majority is available (eventually).

### Why It's Hard

```
Original Paxos paper: 8 pages
Understanding it: Weeks for many engineers
Implementing it correctly: Months

"The dirty little secret is that most implementations
that claim to be Paxos aren't actually Paxos."
— Industry folklore
```

## Raft: Understandable Consensus

Diego Ongaro designed Raft (2013) specifically for understandability.

**Key Insight**: Decompose consensus into three sub-problems.

### 1. Leader Election

```
States: Follower, Candidate, Leader

Follower:
    Receives heartbeats from leader
    If no heartbeat in election_timeout:
        Become Candidate

Candidate:
    Increment term
    Vote for self
    Send RequestVote to all
    If majority votes: Become Leader
    If someone else wins: Become Follower

Leader:
    Send heartbeats to maintain authority
    Handle all client requests
    Replicate log to followers
```

### 2. Log Replication

```
Leader:
    Receives command from client
    Appends to own log
    Sends AppendEntries to followers
    Waits for majority acknowledgment
    Commits entry
    Applies to state machine
    Responds to client

Followers:
    Receive AppendEntries
    Append to log
    Acknowledge
```

### 3. Safety

**Election Safety**: At most one leader per term.
**Log Matching**: If two logs have same index and term, they're identical up to that point.
**Leader Completeness**: If entry is committed, it appears in all future leaders' logs.

## Raft in Action

```
Term 1:
[Leader S1] ──heartbeat──→ [Follower S2]
           ──heartbeat──→ [Follower S3]
           ──heartbeat──→ [Follower S4]
           ──heartbeat──→ [Follower S5]

Leader S1 crashes!

Term 2:
S2 times out, becomes Candidate
S2 → S3, S4, S5: "Vote for me"
S3, S4 vote for S2
S2 becomes Leader
S2 ──heartbeat──→ S3, S4, S5
```

## Raft vs Paxos

| Aspect | Paxos | Raft |
|--------|-------|------|
| Published | 1989/1998 | 2014 |
| Primary goal | Correctness | Understandability |
| Leader | Optional | Required |
| Membership changes | Complex | Simpler (joint consensus) |
| Understanding time | Weeks | Days |

## Multi-Paxos and Raft for State Machines

Basic Paxos agrees on one value. For state machine replication, you need to agree on a SEQUENCE of values:

```
Log entry 1: set x = 1
Log entry 2: set y = 2
Log entry 3: set x = 5

All nodes execute in same order → same final state
```

Multi-Paxos and Raft do this by running consensus for each log entry.

## Real-World Implementations

### etcd
```
Uses Raft for consensus
Powers Kubernetes
Strong consistency for configuration
```

### ZooKeeper
```
Uses ZAB (ZooKeeper Atomic Broadcast)
Similar to Raft/Paxos
Leader-based consensus
```

### CockroachDB
```
Uses Raft for replication
Each range (shard) has its own Raft group
```

### TiDB/TiKV
```
Uses Raft
Distributed SQL database
```

## Quorum Requirements

```
N nodes, majority quorum: (N/2) + 1

3 nodes: Need 2 for consensus. Tolerate 1 failure.
5 nodes: Need 3 for consensus. Tolerate 2 failures.
7 nodes: Need 4 for consensus. Tolerate 3 failures.

Even numbers are wasteful:
4 nodes: Need 3 for consensus. Still only tolerate 1 failure!
```

## The Tradeoffs

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| Majority quorum | Fault tolerance | Minority can't proceed |
| Strong leader | Simplicity | Leader bottleneck |
| Synchronous log | Consistency | Latency |
| Disk before ack | Durability | Performance |

## The Principle

> **Paxos and Raft solve distributed consensus by requiring majority agreement. They guarantee that once a value is chosen, it remains chosen—even across failures. Raft trades some of Paxos's generality for understandability.**

Understanding Raft is a gateway to understanding distributed systems.

---

## Summary

- Paxos: Original consensus algorithm, provably correct, hard to understand
- Raft: Designed for understandability, equivalent power
- Three sub-problems: leader election, log replication, safety
- Majority quorum required for progress
- Used in etcd, ZooKeeper, CockroachDB, and more

---

*For loosely coupled systems, Gossip protocols spread information without consensus.*
