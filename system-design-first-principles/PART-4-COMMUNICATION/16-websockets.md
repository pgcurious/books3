# Chapter 16: WebSockets

> *"The best time to plant a tree was 20 years ago. The second best time is now. The best time to open a WebSocket is before you need it."*
> — Anonymous (probably a developer frustrated with polling)

---

## The Fundamental Problem

### Why Does This Exist?

You're building a real-time chat application. When Alice sends a message to Bob, Bob should see it immediately—not in 5 seconds, not when he refreshes, but *now*.

With traditional HTTP:
1. Bob loads the chat page
2. Server sends the current messages
3. Connection closes
4. ...
5. Alice sends a new message
6. Bob's browser has no way to know
7. Bob must ask the server again

HTTP is **client-initiated**. The server can only respond to requests—it can't push data to clients unprompted.

So Bob's browser polls: "Any new messages?" No. "Any new messages?" No. "Any new messages?" Yes, here's one. "Any new messages?" No...

This works but is wasteful, laggy, and doesn't scale.

The raw, primitive problem is this: **How do you push data from server to client instantly, without the client constantly asking "anything new?"**

### The Real-World Analogy

**HTTP (Request-Response):**

Like sending letters. You write a letter, wait for a response. If you want updates, you have to keep sending letters asking "what's new?"

**HTTP Polling:**

Like calling someone every 5 minutes asking "anything to tell me?" Mostly the answer is no, and you've wasted both your time.

**WebSockets:**

Like a phone call. You dial once, the line stays open. Either party can speak at any time. You hear things the moment they're said.

---

## The Naive Solution

### What Would a Beginner Try First?

"Just poll faster!"

Set up a loop:
```javascript
setInterval(() => {
  fetch('/api/messages?since=' + lastMessageId)
    .then(messages => renderMessages(messages));
}, 1000);  // Every second
```

### Why Does It Break Down?

**1. Latency**

With 1-second polling, average latency is 500ms. For real-time applications like gaming or trading, this is unacceptable.

**2. Wasted resources**

99% of polls return empty. Each poll is a full HTTP request—TCP handshake, headers, connection setup. For a chat app with 10,000 users, that's 10,000 requests per second, mostly for nothing.

**3. Server load**

Each poll hits your server, database, and network. Scaling polling is expensive.

**4. Mobile battery drain**

Constant network requests drain batteries. Users notice and complain.

**5. Scaling nightmare**

More users = more polls = more servers, linearly. Real-time at scale becomes prohibitively expensive.

### The Flawed Assumption

Polling assumes **HTTP's request-response model is the only option**. WebSockets challenge this by maintaining a persistent, bidirectional connection.

---

## The Core Insight

### The "Aha" Moment

Here's the fundamental realization:

> **If you keep the connection open, both sides can send data at any time without the overhead of establishing new connections.**

HTTP was designed for document retrieval—client requests, server responds, connection closes. WebSockets are designed for real-time communication—connection opens once, both sides send messages freely, connection stays open until explicitly closed.

### The Trade-off Acceptance

WebSockets accept:
- **Stateful connections**: Server must track each connected client
- **Connection management**: Handling connect, disconnect, reconnect
- **Scaling complexity**: Stateful connections are harder to load balance
- **Resource consumption**: Each connection uses server memory

We accept these in exchange for instant bidirectional communication.

### The Sticky Metaphor

**HTTP is like walkie-talkies with "over."**

You say your piece, say "over," and wait. The other person responds, says "over," and waits. Structured, but slow for rapid conversation.

**WebSockets are like an open phone line.**

You say something, they hear it immediately. They say something, you hear it immediately. No "over," no waiting, no overhead—just instant communication.

---

## The Mechanism

### Building WebSocket Communication

**Step 1: Establish connection**

WebSocket connections start as HTTP, then "upgrade":

```
Client → Server: HTTP Request
GET /chat HTTP/1.1
Host: example.com
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13

Server → Client: HTTP Response
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=

[TCP connection now speaks WebSocket protocol]
```

**Step 2: Send messages**

Once connected, either side can send at any time:

```java
// Server-side (Java)
@ServerEndpoint("/chat")
public class ChatEndpoint {
    private static Set<Session> sessions = ConcurrentHashMap.newKeySet();

    @OnOpen
    public void onOpen(Session session) {
        sessions.add(session);
        System.out.println("New connection: " + session.getId());
    }

    @OnMessage
    public void onMessage(String message, Session sender) {
        // Broadcast to all connected clients
        ChatMessage chatMessage = parseMessage(message);
        String broadcast = formatMessage(chatMessage);

        for (Session session : sessions) {
            if (session.isOpen()) {
                session.getAsyncRemote().sendText(broadcast);
            }
        }
    }

    @OnClose
    public void onClose(Session session) {
        sessions.remove(session);
    }

    @OnError
    public void onError(Session session, Throwable error) {
        sessions.remove(session);
        error.printStackTrace();
    }
}
```

```javascript
// Client-side (JavaScript)
const ws = new WebSocket('wss://example.com/chat');

ws.onopen = () => {
    console.log('Connected');
    ws.send(JSON.stringify({ type: 'join', room: 'general' }));
};

ws.onmessage = (event) => {
    const message = JSON.parse(event.data);
    displayMessage(message);
};

ws.onclose = () => {
    console.log('Disconnected');
    // Implement reconnection logic
    setTimeout(() => connect(), 1000);
};

// Send message
function sendMessage(text) {
    ws.send(JSON.stringify({ type: 'message', text: text }));
}
```

### Scaling WebSockets

The challenge: WebSocket connections are stateful. User A connects to Server 1. User B connects to Server 2. How does A's message reach B?

**Solution: Message Broker**

```
User A ─── WebSocket ───► Server 1 ─── Pub/Sub ───► Server 2 ─── WebSocket ───► User B
              │                           │                           │
              │                           │                           │
              │                    ┌──────┴──────┐                   │
              │                    │   Redis     │                   │
              │                    │   Pub/Sub   │                   │
              │                    └─────────────┘                   │
```

```java
public class ScalableWebSocketServer {
    private final RedisPublisher redis;
    private final Set<Session> localSessions = ConcurrentHashMap.newKeySet();

    @OnMessage
    public void onMessage(String message, Session sender) {
        // Publish to Redis—all servers will receive
        redis.publish("chat:messages", message);
    }

    // Redis subscription handler (runs on all servers)
    @RedisSubscription("chat:messages")
    public void onRedisMessage(String message) {
        // Broadcast to locally connected clients
        for (Session session : localSessions) {
            if (session.isOpen()) {
                session.getAsyncRemote().sendText(message);
            }
        }
    }
}
```

### Connection Management

**Heartbeats (Ping/Pong)**

Connections can silently die. Detect dead connections with heartbeats:

```java
public class HeartbeatManager {
    @Scheduled(fixedRate = 30000)  // Every 30 seconds
    public void sendHeartbeats() {
        for (Session session : sessions) {
            try {
                session.getBasicRemote().sendPing(ByteBuffer.wrap(new byte[0]));
            } catch (Exception e) {
                // Connection is dead
                sessions.remove(session);
            }
        }
    }
}
```

**Reconnection with State Recovery**

```javascript
class RobustWebSocket {
    constructor(url) {
        this.url = url;
        this.lastMessageId = 0;
        this.connect();
    }

    connect() {
        this.ws = new WebSocket(this.url);

        this.ws.onopen = () => {
            // Request missed messages
            this.ws.send(JSON.stringify({
                type: 'sync',
                since: this.lastMessageId
            }));
        };

        this.ws.onmessage = (event) => {
            const msg = JSON.parse(event.data);
            this.lastMessageId = msg.id;
            this.handleMessage(msg);
        };

        this.ws.onclose = () => {
            // Reconnect with exponential backoff
            setTimeout(() => this.connect(), this.backoff());
        };
    }
}
```

### WebSocket vs. Alternatives

**Server-Sent Events (SSE)**

One-way: server to client only. Simpler for cases where client doesn't need to send data.

```javascript
// SSE Client
const eventSource = new EventSource('/events');
eventSource.onmessage = (event) => {
    console.log('Received:', event.data);
};
// No eventSource.send() - it's one-way
```

**Long Polling**

HTTP request stays open until server has data. Compromise between polling and WebSockets.

```javascript
// Long polling
async function longPoll() {
    const response = await fetch('/api/updates?timeout=30');
    const data = await response.json();
    handleUpdate(data);
    longPoll();  // Immediately start next poll
}
```

**Comparison:**

| Feature | Polling | Long Polling | SSE | WebSocket |
|---------|---------|--------------|-----|-----------|
| Direction | Client → Server | Client → Server | Server → Client | Bidirectional |
| Latency | High | Medium | Low | Low |
| Overhead | High | Medium | Low | Low |
| Complexity | Low | Medium | Low | High |
| Browser support | Universal | Universal | Good | Good |

---

## The Trade-offs

### What Do We Sacrifice?

**1. Stateful complexity**

Each connection is state. Managing thousands of stateful connections is harder than stateless HTTP requests.

**2. Load balancing challenges**

With HTTP, any server can handle any request. With WebSockets, you need sticky sessions or a message broker.

**3. Connection limits**

Servers have file descriptor limits. Each WebSocket is a file descriptor. Plan for this.

**4. Proxy and firewall issues**

Some proxies don't handle WebSocket upgrades well. Some corporate firewalls block WebSocket connections.

**5. Mobile complexity**

Mobile devices aggressively close connections to save battery. Need robust reconnection logic.

### When NOT To Use This

- **Occasional updates**: If data changes every few minutes, polling is simpler.
- **One-way server-to-client**: Consider SSE—simpler and widely supported.
- **Request-response patterns**: If you're always asking a question and getting an answer, HTTP is fine.
- **Serverless architectures**: WebSockets don't fit well with truly serverless (where functions spin down).

### Connection to Other Concepts

- **Load Balancing** (Chapter 1): WebSocket-aware load balancing is tricky
- **Message Queues** (Chapter 7): Often used for cross-server WebSocket delivery
- **Scalability** (Chapter 17): Stateful connections affect scaling strategy
- **API Gateway** (Chapter 9): Gateways must handle WebSocket upgrade

---

## The Evolution

### Brief History

**2008-2011: Development**

WebSocket protocol developed, standardized as RFC 6455 in 2011.

**2011-2015: Browser adoption**

All major browsers added support. Libraries like Socket.io abstracted complexity.

**2015+: Ubiquity**

Real-time became expected. Chat, notifications, live updates everywhere.

### Modern Implementations

**Socket.io**

Library that falls back gracefully (WebSocket → Long Polling → Polling):

```javascript
// Server
const io = require('socket.io')(server);
io.on('connection', (socket) => {
    socket.on('chat message', (msg) => {
        io.emit('chat message', msg);  // Broadcast
    });
});

// Client
const socket = io('https://example.com');
socket.emit('chat message', 'Hello!');
socket.on('chat message', (msg) => displayMessage(msg));
```

**Phoenix Channels (Elixir)**

Built for massive concurrent connections. Handles millions on modest hardware.

**AWS API Gateway WebSocket**

Managed WebSocket with Lambda integration.

### Where It's Heading

**WebSocket over HTTP/3 (WebTransport)**: Lower latency, better congestion handling.

**Edge WebSockets**: WebSocket termination at CDN edge for lower latency.

**Serverless WebSockets**: Better patterns for WebSockets in serverless environments.

---

## Interview Lens

### Common Interview Questions

1. **"How would you design a chat application?"**
   - WebSocket for real-time messages
   - Message broker for scaling across servers
   - HTTP for historical messages and metadata
   - Presence system (who's online)

2. **"How do you scale WebSockets?"**
   - Pub/Sub (Redis, Kafka) for cross-server messaging
   - Sticky sessions or connection-aware routing
   - Connection limits per server
   - Horizontal scaling with shared state

3. **"WebSocket vs. Long Polling—when to use each?"**
   - WebSocket: High-frequency updates, bidirectional
   - Long Polling: Simpler, better firewall compatibility, occasional updates

### Red Flags (Shallow Understanding)

❌ "Just use WebSockets for everything"

❌ Doesn't mention scaling challenges

❌ Can't explain the upgrade handshake

❌ Ignores connection management (heartbeat, reconnection)

### How to Demonstrate Deep Understanding

✅ Explain the HTTP upgrade process

✅ Discuss message broker for horizontal scaling

✅ Mention alternatives (SSE, Long Polling) and when to use them

✅ Address mobile-specific challenges

✅ Know about WebSocket compression and binary frames

---

## Curiosity Hooks

As you continue, consider:

- WebSockets are great for real-time. But how do you know users are actually online? (Presence systems, heartbeats)

- We mentioned scaling with Redis pub/sub. What happens if Redis goes down? (Hint: Chapter 18, Fault Tolerance)

- How do you authenticate WebSocket connections? The handshake is HTTP... (Hint: Chapter 20, AuthN & AuthZ)

- If the page has both REST and WebSocket, how do you share authentication between them?

---

## Summary

**The Problem**: HTTP is client-initiated. Servers can't push data to clients without being asked, leading to wasteful polling for real-time applications.

**The Insight**: By upgrading an HTTP connection to WebSocket, you get a persistent, bidirectional channel where either side can send messages instantly.

**The Mechanism**: HTTP upgrade handshake establishes WebSocket connection. Messages flow freely in both directions. Heartbeats maintain connection liveness.

**The Trade-off**: Stateful connections complicate scaling and load balancing, in exchange for instant bidirectional communication.

**The Evolution**: From early proprietary solutions → standardized WebSocket → libraries like Socket.io → managed cloud services.

**The First Principle**: Request-response is one communication pattern. When you need continuous, bidirectional, real-time communication, you need a different pattern—and WebSocket provides it.

---

*Next: We move to Part 5—how services are organized and found. Starting with [Chapter 10: Microservices](../PART-5-ARCHITECTURE/10-microservices.md)—where we learn that the right way to structure a system depends on how you want to change it.*
