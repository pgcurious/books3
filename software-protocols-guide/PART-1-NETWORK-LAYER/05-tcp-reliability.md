# Chapter 5: TCP—Reliable Delivery

## How We Made Unreliable Networks Reliable

---

> *"The nice thing about TCP is that it works. The bad thing about TCP is that it works in ways that are hard to understand."*
> — W. Richard Stevens

---

## The Frustration

IP delivers packets on a "best effort" basis. But you're building a file transfer system. If even one byte is lost, the file is corrupted. If bytes arrive out of order, the file is scrambled. If the receiver is overloaded, data might be lost.

You need guarantees that IP doesn't provide:
- Every byte arrives
- Bytes arrive in order
- The sender knows if delivery failed
- The receiver isn't overwhelmed

You could build this yourself... but so is everyone else. The same reliability machinery is needed for file transfer, email, remote terminals, and countless other applications.

## The World Before TCP

In the early ARPANET, applications each implemented their own reliability:

- Each application detected lost packets differently
- Each had its own retransmission logic
- Each handled congestion differently
- Bugs were common; correctness was hard to prove

The waste was enormous. Every application team was solving the same problems, often badly.

## The Insight: A Reliable Abstraction

What if the network provided a reliable **stream** abstraction?

Instead of dealing with packets, applications would see a continuous stream of bytes. The underlying complexity—packet loss, reordering, retransmission—would be invisible.

```
Application View:

Send: "Hello, World!"
Receive: "Hello, World!"

The application doesn't know or care that this was:
- Split into multiple packets
- Some packets lost and retransmitted
- Packets arrived out of order and were reassembled
- Flow was throttled to match receiver speed
```

This is TCP: the **Transmission Control Protocol**.

## The Three-Way Handshake

Before any data flows, TCP establishes a connection:

```
Client                             Server
   |                                  |
   |------- SYN (seq=100) ---------->|  "I want to connect"
   |                                  |
   |<-- SYN-ACK (seq=300, ack=101) --|  "OK, I want to connect too"
   |                                  |
   |------- ACK (ack=301) ---------->|  "Acknowledged"
   |                                  |
   |      Connection established      |
```

**Why three steps?**

1. **SYN**: Client proves it's alive, shares its initial sequence number
2. **SYN-ACK**: Server proves it's alive, shares its sequence number, acknowledges client's
3. **ACK**: Client proves it received the server's message

Two steps isn't enough: the server wouldn't know the client received its response. This is provable—a reliable channel requires at least three messages.

## Sequence Numbers and Acknowledgments

TCP numbers every byte:

```
"Hello" → bytes 1, 2, 3, 4, 5
If seq=1000, then 'H'=1000, 'e'=1001, 'l'=1002, 'l'=1003, 'o'=1004

Receiver acknowledges: "I've received up to byte 1005"
(Meaning: "Send me 1005 next")
```

This handles:

**Loss**: If no acknowledgment arrives, resend.
```
Sender: Sends bytes 1000-1004
Sender: Waits for ACK...
Sender: No ACK received, timeout!
Sender: Resends bytes 1000-1004
```

**Reordering**: Receiver buffers and reassembles.
```
Receives: bytes 1005-1009
Receives: bytes 1010-1014
Receives: bytes 1000-1004 (delayed)
Receiver assembles: 1000-1014 in correct order
```

**Duplication**: Receiver ignores duplicates based on sequence numbers.

## Flow Control: Don't Overwhelm the Receiver

What if the sender is faster than the receiver?

TCP uses a **sliding window**:

```
Receiver advertises: "I have room for 10,000 bytes"
Sender can send up to 10,000 bytes without waiting
As receiver processes data: "Now I have room for 15,000"
Window expands; sender can send more
If receiver is overwhelmed: "Window = 0"
Sender stops until receiver recovers
```

This adapts to receiver capabilities in real-time.

## Congestion Control: Don't Overwhelm the Network

Flow control protects the receiver. But what about the network?

In 1986, the internet suffered "congestion collapse"—networks became so overloaded that almost no data got through. The problem: senders transmitted as fast as possible, overwhelming routers, causing more retransmissions, creating more congestion.

TCP added **congestion control**:

### Slow Start
Start with a small sending window, then double it each round trip:

```
Round 1: Send 1 segment
Round 2: Send 2 segments
Round 3: Send 4 segments
Round 4: Send 8 segments
...exponential growth until something goes wrong
```

### Congestion Avoidance
After detecting possible congestion (packet loss), grow slowly:

```
Instead of doubling, add one segment per round trip.
Linear growth is more conservative.
```

### Fast Retransmit and Recovery
Don't wait for a timeout to retransmit:

```
If you receive 3 duplicate ACKs, a packet was probably lost.
Retransmit immediately without waiting for timeout.
```

This is **TCP's genius and curse**: it simultaneously provides reliability while preventing network collapse. But it's complex and the algorithms have evolved through many versions (Tahoe, Reno, NewReno, CUBIC, BBR).

## Connection Termination

Closing is also careful:

```
Client                             Server
   |                                  |
   |-------- FIN ------------------>|  "I'm done sending"
   |                                  |
   |<------- ACK -------------------|  "Acknowledged"
   |                                  |
   |<------- FIN -------------------|  "I'm done too"
   |                                  |
   |-------- ACK ------------------>|  "Acknowledged"
   |                                  |
   |       Connection closed          |
```

**Why so elaborate?**

Each direction is closed independently. Client might be done sending but still want to receive. The four-step close (FIN, ACK, FIN, ACK) handles this asymmetry.

There's also a TIME_WAIT state: after closing, TCP waits before fully releasing the connection to handle delayed packets that might still be in flight.

## The Head-of-Line Blocking Problem

TCP guarantees in-order delivery. This creates a problem:

```
Packets: 1, 2, 3, 4, 5

Received: 1, 2, [3 lost], 4, 5

Application sees: 1, 2, [waiting...]

Packets 4 and 5 are buffered but not delivered
because 3 hasn't arrived yet.

When 3 is retransmitted and arrives:
Application sees: 3, 4, 5 (all at once)
```

For some applications (video streaming, gaming), this is terrible. You'd rather skip packet 3 and use 4 and 5. But TCP's byte-stream abstraction doesn't allow this.

This is a fundamental tradeoff of TCP: reliability requires ordering; ordering causes head-of-line blocking.

## The Tradeoffs TCP Made

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| Reliable delivery | No lost data | Latency (retransmissions take time) |
| Ordered delivery | Simple programming model | Head-of-line blocking |
| Congestion control | Network stability | Variable throughput |
| Connection setup | Prevents spoofing | Latency (handshake cost) |
| Byte stream | Simple API | Message boundaries invisible |

## When TCP is Wrong

TCP is not always the right choice:

**Real-time applications**: Video conferencing prefers dropping frames to waiting for retransmission.

**Short-lived requests**: The handshake overhead dominates small requests.

**Multiplexed connections**: Head-of-line blocking affects all streams.

**High-latency links**: Congestion control algorithms assume certain latencies.

These cases led to alternatives: UDP for real-time, QUIC for multiplexing.

## The Principle

> **TCP transforms unreliable networks into reliable streams by adding acknowledgments, retransmission, flow control, and congestion control. This complexity is invisible to applications but essential to the internet's functioning.**

The beauty of TCP is that applications don't think about packets. They write bytes to a socket and trust they'll arrive, in order, at the other end.

The cost of TCP is latency, head-of-line blocking, and complexity in the kernel.

## Why TCP Matters Today

Understanding TCP helps you understand:

- **Why connections take time to warm up**: Slow start
- **Why bandwidth varies over time**: Congestion control
- **Why some applications use UDP**: Avoiding TCP's guarantees
- **Why HTTP/2 on TCP has issues**: Head-of-line blocking
- **Why connection pooling helps**: Avoiding handshake overhead
- **Why TCP tuning exists**: Buffer sizes, algorithms matter

---

## Summary

- TCP provides a reliable byte stream over unreliable networks
- The three-way handshake establishes connections safely
- Sequence numbers and ACKs detect and repair loss
- Flow control prevents overwhelming receivers
- Congestion control prevents overwhelming networks
- Head-of-line blocking is a fundamental tradeoff
- TCP is not always the right choice for every application

---

*TCP provides reliability but adds latency. Sometimes speed matters more than completeness. That's where UDP comes in—our next chapter.*
