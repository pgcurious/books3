# Chapter 8: DNS—The Internet's Phone Book

## How We Made Addresses Human-Readable

---

> *"There are only two hard things in Computer Science: cache invalidation and naming things."*
> — Phil Karlton

---

## The Frustration

It's 1982. The internet is growing rapidly. To connect to a computer, you need its IP address: `10.0.0.51`. But you also want to connect to the file server, the mail server, and the new research computer across campus.

You can't remember these numbers. No one can. You keep a notepad with names and addresses.

But what happens when someone adds a new computer? Or an address changes? You need to update your notes. So does everyone else.

The early ARPANET solution was a single file—HOSTS.TXT—maintained at Stanford Research Institute. Everyone periodically downloaded the latest version. It listed every computer on the entire network.

This worked when there were a few hundred hosts. By 1982, there were thousands. The file was huge. Updates were slow. Conflicts were common. The system was collapsing.

## The World Before DNS

HOSTS.TXT was simple:

```
# HOSTS.TXT
10.0.0.51    SRI-NIC
10.0.0.73    MIT-AI
10.0.0.77    UCLA-SECURITY
10.2.0.52    USC-ISIB
```

Problems emerged:

**Centralization**: One organization controlled all names. Bottleneck.

**Slow updates**: Changed your name? Wait for the weekly update. Hope it propagated.

**No hierarchy**: Every name was global. Conflicts inevitable.

**Traffic**: Everyone downloading the same growing file.

**Consistency**: Different sites had different versions.

## The Insight: Distributed, Hierarchical Naming

DNS (Domain Name System) solved this with two key ideas:

### 1. Hierarchical Namespace

Instead of flat names, use a tree structure:

```
                    .  (root)
                    │
        ┌───────────┼───────────┐
        │           │           │
       com         org          edu
        │           │           │
    ┌───┴───┐       │      ┌────┴────┐
    │       │       │      │         │
  google   amazon  wiki   mit      stanford
    │       │       │      │         │
   www     www     www    web       www
```

`www.google.com` means:
- Start at root (.)
- Go to `com`
- Go to `google`
- Find `www`

Each level can be managed independently.

### 2. Distributed Authority

No single organization controls everything:

```
ICANN controls: root zone, top-level domains
Verisign controls: .com, .net
MIT controls: mit.edu
Google controls: google.com

Each authority manages its piece of the tree.
```

This is **delegation**. The root knows where to find `.com`. `.com` knows where to find `google.com`. `google.com` knows where to find `www.google.com`.

## How DNS Resolution Works

When you type `www.google.com`:

```
Step 1: Ask local resolver (your ISP or 8.8.8.8)
        "What's www.google.com?"

Step 2: Resolver asks root server
        "Where's .com?"
        Root: "Ask Verisign at 192.5.6.30"

Step 3: Resolver asks .com server
        "Where's google.com?"
        .com: "Ask Google's nameserver at 216.239.32.10"

Step 4: Resolver asks Google's nameserver
        "What's www.google.com?"
        Google: "142.250.80.46"

Step 5: Resolver returns result to you
        And caches it for next time

Your browser connects to 142.250.80.46
```

In practice, most of these results are cached. A warm cache resolves in milliseconds.

## DNS Record Types

DNS doesn't just map names to addresses:

### A Record (Address)
Maps a name to an IPv4 address.
```
www.google.com → 142.250.80.46
```

### AAAA Record (IPv6 Address)
Maps a name to an IPv6 address.
```
www.google.com → 2607:f8b0:4004:800::200e
```

### CNAME (Canonical Name)
Alias one name to another.
```
mail.google.com → googlemail.l.google.com
```

### MX (Mail Exchange)
Where to deliver email for a domain.
```
google.com mail → smtp.google.com (priority 10)
```

### TXT (Text)
Arbitrary text, often used for verification.
```
google.com → "v=spf1 include:_spf.google.com ~all"
```

### NS (Name Server)
Which servers are authoritative for a domain.
```
google.com NS → ns1.google.com, ns2.google.com
```

## Why DNS Uses UDP (Mostly)

DNS primarily uses UDP for several reasons:

```
DNS query: ~50 bytes
DNS response: ~100-500 bytes
TCP handshake: 3 packets, minimum ~150 bytes overhead

For tiny messages, TCP overhead dominates.
```

UDP is perfect:
- No connection setup
- Simple request-response
- Server is stateless
- Low latency

DNS falls back to TCP when:
- Response is too large (>512 bytes, modern: >1232)
- Zone transfers (full database copies between servers)
- DNSSEC signatures (can be large)

## Caching: The Performance Secret

DNS would be slow if every query walked the hierarchy. Caching makes it fast:

### TTL (Time To Live)
Every DNS record has a TTL—how long it can be cached:

```
google.com A 142.250.80.46  TTL: 300 (5 minutes)
gov.uk A 151.101.0.144      TTL: 600 (10 minutes)
example.com A 93.184.216.34 TTL: 86400 (1 day)
```

Trade-off:
- Short TTL: Changes propagate quickly, more queries
- Long TTL: Fewer queries, changes propagate slowly

### Cache Hierarchy
```
Your browser cache
    ↓ miss
Your OS cache
    ↓ miss
Your router cache
    ↓ miss
Your ISP resolver cache
    ↓ miss
Authoritative query
```

Most queries are answered from cache. Fresh authoritative queries are rare.

## DNS Security: The Original Flaw

DNS was designed when the internet was trusted. It has no built-in authentication:

### DNS Spoofing
An attacker responds faster than the real server:
```
You: "What's bank.com?"
Attacker (fast): "192.168.1.100" (attacker's server)
Real server (slow): "151.101.1.57"

Your browser goes to the attacker.
```

### Cache Poisoning
An attacker poisons the resolver's cache:
```
If an attacker can get bad data into your ISP's cache,
everyone using that ISP gets poisoned responses.
```

### Solutions

**DNSSEC (DNS Security Extensions)**
Cryptographic signatures on DNS records:
```
google.com A 142.250.80.46
RRSIG: [cryptographic signature]

Resolver can verify the response is authentic.
```

DNSSEC adoption is incomplete. Many domains don't sign. Many resolvers don't validate.

**DNS over HTTPS (DoH) / DNS over TLS (DoT)**
Encrypts DNS queries:
```
Traditional: Query and response are plaintext
DoH: Query is encrypted inside HTTPS
DoT: Query is encrypted inside TLS

Prevents eavesdropping and tampering in transit.
```

## The Principle

> **DNS solved the naming problem with hierarchy (scaling ownership) and distribution (scaling performance). Every major internet service depends on DNS working correctly.**

DNS is so fundamental that its failure takes down everything. If DNS breaks, you can't reach websites, send email, or use most internet services—even if all other infrastructure is fine.

## DNS Beyond Names

DNS has evolved beyond simple name resolution:

### Load Balancing
Return different addresses to distribute traffic:
```
google.com → 142.250.80.46 (30% of queries)
google.com → 142.250.80.14 (30% of queries)
google.com → 142.250.80.78 (40% of queries)
```

### CDN Routing
Return addresses of nearby servers:
```
From US: example.com → 192.0.2.1 (US server)
From EU: example.com → 192.0.2.2 (EU server)
```

### Service Discovery
Find services in microservices architectures:
```
_http._tcp.example.com SRV → server1:8080, server2:8080
```

### Email Security
SPF, DKIM, DMARC records prove email authenticity:
```
example.com TXT "v=spf1 ip4:192.0.2.0/24 -all"
```

## The Tradeoffs

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| Hierarchical | Scalable administration | Complexity |
| Caching | Performance | Stale data risk |
| UDP default | Low latency | Size limits, no connection |
| Decentralized | Resilience | Coordination challenges |
| No auth (original) | Simplicity | Security vulnerabilities |

## Why DNS Matters Today

Understanding DNS helps you understand:

- **Why propagation takes time**: TTL and caches
- **Why outages cascade**: DNS failure breaks everything
- **Why CDNs work**: DNS-based routing
- **Why email is spam-resistant**: DNS-based verification
- **Why HTTPS matters**: DNS can be spoofed without it
- **Why DNS privacy is a thing**: Your queries reveal your browsing

---

## Summary

- DNS replaced flat, centralized naming with hierarchical, distributed naming
- Resolution walks the hierarchy: root → TLD → domain → record
- UDP is used for efficiency; TCP for large responses
- Caching with TTL makes DNS fast
- Original DNS has security flaws; DNSSEC and DoH address them
- DNS is used for far more than name resolution

---

*DNS tells us where to connect. But how do we talk once we get there? That's where HTTP comes in—our next chapter.*
