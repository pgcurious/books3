# Chapter 10: Microservices

> *"You build it, you run it."*
> — Werner Vogels, Amazon CTO

---

## The Fundamental Problem

### Why Does This Exist?

Your e-commerce monolith has grown. It started as a clean codebase—one application, one team, one deployment. Now it's:

- 2 million lines of code
- 50 developers making changes simultaneously
- A single bug can take down the entire site
- Deployments are a two-day process with a war room
- The team that owns search can't deploy without coordinating with the team that owns checkout
- A change to the recommendation algorithm requires testing the entire application

Everyone touches the same codebase, the same database, the same deployment pipeline. Everyone is in everyone else's way.

The raw, primitive problem is this: **How do you structure a system so that teams can develop, deploy, and scale their components independently?**

### The Real-World Analogy

Consider a manufacturing conglomerate.

**Monolith approach**: One giant factory makes everything—cars, electronics, appliances. Every production line shares resources. A problem in car assembly stops electronics production. You can't upgrade the appliance line without shutting down the whole factory.

**Microservices approach**: Separate factories for cars, electronics, and appliances. Each factory has its own management, budget, and release schedule. They communicate through well-defined contracts (standard shipping containers, purchase orders). A fire in the appliance factory doesn't affect car production.

---

## The Naive Solution

### What Would a Beginner Try First?

"Let's split the monolith into separate deployables!"

Take the existing code, carve it into pieces, deploy each piece separately. Ship the search module alone, the checkout module alone, etc.

### Why Does It Break Down?

**1. Distributed monolith**

If you've just moved the code but everything still shares a database and has tight coupling, you've got the worst of both worlds—network overhead plus coordination requirements.

**2. Wrong boundaries**

Slicing along existing code structure often produces services that need constant coordination. The "user service" needs the "order service" needs the "inventory service" for every request.

**3. Missing infrastructure**

Microservices need service discovery, distributed tracing, centralized logging, config management, CI/CD for each service. Without this, you drown in operational complexity.

**4. Database entanglement**

If 10 services share one database, they're not really independent. Schema changes affect everyone.

### The Flawed Assumption

The naive approach assumes **microservices are about code structure**. The real insight is that **microservices are about organizational structure and change management**.

---

## The Core Insight

### The "Aha" Moment

Here's the fundamental realization:

> **Microservices are not a technical strategy; they're an organizational strategy for enabling independent change.**

The goal isn't small services. The goal is:
- Teams that can work without coordinating with other teams
- Services that can deploy without deploying other services
- Components that can scale without scaling unrelated components

This is **Conway's Law** in action: your system architecture will mirror your communication structure. If you want independent services, you need independent teams.

### The Trade-off Acceptance

Microservices accept:
- **Network complexity**: Services communicate over networks, not function calls
- **Data consistency challenges**: No shared database means eventual consistency
- **Operational overhead**: Dozens of services to deploy, monitor, and troubleshoot
- **Distributed system complexity**: Partial failures, latency, debugging across services

We accept these in exchange for team autonomy, independent scaling, and technology flexibility.

### The Sticky Metaphor

**A monolith is like a department store; microservices are like a shopping mall.**

In a department store, everything's under one roof, one management, one checkout system. Want to change the shoe section? Better coordinate with ladies' wear—you might affect their foot traffic.

In a shopping mall, each store is independent. They share the building and common areas, but each store has its own inventory, staff, and hours. Opening a new shoe store doesn't require permission from the electronics store.

The mall has overhead (security, common areas, directories), but stores can innovate independently.

---

## The Mechanism

### Building Microservices From First Principles

**Principle 1: Domain-Driven Design**

Split by business capability, not technical layer:

```
BAD (Technical split):                GOOD (Business split):
┌─────────────────────┐              ┌─────────┐ ┌─────────┐ ┌─────────┐
│   Frontend Layer    │              │ Search  │ │ Orders  │ │Payments │
├─────────────────────┤              │ Service │ │ Service │ │ Service │
│   Business Logic    │              ├─────────┤ ├─────────┤ ├─────────┤
├─────────────────────┤              │Search DB│ │Order DB │ │PaymentDB│
│   Data Access       │              └─────────┘ └─────────┘ └─────────┘
├─────────────────────┤
│      Database       │              Each service owns its domain
└─────────────────────┘              and its data completely
```

**Principle 2: Independent Databases**

Each service owns its data:

```java
// Order Service - owns order data
public class OrderService {
    private final OrderRepository orderRepo;  // Own database

    // DON'T directly access user data
    // DO call User Service for user info
    public Order createOrder(String userId, List<Item> items) {
        UserInfo user = userServiceClient.getUser(userId);  // API call
        Order order = new Order(userId, items);
        return orderRepo.save(order);
    }
}
```

**Principle 3: API Contracts**

Services communicate through versioned, well-defined APIs:

```java
// Public API contract
public interface OrderServiceApi {
    @GetMapping("/orders/{id}")
    OrderResponse getOrder(@PathVariable String id);

    @PostMapping("/orders")
    OrderResponse createOrder(@RequestBody CreateOrderRequest request);

    // Version when making breaking changes
    @GetMapping("/v2/orders/{id}")
    OrderResponseV2 getOrderV2(@PathVariable String id);
}
```

**Principle 4: Smart Endpoints, Dumb Pipes**

Keep communication simple (HTTP, messaging). Put logic in services, not in the communication layer.

```java
// Services are smart
public class OrderService {
    public Order process(OrderRequest request) {
        // All the business logic lives here
        validateOrder(request);
        checkInventory(request.getItems());
        processPayment(request.getPayment());
        return createOrder(request);
    }
}

// Communication is dumb
// Just HTTP calls or messages—no complex routing or transformation
restTemplate.postForObject(orderServiceUrl + "/orders", request, Order.class);
```

### Service Communication

**Synchronous (Request-Response)**

```java
@Service
public class CheckoutService {
    private final RestTemplate restTemplate;

    public CheckoutResult checkout(Cart cart, PaymentInfo payment) {
        // Synchronous calls to other services
        InventoryResponse inventory = restTemplate.postForObject(
            inventoryService + "/reserve", cart.getItems(), InventoryResponse.class);

        if (!inventory.isAvailable()) {
            return CheckoutResult.failed("Items not available");
        }

        PaymentResponse paymentResult = restTemplate.postForObject(
            paymentService + "/charge", payment, PaymentResponse.class);

        if (!paymentResult.isSuccess()) {
            // Compensate - release inventory
            restTemplate.postForObject(inventoryService + "/release", cart.getItems(), Void.class);
            return CheckoutResult.failed("Payment failed");
        }

        return CheckoutResult.success(paymentResult.getOrderId());
    }
}
```

**Asynchronous (Event-Driven)**

```java
@Service
public class OrderService {
    private final EventPublisher eventPublisher;

    public Order createOrder(OrderRequest request) {
        Order order = orderRepository.save(new Order(request));

        // Publish event—don't wait for consumers
        eventPublisher.publish(new OrderCreatedEvent(
            order.getId(),
            order.getItems(),
            order.getCustomerId()
        ));

        return order;
    }
}

// Other services react to events
@EventListener
public class InventoryEventHandler {
    @OnEvent("OrderCreated")
    public void onOrderCreated(OrderCreatedEvent event) {
        inventoryService.reserveItems(event.getItems());
    }
}

@EventListener
public class NotificationEventHandler {
    @OnEvent("OrderCreated")
    public void onOrderCreated(OrderCreatedEvent event) {
        emailService.sendConfirmation(event.getCustomerId(), event.getOrderId());
    }
}
```

### The Saga Pattern

How do you do transactions across services without a shared database?

```java
// Saga: sequence of local transactions with compensating actions
public class OrderSaga {
    private final List<SagaStep> steps;

    public void execute(OrderRequest request) {
        List<SagaStep> completedSteps = new ArrayList<>();

        try {
            for (SagaStep step : steps) {
                step.execute(request);
                completedSteps.add(step);
            }
        } catch (Exception e) {
            // Rollback in reverse order
            Collections.reverse(completedSteps);
            for (SagaStep step : completedSteps) {
                step.compensate(request);
            }
            throw new SagaFailedException(e);
        }
    }
}

// Steps with compensation
class ReserveInventoryStep implements SagaStep {
    void execute(OrderRequest r) { inventoryService.reserve(r.getItems()); }
    void compensate(OrderRequest r) { inventoryService.release(r.getItems()); }
}

class ChargePaymentStep implements SagaStep {
    void execute(OrderRequest r) { paymentService.charge(r.getPayment()); }
    void compensate(OrderRequest r) { paymentService.refund(r.getPayment()); }
}
```

---

## The Trade-offs

### What Do We Sacrifice?

**1. Simplicity**

A monolith is conceptually simple. Microservices introduce network failures, data consistency challenges, and distributed debugging.

**2. Performance**

Function calls become network calls. Latency increases. You need caching, async patterns, and careful API design.

**3. Consistency**

No shared database means no ACID transactions across services. You must embrace eventual consistency.

**4. Operations**

Dozens of services to deploy, monitor, log, and troubleshoot. You need serious DevOps maturity.

### When NOT To Use This

- **Small teams**: 5 developers don't need 20 services. The overhead drowns the benefits.
- **New products**: You don't know the domain boundaries yet. Start with a monolith.
- **Simple domains**: A CRUD app doesn't need microservices.
- **No DevOps maturity**: Without CI/CD, monitoring, and automation, microservices are pain.

### Connection to Other Concepts

- **API Gateway** (Chapter 9): Single entry point for microservices
- **Service Discovery** (Chapter 11): How services find each other
- **Message Queues** (Chapter 7): Async communication between services
- **Eventual Consistency** (Chapter 15): Data consistency in microservices

---

## The Evolution

### Brief History

**2000s: SOA (Service-Oriented Architecture)**

Enterprise services with heavy protocols (SOAP, ESB). Right idea, wrong execution.

**2011: "Microservices" coined**

Term emerged from discussions at software architecture workshops.

**2014: Martin Fowler's canonical article**

"Microservices" article defined the pattern, sparked massive adoption.

**2020s: Maturity and pushback**

Both tooling maturity and "monolith-first" counter-movement. Not everything needs microservices.

### Modern Patterns

**Service Mesh**

Infrastructure layer handling service-to-service communication:

```yaml
# Istio automatic retry, timeout, circuit breaker
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
spec:
  hosts: [order-service]
  http:
  - route:
    - destination:
        host: order-service
    retries:
      attempts: 3
      perTryTimeout: 2s
    timeout: 10s
```

**Modular Monolith**

Monolith structured as modules that could become services:

```java
// Modules with clear boundaries, but single deployment
@Module
public class OrderModule {
    // Public API
    public Order createOrder(OrderRequest request) { ... }

    // Internal—not visible to other modules
    private void validateOrder(OrderRequest request) { ... }
}
```

### Where It's Heading

**Function-as-a-Service**: Even smaller than microservices—individual functions.

**Cell-based architecture**: Groups of services as deployment units.

**AI-assisted decomposition**: Tools that suggest service boundaries.

---

## Interview Lens

### Common Interview Questions

1. **"Monolith vs. Microservices—when to use each?"**
   - Monolith: Small teams, new products, simple domains
   - Microservices: Large teams, stable domains, need independent scaling/deployment

2. **"How do you handle transactions across services?"**
   - Saga pattern with compensating transactions
   - Eventual consistency
   - Sometimes: avoid cross-service transactions by better boundary design

3. **"How do you decompose a monolith?"**
   - Identify bounded contexts (domain-driven design)
   - Strangle fig pattern—gradually replace pieces
   - Start with the most independent parts

### Red Flags (Shallow Understanding)

❌ "Microservices are always better"

❌ Doesn't mention operational complexity

❌ Can't explain distributed transaction challenges

❌ Thinks microservices are about code size

### How to Demonstrate Deep Understanding

✅ Discuss organizational benefits (team autonomy)

✅ Mention Conway's Law

✅ Explain data ownership and eventual consistency implications

✅ Know when microservices are NOT appropriate

✅ Discuss the Saga pattern for distributed transactions

---

## Curiosity Hooks

As you continue, consider:

- Services need to find each other. How do they know where other services are? (Hint: Chapter 11, Service Discovery)

- We have many services. How do we present a unified API to clients? (Hint: Chapter 9, API Gateway)

- Debugging is harder. How do we trace requests across services? (Hint: Chapter 19, Monitoring)

- Services have their own data. How do we maintain consistency? (Hint: Chapter 15, Eventual Consistency)

---

## Summary

**The Problem**: Large codebases with many teams create coordination overhead. Everyone is in everyone else's way.

**The Insight**: Microservices are an organizational strategy, not just a technical one. The goal is enabling independent change—teams that can develop, deploy, and scale without coordinating with other teams.

**The Mechanism**: Services split by business capability, each owning its data. Communication via APIs or events. Saga pattern for distributed transactions.

**The Trade-off**: Significant operational complexity, distributed system challenges, and eventual consistency—in exchange for team autonomy and independent scaling.

**The Evolution**: From SOA → microservices → service mesh → function-as-a-service. The pattern continues evolving toward finer-grained, independently deployable units.

**The First Principle**: Architecture should minimize coordination costs. If deploying one thing requires coordinating with unrelated teams, your architecture doesn't match your organization.

---

*Next: [Chapter 11: Service Discovery](./11-service-discovery.md)—where we learn how services find each other in a world where locations change constantly.*
