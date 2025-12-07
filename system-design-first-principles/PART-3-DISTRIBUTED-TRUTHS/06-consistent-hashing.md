# Chapter 6: Consistent Hashing

> *"The simplest solution is usually the best."*
> — Occam's Razor (but consistent hashing proves that sometimes the simple solution has a fatal flaw)

---

## The Fundamental Problem

### Why Does This Exist?

You're building a distributed cache. You have 10 cache servers and millions of keys. When a request comes in for key "user:12345", which server should store and retrieve it?

The obvious answer is hashing:
```
server = hash("user:12345") % 10
```

Simple. Deterministic. Any server can compute which cache holds any key.

Now a cache server dies. You have 9 servers. The calculation changes:
```
server = hash("user:12345") % 9
```

For almost every key, `hash(key) % 10` ≠ `hash(key) % 9`. Almost every key now maps to a different server. Your cache hit rate drops to nearly zero. Every request becomes a cache miss. Your database gets slammed.

The raw, primitive problem is this: **How do you distribute data across nodes such that adding or removing a node doesn't require reorganizing most of the data?**

### The Real-World Analogy

Imagine assigning students to classrooms. You have 10 classrooms and 1,000 students. You assign by: classroom = student_id % 10.

Works great until a classroom is closed for repairs. Now you have 9 classrooms. With student_id % 9, almost every student is in a different room. Chaos ensues as 900+ students shuffle between classrooms.

Wouldn't it be better if closing one classroom only affected the students in that classroom, who could be distributed among the others?

---

## The Naive Solution

### What Would a Beginner Try First?

"Use modulo hashing!"

```java
public class ModuloHashing {
    private final int numNodes;

    public int getNode(String key) {
        return Math.abs(key.hashCode()) % numNodes;
    }
}
```

Clean. Fast. Perfectly distributes keys across nodes (assuming a good hash function).

### Why Does It Break Down?

**1. Node removal is catastrophic**

If you have N nodes and remove one:
- Before: key goes to `hash(key) % N`
- After: key goes to `hash(key) % (N-1)`

For most keys, these are different. Nearly 100% of keys must be remapped.

**2. Node addition is equally catastrophic**

Adding a node means going from N to N+1. Same problem—nearly all keys move.

**3. Cache stampede**

When keys move, they're not in the new location yet. Every request is a miss. All misses hit the database simultaneously. Database collapses.

**4. Gradual scaling is impossible**

You can't gently add capacity. Every scaling event is a disruptive full reshuffle.

### The Flawed Assumption

Modulo hashing assumes **the number of nodes is fixed**. It treats the node count as a constant in the hash function. When that "constant" changes, everything breaks.

---

## The Core Insight

### The "Aha" Moment

Here's the fundamental realization:

> **If both keys and nodes live on the same hash ring, adding or removing a node only affects its neighbors—not the entire dataset.**

Instead of mapping keys to node indices, map both keys and nodes to points on a conceptual circle (the hash ring). Each key is handled by the nearest node clockwise on the ring.

When a node is removed, its keys go to the next node clockwise—only those keys move. When a node is added, it takes over some keys from its clockwise neighbor—only those keys move.

The number of keys that move is proportional to 1/N, not N.

### The Trade-off Acceptance

Consistent hashing trades **perfect uniformity for stability**. Keys might not be perfectly evenly distributed (especially with few nodes), but the distribution is stable across topology changes.

We accept slight imbalance in exchange for minimal disruption during scaling.

### The Sticky Metaphor

**Consistent hashing is like assigned seating at a round table.**

Imagine seats around a circular table. Each guest is assigned to the nearest empty seat clockwise. When a guest leaves, only the person who would sit there next is affected. When a new guest arrives and claims a seat, only the person who had been responsible for that seat's "region" is affected.

Compare this to "everyone sits in seat `guest_number % total_seats`"—if the table size changes, everyone shuffles.

---

## The Mechanism

### Building Consistent Hashing From Scratch

**Step 1: Create the ring**

The ring is conceptual—just a circular number space (typically 0 to 2³² or 0 to 2¹²⁸).

```java
public class ConsistentHash<T> {
    // TreeMap gives us ceiling/floor operations for finding nearest node
    private final TreeMap<Long, T> ring = new TreeMap<>();
    private final int virtualNodes;  // Will explain shortly

    public ConsistentHash(int virtualNodes) {
        this.virtualNodes = virtualNodes;
    }

    // Hash function maps strings to positions on the ring
    private long hash(String key) {
        // Use a consistent hash function (MD5, SHA, etc.)
        // Return a long representing position on ring
        return Math.abs(key.hashCode());  // Simplified
    }
}
```

**Step 2: Add nodes to the ring**

Each node is placed at a position determined by hashing the node's identifier.

```java
public void addNode(T node) {
    // Add multiple "virtual nodes" for better distribution
    for (int i = 0; i < virtualNodes; i++) {
        long position = hash(node.toString() + "#" + i);
        ring.put(position, node);
    }
}

public void removeNode(T node) {
    for (int i = 0; i < virtualNodes; i++) {
        long position = hash(node.toString() + "#" + i);
        ring.remove(position);
    }
}
```

**Step 3: Route keys to nodes**

Find the first node clockwise from the key's position.

```java
public T getNode(String key) {
    if (ring.isEmpty()) {
        throw new IllegalStateException("No nodes in ring");
    }

    long keyPosition = hash(key);

    // Find the first node at or after this position
    Map.Entry<Long, T> entry = ring.ceilingEntry(keyPosition);

    // If no node after, wrap around to the first node
    if (entry == null) {
        entry = ring.firstEntry();
    }

    return entry.getValue();
}
```

### Visualizing the Ring

```
                         0
                         │
                   ┌─────┼─────┐
                   │     │     │
              Node A     │     Node D
            (pos 1000)   │   (pos 3500)
                 │       │       │
                 │       │       │
    ───────────────────────────────────
                 │       │       │
                 │       │       │
             Node B      │     Node C
           (pos 2000)    │   (pos 3000)
                   │     │     │
                   └─────┼─────┘
                         │
                       4000

Key "user:123" hashes to position 2500
→ Clockwise, nearest node is C (pos 3000)
→ Key goes to Node C
```

### The Virtual Node Trick

With only a few physical nodes, distribution can be uneven:

```
Ring with 3 nodes:
Node A at position 1000 → handles 0-1000 (1000 range)
Node B at position 1500 → handles 1001-1500 (500 range)
Node C at position 4000 → handles 1501-4000 (2500 range)

Node C handles 5x more keys than Node B!
```

**Solution: Virtual Nodes**

Each physical node gets multiple positions on the ring:

```java
// Instead of 3 positions (one per node), we have 300 (100 per node)
// Node A at positions: 100, 400, 900, 1200, 2100, 2800, 3300, ...
// Node B at positions: 200, 500, 1100, 1700, 2400, 3100, 3600, ...
// Node C at positions: 300, 800, 1000, 1800, 2200, 2900, 3800, ...
```

With 100 virtual nodes per physical node, the load distribution approaches uniform.

```java
public class ConsistentHashWithVirtualNodes<T> {
    private final TreeMap<Long, T> ring = new TreeMap<>();
    private static final int VIRTUAL_NODES = 150;  // Typical range: 100-200

    public void addNode(T node) {
        for (int i = 0; i < VIRTUAL_NODES; i++) {
            // Each virtual node gets a unique position
            long position = hash(node.toString() + "-vnode-" + i);
            ring.put(position, node);
        }
    }
}
```

### Complete Implementation

```java
public class ConsistentHashRing<T> {
    private final TreeMap<Long, T> ring = new TreeMap<>();
    private final Map<T, Set<Long>> nodePositions = new HashMap<>();
    private final int virtualNodes;
    private final MessageDigest md5;

    public ConsistentHashRing(int virtualNodes) {
        this.virtualNodes = virtualNodes;
        try {
            this.md5 = MessageDigest.getInstance("MD5");
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException(e);
        }
    }

    // Better hash function using MD5
    private long hash(String key) {
        md5.reset();
        byte[] digest = md5.digest(key.getBytes());
        // Use first 8 bytes as a long
        long h = 0;
        for (int i = 0; i < 8; i++) {
            h = (h << 8) | (digest[i] & 0xFF);
        }
        return h;
    }

    public synchronized void addNode(T node) {
        Set<Long> positions = new HashSet<>();
        for (int i = 0; i < virtualNodes; i++) {
            long pos = hash(node.toString() + "#" + i);
            ring.put(pos, node);
            positions.add(pos);
        }
        nodePositions.put(node, positions);
    }

    public synchronized void removeNode(T node) {
        Set<Long> positions = nodePositions.remove(node);
        if (positions != null) {
            positions.forEach(ring::remove);
        }
    }

    public synchronized T getNode(String key) {
        if (ring.isEmpty()) return null;

        long hash = hash(key);
        Map.Entry<Long, T> entry = ring.ceilingEntry(hash);
        return (entry != null) ? entry.getValue() : ring.firstEntry().getValue();
    }

    // For replication: get N nodes for a key
    public synchronized List<T> getNodes(String key, int count) {
        if (ring.isEmpty()) return Collections.emptyList();

        List<T> result = new ArrayList<>();
        Set<T> seen = new HashSet<>();

        long hash = hash(key);
        NavigableMap<Long, T> tailMap = ring.tailMap(hash, true);

        // Walk clockwise collecting unique physical nodes
        for (T node : tailMap.values()) {
            if (seen.add(node) && result.size() < count) {
                result.add(node);
            }
        }

        // Wrap around if needed
        if (result.size() < count) {
            for (T node : ring.values()) {
                if (seen.add(node) && result.size() < count) {
                    result.add(node);
                }
            }
        }

        return result;
    }
}
```

---

## The Trade-offs

### What Do We Sacrifice?

**1. Perfect uniformity**

Even with virtual nodes, distribution isn't perfectly even. With 100 virtual nodes per physical node, expect ~10% variance in load.

**2. Complexity**

Modulo hashing is trivial. Consistent hashing requires understanding rings, virtual nodes, and clockwise lookup.

**3. Memory for virtual nodes**

100 virtual nodes × 1000 physical nodes = 100,000 entries in the ring. Memory usage scales with virtual nodes.

**4. Potential for cascading failures**

When a node fails, its traffic goes to its clockwise neighbor. That neighbor might get overwhelmed, fail, and cause cascading failures.

### When NOT To Use This

- **Static node count**: If your cluster never changes size, modulo hashing is simpler and equally effective.
- **Very few nodes**: With 2-3 nodes, consistent hashing benefits are minimal.
- **External coordination available**: Some systems (e.g., Kubernetes) handle distribution externally.

### Connection to Other Concepts

- **Sharding** (Chapter 3): Consistent hashing is a sharding strategy
- **Replication** (Chapter 4): Use getNodes(key, 3) to replicate to 3 nodes
- **Load Balancing** (Chapter 1): Consistent hashing can route requests
- **CAP Theorem** (Chapter 5): Node failures in consistent hash rings affect availability vs. consistency

---

## The Evolution

### Brief History

**1997: Original Paper**

Karger et al. published "Consistent Hashing and Random Trees" at MIT. Designed for web caching.

**2007: Amazon Dynamo**

Amazon's Dynamo paper brought consistent hashing into mainstream distributed systems. DynamoDB, Cassandra, and Riak all use variants.

**2010s: Virtual nodes become standard**

Production systems universally adopted virtual nodes to solve distribution skew.

**2020s: Alternatives emerge**

Jump consistent hash, maglev hashing, and other algorithms offer different trade-offs.

### Modern Variations

**Jump Consistent Hash**

```java
// Google's Jump Consistent Hash
// Zero memory usage, perfect distribution
// But: doesn't support arbitrary node removal
public static int jumpConsistentHash(long key, int numBuckets) {
    long b = -1;
    long j = 0;
    while (j < numBuckets) {
        b = j;
        key = key * 2862933555777941757L + 1;
        j = (long) ((b + 1) * (1L << 31) / ((key >>> 33) + 1));
    }
    return (int) b;
}
```

**Bounded-Load Consistent Hashing**

When a node is overloaded, requests overflow to the next node. Prevents hotspots.

**Rendezvous Hashing (Highest Random Weight)**

Instead of a ring, each key-node pair gets a score. Key goes to highest-scoring node. No virtual nodes needed.

### Where It's Heading

**Adaptive virtual nodes**: Adjust number of virtual nodes based on node capacity.

**Integration with container orchestration**: Kubernetes-aware consistent hashing that respects pod topology.

**Hardware-accelerated lookup**: FPGA/GPU implementations for high-throughput systems.

---

## Interview Lens

### Common Interview Questions

1. **"Why doesn't simple modulo hashing work for distributed caches?"**
   - Node changes cause massive reshuffling
   - Cache miss storm when nodes added/removed
   - No graceful scaling

2. **"Explain how consistent hashing works"**
   - Ring with positions for keys and nodes
   - Keys go to nearest node clockwise
   - Adding/removing node only affects neighbors

3. **"What are virtual nodes and why do we need them?"**
   - Multiple positions per physical node
   - Improves distribution uniformity
   - Prevents hotspots from unlucky node placement

### Red Flags (Shallow Understanding)

❌ "Use hash(key) % num_nodes" without discussing scaling problems

❌ Doesn't know about virtual nodes

❌ Can't explain why only 1/N keys move when a node is added

❌ Thinks consistent hashing eliminates all reshuffling

### How to Demonstrate Deep Understanding

✅ Draw the ring and explain clockwise lookup

✅ Explain the math: 1/N keys move vs ~100% with modulo

✅ Discuss virtual nodes and their purpose

✅ Mention alternatives (jump hash, rendezvous hashing)

✅ Discuss how consistent hashing enables replication (get N nodes)

---

## Curiosity Hooks

As you explore further, consider:

- Consistent hashing tells us where to store data. But what happens when the node storing our data fails? (Hint: Replication to multiple nodes on the ring)

- We minimized data movement during scaling. What about connection handling? (Hint: Connection draining, graceful shutdown)

- Keys going to "nearest node clockwise" assumes one copy. What about read replicas? (Hint: Get N nearest nodes)

- Consistent hashing works for caches. What about for message queues or databases? (Same principle, different considerations)

---

## Summary

**The Problem**: Simple modulo hashing causes massive data reshuffling when nodes are added or removed—unacceptable for production distributed systems.

**The Insight**: By placing both keys and nodes on a hash ring and routing keys to the nearest node clockwise, adding/removing a node only affects keys in its immediate range—approximately 1/N of all keys.

**The Mechanism**: Hash ring with virtual nodes. TreeMap for efficient lookup. Clockwise navigation to find responsible node.

**The Trade-off**: Slightly uneven distribution (mitigated by virtual nodes) for minimal disruption during scaling.

**The Evolution**: From 1997 academic paper → Amazon Dynamo → standard in distributed systems → newer algorithms like jump consistent hash.

**The First Principle**: The number of affected keys should scale with 1/N (where N is node count), not with total keys. Stable hashing enables graceful scaling.

---

*Next: [Chapter 18: Fault Tolerance](./18-fault-tolerance.md)—where we learn that failures aren't exceptions to plan for, but the normal state of distributed systems.*
