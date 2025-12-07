# Chapter 9: API Gateway

> *"Any problem in computer science can be solved with another layer of indirection."*
> — David Wheeler

---

## The Fundamental Problem

### Why Does This Exist?

You've embraced microservices. Your e-commerce platform now has:

- User service (port 8001)
- Product service (port 8002)
- Cart service (port 8003)
- Order service (port 8004)
- Payment service (port 8005)
- Review service (port 8006)
- Recommendation service (port 8007)

A mobile app needs to show a product page. That page requires data from products, reviews, recommendations, and cart (to show if item is already added). The app must make 4 separate HTTP calls to 4 different services.

Now multiply this by every screen in your app. Your mobile app is making dozens of network calls per screen, managing connections to dozens of services, handling authentication for each one, retrying failures independently.

The raw, primitive problem is this: **How do you present a unified, coherent API to clients when your backend is actually dozens of independent services?**

### The Real-World Analogy

Consider a corporate headquarters with many departments: Legal, HR, Finance, Engineering, Marketing. Each has its own office, processes, and experts.

**Without a receptionist (no gateway):**

You walk into the building. You need to find Legal on floor 3, then HR on floor 7, then Finance on floor 2. You navigate the building yourself, knock on each door, explain who you are each time, and hope you find the right person.

**With a receptionist (gateway):**

You walk in, tell the receptionist "I'm here for new employee onboarding." They route you to HR, let HR know you're coming, give you a visitor badge (authentication), and tell you where to go. One point of contact hides internal complexity.

---

## The Naive Solution

### What Would a Beginner Try First?

"Just have clients call each service directly!"

Clients know about all services. They make calls as needed. Services expose their APIs directly.

### Why Does It Break Down?

**1. Client complexity**

Clients must know about every service's location, API format, and authentication. Adding a new service means updating all clients.

**2. Cross-cutting concerns multiply**

Authentication, rate limiting, logging, CORS—each service implements these independently. Changes require updating N services.

**3. Chatty clients**

A single user action might require 10 API calls. Mobile networks are slow and unreliable; many calls means many failure points.

**4. Protocol mismatch**

Your services speak gRPC. Your web app speaks REST. Your mobile app wants GraphQL. Who translates?

**5. Security exposure**

Every service is internet-facing. Attack surface is huge.

### The Flawed Assumption

Direct client-to-service communication assumes **clients can and should manage backend complexity**. An API gateway asserts that **clients shouldn't know or care about internal architecture**.

---

## The Core Insight

### The "Aha" Moment

Here's the fundamental realization:

> **By placing a single entry point in front of all services, you can handle cross-cutting concerns once and present an API optimized for clients, not for internal organization.**

The API gateway is an **abstraction layer**. To clients, there's one API. Behind it, there could be 10 services or 1,000—clients don't know and don't care.

### The Trade-off Acceptance

An API gateway accepts:
- **Additional latency**: One more network hop
- **Single point of failure**: Gateway must be highly available
- **Potential bottleneck**: All traffic flows through it
- **Development overhead**: Gateway needs maintenance

We accept these in exchange for simplified clients, centralized cross-cutting concerns, and decoupled evolution.

### The Sticky Metaphor

**An API gateway is like a waiter at a restaurant.**

Customers (clients) don't walk into the kitchen (services) and talk to each cook (microservice). They tell the waiter what they want. The waiter translates the order, coordinates with kitchen, bar, and dessert stations, and brings back one coherent meal.

Customers don't know that pasta and dessert come from different stations. They order "the special with dessert" and get a complete experience.

---

## The Mechanism

### Building an API Gateway From Scratch

**Core Responsibilities:**

```java
public class ApiGateway {

    // 1. ROUTING - Direct requests to correct service
    public Response handleRequest(Request request) {
        Route route = routingTable.findRoute(request.getPath());
        ServiceClient client = serviceRegistry.getClient(route.getServiceName());
        return client.forward(request);
    }

    // 2. AUTHENTICATION - Verify identity
    public boolean authenticate(Request request) {
        String token = request.getHeader("Authorization");
        return authService.validateToken(token);
    }

    // 3. RATE LIMITING - Protect services
    public boolean checkRateLimit(Request request) {
        String userId = extractUserId(request);
        return rateLimiter.allowRequest(userId);
    }

    // 4. AGGREGATION - Combine multiple service calls
    public ProductPageResponse getProductPage(String productId) {
        CompletableFuture<Product> product = productService.getProduct(productId);
        CompletableFuture<List<Review>> reviews = reviewService.getReviews(productId);
        CompletableFuture<List<Product>> recommended = recommendationService.get(productId);

        return new ProductPageResponse(
            product.join(),
            reviews.join(),
            recommended.join()
        );
    }
}
```

**Request Flow:**

```
┌────────────────────────────────────────────────────────────────────┐
│                           API Gateway                               │
│                                                                     │
│  ┌──────────┐  ┌───────────┐  ┌────────────┐  ┌─────────────────┐ │
│  │   SSL    │→ │   Rate    │→ │   Auth     │→ │    Routing      │ │
│  │ Termination│ │  Limiting │  │ Validation │  │  & Aggregation  │ │
│  └──────────┘  └───────────┘  └────────────┘  └─────────────────┘ │
│                                                        │            │
└────────────────────────────────────────────────────────│────────────┘
                                                         │
                         ┌───────────────────────────────┼───────────┐
                         │                               │           │
                         ▼                               ▼           ▼
                  ┌────────────┐                 ┌────────────┐  ┌────────────┐
                  │   User     │                 │  Product   │  │  Review    │
                  │  Service   │                 │  Service   │  │  Service   │
                  └────────────┘                 └────────────┘  └────────────┘
```

### Gateway Patterns

**Request Routing**

```java
public class RoutingGateway {
    private final Map<String, ServiceEndpoint> routes = new HashMap<>();

    public void registerRoute(String path, ServiceEndpoint endpoint) {
        routes.put(path, endpoint);
    }

    public Response route(Request request) {
        // /users/* → user-service
        // /products/* → product-service
        // /orders/* → order-service

        ServiceEndpoint endpoint = routes.entrySet().stream()
            .filter(e -> request.getPath().startsWith(e.getKey()))
            .findFirst()
            .map(Map.Entry::getValue)
            .orElseThrow(() -> new NotFoundException("No route"));

        return endpoint.forward(request);
    }
}
```

**API Aggregation/Composition**

```java
public class AggregatingGateway {

    // One client call → multiple service calls
    @GetMapping("/api/homepage")
    public HomepageResponse getHomepage(String userId) {
        // Make parallel calls to multiple services
        CompletableFuture<UserProfile> profile =
            userService.getProfile(userId);
        CompletableFuture<List<Product>> recommended =
            recommendationService.getForUser(userId);
        CompletableFuture<List<Order>> recentOrders =
            orderService.getRecent(userId, 5);
        CompletableFuture<Cart> cart =
            cartService.getCart(userId);

        // Combine into single response
        CompletableFuture.allOf(profile, recommended, recentOrders, cart).join();

        return new HomepageResponse(
            profile.join(),
            recommended.join(),
            recentOrders.join(),
            cart.join()
        );
    }
}
```

**Protocol Translation**

```java
public class ProtocolGateway {

    // Clients speak REST, services speak gRPC
    @PostMapping("/api/users")
    public UserResponse createUser(@RequestBody CreateUserRequest request) {
        // Translate REST to gRPC
        UserServiceGrpc.CreateUserRequest grpcRequest =
            UserServiceGrpc.CreateUserRequest.newBuilder()
                .setName(request.getName())
                .setEmail(request.getEmail())
                .build();

        // Call gRPC service
        UserServiceGrpc.UserResponse grpcResponse =
            userServiceStub.createUser(grpcRequest);

        // Translate gRPC to REST
        return new UserResponse(
            grpcResponse.getId(),
            grpcResponse.getName()
        );
    }
}
```

**Backend for Frontend (BFF)**

Different gateways for different clients:

```
┌──────────────┐    ┌──────────────────┐
│  Mobile App  │───►│  Mobile Gateway  │──┐
└──────────────┘    │  (minimal data)  │  │
                    └──────────────────┘  │
                                          │
┌──────────────┐    ┌──────────────────┐  │   ┌────────────┐
│   Web App    │───►│   Web Gateway    │──┼──►│  Services  │
└──────────────┘    │  (rich data)     │  │   └────────────┘
                    └──────────────────┘  │
                                          │
┌──────────────┐    ┌──────────────────┐  │
│  Partner API │───►│ Partner Gateway  │──┘
└──────────────┘    │  (different auth)│
                    └──────────────────┘
```

### Cross-Cutting Concerns

**Centralized Authentication**

```java
@Component
public class AuthFilter implements Filter {
    private final JwtValidator jwtValidator;

    @Override
    public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain) {
        HttpServletRequest request = (HttpServletRequest) req;
        String token = request.getHeader("Authorization");

        if (token == null || !jwtValidator.validate(token)) {
            ((HttpServletResponse) res).setStatus(401);
            return;
        }

        // Add user info to request for downstream services
        Claims claims = jwtValidator.getClaims(token);
        request.setAttribute("userId", claims.getSubject());

        chain.doFilter(req, res);
    }
}
```

**Response Transformation**

```java
public class ResponseTransformer {
    // Hide internal error details
    public Response transformError(Exception e) {
        if (e instanceof NotFoundException) {
            return Response.status(404).body("Resource not found");
        }
        // Don't expose internal errors
        log.error("Internal error", e);
        return Response.status(500).body("Internal server error");
    }

    // Consistent response format
    public Response wrapResponse(Object data) {
        return Response.ok(new ApiResponse(
            "success",
            data,
            Instant.now()
        ));
    }
}
```

---

## The Trade-offs

### What Do We Sacrifice?

**1. Added latency**

Every request goes through an additional hop. Typically 1-10ms, but it adds up.

**2. Single point of failure**

If the gateway is down, everything is down. Must be highly available.

**3. Development bottleneck**

Gateway changes might be required for new services. Can become a team bottleneck.

**4. Complexity**

Gateway itself is a complex piece of software that requires maintenance.

### When NOT To Use This

- **Simple architectures**: If you have 2-3 services, a gateway might be overkill.
- **Service-to-service communication**: Internal services often communicate directly, not through the gateway.
- **Latency-critical paths**: That extra hop might be unacceptable.
- **When BFF pattern suffices**: Sometimes a thin BFF is better than a full gateway.

### Connection to Other Concepts

- **Load Balancing** (Chapter 1): Gateways often include load balancing
- **Rate Limiting** (Chapter 8): Centralized at the gateway
- **Service Discovery** (Chapter 11): Gateway needs to find services
- **Microservices** (Chapter 10): Gateways are essential for microservices

---

## The Evolution

### Brief History

**2000s: ESB (Enterprise Service Bus)**

Heavy, XML-based, often became the bottleneck. Good intentions, poor execution.

**2010s: API Gateways emerge**

Netflix Zuul, Kong, Ambassador. Lightweight, programmable, focused.

**2015+: Service meshes**

Istio, Linkerd. Gateway-like functionality distributed throughout the infrastructure.

**2020s: Multi-purpose gateways**

GraphQL federation, edge computing, serverless integration.

### Modern Implementations

**Kong**

Open source, plugin-based, Nginx under the hood.

**AWS API Gateway**

Managed service, integrates with Lambda, handles auth natively.

**Envoy/Istio**

Service mesh approach, sidecar proxies, more distributed than traditional gateway.

### Where It's Heading

**GraphQL Gateways**: Federation of GraphQL schemas across services.

**Edge Gateways**: Running gateway logic at CDN edge for lower latency.

**API-as-Product**: Gateways that manage API versions, documentation, and monetization.

---

## Interview Lens

### Common Interview Questions

1. **"Why use an API Gateway?"**
   - Unified entry point for clients
   - Cross-cutting concerns (auth, rate limiting)
   - API aggregation and transformation
   - Decouples clients from backend

2. **"How do you prevent the gateway from becoming a bottleneck?"**
   - Horizontal scaling (multiple gateway instances)
   - Efficient routing (no heavy logic in gateway)
   - Caching at gateway level
   - Consider BFF pattern for client-specific needs

3. **"What's the difference between API Gateway and Service Mesh?"**
   - Gateway: North-south traffic (external to internal)
   - Mesh: East-west traffic (internal service-to-service)
   - Gateway is a single entry point; mesh is distributed

### Red Flags (Shallow Understanding)

❌ "Put all business logic in the gateway" (should be thin)

❌ Doesn't mention high availability requirements

❌ Can't explain when NOT to use a gateway

❌ Confuses gateway with load balancer

### How to Demonstrate Deep Understanding

✅ Discuss the BFF pattern for different client types

✅ Mention gateway's role in request/response transformation

✅ Explain how to avoid gateway becoming a bottleneck

✅ Know specific implementations (Kong, AWS API Gateway, Envoy)

✅ Discuss service mesh as an evolution/alternative

---

## Curiosity Hooks

As you continue, consider:

- The gateway routes to services. But how does it know where services are? (Hint: Chapter 11, Service Discovery)

- Gateway handles external clients. What about service-to-service communication? (Hint: Chapter 10, Microservices)

- We mentioned authentication at the gateway. How does authentication actually work? (Hint: Chapter 20, AuthN & AuthZ)

- Gateway can cache responses. How does this interact with your overall caching strategy? (Hint: Chapter 2, Caching)

---

## Summary

**The Problem**: Clients shouldn't need to know about internal service architecture. Direct client-to-service communication creates coupling and complexity.

**The Insight**: A single entry point can hide backend complexity, handle cross-cutting concerns once, and present an API optimized for clients rather than internal organization.

**The Mechanism**: Request routing, protocol translation, authentication, rate limiting, response aggregation, and transformation—all in one place.

**The Trade-off**: Added latency and operational complexity for simplified clients and centralized concerns.

**The Evolution**: From ESB → dedicated API gateways → service meshes. Moving from monolithic to distributed edge processing.

**The First Principle**: External API design and internal service design are different problems. The gateway lets you optimize each independently.

---

*Next: [Chapter 16: WebSockets](./16-websockets.md)—where we learn that sometimes HTTP's request-response model just isn't enough.*
