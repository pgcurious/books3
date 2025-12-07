# Design a System from Scratch

> *"In theory, there is no difference between theory and practice. In practice, there is."*
> — Attributed to various

---

## Putting It All Together

This chapter walks through designing a complete system, applying all 20 concepts we've learned. We'll design a **URL shortener like bit.ly**—a classic system design problem that touches every concept.

---

## The Problem Statement

Build a URL shortening service that:
- Takes a long URL and returns a short one
- Redirects short URL visitors to the original URL
- Tracks click analytics
- Handles millions of URLs and billions of clicks
- Works globally with low latency

---

## Step 1: Clarify Requirements

Before architecture, understand constraints:

### Functional Requirements
- Create short URL from long URL
- Redirect short URL to long URL
- Track clicks (optional: analytics dashboard)
- Custom short URLs (optional)
- Expiration (optional)

### Non-Functional Requirements
- **Scale**: 100M URLs created/month, 10B redirects/month
- **Latency**: Redirects in <100ms p99
- **Availability**: 99.99% (52 minutes downtime/year)
- **Durability**: URLs must never be lost

### Back-of-the-Envelope Estimates

```
URLs created: 100M/month ≈ 40/second
Redirects: 10B/month ≈ 4000/second (read-heavy!)

Read:Write ratio = 4000:40 = 100:1 → Cache heavily!

Storage (5 years):
- 100M URLs/month × 12 months × 5 years = 6B URLs
- Each URL: ~500 bytes (short + long URL + metadata)
- Total: 6B × 500 bytes ≈ 3TB

Short URL length:
- 6 characters, base62: 62^6 = 56.8B combinations → plenty for 6B URLs
```

---

## Step 2: High-Level Architecture

Start with the basics, then add concepts:

```
┌─────────────────────────────────────────────────────────────────────┐
│                          USERS                                       │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                           CDN (12)                                   │
│   • Cache redirects at edge                                          │
│   • Serve static assets (dashboard)                                  │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      API Gateway (9)                                 │
│   • Rate limiting (8) per user/IP                                    │
│   • Authentication (20) for API access                               │
│   • Route: /create → URL Service, /{shortUrl} → Redirect Service    │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
              ┌──────────────────┴──────────────────┐
              ▼                                     ▼
┌───────────────────────────┐         ┌───────────────────────────┐
│      URL Service          │         │    Redirect Service        │
│   • Generate short URL    │         │   • Lookup & redirect      │
│   • Validate custom URLs  │         │   • Record click event     │
└───────────┬───────────────┘         └─────────────┬─────────────┘
            │                                       │
            │                                       │
            ▼                                       ▼
┌───────────────────────────┐         ┌───────────────────────────┐
│        URL Cache (2)       │         │    Analytics Queue (7)     │
│   (Redis)                 │         │   (Kafka)                  │
└───────────┬───────────────┘         └─────────────┬─────────────┘
            │                                       │
            ▼                                       ▼
┌───────────────────────────┐         ┌───────────────────────────┐
│    URL Database (3,4)      │         │   Analytics Service        │
│   • Sharded by short URL  │         │   • Aggregate clicks       │
│   • Replicated for reads  │         │   • Store in time-series DB│
└───────────────────────────┘         └───────────────────────────┘
```

---

## Step 3: Deep Dive - Each Component

### Short URL Generation

**Options:**

1. **Counter-based**: Auto-increment ID, base62 encode
2. **Hash-based**: Hash the long URL, take first N chars
3. **Random**: Generate random string, check for collision

```java
// Option 1: Counter-based (needs coordination)
public class CounterBasedGenerator {
    private final AtomicLong counter;

    public String generateShortUrl() {
        long id = counter.incrementAndGet();
        return base62Encode(id);  // 1 → "1", 62 → "10", etc.
    }

    private String base62Encode(long num) {
        StringBuilder sb = new StringBuilder();
        while (num > 0) {
            sb.append(BASE62_CHARS.charAt((int)(num % 62)));
            num /= 62;
        }
        return sb.reverse().toString();
    }
}
```

**Challenge**: Counter needs coordination across servers.

**Solution**: Use distributed ID generator (Twitter Snowflake pattern):

```java
// Snowflake: 64-bit ID = timestamp + datacenter + machine + sequence
public class SnowflakeGenerator {
    private final long datacenterId;
    private final long machineId;
    private long sequence = 0;
    private long lastTimestamp = -1;

    public synchronized long nextId() {
        long timestamp = System.currentTimeMillis();

        if (timestamp == lastTimestamp) {
            sequence = (sequence + 1) & 0xFFF;  // 12 bits = 4096 per ms
            if (sequence == 0) {
                timestamp = waitNextMillis(timestamp);
            }
        } else {
            sequence = 0;
        }

        lastTimestamp = timestamp;

        return ((timestamp - EPOCH) << 22)
             | (datacenterId << 17)
             | (machineId << 12)
             | sequence;
    }
}
```

### Database Design

**Schema:**

```sql
-- URL mapping table
CREATE TABLE url_mappings (
    short_url VARCHAR(10) PRIMARY KEY,
    long_url TEXT NOT NULL,
    user_id VARCHAR(36),
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP,
    click_count BIGINT DEFAULT 0
);

-- Sharding key: short_url (random distribution)
-- Consistent hashing (6) to determine shard
```

**Why shard by short_url?**
- Redirects (main traffic) lookup by short_url → single shard
- Even distribution (short URLs are random)

**Replication (Chapter 4):**
- Each shard has 3 replicas
- Primary for writes
- Replicas for reads (redirect is read-heavy)

### Caching Strategy (Chapter 2)

```java
public class RedirectService {
    private final Cache<String, String> urlCache;  // Redis
    private final UrlRepository database;

    public String getLongUrl(String shortUrl) {
        // Check cache first
        String cached = urlCache.get(shortUrl);
        if (cached != null) {
            return cached;
        }

        // Cache miss → database
        String longUrl = database.findLongUrl(shortUrl);
        if (longUrl == null) {
            throw new NotFoundException();
        }

        // Populate cache (24h TTL)
        urlCache.put(shortUrl, longUrl, Duration.ofHours(24));
        return longUrl;
    }
}
```

**Cache size estimate:**
- Hot URLs (20% accessed 80% of time) = 1.2B URLs
- Store short→long mapping: ~200 bytes each
- Hot data cache: ~240GB (distributed Redis cluster)

### Analytics Pipeline (Chapters 7, 15)

Clicks happen at 4000/second. Recording synchronously would be slow and risk data loss.

```java
public class RedirectService {
    private final MessageQueue analyticsQueue;

    public Response redirect(String shortUrl, HttpRequest request) {
        String longUrl = getLongUrl(shortUrl);

        // Async analytics - don't block redirect
        analyticsQueue.publish(new ClickEvent(
            shortUrl,
            Instant.now(),
            request.getHeader("User-Agent"),
            request.getRemoteAddress(),
            request.getHeader("Referer")
        ));

        return Response.redirect(longUrl);
    }
}

// Consumers aggregate and store
public class AnalyticsConsumer {
    @KafkaListener(topics = "clicks")
    public void processClick(ClickEvent event) {
        // Batch updates to time-series DB
        analyticsDb.incrementClick(event.getShortUrl(), event.getTimestamp());
        analyticsDb.recordMetadata(event);
    }
}
```

### Global Distribution (Chapter 12 - CDNs)

Users are worldwide. Redirect latency matters.

```
Americas                  Europe                    Asia-Pacific
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│  CDN Edge       │      │  CDN Edge       │      │  CDN Edge       │
│  (Cache-hit:    │      │  (Cache-hit:    │      │  (Cache-hit:    │
│   redirect in   │      │   redirect in   │      │   redirect in   │
│   <10ms)        │      │   <10ms)        │      │   <10ms)        │
└────────┬────────┘      └────────┬────────┘      └────────┬────────┘
         │                        │                        │
         └────────────────────────┼────────────────────────┘
                                  │
                                  ▼
                         Origin (cache miss)
```

CDN can cache redirects! Configure:
```
Cache-Control: public, max-age=86400
```

Most popular URLs served entirely from edge.

### Rate Limiting (Chapter 8)

Prevent abuse:

```java
public class RateLimitFilter {
    private final RateLimiter limiter;  // Redis-based

    public void filter(Request request) {
        String key = getUserIdOrIp(request);

        // Different limits for different operations
        if (request.isCreate()) {
            if (!limiter.allow(key + ":create", 100, Duration.ofHour())) {
                throw new TooManyRequestsException("100 URLs/hour limit");
            }
        } else {
            // Redirects: higher limit
            if (!limiter.allow(key + ":redirect", 10000, Duration.ofMinute())) {
                throw new TooManyRequestsException();
            }
        }
    }
}
```

### Service Discovery (Chapter 11)

In Kubernetes:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: url-service
spec:
  selector:
    app: url-service
  ports:
    - port: 80

---
# Other services call: http://url-service/api/...
# Kubernetes DNS handles discovery
```

### Monitoring (Chapter 19)

Key metrics to track:

```java
// RED metrics for each service
Counter redirectsTotal = Counter.builder("redirects_total")
    .tag("status", "success|notfound|error")
    .register(registry);

Timer redirectLatency = Timer.builder("redirect_latency")
    .publishPercentiles(0.5, 0.95, 0.99)
    .register(registry);

// Business metrics
Counter urlsCreated = Counter.builder("urls_created_total")
    .register(registry);

Gauge cacheHitRatio = Gauge.builder("cache_hit_ratio")
    .register(registry);
```

### Fault Tolerance (Chapter 18)

What happens when things fail?

```java
public class ResilientRedirectService {
    private final CircuitBreaker dbCircuitBreaker;
    private final Cache<String, String> cache;

    public String getLongUrl(String shortUrl) {
        // Try cache
        String cached = cache.get(shortUrl);
        if (cached != null) return cached;

        // Try database with circuit breaker
        return dbCircuitBreaker.execute(
            () -> database.findLongUrl(shortUrl),
            () -> {
                // Fallback: return error page with retry suggestion
                throw new ServiceUnavailableException("Please try again");
            }
        );
    }
}
```

---

## Step 4: Addressing Non-Functional Requirements

### Scalability (Chapter 17)

| Component | Scaling Strategy |
|-----------|------------------|
| API Gateway | Horizontal + Auto-scaling |
| URL Service | Horizontal (stateless) |
| Redirect Service | Horizontal (stateless) |
| Cache | Redis Cluster (scale horizontally) |
| Database | Sharding + Read replicas |
| Analytics | Kafka partitions + Consumer groups |

### Availability (Chapter 18, CAP)

- Multiple AZs within each region
- Database: Multi-AZ replication
- Cache: Redis Sentinel or Cluster for failover
- Stateless services: Easy to replace

**Consistency trade-off:**
- URL creation: Strong consistency (can't create duplicates)
- Analytics: Eventual consistency (batch processing is fine)
- Redirects: Read from replica okay (data doesn't change often)

### Security (Chapter 20)

```java
// API key authentication for URL creation
public class AuthFilter {
    public void filter(Request request) {
        if (request.isCreate()) {
            String apiKey = request.getHeader("X-API-Key");
            if (!apiKeyService.validate(apiKey)) {
                throw new UnauthorizedException();
            }
        }
        // Redirects don't require auth
    }
}

// Validate URLs to prevent malicious redirects
public class UrlValidator {
    public void validate(String url) {
        if (url.contains("javascript:")) throw new InvalidUrlException();
        if (isKnownMaliciousDomain(url)) throw new BlockedUrlException();
        // ... more checks
    }
}
```

---

## Step 5: The Final Architecture

```
┌────────────────────────────────────────────────────────────────────────────┐
│                             GLOBAL USERS                                    │
└────────────────────────────────────┬───────────────────────────────────────┘
                                     │
        ┌────────────────────────────┴────────────────────────────┐
        │                    EDGE LAYER                            │
        │  ┌────────────┐  ┌────────────┐  ┌────────────┐         │
        │  │ CDN Edge   │  │ CDN Edge   │  │ CDN Edge   │  ...    │
        │  │ Americas   │  │ Europe     │  │ Asia       │         │
        │  └──────┬─────┘  └──────┬─────┘  └──────┬─────┘         │
        └─────────┼───────────────┼───────────────┼───────────────┘
                  │               │               │
                  └───────────────┼───────────────┘
                                  │ Origin (cache miss)
                                  ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                         APPLICATION LAYER                                   │
│                                                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                       API Gateway Cluster                            │  │
│  │   • Authentication  • Rate Limiting  • Request Routing              │  │
│  └────────────────────────────────┬────────────────────────────────────┘  │
│                                   │                                        │
│           ┌───────────────────────┼───────────────────────┐               │
│           ▼                       ▼                       ▼               │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐       │
│  │  URL Service    │    │Redirect Service │    │Analytics Service│       │
│  │  (Create URLs)  │    │ (301 Redirect)  │    │ (Aggregate data)│       │
│  └────────┬────────┘    └────────┬────────┘    └────────┬────────┘       │
│           │                      │                      │                 │
└───────────┼──────────────────────┼──────────────────────┼─────────────────┘
            │                      │                      │
┌───────────┼──────────────────────┼──────────────────────┼─────────────────┐
│           │               DATA LAYER                    │                 │
│           ▼                      ▼                      ▼                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐       │
│  │  Redis Cluster  │    │  Kafka Cluster  │    │ Time-Series DB  │       │
│  │    (Cache)      │    │  (Click events) │    │  (Analytics)    │       │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘       │
│           │                                                               │
│           ▼                                                               │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                    Sharded PostgreSQL Cluster                       │  │
│  │   ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐              │  │
│  │   │ Shard 0 │  │ Shard 1 │  │ Shard 2 │  │ Shard 3 │    ...       │  │
│  │   │ Primary │  │ Primary │  │ Primary │  │ Primary │              │  │
│  │   │ Replica │  │ Replica │  │ Replica │  │ Replica │              │  │
│  │   │ Replica │  │ Replica │  │ Replica │  │ Replica │              │  │
│  │   └─────────┘  └─────────┘  └─────────┘  └─────────┘              │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Step 6: Interview Presentation

When presenting in an interview:

1. **Start with requirements** (2 min)
   - Clarify functional and non-functional requirements
   - Do back-of-envelope math

2. **Draw high-level architecture** (5 min)
   - Start simple, add components as you explain them
   - Show the request flow

3. **Deep dive into critical paths** (10 min)
   - URL generation strategy
   - Database sharding approach
   - Caching strategy
   - Analytics pipeline

4. **Address non-functional requirements** (5 min)
   - Scalability approach
   - Availability and failure handling
   - Security considerations

5. **Trade-offs and alternatives** (3 min)
   - Acknowledge what you're trading
   - Discuss alternatives you considered

**Key phrases:**
- "Given the read:write ratio of 100:1, we should cache aggressively..."
- "For availability, we'll use multi-AZ deployment..."
- "The trade-off here is consistency vs. latency..."
- "An alternative would be... but I chose X because..."

---

## Summary

This exercise touched nearly every concept:

| Concept | Application |
|---------|-------------|
| Load Balancing | Distribute across service instances |
| Caching | Redis for URL mappings |
| Sharding | Database split by short URL |
| Replication | Read replicas for redirects |
| CAP | Strong for creates, eventual for analytics |
| Consistent Hashing | Shard selection |
| Message Queues | Analytics event stream |
| Rate Limiting | Prevent abuse |
| API Gateway | Entry point, auth, routing |
| Microservices | Separate URL, Redirect, Analytics services |
| Service Discovery | Kubernetes DNS |
| CDN | Edge caching for redirects |
| DB Indexing | Primary key on short_url |
| Partitioning | By short_url for locality |
| Eventual Consistency | Analytics aggregation |
| Scalability | Horizontal scaling strategy |
| Fault Tolerance | Circuit breakers, replicas |
| Monitoring | Metrics, logs, traces |
| AuthN & AuthZ | API keys for creation |

**This is system design**: not applying one concept, but weaving all of them together into a coherent solution that meets requirements within constraints.

---

*Now go practice with other problems: Design Twitter, Design Netflix, Design Uber. Apply the same first-principles approach, use the checklist, and connect all the concepts.*
