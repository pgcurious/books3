# Chapter 2: What Makes a Protocol

## The Anatomy of Communication Agreements

---

> *"A protocol is not about formats. It's about promises."*
> — Unknown Engineer

---

## The Frustration

You've decided to create a protocol. You define a message format, document it, and ship it.

Six months later, nothing works. Different implementations interpret your "specification" differently. Edge cases weren't covered. Error handling is inconsistent. Some implementations crash on certain inputs while others accept them silently.

**You defined a format. You didn't define a protocol.**

## The World Before

Early computing history is littered with "protocols" that weren't really protocols:

- Formats that specified data layout but not error handling
- Message definitions without flow control
- APIs without versioning strategies
- Interfaces without failure modes

These partial specifications caused endless interoperability problems. They taught the industry a painful lesson: **a protocol must be complete.**

## What a Protocol Actually Is

A protocol is not just a data format. It's a complete agreement covering:

### 1. Syntax: How Messages Look

This is what most people think a protocol is—the structure of messages:

```
Example: HTTP Request Syntax

GET /index.html HTTP/1.1
Host: example.com
Accept: text/html

[The exact format, allowed values, required fields]
```

But syntax is just the beginning.

### 2. Semantics: What Messages Mean

What should happen when a message is received? What state changes? What responses are expected?

```
Example: HTTP Semantics

GET  → Read a resource (no side effects)
POST → Create a resource (has side effects)
PUT  → Replace a resource entirely
DELETE → Remove a resource

404 means "resource doesn't exist"
500 means "server error, not your fault"
```

Two implementations might parse messages identically (same syntax) but do completely different things (different semantics). Both are broken without semantic agreement.

### 3. Ordering: The Dance of Messages

Who speaks first? What sequences are valid? What must happen before what?

```
Example: TCP Three-Way Handshake

1. Client → Server: SYN (I want to connect)
2. Server → Client: SYN-ACK (Acknowledged, I also want to connect)
3. Client → Server: ACK (Acknowledged, let's go)

You cannot send data before this dance completes.
This ordering is part of the protocol.
```

### 4. Error Handling: When Things Go Wrong

What happens when messages are lost? Corrupted? When the other side crashes? When the network partitions?

```
Example: Error Handling Decisions

- If no response in X seconds, what happens?
- If a malformed message arrives, what happens?
- If the connection drops mid-message, what happens?
- If the other side sends something unexpected, what happens?

Each answer must be specified. Unspecified error handling
leads to implementation divergence.
```

### 5. State Management: Memory Across Messages

Does the protocol remember previous messages? What state must each side maintain?

```
Example: Stateful vs Stateless

HTTP 1.0: Stateless - each request is independent
TCP: Stateful - tracks sequence numbers, acknowledgments
WebSocket: Stateful - maintains a persistent connection
OAuth: Stateful - tokens represent authorized sessions
```

### 6. Versioning: Living With Change

How do you evolve the protocol? How do old and new implementations coexist?

```
Example: Versioning Strategies

HTTP/1.0 → HTTP/1.1 → HTTP/2 → HTTP/3
Each version negotiated in the initial handshake.

Protobuf: Add fields (old versions ignore unknown fields)
JSON API: URL versioning (/v1/users, /v2/users)
```

## The Implicit vs Explicit Spectrum

Some protocols are formally specified in hundreds of pages of RFCs. Others are "just JSON over HTTP" with behavior emerging from convention.

```
EXPLICIT (Formally Specified)           IMPLICIT (Convention-Based)
←─────────────────────────────────────────────────────────────→
TCP     HTTP    gRPC    REST    "JSON API"    "We just send JSON"
```

More explicit protocols have:
- Better interoperability
- Clearer test criteria
- Easier debugging
- Higher design cost

More implicit protocols have:
- Faster initial development
- More flexibility
- Higher ongoing ambiguity cost
- Implementation drift over time

Neither is universally better. But understand where your protocol sits on this spectrum.

## The Protocol Stack

Real communication involves multiple protocols working together:

```
Your Application
    ↓ (Your app uses...)
REST API conventions
    ↓ (Carried over...)
HTTP protocol
    ↓ (Secured by...)
TLS protocol
    ↓ (Transported by...)
TCP protocol
    ↓ (Addressed by...)
IP protocol
    ↓ (Transmitted via...)
Ethernet/WiFi
```

Each layer trusts the layer below to handle certain problems. Your REST API doesn't worry about packet loss—TCP handles that. HTTP doesn't worry about encryption—TLS handles that.

This layering is powerful because each protocol can focus on its specific concern.

## Protocol Design Decisions

Every protocol makes tradeoffs. Understanding these helps you evaluate protocols:

### Simplicity vs Power
```
Simple: HTTP/1.1 - text-based, easy to debug
Powerful: HTTP/2 - binary, multiplexed, efficient
```

### Synchronous vs Asynchronous
```
Synchronous: Request-response, wait for answer
Asynchronous: Fire and forget, or callback-based
```

### Binary vs Text
```
Binary: Efficient, compact, hard to debug
Text: Readable, debuggable, larger, slower
```

### Connection-Oriented vs Connectionless
```
Connection-oriented: TCP (setup overhead, reliable)
Connectionless: UDP (no setup, unreliable)
```

### Stateful vs Stateless
```
Stateful: More efficient for ongoing conversations
Stateless: Simpler, more scalable, more redundancy-friendly
```

## The Hidden Assumptions

Every protocol makes assumptions about its environment:

- **Reliability assumptions**: Will messages always arrive? In order?
- **Latency assumptions**: How fast is fast enough? What's too slow?
- **Security assumptions**: Is the network trusted? Who might be listening?
- **Resource assumptions**: How much memory? Bandwidth? CPU?
- **Failure assumptions**: What breaks? How often?

When assumptions don't match reality, protocols fail:

```
TCP assumes the network is best-effort but mostly working.
Run it over a satellite link with 600ms latency and
10% packet loss, and performance collapses.

HTTP assumes relatively fast connections.
Use it over a 2G mobile network in a developing country,
and web pages become unusable.

These aren't protocol bugs—they're assumption mismatches.
```

## The Principle

> **A protocol is an agreement on syntax, semantics, ordering, error handling, state, and evolution—all of it.**

Skip any piece and you don't have a protocol. You have a source of bugs.

## When to Use Existing Protocols

Most of the time, you should use existing protocols:

**Use existing protocols when:**
- Your problem has been solved before
- Interoperability matters
- You need established tooling
- Security is critical (battle-tested beats homegrown)

**Consider new protocols when:**
- Existing protocols add unacceptable overhead
- Your domain has unique requirements
- You control both ends of communication
- You can afford the design and maintenance cost

## Evaluating Protocols

When choosing a protocol, ask:

1. **What problem was this designed to solve?** (Does that match my problem?)
2. **What assumptions does it make?** (Do those match my environment?)
3. **What tradeoffs does it make?** (Can I live with the downsides?)
4. **How mature is it?** (Battle-tested or experimental?)
5. **What's the ecosystem like?** (Tooling, libraries, expertise?)
6. **How does it evolve?** (Can I upgrade? Will it be supported?)

---

## Summary

- A protocol is more than a format—it includes semantics, ordering, error handling, state, and versioning
- Protocols exist on a spectrum from formally specified to convention-based
- Protocol stacks allow each layer to focus on specific concerns
- Every protocol makes assumptions about its environment
- Most of the time, use existing protocols rather than inventing new ones
- Evaluate protocols based on their original problem, assumptions, and tradeoffs

---

*Understanding protocols in isolation isn't enough. We need to understand how they're organized into layers—the subject of our next chapter.*
