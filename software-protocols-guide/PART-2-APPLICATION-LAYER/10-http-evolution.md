# Chapter 10: HTTP/2 and HTTP/3—Evolution

## Making the Web Faster Without Changing URLs

---

> *"The best protocol is invisible. It just works, faster."*
> — Ilya Grigorik

---

## The Frustration

By 2010, the web had a performance problem. Pages contained hundreds of resources: HTML, CSS, JavaScript, images, fonts. HTTP/1.1 required a new request for each resource, and browsers limited connections per domain.

Developers invented workarounds:

- **Spriting**: Combine multiple images into one to reduce requests
- **Inlining**: Embed CSS and JavaScript in HTML
- **Domain sharding**: Spread resources across domains to open more connections
- **Concatenation**: Bundle all JavaScript into one file

These hacks made code harder to maintain, caching less effective, and development more complex. We were fighting the protocol instead of using it.

## The World Before HTTP/2

A typical HTTP/1.1 page load:

```
Browser opens connection 1 to example.com
    Request: index.html → Wait → Response
    Request: style.css → Wait → Response
    Request: app.js → Wait → Response
    ...

Browser opens connections 2-6 to example.com
    More requests in parallel...

Browser opens connections to cdn.example.com
    Even more parallel requests...

Each request waits for its predecessor on the same connection.
Browsers work around this with multiple connections.
```

Six connections per domain was the limit. More domains helped, but DNS lookups and TLS handshakes added latency.

## HTTP/2: The SPDY Legacy

HTTP/2 grew from Google's SPDY experiment. Key insight: we can make HTTP faster without changing its semantics.

```
HTTP/1.1:
"I'll send you requests, one at a time, as text."

HTTP/2:
"I'll send you requests, multiplexed, as binary frames."

Same methods. Same headers. Same URLs.
Completely different wire format.
```

### Binary Framing

HTTP/2 is binary, not text:

```
HTTP/1.1 (text):
GET /index.html HTTP/1.1\r\n
Host: example.com\r\n
Accept: text/html\r\n
\r\n

HTTP/2 (binary):
[Length][Type][Flags][Stream ID][Payload]

Humans can't read it. Parsers love it.
```

Binary framing enables:
- Precise message boundaries (no chunked encoding)
- More efficient parsing
- Smaller messages (header compression)

### Multiplexing

Multiple streams share one connection:

```
HTTP/1.1:
Connection 1: GET /a → [wait] → Response a
Connection 2: GET /b → [wait] → Response b
Connection 3: GET /c → [wait] → Response c

HTTP/2:
Connection:
  Stream 1: GET /a →
  Stream 3: GET /b →
  Stream 5: GET /c →
  [frames from a, b, c interleaved]
  → Response a, b, c (as they complete)
```

One connection, unlimited streams. No head-of-line blocking between streams.

### Header Compression

HTTP headers are repetitive:

```
Request 1:
Host: example.com
User-Agent: Mozilla/5.0...
Accept: text/html...
Cookie: session=abc123...

Request 2:
Host: example.com          ← Same
User-Agent: Mozilla/5.0... ← Same
Accept: text/html...       ← Same
Cookie: session=abc123...  ← Same
```

HTTP/2's HPACK compression:

```
Request 1: Full headers (once)
Request 2: "Same as before, but path=/page2"
Request 3: "Same as before, but path=/page3"

Headers compressed by 80-90% typically.
```

### Server Push

The server can send resources before they're requested:

```
Browser: GET /index.html

Server: Here's index.html.
        I know you'll need style.css, pushing it now.
        I know you'll need app.js, pushing it now.

Browser: Receives index.html, style.css, app.js
         (didn't have to request CSS and JS)
```

This eliminates round trips. However, server push is rarely used in practice—it's hard to get right without pushing resources the browser already has cached.

### Stream Prioritization

Not all resources are equal:

```
CSS: High priority (blocks rendering)
JavaScript: Medium priority
Images: Lower priority

HTTP/2 lets browsers express these priorities.
Servers can respect them when scheduling responses.
```

## The TCP Problem Remains

HTTP/2 fixed HTTP's problems but couldn't fix TCP's.

**Head-of-line blocking at TCP level:**
```
Stream 1: [A][B][C]
Stream 3: [D][E][F]
Stream 5: [G][H][I]

TCP sees: [A][B][C][D][E][F][G][H][I]

If packet C is lost:
- TCP blocks until C is retransmitted
- Streams 3 and 5 wait even though they don't need C
```

All HTTP/2 streams share one TCP connection. TCP's ordered delivery blocks all streams when any packet is lost.

## HTTP/3: QUIC to the Rescue

HTTP/3 is HTTP over QUIC. We covered QUIC in detail earlier; here's how it changes HTTP:

### Independent Streams
Each QUIC stream is independent:

```
QUIC Stream 1: [A][B][X lost][D]  → Stream 1 waits
QUIC Stream 3: [E][F][G][H]       → Delivered immediately
QUIC Stream 5: [I][J][K][L]       → Delivered immediately

Only stream 1 is affected by stream 1's loss.
```

### 0-RTT Connection Establishment
```
HTTP/2 (TCP+TLS):
1. TCP SYN
2. TCP SYN-ACK
3. TCP ACK + TLS ClientHello
4. TLS ServerHello + data
   ... more TLS ...
Total: 2-3 round trips

HTTP/3 (QUIC):
1. ClientHello + first request
2. Response
Total: 0-1 round trips (0-RTT for resumed connections)
```

### Connection Migration
```
On WiFi: Connected to server, streaming video
Walk outside: Phone switches to cellular
HTTP/2: Connection dies, reconnect, buffer empty
HTTP/3: Connection continues, uninterrupted
```

## Adoption and Coexistence

All three versions coexist:

```
Client: "I support HTTP/1.1, HTTP/2, HTTP/3"
Server: "Let's use HTTP/3"
...or...
Server: "I only support HTTP/1.1, let's use that"
```

This happens via:

**ALPN (Application-Layer Protocol Negotiation)**: During TLS handshake, negotiate protocol version.

**Alt-Svc header**: Server tells client "I'm also available via HTTP/3 at this address."

```
HTTP/2 response:
Alt-Svc: h3=":443"; ma=86400

Browser: "Next request, I'll try HTTP/3"
```

Fallback is always available. If HTTP/3 fails, try HTTP/2. If that fails, HTTP/1.1.

## The Tradeoffs of Evolution

### HTTP/2

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| Binary format | Efficiency, precise framing | Human debuggability |
| Multiplexing | One connection, many streams | Complex implementation |
| Header compression | Less bandwidth | Stateful (connection-specific) |
| TCP based | Easy deployment | TCP head-of-line blocking |

### HTTP/3

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| QUIC/UDP | No TCP HOL blocking, 0-RTT | UDP may be blocked/deprioritized |
| Userspace | Fast iteration, easy updates | CPU overhead, less mature |
| Mandatory encryption | Security, anti-ossification | Inspection difficulty |

## When to Use What

**HTTP/1.1**: Legacy systems, very simple APIs, debugging

**HTTP/2**: Default for web. Works everywhere. Significant improvement over HTTP/1.1.

**HTTP/3**: Maximum performance. Mobile users. Lossy networks. When supported.

Most deployments should enable both HTTP/2 and HTTP/3, letting clients choose.

## The Principle

> **HTTP evolved by fixing performance problems without changing semantics. GET remains GET. URLs remain URLs. Only the wire format changed. This backward compatibility enabled gradual adoption.**

The lesson: successful protocol evolution preserves abstractions while improving implementations.

## What Changed, What Didn't

**Unchanged:**
- Methods (GET, POST, PUT, DELETE)
- Status codes (200, 404, 500)
- Headers (most)
- URLs
- Request-response model
- Statelessness

**Changed:**
- Text → Binary framing
- Sequential → Multiplexed
- Uncompressed headers → HPACK/QPACK
- TCP → UDP (HTTP/3)
- Separate TLS → Integrated encryption

## Why HTTP Evolution Matters

Understanding HTTP evolution helps you understand:

- **Why HTTPS everywhere**: HTTP/2 effectively requires TLS
- **Why single connections are preferred**: Multiplexing
- **Why server push didn't take off**: Hard to use correctly
- **Why HTTP/3 exists**: Fixing TCP's limitations
- **Why CDNs matter**: They implement modern protocols first
- **Why old APIs still work**: Semantic compatibility

---

## Summary

- HTTP/2 introduced binary framing, multiplexing, and header compression
- Multiplexing eliminates domain sharding and spriting
- TCP head-of-line blocking remained a problem
- HTTP/3 uses QUIC to eliminate HOL blocking
- All versions coexist; negotiation happens automatically
- Semantics stayed the same; wire format evolved

---

*Beyond HTTP, the internet has protocols for specific tasks. Let's look at how email works—our next chapter.*
