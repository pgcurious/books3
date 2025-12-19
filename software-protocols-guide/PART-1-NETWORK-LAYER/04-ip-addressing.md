# Chapter 4: IP—Addressing the World

## How We Gave Every Device an Identity

---

> *"The wonderful thing about the Internet is that it connects everyone. The terrible thing about the Internet is that it connects everyone."*
> — Unknown

---

## The Frustration

You have a network in New York and a network in Tokyo. Each network works perfectly internally. But how does a computer in New York send a message to a specific computer in Tokyo?

On your local network, you might use machine names or physical addresses. But the Tokyo network has its own names and addresses. There's no global directory. Different networks use different addressing schemes. How do you even describe *where* you want data to go?

## The World Before IP

In the pre-IP era, networks were islands:

- **ARPANET** had its own addressing (IMPs and hosts)
- **Phone networks** used phone numbers
- **Private networks** used proprietary schemes
- **University networks** used whatever seemed good at the time

To send data between networks, you needed:
1. Knowledge of both addressing schemes
2. Custom translation gateways
3. Manual configuration of routes

This didn't scale. The internet needed a universal addressing system.

## The Insight: A Universal Addressing Scheme

**IP (Internet Protocol)** solved this with a radical idea: every device on the internet gets a globally unique address. Regardless of which network you're on, regardless of the underlying technology, you have one address that identifies you to the world.

This seems obvious now. It was revolutionary then.

```
The IP Insight:

Instead of: "Computer 5 on Network ABC"
Use: "192.168.1.5" (a globally unique identifier)

Anyone, anywhere, can reference this address.
The routing infrastructure figures out how to reach it.
```

## IPv4: The Original Design

In 1981, IPv4 was standardized with 32-bit addresses:

```
32 bits = 2³² = 4,294,967,296 possible addresses

Represented as four numbers (0-255):
192.168.1.100
10.0.0.1
8.8.8.8

That's 4.3 billion unique addresses.
"More than we'll ever need."
```

### Why This Structure?

**Hierarchical Addressing**: Unlike phone numbers that carry geographic meaning, IP addresses carry *network* meaning:

```
IP Address: 192.168.1.100

Network Part:  192.168.1.x  (which network)
Host Part:     x.x.x.100    (which device on that network)

The split is determined by the subnet mask.
```

This hierarchy enables routing: routers don't need to know about every individual device, just how to reach networks.

### Special Addresses

Some addresses were reserved for special purposes:

```
127.0.0.1     - Localhost (this machine)
10.x.x.x      - Private networks (not routable globally)
192.168.x.x   - Private networks
224.x.x.x     - Multicast (one-to-many)
255.255.255.255 - Broadcast (everyone on local network)
```

Private addresses were critical: you could reuse the same addresses in different organizations, since they never appear on the public internet.

## What IP Actually Does

IP provides **best-effort delivery** of packets from source to destination:

### Addressing
Every packet contains source and destination IP addresses. Routers read the destination and forward toward it.

### Routing
IP doesn't specify routes. Each router independently decides where to send packets based on its routing table. Packets may take different paths; IP doesn't care.

### Fragmentation
Networks have different maximum packet sizes (MTUs). IP can break large packets into fragments and reassemble them at the destination.

### What IP Does NOT Do

- **Reliability**: Packets can be lost. IP doesn't notice.
- **Ordering**: Packets may arrive out of order. IP doesn't fix this.
- **Error correction**: If bits flip, the packet is corrupt. IP might discard it.
- **Flow control**: IP doesn't slow down if the receiver is overwhelmed.

This "dumb network" philosophy was intentional: keep the network simple, put intelligence at the endpoints. This is the **end-to-end principle**.

## The Address Exhaustion Crisis

By the 1990s, a problem was obvious: we were running out of addresses.

```
4.3 billion addresses seemed infinite in 1981.
By 1992, the internet was growing exponentially.
Calculations showed we'd run out early 2000s.
```

The internet community responded with:

### Short-term: NAT (Network Address Translation)
Hide many devices behind one public IP address:

```
Your home network:
Device 1: 192.168.1.10
Device 2: 192.168.1.11
Device 3: 192.168.1.12

All appear to the internet as one address: 73.45.123.89

NAT translates between internal and external addresses.
```

NAT broke the "every device has a unique address" model but bought us decades.

### Long-term: IPv6
Design a new protocol with vastly more addresses:

```
IPv6: 128-bit addresses = 2¹²⁸ = 340 undecillion addresses

That's 340,282,366,920,938,463,463,374,607,431,768,211,456

Approximately 4 x 10³⁸ addresses
Enough for every atom on Earth to have billions of addresses
```

## IPv6: The New Design

IPv6 isn't just "more addresses." It fixed other IPv4 problems:

```
IPv4: 192.168.1.1
IPv6: 2001:0db8:85a3:0000:0000:8a2e:0370:7334

IPv6 addresses look intimidating but follow a pattern:
- 8 groups of 4 hex digits
- Leading zeros can be omitted
- One run of zeros can be replaced with ::

Simplified: 2001:db8:85a3::8a2e:370:7334
```

### IPv6 Improvements

**No NAT Required**: Every device can have a public address again.

**Simplified Header**: Removed rarely-used fields, making routing faster.

**No Fragmentation by Routers**: Only endpoints fragment. Routers drop oversized packets and send back an error.

**Built-in Security**: IPsec was designed alongside IPv6 (though it works with IPv4 too).

**Auto-configuration**: Devices can configure their own addresses without DHCP.

## The Dual-Stack Present

Today, we live in a transition period:

```
Most networks support both IPv4 and IPv6
Devices prefer IPv6 when available
Falls back to IPv4 when needed
"Happy Eyeballs" algorithm races both connections

This transition has taken decades and is still ongoing.
```

Why so slow? Every device, every router, every firewall, every application needed updating. The installed base is massive.

## The Principle

> **IP solved the addressing problem: how to give every device a unique identity in a global network. It deliberately provides only "best effort" delivery, leaving reliability to higher layers.**

This separation was crucial. By keeping IP simple, it became universal. More complex services layer on top.

## The Tradeoffs IP Made

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| Best-effort delivery | Simplicity, speed | Reliability |
| Stateless routing | Scalability | Guaranteed paths |
| 32-bit addresses (v4) | Early simplicity | Future scalability |
| Packets not circuits | Resilience | QoS guarantees |

## Why This Matters Today

Understanding IP helps you understand:

- **Why NAT exists**: Address conservation created complexity
- **Why some services are hard behind NAT**: Inbound connections are tricky
- **Why IPv6 adoption is slow**: Network effects favor the installed base
- **Why "ping" tells you about connectivity**: It's an IP-level diagnostic
- **Why IP addresses can be spoofed**: IP has no authentication

---

## Summary

- IP provides global addressing: every device gets a unique identifier
- IPv4's 32-bit addresses are exhausted; NAT extended their life
- IPv6's 128-bit addresses provide effectively infinite addresses
- IP deliberately provides only "best effort" delivery
- The end-to-end principle keeps the network simple
- The dual-stack transition has taken decades and continues

---

*IP gets packets to the right machine, but doesn't guarantee they arrive at all. For reliability, we need TCP—our next chapter.*
