# Chapter 37: WebSockets—Persistent Connections

## Bidirectional Communication Over a Single Connection

---

> *"WebSocket is HTTP's rebellious sibling—it starts as HTTP, then breaks all the rules."*
> — Web Developer

---

## The Frustration

You've tried long polling. It works, but:

```
Message 1: Request → Response
Message 2: Request → Response
Message 3: Request → Response

Each message needs a new request.
Headers repeated every time.
Server can't initiate.
```

What if you could keep a connection open and send messages both ways, anytime?

## The Insight: Upgrade HTTP to WebSocket

WebSocket starts as HTTP, then transforms:

```
Client: GET /chat HTTP/1.1
        Upgrade: websocket
        Connection: Upgrade
        Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
        Sec-WebSocket-Version: 13

Server: HTTP/1.1 101 Switching Protocols
        Upgrade: websocket
        Connection: Upgrade
        Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=

[HTTP ends. WebSocket begins.]
```

After the handshake, the connection is a full-duplex binary channel.

## WebSocket Frames

Messages are sent as frames:

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-------+-+-------------+-------------------------------+
|F|R|R|R| opcode|M| Payload len |    Extended payload length    |
|I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
|N|V|V|V|       |S|             |   (if payload len==126/127)   |
| |1|2|3|       |K|             |                               |
+-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
|     Extended payload length continued, if payload len == 127  |
+ - - - - - - - - - - - - - - - +-------------------------------+
|                               |Masking-key, if MASK set to 1  |
+-------------------------------+-------------------------------+
| Masking-key (continued)       |          Payload Data         |
+-------------------------------- - - - - - - - - - - - - - - - +
:                     Payload Data continued ...                :
+ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
|                     Payload Data continued ...                |
+---------------------------------------------------------------+
```

### Opcodes

```
0x0: Continuation frame
0x1: Text frame (UTF-8)
0x2: Binary frame
0x8: Close connection
0x9: Ping
0xA: Pong
```

### Client-to-Server Masking

```
Client → Server: Data is XOR masked
Server → Client: Data is NOT masked

Why? Prevents proxy cache poisoning attacks.
```

## Using WebSockets

### Browser Client

```javascript
const ws = new WebSocket('wss://example.com/chat');

ws.onopen = () => {
    console.log('Connected');
    ws.send(JSON.stringify({ type: 'join', room: 'general' }));
};

ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    console.log('Received:', data);
};

ws.onclose = () => {
    console.log('Disconnected');
};

ws.onerror = (error) => {
    console.error('Error:', error);
};

// Send a message
ws.send(JSON.stringify({ type: 'message', text: 'Hello!' }));
```

### Node.js Server (using ws library)

```javascript
const WebSocket = require('ws');
const wss = new WebSocket.Server({ port: 8080 });

wss.on('connection', (ws) => {
    console.log('Client connected');

    ws.on('message', (message) => {
        const data = JSON.parse(message);
        console.log('Received:', data);

        // Broadcast to all clients
        wss.clients.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(JSON.stringify({
                    type: 'message',
                    from: 'user1',
                    text: data.text
                }));
            }
        });
    });

    ws.on('close', () => {
        console.log('Client disconnected');
    });
});
```

## WebSocket Subprotocols

Negotiate application-level protocol:

```
Client: Sec-WebSocket-Protocol: graphql-ws, json

Server: Sec-WebSocket-Protocol: graphql-ws

Now both sides know to use graphql-ws format.
```

Common subprotocols:
- `graphql-ws`: GraphQL subscriptions
- `wamp`: Web Application Messaging Protocol
- `stomp`: Simple Text Oriented Messaging Protocol

## Ping/Pong: Keeping Connections Alive

```
Server: Sends Ping frame periodically
Client: Must respond with Pong

If no Pong received: Connection presumed dead

Also used to keep connection alive through proxies.
```

## Scaling WebSocket Servers

WebSocket connections are stateful. Scaling requires coordination:

### The Problem

```
User A → Server 1
User B → Server 2

A wants to message B.
Server 1 doesn't know B exists!
```

### Solution: PubSub

```
User A → Server 1 → [Redis PubSub] → Server 2 → User B
                    [or Kafka]
                    [or custom]

All servers subscribe to message channels.
Message goes through the bus.
```

### Connection State

```
Each server tracks:
- Active connections
- User sessions
- Room memberships

Load balancer must be WebSocket-aware.
Sticky sessions often needed.
```

## WebSocket vs Alternatives

| Feature | WebSocket | Long Polling | SSE |
|---------|-----------|--------------|-----|
| Bidirectional | Yes | No | No |
| Binary data | Yes | Via encoding | No |
| Overhead | Low | Medium | Low |
| Reconnection | Manual | Automatic | Automatic |
| Proxy support | Sometimes issues | Good | Good |
| Browser support | Excellent | Universal | Good |

## When WebSocket is Wrong

### Fire-and-Forget
```
Just need to send data without response?
HTTP POST might be simpler.
```

### Server-Only Updates
```
No need to send from client?
SSE is simpler and auto-reconnects.
```

### Hostile Networks
```
Some corporate proxies break WebSocket.
Fallback to long polling needed.
```

### Simple Requests
```
Standard CRUD operations?
REST is more appropriate.
```

## The Tradeoffs

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| Persistent connection | Low latency | Connection management |
| Binary frames | Efficiency | Debugging complexity |
| Full duplex | Real bidirectional | HTTP tooling |
| Upgrade mechanism | Firewall compatibility | Protocol complexity |

## The Principle

> **WebSocket provides true bidirectional communication by upgrading an HTTP connection to a persistent, full-duplex channel. It's the foundation of modern real-time web applications.**

Use WebSocket when you need bidirectional, low-latency communication. Use simpler alternatives when you don't.

---

## Summary

- WebSocket upgrades HTTP to full-duplex communication
- Frames carry text, binary, or control data
- Client-to-server data is masked for security
- Ping/pong keeps connections alive
- Scaling requires PubSub for cross-server communication
- Use when bidirectional communication is needed

---

*For simpler server-to-client streaming, SSE offers an easier path.*
