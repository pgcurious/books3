# Chapter 2: Caching

> *"Those who cannot remember the past are condemned to repeat it."*
> — George Santayana

---

## The Fundamental Problem

### Why Does This Exist?

You're building a popular news website. Every time someone loads the homepage, your server:

1. Queries the database for the top 50 articles
2. Fetches author information for each article
3. Retrieves comment counts
4. Generates HTML from all this data

Each page load takes 200 milliseconds of database queries and 50 milliseconds of processing. At 10 requests per second, your database is sweating. At 1,000 requests per second, it's on fire.

But here's the thing: **the homepage is the same for everyone.** Why are you computing the same result 1,000 times per second?

The raw, primitive problem is this: **How do you avoid doing expensive work repeatedly when the result doesn't change?**

### The Real-World Analogy

Think about how you remember phone numbers. When you first meet someone, you might look up their number in your contacts. But after calling them a few times, you just *remember* it. You don't look it up every single time.

Your brain maintains a cache—a quick-access copy of frequently-used information. You could always look it up (slow, reliable), but remembering is faster.

Or consider a library. You could request any book from the massive underground archive (takes 30 minutes). But the popular books? They're on a display shelf near the entrance (takes 30 seconds). The library caches popular items for faster access.

---

## The Naive Solution

### What Would a Beginner Try First?

"Just add more database servers!"

This is throwing hardware at the problem. If one database server can't handle 1,000 queries per second, use ten database servers.

### Why Does It Break Down?

**1. It's expensive.**

Database servers with high IOPS and low latency are costly. You're paying 10x the hardware cost to serve the same data repeatedly.

**2. It doesn't solve the latency problem.**

Even with infinite database capacity, each request still takes 200ms. You've improved throughput but not response time.

**3. The database becomes a coordination bottleneck.**

Ten read replicas means synchronizing data across ten servers. Complexity explodes.

**4. You're solving the wrong problem.**

The issue isn't "how do we compute faster?" but "why are we computing the same thing over and over?"

### The Flawed Assumption

The naive approach assumes that **every request requires computation**. It treats the database as a machine that must always work, rather than recognizing that most requests are asking for things that haven't changed.

---

## The Core Insight

### The "Aha" Moment

Here's the fundamental realization:

> **The fastest work is work you don't do.**

If you computed something 5 seconds ago and nothing has changed, why compute it again? Store the result. Return the stored result. Skip the computation entirely.

This is caching: **trading memory for time.**

### The Bet on Temporal Locality

Caching works because of a phenomenon called **temporal locality**: if something was accessed recently, it's likely to be accessed again soon.

- The homepage of a news site? Viewed millions of times per day.
- A user's profile they just logged into? Probably accessed again in the next few minutes.
- Yesterday's stock price? Might never be requested again.

Caching is a bet. You're betting that recently-accessed data will be accessed again before it changes. When you win this bet (cache hit), you save massive amounts of work. When you lose (cache miss), you just do the work you would have done anyway.

### The Sticky Metaphor

**A cache is like your brain's working memory.**

You can't consciously hold everything you know—that would be impossible. Instead, you keep a small amount of immediately-relevant information "at the front of your mind."

When someone asks about something in your working memory, you answer instantly. When they ask about something in long-term storage, there's a pause: "Let me think... oh right, that's in Chapter 7." You have to retrieve it.

Your working memory is small but fast. Long-term memory is vast but slow. The magic is in knowing what to keep in working memory.

---

## The Mechanism

### Building It From Scratch

Let's invent caching from first principles.

**Step 1: Identify expensive operations**

Not everything needs caching. Focus on:
- Operations that are slow (database queries, API calls, computations)
- Operations that are repeated often
- Operations where input doesn't change frequently

**Step 2: Store results in fast storage**

```java
public class SimpleCache<K, V> {
    // Why HashMap: O(1) lookup—the whole point is speed
    private final Map<K, V> store = new HashMap<>();

    public V get(K key) {
        return store.get(key);
    }

    public void put(K key, V value) {
        store.put(key, value);
    }
}
```

**Step 3: Check cache before doing work**

```java
public class ArticleService {
    private final SimpleCache<String, Article> cache = new SimpleCache<>();
    private final Database database;

    public Article getArticle(String id) {
        // First, check if we already have it
        Article cached = cache.get(id);
        if (cached != null) {
            return cached;  // Cache hit! No database query needed.
        }

        // Cache miss—do the expensive work
        Article article = database.fetchArticle(id);

        // Store for next time
        cache.put(id, article);

        return article;
    }
}
```

### The Problem: Memory Is Finite

Our simple cache has a fatal flaw: it grows forever. Eventually, it consumes all memory and crashes the application.

We need an **eviction policy**—a way to decide what to remove when space is needed.

**Least Recently Used (LRU)**

Remove the item that hasn't been accessed for the longest time.

```java
public class LRUCache<K, V> {
    private final int capacity;
    // Why LinkedHashMap: maintains insertion order AND allows access-order mode
    private final LinkedHashMap<K, V> store;

    public LRUCache(int capacity) {
        this.capacity = capacity;
        // accessOrder=true means accessing an entry moves it to the end
        this.store = new LinkedHashMap<>(capacity, 0.75f, true) {
            @Override
            protected boolean removeEldestEntry(Map.Entry<K, V> eldest) {
                // When size exceeds capacity, remove least recently used
                return size() > capacity;
            }
        };
    }

    public synchronized V get(K key) {
        return store.get(key);  // Access moves item to end (most recent)
    }

    public synchronized void put(K key, V value) {
        store.put(key, value);  // Automatically evicts oldest if needed
    }
}
```

**Other Eviction Policies:**

- **FIFO (First In, First Out)**: Remove oldest added item. Simple but ignores access patterns.
- **LFU (Least Frequently Used)**: Remove least-accessed item. Good for stable access patterns.
- **Random**: Just pick something. Surprisingly effective and very simple.
- **TTL (Time To Live)**: Remove items after fixed time, regardless of access.

### The Problem: Stale Data

What happens when the underlying data changes? Your cache might serve outdated information.

**Cache Invalidation Strategies:**

```java
// Strategy 1: Time-based expiration
public class TTLCache<K, V> {
    private final Map<K, CacheEntry<V>> store = new HashMap<>();
    private final long ttlMillis;

    public V get(K key) {
        CacheEntry<V> entry = store.get(key);
        if (entry == null) return null;

        // Check if expired
        if (System.currentTimeMillis() > entry.expiresAt) {
            store.remove(key);
            return null;  // Treat as cache miss
        }
        return entry.value;
    }

    private static class CacheEntry<V> {
        V value;
        long expiresAt;
    }
}

// Strategy 2: Explicit invalidation
public class ArticleService {
    private final Cache<String, Article> cache;

    public void updateArticle(String id, Article newContent) {
        database.update(id, newContent);
        cache.invalidate(id);  // Remove stale entry
    }
}

// Strategy 3: Write-through (update cache when updating source)
public void updateArticle(String id, Article newContent) {
    database.update(id, newContent);
    cache.put(id, newContent);  // Update cache with new value
}
```

### Caching Patterns

**Cache-Aside (Lazy Loading)**

```
Application checks cache → miss → fetches from DB → stores in cache → returns
```

The application manages the cache. Most flexible, but application code is more complex.

**Read-Through**

```
Application requests from cache → cache fetches from DB if miss → returns
```

The cache fetches data on miss. Application code is simpler.

**Write-Through**

```
Application writes to cache → cache writes to DB → returns
```

Every write goes through the cache. Data is always consistent.

**Write-Behind (Write-Back)**

```
Application writes to cache → returns immediately → cache eventually writes to DB
```

Writes are fast, but data might be lost if cache fails before persisting.

### Where to Put the Cache

```
┌────────┐     ┌─────────┐     ┌─────────┐     ┌──────────┐
│ Client │────►│ CDN     │────►│ Server  │────►│ Database │
└────────┘     │ Cache   │     │ Cache   │     │          │
               └─────────┘     └─────────┘     └──────────┘
                Layer 1          Layer 2          Layer 3

Also:
- Browser cache (on user's device)
- Operating system page cache
- Database query cache
- CPU caches (L1, L2, L3)
```

Multiple cache layers, each trading different resources for speed.

---

## The Trade-offs

### What Do We Sacrifice?

**1. Freshness (Consistency)**

Cache data might be stale. A user updates their profile, but other users see the old version for 30 seconds. Is that acceptable? Depends on the use case.

**2. Memory**

Caches consume RAM, which is expensive and finite. How much are you willing to spend on caching vs. other purposes?

**3. Complexity**

"There are only two hard things in Computer Science: cache invalidation and naming things." — Phil Karlton

Invalidation is genuinely hard. When data changes, how do you know which cache entries depend on it? How do you invalidate across multiple cache servers?

**4. Cold Start Problem**

When you deploy new servers or restart the cache, it's empty. Suddenly all requests are cache misses—your database gets slammed. This is called a "cache stampede" or "thundering herd."

### When NOT To Use This

- **Highly dynamic data**: Stock tickers change constantly. Caching for 1 second might mean outdated trades.
- **User-specific data that's rarely re-accessed**: A report generated once and downloaded? Don't cache.
- **When consistency is critical**: Financial transactions, medical records—stale data could be catastrophic.
- **Low-latency sources**: If the database query takes 1ms, caching overhead might not be worth it.

### Connection to Other Concepts

- **Load Balancing** (Chapter 1): Caching reduces load on backend servers
- **CDNs** (Chapter 12): CDNs are geographically distributed caches
- **Eventual Consistency** (Chapter 15): Caching introduces consistency trade-offs
- **Database Indexing** (Chapter 13): Both are about finding data faster

---

## The Evolution

### Brief History

**1960s-70s: CPU caches**

Hardware engineers realized main memory was too slow for CPUs. They added small, fast memory close to the processor. The concept was born.

**1990s: Web proxies and CDNs**

As the web grew, organizations deployed proxy servers to cache frequently-accessed websites. Akamai (1998) pioneered commercial CDNs.

**2000s: Application-level caching**

memcached (2003), Redis (2009). Application developers could easily add distributed caching. The "cache everything" era began.

**2010s: Intelligent caching**

Smart invalidation, probabilistic caches, multi-tier caching architectures. Caching became a science, not just a trick.

**2020s: Edge caching and serverless**

Cloudflare Workers, AWS Lambda@Edge. Cache computation, not just data. Move caching to the network edge, as close to users as possible.

### Modern Variations

**Redis**

More than a cache—supports data structures, pub/sub, persistence. Often used as a primary data store for certain use cases.

**Multi-Level Caching**

L1 cache (in-process, microseconds) → L2 cache (Redis, milliseconds) → Database (tens of milliseconds)

**Probabilistic Caches**

Bloom filters and other structures that can tell you "definitely not cached" with certainty, or "probably cached" with high confidence. Trade perfect accuracy for massive memory savings.

### Where It's Heading

**Predictive caching**: ML models predict what users will request next and pre-populate caches.

**Cache-as-code**: Infrastructure as code applies to caching strategies. Declarative cache policies.

**Hardware-accelerated caching**: FPGAs and custom ASICs for line-rate caching at the network layer.

---

## Interview Lens

### Common Interview Questions

1. **"Design a caching system for Twitter's home timeline"**
   - Discuss: fan-out on write vs. fan-out on read
   - Address celebrity problem (users with millions of followers)
   - Cache invalidation when someone tweets

2. **"How do you handle cache invalidation?"**
   - TTL for time-insensitive data
   - Event-driven invalidation for critical updates
   - Version keys for complex invalidation logic

3. **"What happens during a cache failure?"**
   - Discuss graceful degradation
   - Database can handle load (temporarily)
   - Circuit breaker patterns

4. **"How do you prevent a cache stampede?"**
   - Request coalescing (only one request fetches on miss)
   - Lock/mutex around cache population
   - Probabilistic early expiration

### Red Flags (Shallow Understanding)

❌ "Just use Redis" without discussing when NOT to cache

❌ Can't explain cache invalidation strategies

❌ Doesn't mention consistency trade-offs

❌ Thinks caching solves all performance problems

### How to Demonstrate Deep Understanding

✅ Discuss cache hit ratio and how to measure effectiveness

✅ Explain the relationship between cache size and hit ratio

✅ Mention write-through vs. write-behind trade-offs

✅ Acknowledge that caching shifts complexity, doesn't eliminate it

✅ Ask about data access patterns before recommending a caching strategy

---

## Curiosity Hooks

As you continue, consider these questions:

- Caching stores data closer to where it's used. What if users are geographically distributed? (Hint: Chapter 12, CDNs)

- We cached data to avoid redundant computation. What about caching to avoid network hops in service-to-service calls? (Hint: Chapter 10, Microservices)

- Cache invalidation is hard in a single system. How does it work across multiple databases? (Hint: Chapter 4, Replication)

- If we're betting on temporal locality, how do we know if we're winning? (Hint: Chapter 19, Monitoring)

---

## Summary

**The Problem**: Expensive operations are repeated unnecessarily when results haven't changed.

**The Insight**: Store results of expensive operations. Return stored results instead of recomputing. The fastest work is work you don't do.

**The Mechanism**: Fast-lookup storage (hash maps) with eviction policies (LRU, TTL) and invalidation strategies (time-based, event-driven).

**The Trade-off**: Memory and consistency for speed.

**The Evolution**: From CPU caches → web proxies → application caches → edge computing → predictive caching.

**The First Principle**: Trading memory for time is almost always a good deal, because memory is cheap and time is precious.

---

*Next: [Chapter 8: Rate Limiting](./08-rate-limiting.md)—where we learn that sometimes the best way to serve users is to tell them "no."*
