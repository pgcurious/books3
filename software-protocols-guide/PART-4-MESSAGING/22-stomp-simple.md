# Chapter 22: STOMP—Simple Text Messaging

## The HTTP of Messaging Protocols

---

> *"STOMP is so simple you can test it with telnet."*
> — STOMP advocates

---

## The Frustration

You need messaging, but:

- AMQP is complex—exchangers, bindings, queuing semantics
- Kafka requires infrastructure—ZooKeeper, clusters, partitions
- MQTT is IoT-focused—QoS levels you don't need

You just want to send messages and receive messages. Like HTTP, but for messaging.

## The World Before STOMP

Adding messaging to applications was heavyweight:

```
Want simple pub-sub?
→ Install RabbitMQ, learn AMQP
→ Or set up Kafka cluster
→ Or use proprietary vendor solution

For a small feature, massive infrastructure.
```

HTTP developers asked: "Why can't messaging be as simple as HTTP?"

## The Insight: Text-Based Simplicity

STOMP (Simple/Streaming Text Oriented Messaging Protocol) is messaging's answer to HTTP:

```
SEND
destination:/queue/orders
content-type:application/json

{"order_id": 12345, "amount": 99.99}
^@
```

That's a complete message. Human-readable. No binary encoding. No complex framing.

## STOMP Frame Format

Every STOMP interaction is a frame:

```
COMMAND
header1:value1
header2:value2

Body content here
^@ (NULL character terminates)
```

That's it. Command, headers, body, null byte.

## Client Commands

### CONNECT
Start a session:

```
CONNECT
accept-version:1.2
host:broker.example.com
login:user
passcode:pass

^@
```

Server responds:

```
CONNECTED
version:1.2
session:session-12345

^@
```

### SEND
Publish a message:

```
SEND
destination:/queue/orders
content-type:text/plain

Hello, World!
^@
```

### SUBSCRIBE
Listen to a destination:

```
SUBSCRIBE
id:sub-0
destination:/queue/orders

^@
```

### UNSUBSCRIBE
Stop listening:

```
UNSUBSCRIBE
id:sub-0

^@
```

### ACK / NACK
Acknowledge or reject messages:

```
ACK
id:message-12345
subscription:sub-0

^@
```

### DISCONNECT
End session:

```
DISCONNECT
receipt:77

^@
```

## Server Commands

### MESSAGE
Deliver a message:

```
MESSAGE
subscription:sub-0
message-id:message-12345
destination:/queue/orders
content-type:text/plain

Hello, World!
^@
```

### RECEIPT
Confirm server received a frame:

```
RECEIPT
receipt-id:77

^@
```

### ERROR
Report a problem:

```
ERROR
message:Connection failed
content-type:text/plain

Invalid credentials
^@
```

## Destinations

STOMP doesn't specify destination semantics. That's broker-dependent:

```
RabbitMQ conventions:
  /queue/name     - Point-to-point queue
  /topic/name     - Publish-subscribe topic
  /exchange/name  - Direct to exchange
  /amq/queue/name - AMQP queue

ActiveMQ conventions:
  /queue/name     - Queue
  /topic/name     - Topic

The broker decides what destinations mean.
```

## STOMP Over WebSocket

STOMP is popular for browser messaging:

```javascript
// Browser client using STOMP.js
const client = new StompJs.Client({
    brokerURL: 'ws://localhost:15674/ws'
});

client.onConnect = () => {
    // Subscribe
    client.subscribe('/topic/notifications', message => {
        console.log('Received:', message.body);
    });

    // Publish
    client.publish({
        destination: '/queue/orders',
        body: JSON.stringify({order: 123})
    });
};

client.activate();
```

HTTP for web pages, WebSocket+STOMP for real-time messaging.

## Acknowledgment Modes

Three modes for message acknowledgment:

### auto
Messages acknowledged on receipt:

```
SUBSCRIBE
id:sub-0
destination:/queue/orders
ack:auto

^@
```

Simplest. Message might be lost if client crashes.

### client
Client must explicitly ACK:

```
SUBSCRIBE
id:sub-0
destination:/queue/orders
ack:client

^@

// Later, after processing:
ACK
id:message-123

^@
```

Safer. Message redelivered if not ACK'd.

### client-individual
Like client, but ACK only that specific message:

```
SUBSCRIBE
ack:client-individual
...
```

More control. ACK doesn't acknowledge earlier messages.

## Transactions

STOMP supports transactions:

```
BEGIN
transaction:tx-0

^@

SEND
destination:/queue/orders
transaction:tx-0

Order 1
^@

SEND
destination:/queue/orders
transaction:tx-0

Order 2
^@

COMMIT
transaction:tx-0

^@
```

Either both orders are sent, or neither.

## STOMP Brokers

Many brokers support STOMP:

```
RabbitMQ      - Via STOMP plugin
ActiveMQ      - Native STOMP support
Apollo        - STOMP-optimized broker
Spring        - In-memory STOMP broker
```

## STOMP vs Other Protocols

| Aspect | STOMP | AMQP | MQTT |
|--------|-------|------|------|
| Format | Text | Binary | Binary |
| Complexity | Low | High | Low |
| Debugging | Easy (telnet) | Tools needed | Tools needed |
| Browser support | WebSocket + STOMP.js | Complex | WebSocket |
| Features | Basic | Rich | IoT-focused |
| Performance | Lower | Higher | Medium |

## The Tradeoffs

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| Text format | Debuggability | Efficiency |
| Simple spec | Easy implementation | Limited features |
| Broker-defined semantics | Flexibility | Portability |
| WebSocket friendly | Browser support | Native efficiency |

## When STOMP Shines

### Browser Applications
```javascript
// Real-time notifications in web app
client.subscribe('/user/notifications', msg => {
    showNotification(JSON.parse(msg.body));
});
```

### Quick Prototypes
```bash
# Debug with telnet!
telnet broker.example.com 61613
CONNECT
accept-version:1.2
host:localhost

^@
```

### Polyglot Environments
```
Java backend → STOMP → Python worker
              STOMP → JavaScript frontend
              STOMP → Go microservice

Text-based means any language can participate.
```

## The Principle

> **STOMP brings HTTP's simplicity to messaging. When you need messaging without complexity, when debugging matters, when browsers are clients—STOMP delivers simplicity at the cost of some efficiency.**

STOMP isn't the fastest or most feature-rich. It's the most approachable.

## When to Use STOMP

**Use STOMP when:**
- Browser-based real-time features
- Quick integration/prototyping
- Debugging ease is important
- Team is familiar with HTTP/REST
- Basic pub-sub is sufficient

**Consider alternatives when:**
- High throughput needed (Kafka)
- Complex routing (AMQP)
- IoT devices (MQTT)
- Binary efficiency matters

---

## Summary

- STOMP is a text-based messaging protocol
- Frame format: COMMAND, headers, body, null terminator
- Commands: CONNECT, SEND, SUBSCRIBE, ACK, DISCONNECT
- Works over TCP or WebSocket
- Popular for browser messaging
- Simple to debug and implement

---

*We've covered how data moves asynchronously. Now let's explore how applications expose their capabilities through APIs.*
