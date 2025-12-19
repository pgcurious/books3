# Chapter 44: Vector Clocks and CRDTs

## Tracking Causality Without Synchronized Clocks

---

> *"Time is an illusion. Distributed time doubly so."*
> — Apologies to Douglas Adams

---

## The Frustration

Two users edit the same document on different servers. Later, you need to merge their changes. But which happened first?

```
Server 1: User A sets x = "hello" at time 10:00:00.000
Server 2: User B sets x = "world" at time 10:00:00.000

Same timestamp. Different values.
Clocks aren't synchronized perfectly.
Which version wins?
```

Physical clocks can't order events in distributed systems reliably.

## The Insight: Logical Time

Lamport (1978) introduced logical clocks:

> "If event A happened before event B, then A's timestamp < B's timestamp."

### Lamport Timestamps

```
Each node has a counter.

On local event:
    timestamp = counter++

On send:
    attach timestamp to message

On receive:
    counter = max(counter, message_timestamp) + 1
```

This preserves causality:
- A happened-before B implies timestamp(A) < timestamp(B)
- But timestamp(A) < timestamp(B) doesn't mean A happened-before B

## Vector Clocks: Full Causality

Lamport timestamps lose information. Vector clocks preserve it:

```
Each node keeps a vector of counters (one per node).

Node A: [A:0, B:0, C:0]
Node B: [A:0, B:0, C:0]
Node C: [A:0, B:0, C:0]

Node A does something: [A:1, B:0, C:0]
Node A sends to B:     B receives [A:1, B:0, C:0]
Node B updates:        [A:1, B:1, C:0]
```

### Comparing Vector Clocks

```
V1 = [A:1, B:2, C:1]
V2 = [A:1, B:2, C:2]

V1 < V2 if all components V1[i] <= V2[i] and at least one V1[i] < V2[i]
Result: V1 happened-before V2

V1 = [A:2, B:1, C:0]
V2 = [A:1, B:2, C:0]

Neither V1 < V2 nor V2 < V1
Result: Concurrent (conflict!)
```

### Conflict Detection

```
User A writes x = "hello" at [A:1, B:0]
User B writes x = "world" at [A:0, B:1]

Clocks are concurrent.
Conflict detected!
Application must resolve (merge, last-write-wins, etc.)
```

## Version Vectors in Databases

Dynamo-style databases use version vectors:

```
Read x: value="hello", version=[A:1, B:0]
Modify locally
Write x: value="hello world", version=[A:1, B:1]

Server B does same:
Read x: value="hello", version=[A:1, B:0]
Modify locally
Write x: value="HELLO", version=[A:2, B:0]

Merge:
[A:1, B:1] vs [A:2, B:0] → Concurrent!
Return both values (siblings in Riak terms)
Client must resolve
```

## CRDTs: Conflict-Free Replicated Data Types

What if data structures could merge automatically?

### The Insight

Design data types where all concurrent operations commute:

```
A + B = B + A  (order doesn't matter)
```

### G-Counter (Grow-only Counter)

```
Node A: {A: 5, B: 3, C: 2}  value = 10
Node B: {A: 5, B: 4, C: 2}  value = 11

Merge: {A: max(5,5), B: max(3,4), C: max(2,2)}
     = {A: 5, B: 4, C: 2}
     = 11

No conflict! Max of each component.
```

### PN-Counter (Positive-Negative Counter)

```
Two G-Counters: one for increments, one for decrements

Value = sum(increments) - sum(decrements)

Both increment and decrement work!
```

### G-Set (Grow-only Set)

```
Node A: {apple, banana}
Node B: {banana, cherry}

Merge: {apple, banana, cherry}

Set union. No conflict possible.
```

### 2P-Set (Two-Phase Set)

```
Two G-Sets: added and removed

Element present if: in added AND NOT in removed

Once removed, can't be re-added.
```

### LWW-Register (Last-Writer-Wins Register)

```
Each write carries a timestamp.
Merge: keep value with highest timestamp.

Simple but loses concurrent writes.
```

### OR-Set (Observed-Remove Set)

```
Each add creates unique tag.
Remove removes specific tags.

Can add, remove, and re-add elements!
```

## CRDTs in Practice

### Redis (CRDB)
```
G-Counter for distributed counters
Sets with conflict resolution
```

### Riak
```
CRDTs for counters, sets, maps
Automatic merge without siblings
```

### Automerge/Yjs
```
JSON CRDTs for collaborative editing
Google Docs-like experience
```

## The Tradeoffs

| Approach | Conflict Detection | Conflict Resolution |
|----------|-------------------|---------------------|
| Lamport clocks | Partial | Manual |
| Vector clocks | Full | Manual |
| CRDTs | None needed | Automatic |

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| Logical time | Causality tracking | Simplicity |
| Vector clocks | Concurrent detection | Space (N entries) |
| CRDTs | Auto-merge | Limited operations |

## The Principle

> **Vector clocks track causality without relying on physical clocks. CRDTs go further, designing data types where all operations commute, eliminating conflicts by construction.**

These tools enable eventually consistent systems that don't lose updates.

---

## Summary

- Physical clocks can't reliably order distributed events
- Lamport timestamps provide partial ordering
- Vector clocks detect concurrent (conflicting) operations
- CRDTs are data types designed for automatic conflict-free merge
- Common CRDTs: counters, sets, registers, maps
- Used in databases (Riak), collaborative editors (Automerge)

---

*We've covered the major protocols. Now let's synthesize what we've learned—how to choose protocols and think about designing your own.*
