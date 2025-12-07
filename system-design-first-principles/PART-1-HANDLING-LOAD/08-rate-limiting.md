# Chapter 8: Rate Limiting

> *"The art of being wise is the art of knowing what to overlook."*
> — William James

---

## The Fundamental Problem

### Why Does This Exist?

You've built a successful API. Developers love it. Then one morning, your servers melt.

Digging through logs, you discover: a single user sent 50,000 requests in one minute. Maybe it was a bug in their code. Maybe it was a poorly-configured batch job. Maybe it was intentional—a denial-of-service attack.

The result is the same: one user consumed all your resources, and thousands of others got nothing.

The raw, primitive problem is this: **How do you protect shared resources from excessive use by any single actor?**

### The Real-World Analogy

Consider an all-you-can-eat buffet. Without rules, one person could theoretically pile 50 plates and monopolize all the shrimp. The restaurant would run out, other customers would leave angry, and the economics would collapse.

So buffets have implicit rules: "one plate at a time," "no take-home containers." These rules aren't about being stingy—they're about ensuring everyone gets a fair share of limited resources.

Or think about road speed limits. Without them, one reckless driver going 150 mph endangers everyone. Speed limits aren't just about safety; they're about fair use of shared infrastructure.

Rate limiting is the speed limit of the internet.

---

## The Naive Solution

### What Would a Beginner Try First?

"Just scale up! If 50,000 requests overwhelms us, let's handle 100,000!"

This is the arms race approach. When hit with high traffic, add more servers.

### Why Does It Break Down?

**1. It rewards bad behavior.**

By scaling to meet malicious or buggy traffic, you're effectively subsidizing the cost of someone else's mistake (or attack).

**2. Cost grows unbounded.**

An attacker with a botnet can send millions of requests. Can you afford millions of server-seconds to respond to junk requests?

**3. It doesn't prevent resource exhaustion.**

Even with unlimited servers, downstream dependencies (databases, third-party APIs) have limits. You're just pushing the bottleneck elsewhere.

**4. Legitimate users still suffer.**

While you're busy handling the flood, connection pools fill up, queues back up, and real users experience delays.

### The Flawed Assumption

The naive approach assumes **all requests are legitimate and equal.** It assumes capacity is the only constraint when the real constraint is fair allocation.

---

## The Core Insight

### The "Aha" Moment

Here's the fundamental realization:

> **It's better to explicitly reject excess traffic than to implicitly degrade service for everyone.**

A clean "429 Too Many Requests" response is better than a slow, unreliable service. By saying "no" quickly to excess requests, you preserve capacity to say "yes" quickly to legitimate ones.

Rate limiting is **admission control**. Like a nightclub bouncer, you'd rather turn people away at the door than let the dance floor become dangerously overcrowded.

### The Trade-off Acceptance

We accept that **not all requests deserve equal treatment**. We differentiate users, prioritize legitimate traffic, and sacrifice fairness-in-principle for fairness-in-practice.

A paying customer's 100th request might matter more than a free user's 10,000th request. Rate limiting lets you encode that business logic.

### The Sticky Metaphor

**Rate limiting is like a traffic light.**

Without traffic lights, every car tries to enter the intersection simultaneously. Result: gridlock. No one moves.

With traffic lights, cars take turns. Each car waits a bit, but everyone eventually gets through. Aggregate throughput actually *increases* because chaos is replaced with order.

Rate limiting doesn't reduce how much you can serve—it increases how much you actually deliver.

---

## The Mechanism

### Building It From Scratch

Let's invent rate limiting from first principles.

**Step 1: Define the limit**

"100 requests per minute per user"

This requires:
- An identifier (who is making requests?)
- A window (over what time period?)
- A threshold (how many requests?)

**Step 2: Track usage**

We need to count requests per identifier.

**Algorithm 1: Fixed Window Counter**

The simplest approach. Divide time into fixed windows and count.

```java
public class FixedWindowRateLimiter {
    private final int maxRequests;
    private final long windowSizeMs;
    private final Map<String, WindowData> windows = new ConcurrentHashMap<>();

    public FixedWindowRateLimiter(int maxRequests, long windowSizeMs) {
        this.maxRequests = maxRequests;
        this.windowSizeMs = windowSizeMs;
    }

    // Why fixed windows: simple to understand and implement
    // Drawback: burst at window boundaries can double effective rate
    public boolean allowRequest(String userId) {
        long currentWindow = System.currentTimeMillis() / windowSizeMs;

        WindowData data = windows.compute(userId, (key, existing) -> {
            if (existing == null || existing.windowId != currentWindow) {
                return new WindowData(currentWindow, 1);
            }
            existing.count++;
            return existing;
        });

        return data.count <= maxRequests;
    }

    private static class WindowData {
        long windowId;
        int count;
        WindowData(long windowId, int count) {
            this.windowId = windowId;
            this.count = count;
        }
    }
}
```

**Problem with Fixed Windows:**

```
Window 1: 00:00 - 01:00    Window 2: 01:00 - 02:00
   │                          │
   │                      ▼───┼───▼
   │                      │100│100│
   └──────────────────────┴───┴───┘
                          At 00:59:59 and 01:00:01
                          200 requests in 2 seconds!
```

A user could send 100 requests at 00:59 and 100 more at 01:01—200 requests in 2 seconds while never "exceeding" the 100/minute limit.

**Algorithm 2: Sliding Window Log**

Track timestamps of all requests. Count how many fall within the sliding window.

```java
public class SlidingWindowLogRateLimiter {
    private final int maxRequests;
    private final long windowSizeMs;
    private final Map<String, Deque<Long>> requestLogs = new ConcurrentHashMap<>();

    // Why sliding log: precise rate limiting, no boundary issues
    // Drawback: memory usage grows with request rate
    public synchronized boolean allowRequest(String userId) {
        long now = System.currentTimeMillis();
        long windowStart = now - windowSizeMs;

        Deque<Long> timestamps = requestLogs.computeIfAbsent(userId, k -> new LinkedList<>());

        // Remove timestamps outside current window
        while (!timestamps.isEmpty() && timestamps.peekFirst() < windowStart) {
            timestamps.pollFirst();
        }

        if (timestamps.size() < maxRequests) {
            timestamps.addLast(now);
            return true;
        }
        return false;
    }
}
```

Precise, but stores every timestamp. Memory-hungry at high volume.

**Algorithm 3: Token Bucket**

Imagine a bucket that holds tokens. Tokens are added at a fixed rate. Each request consumes a token. If the bucket is empty, the request is rejected.

```java
public class TokenBucketRateLimiter {
    private final int bucketCapacity;      // Maximum burst size
    private final double refillRatePerMs;  // Tokens added per millisecond
    private double tokens;
    private long lastRefillTime;

    public TokenBucketRateLimiter(int bucketCapacity, int refillRatePerSecond) {
        this.bucketCapacity = bucketCapacity;
        this.refillRatePerMs = refillRatePerSecond / 1000.0;
        this.tokens = bucketCapacity;  // Start full
        this.lastRefillTime = System.currentTimeMillis();
    }

    // Why token bucket: allows controlled bursts while enforcing average rate
    // The bucket size controls burst tolerance
    // The refill rate controls sustained throughput
    public synchronized boolean allowRequest() {
        refillTokens();

        if (tokens >= 1) {
            tokens -= 1;
            return true;
        }
        return false;
    }

    private void refillTokens() {
        long now = System.currentTimeMillis();
        double tokensToAdd = (now - lastRefillTime) * refillRatePerMs;
        tokens = Math.min(bucketCapacity, tokens + tokensToAdd);
        lastRefillTime = now;
    }
}
```

Token bucket elegantly handles both:
- **Sustained rate**: Controlled by refill rate
- **Burst tolerance**: Controlled by bucket size

**Algorithm 4: Leaky Bucket**

Requests enter a bucket and "leak out" at a fixed rate. If the bucket overflows, requests are rejected.

```
    Requests
        │
        ▼
   ┌─────────┐  ← Bucket has fixed capacity
   │ ● ● ●   │
   │ ● ● ● ● │  ← Requests queue here
   │ ● ● ●   │
   └────┬────┘
        │  ← Requests "leak" out at constant rate
        ▼
     Processing
```

The difference from token bucket: leaky bucket smooths bursts by queuing rather than allowing them.

### Distributed Rate Limiting

What if you have multiple servers? Each needs to share rate limit state.

```java
public class DistributedRateLimiter {
    private final RedisClient redis;
    private final int maxRequests;
    private final int windowSeconds;

    // Why Redis: atomic operations across all servers
    // All servers see same count for each user
    public boolean allowRequest(String userId) {
        String key = "ratelimit:" + userId;

        // Atomic increment and expiry using Lua script
        String script =
            "local current = redis.call('INCR', KEYS[1]) " +
            "if current == 1 then " +
            "  redis.call('EXPIRE', KEYS[1], ARGV[1]) " +
            "end " +
            "return current";

        Long count = redis.eval(script, List.of(key), List.of(String.valueOf(windowSeconds)));
        return count <= maxRequests;
    }
}
```

### What to Return

When rate limiting, communicate clearly:

```http
HTTP/1.1 429 Too Many Requests
Retry-After: 30
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1625097600

{
  "error": "Rate limit exceeded",
  "message": "Please retry after 30 seconds"
}
```

Help clients back off gracefully rather than hammering your servers with retries.

---

## The Trade-offs

### What Do We Sacrifice?

**1. Legitimate traffic may be blocked**

A user with a valid but unusual workload might hit limits. You've traded serving everyone for protecting the majority.

**2. Complexity in distributed systems**

Coordinating rate limits across multiple servers requires shared state. Shared state adds latency and potential inconsistency.

**3. Gaming and unfairness**

Users might create multiple accounts to bypass per-user limits. Rate limiting by IP blocks entire offices behind NAT. There's no perfect identifier.

**4. Cold start and burst issues**

A new user might legitimately need to bootstrap with many requests. Fixed limits don't accommodate variable legitimate needs.

### When NOT To Use This

- **Internal services with trusted callers**: Rate limiting adds latency. If you control both sides, you might prefer other backpressure mechanisms.
- **When fairness isn't the goal**: Some services prioritize throughput over fairness. Rate limiting isn't free.
- **One-time bulk operations**: A legitimate data migration might look like an attack. Provide alternatives for known batch workloads.

### Connection to Other Concepts

- **API Gateway** (Chapter 9): Often implements rate limiting
- **Load Balancing** (Chapter 1): Both protect backend services
- **Message Queues** (Chapter 7): Alternative to rate limiting—queue and process at your own pace
- **Monitoring** (Chapter 19): Essential to tune rate limits correctly

---

## The Evolution

### Brief History

**1970s: Congestion control**

The internet's ancestor (ARPANET) faced congestion. TCP flow control emerged as a way to adaptively rate-limit senders.

**1990s: Web server limits**

Apache and IIS added connection limits. Primitive rate limiting at the server level.

**2000s: API rate limiting**

Twitter API (2006) popularized rate limits as a product feature. "150 requests per hour per user." Developers learned to plan around limits.

**2010s: Sophisticated algorithms**

Netflix's adaptive rate limiting. Google's token bucket implementations. Rate limiting became configurable and intelligent.

**2020s: Edge rate limiting**

Cloudflare, AWS WAF—rate limiting at the network edge before requests even hit your servers.

### Modern Variations

**Adaptive Rate Limiting**

Adjust limits based on system load. Under heavy load, reduce limits. Under light load, be generous.

```java
// Why adaptive: static limits either waste capacity or provide inadequate protection
public int getCurrentLimit() {
    double systemLoad = getSystemLoad();  // 0.0 to 1.0
    if (systemLoad > 0.9) return maxLimit / 4;
    if (systemLoad > 0.7) return maxLimit / 2;
    return maxLimit;
}
```

**Tiered Rate Limiting**

Different limits for different user types:
- Free users: 100 requests/hour
- Paid users: 10,000 requests/hour
- Enterprise: Custom limits

**Request Classification**

Not all requests are equal. Rate limit writes more aggressively than reads. Protect expensive operations more than cheap ones.

### Where It's Heading

**ML-based anomaly detection**: Instead of fixed rules, models learn normal patterns and flag anomalies.

**Client-side rate limiting**: SDKs that prevent clients from even attempting requests they know will fail.

**Cooperative rate limiting**: Clients report their intended usage; servers allocate capacity accordingly.

---

## Interview Lens

### Common Interview Questions

1. **"Design a rate limiter for a distributed system"**
   - Discuss algorithm choice (token bucket vs. sliding window)
   - Address distributed state (Redis, sticky sessions, or approximate)
   - Talk about consistency trade-offs

2. **"How would you rate limit an API gateway?"**
   - Layer rate limits: global, per-tenant, per-user, per-endpoint
   - Discuss how to identify users (API keys, JWT, IP)
   - Handle the "thundering herd" after limit resets

3. **"What are the trade-offs between local and distributed rate limiting?"**
   - Local: Fast, no network hop, but imprecise with multiple servers
   - Distributed: Accurate, but adds latency and Redis dependency
   - Hybrid: Local with periodic sync

### Red Flags (Shallow Understanding)

❌ "Just count requests per second" without discussing algorithms

❌ Ignores distributed consistency problems

❌ Can't explain why token bucket allows bursts

❌ Doesn't mention communicating limits to clients

### How to Demonstrate Deep Understanding

✅ Compare token bucket vs. leaky bucket vs. sliding window with trade-offs

✅ Discuss how to handle clock skew in distributed systems

✅ Mention race conditions in concurrent counter updates

✅ Explain why 429 with Retry-After is better than just dropping requests

✅ Consider the UX of rate limiting—making it transparent to users

---

## Curiosity Hooks

As you progress, ponder these questions:

- Rate limiting is per-user. But how do you identify a user behind a load balancer? (Hint: Chapter 20, AuthN)

- You're rate limiting external API calls. What about rate limiting between your own services? (Hint: Chapter 10, Microservices)

- Rate limiting says "slow down." Message queues say "I'll get to it later." When do you choose which? (Hint: Chapter 7, Message Queues)

- How do you know your rate limits are set correctly? (Hint: Chapter 19, Monitoring)

---

## Summary

**The Problem**: Shared resources can be exhausted by excessive use from any single actor.

**The Insight**: It's better to explicitly reject excess traffic than to implicitly degrade service for everyone. Admission control preserves service quality.

**The Mechanism**: Count requests per user over time windows using algorithms like token bucket or sliding window. Return 429 with retry information when exceeded.

**The Trade-off**: Some legitimate traffic may be blocked in exchange for protecting the system and majority of users.

**The Evolution**: From TCP congestion control → server limits → API rate limits → edge rate limiting → adaptive/ML-based approaches.

**The First Principle**: The goal isn't to maximize requests served—it's to maximize *value* delivered. Sometimes saying "no" delivers more value than struggling to say "yes."

---

*Next: [Chapter 17: Scalability](./17-scalability.md)—where we zoom out and ask the big question: what does it really mean for a system to scale?*
