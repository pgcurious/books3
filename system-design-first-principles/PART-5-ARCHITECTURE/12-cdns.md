# Chapter 12: CDNs (Content Delivery Networks)

> *"The fastest request is one that travels the shortest distance."*
> — Physics, basically

---

## The Fundamental Problem

### Why Does This Exist?

Your startup is in San Francisco. Your servers are in San Francisco. Your users are... everywhere.

A user in Sydney, Australia loads your page. The request travels 12,000 kilometers to San Francisco. The response travels 12,000 kilometers back. At the speed of light, that's 80+ milliseconds of pure physics—before your server even starts processing.

Now multiply by every image, script, and stylesheet. A typical webpage has 50-100 resources. That's 4-8 seconds of latency just from distance.

Meanwhile, a competitor with servers closer to Sydney loads instantly.

The raw, primitive problem is this: **How do you serve content quickly to users who are geographically far from your servers?**

### The Real-World Analogy

Consider how newspapers were distributed before the internet.

The New York Times is written in New York. But they don't print one copy and mail it worldwide. They print at regional facilities: Los Angeles, Chicago, Atlanta, London. Readers get their paper from the nearest facility.

The content is the same. The distribution is local. Readers don't wait for cross-country delivery.

A CDN is regional printing for the internet.

---

## The Naive Solution

### What Would a Beginner Try First?

"Deploy more servers in more locations!"

Run servers in Sydney, London, Tokyo. Users connect to the nearest server.

### Why Does It Break Down?

**1. Operational complexity**

Managing servers in 20 global locations is hard. Different providers, different regulations, different time zones for support.

**2. Data synchronization**

Your database is in San Francisco. Sydney servers still need to query it. You've reduced latency for static content but not for dynamic data.

**3. Cost**

Running full application servers globally is expensive. Most of your server capacity handles static files that rarely change.

**4. Uneven traffic**

Traffic patterns vary by region and time. You're paying for peak capacity in every location.

### The Flawed Assumption

The naive approach assumes **you need your application everywhere**. CDNs recognize that **most content is static and can be cached at the edge**.

---

## The Core Insight

### The "Aha" Moment

Here's the fundamental realization:

> **Static content (images, scripts, videos) is the same for all users and doesn't change frequently. Cache it at locations close to users, and you eliminate distance latency for most requests.**

A CDN is a globally distributed caching layer. Instead of every request traveling to your origin server, most requests are served from a nearby edge server that has a cached copy.

For a typical webpage:
- HTML: 5KB (dynamic, from origin)
- Images, CSS, JS: 2MB (static, from CDN edge)

95%+ of bytes come from static content that can be cached.

### The Trade-off Acceptance

CDNs accept:
- **Cache staleness**: Edge might serve outdated content until cache expires
- **Cost**: CDN services charge per bandwidth
- **Complexity**: Cache invalidation, configuration, debugging
- **Less control**: Content is served by third-party infrastructure

We accept these for dramatically reduced latency and origin server load.

### The Sticky Metaphor

**A CDN is like a franchise business model.**

McDonald's headquarters doesn't ship every burger from Illinois. Instead, franchises around the world make the same burgers locally. The recipe (content) comes from headquarters, but the production (serving) happens locally.

Users get their burgers fast because there's a McDonald's nearby. Headquarters focuses on recipes, not individual burger delivery.

---

## The Mechanism

### How CDNs Work

**Step 1: Content Distribution**

Content is copied from your origin to edge servers worldwide:

```
Origin Server (San Francisco)
            │
    ┌───────┴───────┐
    │   CDN Cloud   │
    │               │
    │  ┌─────────┐  │
    │  │ Origin  │  │
    │  │ Shield  │  │
    │  └────┬────┘  │
    │       │       │
    ├───────┼───────┤
    ▼       ▼       ▼
┌──────┐ ┌──────┐ ┌──────┐
│ Edge │ │ Edge │ │ Edge │
│Sydney│ │London│ │Tokyo │
└──────┘ └──────┘ └──────┘
    ▲       ▲       ▲
    │       │       │
  Users   Users   Users
```

**Step 2: DNS Resolution**

When a user requests your content, DNS routes them to the nearest edge:

```java
// User in Sydney requests: images.example.com/logo.png

// DNS resolution (anycast or geo-based):
// images.example.com → Sydney edge IP (closest)

// Request goes to Sydney edge server, NOT your origin
```

**Step 3: Cache Check**

Edge server checks if it has the content:

```java
public class CDNEdgeServer {
    private final Cache cache;
    private final OriginClient origin;

    public Response handleRequest(Request request) {
        String cacheKey = buildCacheKey(request);

        // Check cache
        CachedContent cached = cache.get(cacheKey);

        if (cached != null && !cached.isExpired()) {
            // Cache HIT—return immediately
            return Response.ok(cached.getContent())
                .header("X-Cache", "HIT");
        }

        // Cache MISS—fetch from origin
        Response originResponse = origin.fetch(request);

        // Cache for future requests
        if (isCacheable(originResponse)) {
            cache.put(cacheKey, originResponse.getContent(), getTTL(originResponse));
        }

        return originResponse.withHeader("X-Cache", "MISS");
    }
}
```

**Step 4: Cache Control**

Your origin controls how long content is cached:

```http
# Origin response headers
Cache-Control: max-age=86400, public  # Cache for 24 hours
ETag: "abc123"                         # Version identifier
```

```java
// Different TTLs for different content types
public class CachePolicy {
    public Duration getTTL(Response response) {
        String contentType = response.getContentType();

        if (contentType.startsWith("image/")) {
            return Duration.ofDays(365);  // Images rarely change
        }
        if (contentType.equals("text/css") || contentType.equals("application/javascript")) {
            return Duration.ofDays(30);   // Versioned assets
        }
        if (contentType.equals("text/html")) {
            return Duration.ofMinutes(5); // HTML might change
        }
        return Duration.ofHours(1);       // Default
    }
}
```

### Cache Invalidation

The hardest problem. When content changes, how do you update all edges?

```java
public class CDNInvalidation {
    private final CDNProvider cdn;

    // Option 1: Purge specific paths
    public void invalidatePath(String path) {
        cdn.purge(path);  // All edges drop this from cache
    }

    // Option 2: Version in URL (cache forever, new version = new URL)
    public String versionedUrl(String basePath, String content) {
        String hash = computeHash(content);
        return basePath + "?v=" + hash;
        // /styles.css?v=abc123
        // When content changes, hash changes, URL changes
    }

    // Option 3: Surrogate keys / cache tags
    public void invalidateByTag(String tag) {
        cdn.purgeByTag(tag);  // Purge all content with this tag
        // Tag "product-123" invalidates all assets for that product
    }
}
```

### Edge Computing

Modern CDNs run code at the edge, not just cache content:

```javascript
// Cloudflare Worker / Lambda@Edge
// Runs at edge locations, not origin

addEventListener('fetch', event => {
    event.respondWith(handleRequest(event.request));
});

async function handleRequest(request) {
    // A/B testing at the edge
    const variant = Math.random() < 0.5 ? 'A' : 'B';

    // Personalization at the edge
    const country = request.cf.country;

    // Modify request before hitting origin
    const modifiedRequest = new Request(request.url + `?variant=${variant}&country=${country}`);

    return fetch(modifiedRequest);
}
```

### CDN Architecture Layers

```
                    User Request
                         │
                         ▼
┌─────────────────────────────────────────────────┐
│              Edge Locations (PoPs)               │
│   200+ locations worldwide                       │
│   Handle most requests from cache               │
└───────────────────────┬─────────────────────────┘
                        │ Cache Miss
                        ▼
┌─────────────────────────────────────────────────┐
│              Regional Shields                    │
│   Consolidates requests to origin               │
│   Reduces origin load from cache misses         │
└───────────────────────┬─────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────┐
│              Origin Server                       │
│   Your actual servers                           │
│   Sees minimal traffic (cache hits don't reach) │
└─────────────────────────────────────────────────┘
```

---

## The Trade-offs

### What Do We Sacrifice?

**1. Cache staleness**

Users might see outdated content until cache expires or is invalidated.

**2. Cost complexity**

CDN pricing (per GB, per request) can be unpredictable with traffic spikes.

**3. Debugging difficulty**

Issues might be edge-specific. "It works from here but not from Tokyo."

**4. Dynamic content limitations**

CDNs excel at static content. Dynamic, personalized content is harder to cache.

### When NOT To Use This

- **Purely dynamic content**: If every response is unique, caching doesn't help.
- **Small, localized user base**: All users in one region? CDN adds complexity without benefit.
- **Low traffic**: CDN costs might exceed hosting costs for small sites.
- **Sensitive data**: Caching private data at edges introduces security considerations.

### Connection to Other Concepts

- **Caching** (Chapter 2): CDN is geographically distributed caching
- **Load Balancing** (Chapter 1): CDNs balance load across edges
- **Scalability** (Chapter 17): CDNs scale content delivery without scaling origin

---

## The Evolution

### Brief History

**1998: Akamai founded**

First commercial CDN. Solved the "flash crowd" problem (traffic spikes).

**2000s: CDN maturity**

Video streaming drove adoption. Netflix, YouTube couldn't exist without CDNs.

**2010s: Commoditization**

Cloudflare, Fastly, AWS CloudFront. CDN became affordable for everyone.

**2020s: Edge computing**

CDNs evolved from dumb caches to programmable edge platforms.

### Modern CDN Capabilities

**Dynamic Site Acceleration (DSA)**

Optimize even non-cacheable content through route optimization and connection reuse.

**DDoS Protection**

CDN absorbs attack traffic, protecting origin.

**Web Application Firewall (WAF)**

Security rules at the edge, blocking malicious requests before they reach origin.

**Image Optimization**

Automatic resizing, format conversion (WebP), compression at the edge.

```
Original: /images/photo.jpg
CDN serves: /images/photo.jpg?w=300&format=webp
            ↑ Transformed at edge, cached per variant
```

### Where It's Heading

**Full-stack edge**: Run entire applications at the edge (databases, compute, everything).

**AI at the edge**: ML inference at edge locations for real-time personalization.

**Private CDNs**: Build your own edge network for specific use cases.

---

## Interview Lens

### Common Interview Questions

1. **"How does a CDN work?"**
   - Distributed cache servers (edge/PoP)
   - DNS routes users to nearest edge
   - Edge serves from cache or fetches from origin
   - Cache-Control headers determine TTL

2. **"How do you handle cache invalidation?"**
   - TTL-based expiration
   - Explicit purge API
   - Version in URLs (cache busting)
   - Surrogate keys for grouped invalidation

3. **"When wouldn't you use a CDN?"**
   - Purely dynamic/personalized content
   - Small, localized user base
   - Low traffic volumes
   - Highly sensitive data

### Red Flags (Shallow Understanding)

❌ "CDN just makes things faster" (missing: how)

❌ Doesn't mention cache invalidation challenges

❌ Can't explain when NOT to use CDN

❌ Thinks CDN is only for images

### How to Demonstrate Deep Understanding

✅ Explain DNS and anycast routing to edges

✅ Discuss Cache-Control headers and TTL strategies

✅ Mention origin shield for reducing origin load

✅ Know about edge computing capabilities

✅ Discuss cache invalidation strategies

---

## Summary

**The Problem**: Users far from your servers experience high latency due to physical distance. Speed of light is a hard limit.

**The Insight**: Most content is static and can be cached. Place caches close to users worldwide, and you eliminate distance latency for most requests.

**The Mechanism**: Distributed edge servers caching content, DNS routing to nearest edge, Cache-Control headers managing TTL, invalidation for updates.

**The Trade-off**: Cache staleness and complexity for dramatic latency reduction and origin load reduction.

**The Evolution**: From content caching → full application delivery → edge computing platforms.

**The First Principle**: The fastest request is one that doesn't travel far. CDNs bring your content to where your users already are.

---

*Next: We move to Part 6—Operations. Starting with [Chapter 19: Monitoring](../PART-6-OPERATIONS/19-monitoring.md)—where we learn that you can't fix what you can't see.*
