# Chapter 46: Designing Your Own Protocols

## When and How to Create Custom Protocols

---

> *"Don't design a protocol unless you absolutely have to. But if you must, design it well."*
> — Protocol Designer's Wisdom

---

## When to Design Your Own

### Almost Never

Existing protocols cover most needs:

```
API communication? REST, gRPC, GraphQL
Messaging? Kafka, AMQP, MQTT
Real-time? WebSocket, SSE
File transfer? HTTP, S3 API

Someone has probably solved your problem.
```

### Rare Cases for Custom Protocols

```
1. Extreme performance requirements
   - Existing protocols have unacceptable overhead
   - You control both ends

2. Unique domain constraints
   - Specialized hardware
   - Regulatory requirements
   - Legacy system integration

3. Novel use case
   - Truly new problem space
   - Research/experimentation
```

## If You Must: Design Principles

### 1. Start with Requirements

```
Questions to answer:
- What data is exchanged?
- What are the latency requirements?
- What failure modes exist?
- How will it evolve?
- Who will implement it?
```

### 2. Design for Evolution

```
Bad: Version 1 assumes everything is fixed
Good: Version 1 includes versioning, extension points

Future you will thank present you.
```

### 3. Keep It Simple

```
Simple protocols:
- Easier to implement correctly
- Easier to debug
- Fewer edge cases
- Faster to adopt

Complexity should be justified.
```

### 4. Document Everything

```
Document:
- Message formats
- State machines
- Error handling
- Edge cases
- Security considerations
- Examples

Undocumented protocols become mysteries.
```

## Message Design

### Framing

How do messages start and end?

```
Option A: Length-prefixed
[4 bytes: length][payload]
Pro: Easy to parse
Con: Must know length upfront

Option B: Delimiter-based
[payload][delimiter]
Pro: Streaming-friendly
Con: Must escape delimiters in payload

Option C: Self-describing (JSON)
{...json...}
Pro: Flexible
Con: Parsing overhead
```

### Type Systems

```
Option A: No types
Just bytes. Receiver interprets.
Simple but error-prone.

Option B: Implicit types
Message type implies structure.
Less overhead, tight coupling.

Option C: Self-describing types
Field names and types in message.
Flexible but larger.

Option D: Schema-based
External schema defines types.
Efficient and type-safe.
```

### Versioning

```
Option A: Version in header
{version: 2, ...}
Simple. Breaking changes = new version.

Option B: Feature negotiation
Client: I support features A, B, C
Server: Let's use A and C
Flexible but complex.

Option C: Extension points
Unknown fields are ignored.
Forward compatible.
```

## State Management

### Stateless

```
Every message is independent.
No connection memory.

Pro: Simple, scalable
Con: More data per message
Example: HTTP, DNS
```

### Stateful

```
Connection remembers previous messages.
Session state maintained.

Pro: Efficiency, context
Con: Complexity, recovery
Example: TCP, database connections
```

### Choose Based On

```
Many short interactions? → Stateless
Long conversations? → Stateful
Need to scale horizontally? → Prefer stateless
```

## Error Handling

### Explicit Error Messages

```
{type: "error", code: "INVALID_REQUEST", message: "..."}

Clear and debuggable.
```

### Error Codes

```
Define error categories:
1xx: Informational
2xx: Success
4xx: Client error
5xx: Server error

Or domain-specific codes.
```

### Recovery Strategies

```
What happens after an error?
- Connection continues? Closes?
- Retry allowed? When?
- State reset? Preserved?

Document all of this.
```

## Security Considerations

### Authentication

```
How do parties prove identity?
- Credentials in handshake
- Token per message
- Certificate-based
```

### Encryption

```
Transport encryption (TLS)?
Message-level encryption?
End-to-end encryption?
```

### Common Vulnerabilities

```
- Replay attacks (use nonces)
- Injection (validate inputs)
- DoS (rate limiting)
- Information leakage (minimize data)
```

## Testing Your Protocol

### Conformance Testing

```
Does implementation match spec?
- Positive tests (valid messages)
- Negative tests (invalid messages)
- Edge cases (boundaries)
```

### Interoperability Testing

```
Do different implementations work together?
- Test against multiple implementations
- Vary message ordering, timing
- Test error paths
```

### Fuzz Testing

```
Send random/malformed data.
Implementation should:
- Not crash
- Not leak memory
- Return proper errors
```

## Documentation Template

```markdown
# Protocol Name

## Overview
What problem does this solve?

## Terminology
Define key terms.

## Message Format
How are messages structured?

## Message Types
What messages exist? What do they mean?

## State Machine
What states exist? What transitions are valid?

## Error Handling
What errors can occur? How are they reported?

## Security
What security measures are required?

## Examples
Show complete message exchanges.

## Versioning
How will the protocol evolve?
```

## Real-World Example: A Simple RPC Protocol

```
# Simple RPC Protocol

## Message Format
[4 bytes: length][1 byte: type][payload]

## Message Types
0x01: Request
      [4 bytes: request_id][2 bytes: method_id][payload]

0x02: Response
      [4 bytes: request_id][payload]

0x03: Error
      [4 bytes: request_id][2 bytes: error_code][message]

## Flow
1. Client sends Request
2. Server sends Response or Error
3. Requests can be pipelined

## Errors
0x01: Unknown method
0x02: Invalid payload
0x03: Server error
```

## The Principle

> **Custom protocols should be a last resort, not a first choice. If you must design one, prioritize simplicity, document thoroughly, and plan for evolution.**

Most protocols fail because they're too complex, too poorly documented, or too rigid to evolve.

---

## Summary

- Use existing protocols when possible
- Design custom protocols only for unique constraints
- Prioritize simplicity and evolution
- Document message formats, state, errors, security
- Test conformance, interoperability, and with fuzzing
- Learn from existing protocols' designs

---

*What does the future of protocols look like?*
