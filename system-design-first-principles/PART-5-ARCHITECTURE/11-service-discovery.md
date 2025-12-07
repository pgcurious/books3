# Chapter 11: Service Discovery

> *"The only constant in life is change."*
> — Heraclitus (and Kubernetes, constantly)

---

## The Fundamental Problem

### Why Does This Exist?

You have microservices. The Order Service needs to call the Payment Service. Simple enough—just configure the URL:

```java
payment.service.url=http://192.168.1.100:8080
```

Done. Until:
- The Payment Service crashes and restarts on a different IP
- You scale Payment Service to 3 instances—which one to call?
- A new Payment Service instance spins up—how does Order Service know?
- You deploy to a new environment—all IPs are different
- The Payment Service moves to a different port

In dynamic environments (containers, cloud, auto-scaling), IP addresses and ports change constantly. Hard-coding them is impossible.

The raw, primitive problem is this: **How do services find each other when their locations change constantly?**

### The Real-World Analogy

Consider making a phone call. You don't memorize phone numbers. You look up "Dr. Smith" in your contacts (or directory), get the number, and dial. If Dr. Smith changes numbers, they update the directory. You don't need to update your brain.

The phone directory is a service registry. Looking up a name is service discovery. The indirection (name → number) allows changes without updating every caller.

---

## The Naive Solution

### What Would a Beginner Try First?

"Put all the addresses in a config file!"

```yaml
services:
  payment: http://192.168.1.100:8080
  inventory: http://192.168.1.101:8081
  users: http://192.168.1.102:8082
```

Update the file when things change. Redeploy when you scale.

### Why Does It Break Down?

**1. Manual updates don't scale**

In a Kubernetes cluster, pods come and go constantly. Containers might live for minutes. You can't manually update config files that fast.

**2. Deployment coupling**

Adding a new instance of Payment Service requires redeploying every service that calls it. You've coupled everything together.

**3. No health awareness**

The config file says the service is at this address, but is it actually healthy? Running? Accepting requests?

**4. Environment differences**

Your config file has production addresses. But what about staging? Dev? Each environment needs different configs.

### The Flawed Assumption

Static configuration assumes **service locations are stable**. In modern infrastructure, service locations are ephemeral. Service discovery embraces this.

---

## The Core Insight

### The "Aha" Moment

Here's the fundamental realization:

> **Instead of services knowing each other's addresses, services register themselves with a central directory and look up each other by name.**

The indirection through a registry allows:
- Services to come and go without updating callers
- Multiple instances to be discoverable behind one name
- Health checks to remove unhealthy instances
- Environment independence (same names, different registries)

### The Trade-off Acceptance

Service discovery accepts:
- **Additional infrastructure**: A registry to run and maintain
- **Network dependency**: Registry must be highly available
- **Lookup latency**: Extra call to find service location
- **Complexity**: Another system to understand and debug

We accept these for dynamic, self-healing service communication.

### The Sticky Metaphor

**Service discovery is like a hotel concierge.**

Guests (services) check in and tell the concierge (registry) their room number (address). When someone wants to find a guest, they ask the concierge, not wander the halls. If a guest changes rooms, they update the concierge. Other guests don't need to know about the move.

---

## The Mechanism

### Building Service Discovery From Scratch

**Step 1: Service Registry**

A central store of service instances:

```java
public class ServiceRegistry {
    private final Map<String, Set<ServiceInstance>> registry = new ConcurrentHashMap<>();

    // Services register themselves on startup
    public void register(String serviceName, ServiceInstance instance) {
        registry.computeIfAbsent(serviceName, k -> ConcurrentHashMap.newKeySet())
            .add(instance);
    }

    // Services deregister on shutdown
    public void deregister(String serviceName, ServiceInstance instance) {
        Set<ServiceInstance> instances = registry.get(serviceName);
        if (instances != null) {
            instances.remove(instance);
        }
    }

    // Callers look up services by name
    public Set<ServiceInstance> lookup(String serviceName) {
        return registry.getOrDefault(serviceName, Collections.emptySet());
    }
}

public record ServiceInstance(String id, String host, int port, Map<String, String> metadata) {}
```

**Step 2: Service Registration**

Services register themselves on startup:

```java
@Component
public class ServiceRegistration {
    private final ServiceRegistry registry;
    private final ServiceInstance self;

    @PostConstruct
    public void register() {
        // Register when starting up
        registry.register("payment-service", self);
    }

    @PreDestroy
    public void deregister() {
        // Deregister when shutting down
        registry.deregister("payment-service", self);
    }
}
```

**Step 3: Service Discovery (Client-Side)**

Callers look up and choose an instance:

```java
@Component
public class PaymentServiceClient {
    private final ServiceRegistry registry;
    private final RestTemplate restTemplate;

    public PaymentResponse charge(PaymentRequest request) {
        // Look up available instances
        Set<ServiceInstance> instances = registry.lookup("payment-service");

        if (instances.isEmpty()) {
            throw new ServiceUnavailableException("No payment-service instances");
        }

        // Choose one (simple round-robin, could be more sophisticated)
        ServiceInstance instance = chooseInstance(instances);

        // Call the service
        String url = String.format("http://%s:%d/api/charge", instance.host(), instance.port());
        return restTemplate.postForObject(url, request, PaymentResponse.class);
    }

    private ServiceInstance chooseInstance(Set<ServiceInstance> instances) {
        // Simple random selection
        return instances.stream()
            .skip(ThreadLocalRandom.current().nextInt(instances.size()))
            .findFirst()
            .orElseThrow();
    }
}
```

### Health Checks

The registry should only return healthy instances:

```java
public class HealthAwareRegistry {
    private final ScheduledExecutorService healthChecker = Executors.newScheduledThreadPool(4);

    public void register(String serviceName, ServiceInstance instance) {
        registry.register(serviceName, instance);

        // Start periodic health checks
        healthChecker.scheduleAtFixedRate(
            () -> checkHealth(serviceName, instance),
            0, 10, TimeUnit.SECONDS
        );
    }

    private void checkHealth(String serviceName, ServiceInstance instance) {
        try {
            boolean healthy = httpClient.get(
                String.format("http://%s:%d/health", instance.host(), instance.port())
            ).isSuccessful();

            if (!healthy) {
                markUnhealthy(serviceName, instance);
            }
        } catch (Exception e) {
            markUnhealthy(serviceName, instance);
        }
    }

    public Set<ServiceInstance> lookup(String serviceName) {
        // Only return healthy instances
        return registry.getHealthyInstances(serviceName);
    }
}
```

### Discovery Patterns

**Client-Side Discovery**

Client queries registry, picks instance, calls directly:

```
┌────────┐      1. Lookup       ┌──────────┐
│ Client │ ──────────────────►  │ Registry │
│        │ ◄────────────────── │          │
└────┬───┘  2. Instance list    └──────────┘
     │
     │ 3. Direct call
     ▼
┌─────────────┐
│   Service   │
│  Instance   │
└─────────────┘
```

```java
// Client-side: Netflix Eureka, Consul client
public class ClientSideDiscovery {
    public Response callService(String serviceName, Request request) {
        List<ServiceInstance> instances = registry.getInstances(serviceName);
        ServiceInstance chosen = loadBalancer.choose(instances);
        return httpClient.call(chosen, request);
    }
}
```

**Server-Side Discovery**

Client calls a load balancer that handles discovery:

```
┌────────┐                    ┌───────────────┐      ┌──────────┐
│ Client │ ─── Request ────►  │ Load Balancer │ ◄──► │ Registry │
│        │ ◄── Response ───── │               │      └──────────┘
└────────┘                    └───────┬───────┘
                                      │
                              ┌───────┴───────┐
                              ▼               ▼
                        ┌─────────┐     ┌─────────┐
                        │ Service │     │ Service │
                        │ Inst. 1 │     │ Inst. 2 │
                        └─────────┘     └─────────┘
```

```java
// Server-side: AWS ALB, Kubernetes Services
// Client just calls the load balancer address
// Discovery is handled by infrastructure
public class ServerSideDiscovery {
    private final String loadBalancerUrl;

    public Response callService(Request request) {
        // Client doesn't know about individual instances
        return httpClient.post(loadBalancerUrl + "/api/endpoint", request);
    }
}
```

### DNS-Based Discovery

Use DNS for discovery—services register DNS records:

```
payment-service.prod.internal → 10.0.1.5, 10.0.1.6, 10.0.1.7

// Client queries DNS
nslookup payment-service.prod.internal
→ Returns multiple IPs
→ Client picks one
```

Kubernetes uses this: `payment-service.default.svc.cluster.local`

---

## The Trade-offs

### What Do We Sacrifice?

**1. Registry availability**

If the registry is down, services can't find each other. Registry must be highly available.

**2. Stale information**

Between health checks, the registry might return instances that just became unhealthy.

**3. Complexity**

Another infrastructure component to operate, monitor, and troubleshoot.

**4. Client library dependency**

Client-side discovery requires every service to include discovery logic.

### When NOT To Use This

- **Static infrastructure**: Fixed VMs with stable IPs might not need dynamic discovery.
- **Very simple setups**: Two services talking to each other—just configure the address.
- **Monolith**: One service, nothing to discover.

### Connection to Other Concepts

- **Load Balancing** (Chapter 1): Discovery finds instances, load balancing distributes traffic
- **Microservices** (Chapter 10): Service discovery is essential for microservices
- **Fault Tolerance** (Chapter 18): Health checks prevent routing to failed instances
- **API Gateway** (Chapter 9): Gateway uses discovery to find backend services

---

## The Evolution

### Brief History

**2000s: DNS and hardcoding**

Services talked to well-known hosts. Manual updates when things changed.

**2010s: Purpose-built registries**

Netflix Eureka, HashiCorp Consul, Apache ZooKeeper. Dynamic registration and discovery.

**2015+: Container orchestration**

Kubernetes built-in service discovery. Services get DNS names automatically.

### Modern Implementations

**Kubernetes Services**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: payment-service
spec:
  selector:
    app: payment
  ports:
    - port: 80
      targetPort: 8080

# Now other pods can call:
# http://payment-service:80/api/charge
# Kubernetes handles discovery and load balancing
```

**Consul**

```java
// Register with Consul
consulClient.agentServiceRegister(
    ImmutableRegistration.builder()
        .id("payment-1")
        .name("payment")
        .address("10.0.1.5")
        .port(8080)
        .check(Registration.RegCheck.http("http://10.0.1.5:8080/health", 10))
        .build()
);

// Discover via Consul
List<ServiceInstance> instances = consulClient.healthServiceInstances("payment").getResponse();
```

**AWS Cloud Map**

Managed service discovery for AWS:

```java
// Services register to Cloud Map namespace
// Other services discover via DNS or API
// http://payment.prod.local → resolves to healthy instances
```

### Where It's Heading

**Service Mesh**: Istio, Linkerd handle discovery transparently. Your code doesn't even know.

**Multi-cluster discovery**: Services discovering each other across Kubernetes clusters and clouds.

---

## Interview Lens

### Common Interview Questions

1. **"How do services find each other in a microservices architecture?"**
   - Service registry (Consul, Eureka, etcd)
   - Services register on startup, deregister on shutdown
   - Callers lookup by service name
   - Health checks ensure only healthy instances returned

2. **"Client-side vs. server-side discovery?"**
   - Client-side: Client queries registry, chooses instance (more control, more client logic)
   - Server-side: Load balancer handles discovery (simpler client, more infrastructure)

3. **"What happens if the registry goes down?"**
   - Clients might cache last known instances
   - Retry to registry with backoff
   - Registry itself should be highly available (clustered)

### Red Flags (Shallow Understanding)

❌ "Just put IPs in a config file"

❌ Doesn't mention health checks

❌ Can't explain client-side vs. server-side

❌ Ignores registry availability concerns

### How to Demonstrate Deep Understanding

✅ Explain the registry pattern and health checks

✅ Compare discovery implementations (DNS, Consul, Kubernetes)

✅ Discuss graceful degradation when registry is unavailable

✅ Mention caching of discovered instances

---

## Summary

**The Problem**: In dynamic environments, service locations change constantly. Hard-coded addresses don't work.

**The Insight**: Decouple service names from addresses through a registry. Services register their location; callers look up by name.

**The Mechanism**: Central registry, service registration on startup, lookup by name, health checks to filter unhealthy instances.

**The Trade-off**: Additional infrastructure dependency and complexity for dynamic, self-healing service communication.

**The Evolution**: From DNS → purpose-built registries → platform-provided discovery (Kubernetes).

**The First Principle**: Names are stable; locations are ephemeral. Build on names, not addresses.

---

*Next: [Chapter 12: CDNs](./12-cdns.md)—where we learn that the fastest way to serve content is to already be where your users are.*
