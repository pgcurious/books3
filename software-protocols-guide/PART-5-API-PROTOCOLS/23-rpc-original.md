# Chapter 23: RPC—The Original API

## Calling Functions Over the Network

---

> *"RPC's promise: make remote calls look like local calls. RPC's reality: remote calls are nothing like local calls."*
> — Jim Waldo et al., "A Note on Distributed Computing"

---

## The Frustration

You have a function on one computer that you want to call from another computer. In a single program, calling a function is trivial:

```python
result = calculate_price(order_id, quantity)
```

But what if `calculate_price` lives on another server? You need to:

1. Serialize the arguments
2. Send them over the network
3. Wait for the response
4. Deserialize the result
5. Handle network failures

Every remote call requires this plumbing. Writing it for every function is tedious and error-prone.

## The World Before RPC

Distributed communication was explicit:

```python
# Without RPC
socket = connect("pricing-server", 8080)
socket.send(serialize({"function": "calculate_price",
                       "args": [order_id, quantity]}))
response = socket.receive()
result = deserialize(response)
if response["error"]:
    handle_error(response["error"])
```

The communication details were always visible. Every call was custom.

## The Insight: Location Transparency

RPC (Remote Procedure Call) promised to hide the network:

```python
# With RPC
result = pricing_service.calculate_price(order_id, quantity)

# Same syntax whether local or remote
```

The programmer writes function calls. The RPC system handles:
- Finding the server
- Serializing arguments
- Network communication
- Deserializing results
- Returning values or errors

## How RPC Works

### Stubs and Skeletons

```
┌───────────────────────────────────────────────────────────────┐
│                        CLIENT                                  │
│  Application → Client Stub → [Serialize] → Network            │
└───────────────────────────────────────────────────────────────┘
                              │
                              ▼
                         [Network]
                              │
                              ▼
┌───────────────────────────────────────────────────────────────┐
│                        SERVER                                  │
│  Network → Server Stub → [Deserialize] → Actual Function      │
└───────────────────────────────────────────────────────────────┘
```

**Client stub**: Looks like the real function. Intercepts calls, serializes, sends.

**Server stub (skeleton)**: Receives calls, deserializes, invokes real function, returns result.

### Interface Definition Languages (IDL)

Define the contract:

```idl
// Example IDL
interface PricingService {
    double calculatePrice(int orderId, int quantity);
    Order getOrder(int orderId);
}
```

Generate stubs:

```bash
rpc_compiler pricing.idl --language=java
# Generates: PricingServiceClient.java, PricingServiceServer.java
```

Both sides agree on the contract via the IDL.

## Early RPC Systems

### Sun RPC (ONC RPC) - 1984

The original Unix RPC:

```c
// XDR (eXternal Data Representation) for serialization
program PRICING_PROG {
    version PRICING_VERS {
        double CALCULATE_PRICE(calc_args) = 1;
    } = 1;
} = 0x20000001;
```

Powers NFS (Network File System) to this day.

### DCE RPC - 1990s

Distributed Computing Environment from OSF:

- UUID-based interface identification
- Authentication integration
- Used by Microsoft for DCOM and later MS-RPC

### CORBA - 1991

Common Object Request Broker Architecture:

```idl
interface Account {
    float balance();
    void deposit(in float amount);
    void withdraw(in float amount);
};
```

Language-independent, vendor-independent... and complex.

## The RPC Fallacy

RPC tries to make remote calls look local. But they're fundamentally different:

### Latency

```
Local function call:    ~1 nanosecond
Same-machine RPC:       ~100 microseconds
Cross-datacenter RPC:   ~10 milliseconds
Cross-continent RPC:    ~100 milliseconds

That's 100,000,000x difference from local to cross-continent.
```

### Failure Modes

```
Local call can fail:
  - Exception thrown
  - Stack overflow

Remote call can also fail:
  - Network timeout
  - Server unavailable
  - Partial failure (request sent, response lost)
  - Server crashed mid-processing
  - Load balancer rerouted to different server
```

### Semantic Differences

```
Local:
  int x = func();
  int y = func();
  // x == y if func() is deterministic

Remote:
  int x = remote_func();  // Server state: A
  int y = remote_func();  // Server state changed to B
  // x != y even if function is "deterministic"
```

## The Eight Fallacies

Distributed computing has well-known fallacies:

1. **The network is reliable**
2. **Latency is zero**
3. **Bandwidth is infinite**
4. **The network is secure**
5. **Topology doesn't change**
6. **There is one administrator**
7. **Transport cost is zero**
8. **The network is homogeneous**

RPC's "location transparency" tempts developers to forget these.

## Retry Semantics

What happens when a call times out?

### At-Most-Once
Don't retry. Accept possible failure:

```
try:
    result = service.charge_credit_card(amount)
except Timeout:
    # Did it charge? We don't know.
    alert_human()
```

Safe but inconvenient.

### At-Least-Once
Retry until success:

```
while True:
    try:
        result = service.charge_credit_card(amount)
        break
    except Timeout:
        continue  # Might double-charge!
```

Dangerous for non-idempotent operations.

### Idempotent Operations
Design for safe retry:

```
# Bad: charge $50
service.charge(50)  # If retried, charges $100

# Good: charge $50 with idempotency key
service.charge(50, idempotency_key="order-123")  # Safe to retry
```

Idempotency enables at-least-once semantics safely.

## Modern RPC Evolution

RPC didn't disappear. It evolved:

```
Sun RPC → CORBA → SOAP → REST → gRPC
                         └─→ GraphQL
                         └─→ Thrift
```

Each generation learned from the previous:
- SOAP: Added XML, web standards
- REST: Embraced HTTP, dropped RPC metaphor
- gRPC: Modern binary RPC with HTTP/2

## The Principle

> **RPC solved the problem of making remote calls convenient. But its promise of "location transparency" was misleading—remote calls are fundamentally different from local calls in latency, failure modes, and semantics.**

The lesson: embrace the network's reality rather than hiding it.

## RPC Design Guidelines

### Acknowledge the Network
```
// Bad: pretend it's local
user = getUser(id)

// Better: make remoteness visible
user = await userService.getUser(id)  // async signals network
```

### Handle Failures Explicitly
```python
try:
    result = service.process(data)
except NetworkTimeout:
    # Explicit handling
    result = fallback()
except ServiceUnavailable:
    queue_for_later(data)
```

### Design for Idempotency
```protobuf
message CreateOrderRequest {
    string idempotency_key = 1;
    Order order = 2;
}
```

### Consider Batching
```
// Bad: N network calls
for user_id in user_ids:
    user = service.getUser(user_id)

// Better: 1 network call
users = service.getUsers(user_ids)
```

## RPC vs Other Patterns

| Aspect | RPC | REST | Messaging |
|--------|-----|------|-----------|
| Style | Procedure calls | Resources | Events |
| Coupling | Tight | Medium | Loose |
| Synchronous | Usually | Usually | No |
| Discovery | Interface | URLs | Topics |

---

## Summary

- RPC makes remote calls look like local calls
- Stubs and skeletons handle serialization/communication
- IDLs define contracts between client and server
- "Location transparency" is a partial lie—remote calls are different
- The Eight Fallacies remind us: networks are not transparent
- Retry semantics (at-most-once, at-least-once) have tradeoffs
- Design for idempotency, explicit failure handling, and batching

---

*RPC got dressed up in XML and web services. Let's see what SOAP brought.*
