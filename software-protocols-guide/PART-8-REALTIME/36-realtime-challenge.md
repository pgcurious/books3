# Chapter 36: The Real-Time Challenge

## When Request-Response Isn't Fast Enough

---

> *"The challenge of real-time is that 'now' means different things to different systems."*
> — Distributed Systems Engineer

---

## The Frustration

You're building a chat application with HTTP:

```
Client: GET /messages?since=last_id
Server: [new messages or empty]
Client: Wait 1 second
Client: GET /messages?since=last_id
Server: [new messages or empty]
...
```

This is **polling**. Problems:

- **Latency**: Up to 1 second delay for new messages
- **Waste**: Most requests return empty
- **Scale**: 1000 users = 1000 requests/second, mostly useless

What if the server could push messages when they happen?

## What "Real-Time" Means

Different applications have different requirements:

### Hard Real-Time
Deadline must be met. Failure = catastrophe.
```
Examples: Medical devices, aircraft control
Latency requirement: Microseconds to milliseconds
Protocols: Custom, specialized
```

### Soft Real-Time
Deadlines matter but occasional misses are acceptable.
```
Examples: Video streaming, VoIP
Latency requirement: Milliseconds to low seconds
Protocols: RTP, WebRTC
```

### Near Real-Time
Fast updates, but not mission-critical.
```
Examples: Chat, notifications, live dashboards
Latency requirement: Hundreds of milliseconds
Protocols: WebSocket, SSE, MQTT
```

Most web applications need near real-time.

## The HTTP Request-Response Problem

HTTP was designed for document retrieval:

```
Client: "Give me this document"
Server: "Here it is"
Connection: Done

Problems for real-time:
1. Client must initiate every request
2. Server can't push unprompted
3. Each request has overhead
4. No persistent connection (HTTP/1.0)
```

## Evolution of Real-Time on the Web

### 1. Polling (1995+)

```javascript
setInterval(() => {
    fetch('/messages')
        .then(r => r.json())
        .then(displayMessages);
}, 1000);
```

Simple but wasteful.

### 2. Long Polling (2005+)

```
Client: GET /messages (request stays open)
Server: Waits for new message...
         ...message arrives!
Server: Returns immediately with message
Client: Processes, immediately sends new request
```

Better latency, but still request-per-message.

### 3. Server-Sent Events (2006+)

```
Client: GET /events (HTTP connection stays open)
Server: Sends events as they happen
        data: {"type": "message", "text": "Hello"}

        data: {"type": "message", "text": "World"}
        ...
```

Server can push, but only server → client.

### 4. WebSocket (2011+)

```
Client: Upgrade HTTP connection to WebSocket
Server: Confirmed
...bidirectional messages...
Client: {"type": "message", "text": "Hello"}
Server: {"type": "message", "text": "Hi back"}
```

Full bidirectional communication.

### 5. WebRTC (2011+)

```
Peer-to-peer connection
Audio, video, data channels
Lowest latency possible
```

Real-time media and data.

## Trade-Offs Between Approaches

| Method | Latency | Bidirectional | Complexity | Browser Support |
|--------|---------|---------------|------------|-----------------|
| Polling | High | N/A | Low | Universal |
| Long Polling | Medium | N/A | Medium | Universal |
| SSE | Low | No | Low | Good |
| WebSocket | Low | Yes | Medium | Good |
| WebRTC | Lowest | Yes | High | Good |

## When to Use What

### Notifications, Live Feeds
```
Use: Server-Sent Events
Why: Simple, server → client only
Example: Twitter timeline, stock prices
```

### Chat, Collaboration
```
Use: WebSocket
Why: Bidirectional needed
Example: Slack, Google Docs
```

### Video/Audio Calls
```
Use: WebRTC
Why: Low latency, peer-to-peer
Example: Zoom, Google Meet
```

### Simple Updates, Fallback Required
```
Use: Polling or Long Polling
Why: Works everywhere
Example: Legacy browsers, firewall issues
```

## The Architectural Shift

Real-time changes architecture:

### Request-Response Architecture

```
┌─────────┐     ┌─────────┐     ┌──────────┐
│ Browser │────→│   API   │────→│ Database │
└─────────┘     └─────────┘     └──────────┘
                    │
                    ↓
              [Response]
```

### Real-Time Architecture

```
┌─────────┐←──────┌─────────┐←──────┌──────────┐
│ Browser │       │   API   │       │ Database │
└─────────┘─────→ └─────────┘       └──────────┘
    ↑                 │
    │                 ↓
    │           ┌──────────┐
    └───────────│  PubSub  │
                └──────────┘
```

New components:
- Connection management
- Message routing
- State synchronization
- Presence detection

## Scaling Real-Time

Stateless HTTP scales easily. Real-time connections are stateful:

```
Challenge:
- User A is connected to Server 1
- User B is connected to Server 2
- A sends message to B
- How does Server 1 reach Server 2?

Solution: PubSub/Message bus
- Server 1 publishes to channel
- Server 2 subscribes to channel
- Message reaches B
```

## The Principle

> **Real-time communication inverts the HTTP model: instead of clients pulling, servers push. This enables low-latency updates but requires new architectural patterns for connection management and message routing.**

The protocols in this section solve different aspects of the real-time problem.

---

## Summary

- HTTP request-response creates latency and waste for real-time needs
- Evolution: Polling → Long Polling → SSE → WebSocket → WebRTC
- Different applications need different real-time guarantees
- Real-time architectures are stateful and need connection management
- PubSub patterns help scale real-time across servers

---

*Let's explore WebSocket—the bidirectional protocol that enables modern real-time web apps.*
