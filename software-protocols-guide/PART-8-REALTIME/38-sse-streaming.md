# Chapter 38: Server-Sent Events—Simple Streaming

## When You Only Need Server-to-Client

---

> *"The best protocol is often the simplest one that solves your problem."*
> — Every senior engineer eventually

---

## The Frustration

WebSocket is powerful, but for many use cases it's overkill:

- Live dashboard: Server sends updates, client just displays
- Notification feed: Server pushes, client receives
- Stock ticker: Prices flow one direction

Setting up WebSocket infrastructure for one-way data feels wrong.

## The Insight: HTTP Can Stream

HTTP supports streaming responses. Server-Sent Events (SSE) formalizes this:

```
Client: GET /events
        Accept: text/event-stream

Server: HTTP/1.1 200 OK
        Content-Type: text/event-stream
        Cache-Control: no-cache
        Connection: keep-alive

        data: {"price": 100.50}

        data: {"price": 100.75}

        data: {"price": 101.00}

        ...
```

The connection stays open. Server sends events as they happen.

## SSE Event Format

Simple, text-based:

```
event: price-update
data: {"symbol": "GOOG", "price": 2850.00}
id: 12345
retry: 5000

event: price-update
data: {"symbol": "AAPL", "price": 175.50}
id: 12346

```

### Fields

```
data:   The payload (can span multiple lines)
event:  Event type (defaults to "message")
id:     Event ID (for reconnection)
retry:  Reconnection time in ms
```

### Multi-line Data

```
data: line 1
data: line 2
data: line 3

Client receives: "line 1\nline 2\nline 3"
```

## Using SSE

### Browser Client

```javascript
const events = new EventSource('/events');

events.onopen = () => {
    console.log('Connected');
};

events.onmessage = (event) => {
    console.log('Received:', event.data);
};

events.addEventListener('price-update', (event) => {
    const data = JSON.parse(event.data);
    updatePrice(data.symbol, data.price);
});

events.onerror = (error) => {
    console.error('Error:', error);
    // Browser will auto-reconnect
};
```

### Node.js Server

```javascript
const http = require('http');

http.createServer((req, res) => {
    if (req.url === '/events') {
        res.writeHead(200, {
            'Content-Type': 'text/event-stream',
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive'
        });

        // Send event every second
        const interval = setInterval(() => {
            const data = { timestamp: Date.now(), price: Math.random() * 100 };
            res.write(`data: ${JSON.stringify(data)}\n\n`);
        }, 1000);

        req.on('close', () => {
            clearInterval(interval);
        });
    }
}).listen(8080);
```

## Built-In Reconnection

SSE auto-reconnects on failure:

```
1. Connection drops
2. Browser waits (retry: value, default 3s)
3. Browser reconnects with Last-Event-ID header
4. Server can resume from that ID

No application code needed for basic reconnection.
```

### Resumption Example

```javascript
// Server tracks events
events.addEventListener('open', () => {
    // Browser sends Last-Event-ID header automatically
});

// Server responds from that point
if (req.headers['last-event-id']) {
    const lastId = parseInt(req.headers['last-event-id']);
    sendEventsSince(lastId, res);
}
```

## SSE vs WebSocket

| Feature | SSE | WebSocket |
|---------|-----|-----------|
| Direction | Server → Client | Bidirectional |
| Protocol | HTTP | WebSocket (upgrade) |
| Reconnection | Automatic | Manual |
| Binary data | No (text only) | Yes |
| Complexity | Low | Medium |
| Browser support | Good | Excellent |
| Proxy/firewall | Excellent | Sometimes issues |

## When SSE Shines

### Live Dashboards
```
Server pushes metrics, client displays.
No need for client to send data.
SSE is simpler than WebSocket.
```

### Notification Feeds
```
Events happen server-side.
Client just needs to receive them.
Auto-reconnection is valuable.
```

### Progress Updates
```
Long-running job on server.
Send progress as events.
Client displays progress bar.
```

### Real-Time Search Results
```
Query submitted via POST.
Results stream via SSE.
User sees results as they're found.
```

## When SSE Falls Short

### Bidirectional Needs
```
Chat applications: Users send AND receive messages.
Use WebSocket.
```

### Binary Data
```
Streaming video frames, binary protocols.
Use WebSocket or WebRTC.
```

### High-Frequency Updates
```
Game state at 60fps.
Use WebSocket with binary frames.
```

### Browsers Without Support
```
IE/Edge legacy didn't support SSE.
Polyfills exist, or use long polling.
```

## SSE with HTTP/2

HTTP/2 makes SSE even better:

```
HTTP/1.1:
- One SSE connection = one TCP connection
- Browser limits connections per domain (6)

HTTP/2:
- Multiple SSE streams on one connection
- No connection limit issue
- Efficient multiplexing
```

## The Tradeoffs

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| HTTP-based | Simplicity, proxy support | Binary data |
| Unidirectional | Simplicity | Client-to-server |
| Auto-reconnect | Reliability | Custom backoff |
| Text format | Debuggability | Efficiency |

## The Principle

> **SSE proves that the simplest solution is often best. For server-to-client streaming, HTTP's built-in capabilities—formalized as SSE—provide reliability and simplicity without WebSocket's complexity.**

Don't use WebSocket when SSE will do. But don't use SSE when you need bidirectional communication.

---

## Summary

- SSE streams events over HTTP with automatic reconnection
- Simple text format: data, event, id, retry fields
- Browser provides EventSource API with built-in reconnection
- Perfect for dashboards, notifications, progress updates
- Not suitable for bidirectional or binary data
- Works well with HTTP/2 multiplexing

---

*For peer-to-peer communication and real-time media, WebRTC goes beyond server-mediated connections.*
