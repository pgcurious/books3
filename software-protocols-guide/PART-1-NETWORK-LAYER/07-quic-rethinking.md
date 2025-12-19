# Chapter 7: QUIC—Rethinking Transport

## Learning from Decades of TCP and UDP

---

> *"QUIC is what TCP would look like if we designed it today."*
> — Ian Swett, Google

---

## The Frustration

By 2012, Google had a problem. The web was getting faster—faster servers, faster browsers, faster networks—but TCP was holding things back.

**The handshake tax**: Every new connection costs 1-3 round trips before data flows. On a 100ms latency connection to a mobile user, that's 100-300ms of pure waiting.

**Head-of-line blocking**: HTTP/2 multiplexes multiple requests over one TCP connection. But if any packet is lost, ALL requests wait. One lost packet from a CSS file delays the JavaScript response.

**Ossification**: TCP is implemented in operating system kernels. Changing TCP means updating billions of devices. New TCP features take a decade to deploy—if they ever do.

**No encryption by default**: TLS adds another handshake, another round trip.

Google asked: what if we could fix these problems?

## The World Before QUIC

Developers worked around TCP's limitations:

- **Multiple TCP connections**: Open 6 connections per domain (browser limit). Each has separate handshake overhead.
- **Connection pooling**: Reuse connections, but still suffer head-of-line blocking.
- **Domain sharding**: Spread resources across domains to open more connections. Adds DNS lookups.
- **TLS session resumption**: Reduce handshake cost on repeat visits. Doesn't help first visits.

These were patches. TCP's fundamental design remained unchanged since 1981.

## The Insight: Build on UDP, Fix Everything

QUIC started with a radical idea: implement transport in userspace on top of UDP.

```
Traditional Stack:
┌─────────────────┐
│   Application   │
├─────────────────┤
│   TLS (1.3)     │
├─────────────────┤
│   TCP           │ ← in kernel, hard to change
├─────────────────┤
│   IP            │
└─────────────────┘

QUIC Stack:
┌─────────────────┐
│   Application   │
├─────────────────┤
│   QUIC          │ ← in userspace, easy to update
├─────────────────┤
│   UDP           │
├─────────────────┤
│   IP            │
└─────────────────┘
```

By building on UDP, QUIC could:
- Deploy through app updates, not OS updates
- Iterate rapidly (Google updated QUIC weekly)
- Work through NAT and firewalls (UDP usually allowed)
- Include encryption as mandatory, not optional

## What QUIC Fixes

### 1. Connection Establishment: 0-RTT

TCP+TLS takes 2-3 round trips before data flows:

```
TCP: Client ← → Server  (SYN, SYN-ACK, ACK)     1-2 RTT
TLS: Client ← → Server  (ClientHello, etc.)    1-2 RTT
Then: Data starts flowing

Total: 2-4 round trips minimum
```

QUIC combines these:

```
First connection: 1 RTT
Client → Server: ClientHello + crypto
Server → Client: ServerHello + encrypted response
Data can flow immediately

Resumed connection: 0 RTT
Client → Server: Remembered crypto + first request
Server → Client: Response
Data flows with the first packet
```

0-RTT means the first request and the connection establishment happen together. For reconnecting to a known server, data starts flowing immediately.

### 2. Stream Multiplexing Without Head-of-Line Blocking

TCP sees everything as one byte stream. QUIC has independent streams:

```
TCP (HTTP/2):
Stream A: [1] [2] [X] [4] [5]  ← packet 3 lost
Stream B: [1] [2] [3] [4] [5]  ← all delivered
Stream C: [1] [2] [3] [4] [5]  ← all delivered

ALL streams wait for Stream A's packet 3.

QUIC:
Stream A: [1] [2] [X] [4] [5]  ← packet 3 lost, Stream A waits
Stream B: [1] [2] [3] [4] [5]  ← delivered immediately
Stream C: [1] [2] [3] [4] [5]  ← delivered immediately

Only Stream A is affected by Stream A's loss.
```

Each stream is independent. Lost packets on one stream don't block others.

### 3. Built-in Encryption

QUIC requires TLS 1.3. There's no unencrypted QUIC:

```
Even packet headers are encrypted (mostly).
Connection IDs are opaque to observers.
Middleboxes can't inspect QUIC traffic.

This is intentional: it prevents ossification.
If middleboxes can't see inside, they can't break
when QUIC evolves.
```

### 4. Connection Migration

TCP connections are identified by (source IP, source port, dest IP, dest port). Change any of these, and the connection breaks.

```
TCP problem:
You're on WiFi, connected to a service.
You walk outside, phone switches to cellular.
New IP address.
TCP connection dies.
Application must reconnect, re-authenticate, resume.

QUIC solution:
Connections use a connection ID, not IP addresses.
When your IP changes, QUIC continues with the same ID.
The server sees the same connection, different source.
Seamless migration, no interruption.
```

This matters enormously for mobile users who switch between networks constantly.

### 5. Improved Loss Recovery

TCP's retransmission is ambiguous:

```
TCP problem:
Send packet with sequence 1000.
Retransmit packet with sequence 1000.
Receive ACK for sequence 1000.
Which packet was acknowledged? 🤷
```

QUIC uses unique packet numbers:

```
Send packet #42 with stream data.
Retransmit in packet #55.
ACK for #42 → original arrived.
ACK for #55 → retransmit arrived.
No ambiguity. Better RTT estimation.
```

## The Tradeoffs

QUIC isn't free:

### Userspace Overhead
Kernel TCP is highly optimized. Userspace QUIC has more copying, more system calls.

```
Kernel TCP: Zero-copy possible, hardware offload available
QUIC: Still maturing, limited hardware acceleration
```

### UDP Issues
Some networks block or deprioritize UDP. QUIC can fall back to TCP.

### Complexity
QUIC is more complex than TCP. Debugging is harder. Tools are less mature.

### CPU Cost
Mandatory encryption and userspace processing increase CPU usage.

## QUIC vs TCP Performance

Real-world results vary, but generally:

**QUIC wins when:**
- Network has high latency (handshake savings)
- Network has packet loss (no cross-stream blocking)
- User changes networks (connection migration)
- First-time page loads (faster start)

**TCP may win when:**
- Network is stable and fast
- Connection is long-lived (handshake is amortized)
- Hardware TCP offload is available
- UDP is deprioritized by the network

## HTTP/3: QUIC's Primary User

HTTP/3 is HTTP over QUIC. It's why QUIC exists:

```
HTTP/1.1 over TCP: One request per connection, or pipelining (rarely)
HTTP/2 over TCP: Multiplexed requests, but head-of-line blocking
HTTP/3 over QUIC: Multiplexed requests without head-of-line blocking
```

HTTP/3 adoption is growing. Major sites (Google, Facebook, Cloudflare) serve HTTP/3. Modern browsers support it. It's becoming the default for the web.

## The Principle

> **QUIC solves the problems we discovered after 40 years of TCP: handshake latency, head-of-line blocking, encryption as afterthought, and connection fragility. By building on UDP, it can evolve without waiting for OS updates.**

QUIC represents a generational shift: moving transport protocol innovation from the kernel to applications.

## The Lessons

QUIC teaches us about protocol evolution:

### 1. Ossification is Real
You can't change TCP because middleboxes inspect and depend on it. QUIC encrypts everything to prevent this.

### 2. Layering Can Be Reconsidered
TCP and TLS were separate layers. QUIC integrates them because the separation caused problems.

### 3. Userspace Can Compete
The performance cost of userspace is acceptable when the design benefits are large enough.

### 4. Incremental Deployment Works
QUIC doesn't require network upgrades. It works on today's internet, today.

## Why QUIC Matters Today

Understanding QUIC helps you understand:

- **Why HTTP/3 exists**: It's HTTP over QUIC
- **Why modern web is faster**: 0-RTT, no head-of-line blocking
- **Why mobile apps feel smoother**: Connection migration
- **Why some traffic is unblocked**: UDP instead of blocked ports
- **Why debugging web requests is harder**: Encrypted transport

---

## Summary

- QUIC fixes TCP problems: slow handshakes, head-of-line blocking, no encryption, connection fragility
- Built on UDP to deploy without OS changes
- 0-RTT for repeat connections, 1-RTT for new ones
- Streams are independent—loss on one doesn't block others
- Mandatory encryption prevents ossification
- Connection IDs survive network changes
- HTTP/3 is HTTP over QUIC

---

*We've covered how data travels reliably across networks. Now let's look at the protocols that use these transport layers—starting with how we name things on the internet.*
