# Chapter 19: Monitoring

> *"You can't improve what you don't measure."*
> — Peter Drucker

---

## The Fundamental Problem

### Why Does This Exist?

It's 3 AM. Your pager goes off. Users are complaining that the site is slow. You log in and stare at dozens of servers, hundreds of services, millions of requests.

Where is the problem?

- Is it the database?
- Is it one specific service?
- Is it the network?
- Is it external—an API you depend on?
- Is it everywhere?

Without monitoring, you're debugging blind. You're guessing, checking logs one by one, trying random fixes, hoping something works. Users wait. Business loses money.

The raw, primitive problem is this: **How do you understand what's happening inside a complex distributed system, especially when things go wrong?**

### The Real-World Analogy

Consider how doctors diagnose patients. They don't guess what's wrong—they measure. Heart rate, blood pressure, temperature, blood tests, imaging. These measurements tell them what's happening inside a complex system (the human body).

Modern cars have dashboards with gauges. Speed, fuel, temperature, engine warnings. You know there's a problem before the engine catches fire.

Monitoring is the dashboard for your software. It tells you what's happening before users tell you something's wrong.

---

## The Naive Solution

### What Would a Beginner Try First?

"Add logging everywhere!"

```java
logger.info("Processing order " + orderId);
logger.info("Payment processed");
logger.info("Order complete");
```

When something breaks, grep the logs.

### Why Does It Break Down?

**1. Log volume**

At scale, you generate terabytes of logs daily. Finding the relevant line is needles in haystacks.

**2. Reactive, not proactive**

Logs tell you what happened. You only check them after users complain. You've already failed.

**3. No correlation**

One request might span 20 services. Each logs independently. Correlating "what happened to request X across all services" is nearly impossible.

**4. No aggregation**

Logs are individual events. You can't easily answer: "What's our 99th percentile latency?" or "How many errors per second?"

### The Flawed Assumption

The naive approach assumes **point-in-time debugging is sufficient**. Production systems need continuous, aggregated visibility into system health.

---

## The Core Insight

### The "Aha" Moment

Here's the fundamental realization:

> **Monitoring is not about collecting data—it's about answering questions. Good monitoring lets you ask "why is this slow?" and get an answer in minutes, not hours.**

The questions you need to answer:
- Is the system healthy right now?
- How is it performing over time?
- When things fail, where exactly did they fail?
- What changed that might have caused this?

### The Three Pillars of Observability

Modern monitoring rests on three pillars:

1. **Metrics**: Aggregated numeric measurements (request rate, latency, error rate)
2. **Logs**: Detailed event records (what happened)
3. **Traces**: Request flows across services (how did request X travel?)

```
Metrics → Answer: "Is there a problem?"
Logs   → Answer: "What happened?"
Traces → Answer: "Where is the problem?"
```

### The Sticky Metaphor

**Monitoring is like instrumentation in a cockpit.**

Pilots don't fly by looking out the window—they fly by instruments. Altitude, airspeed, heading, fuel, engine health. When something's wrong, alarms sound. They know exactly which system needs attention.

Without instruments, a pilot couldn't fly through clouds. Without monitoring, you can't operate complex systems.

---

## The Mechanism

### Metrics

Numeric measurements aggregated over time:

```java
// Prometheus-style metrics
public class OrderService {
    private final Counter ordersTotal = Counter.builder("orders_total")
        .description("Total orders processed")
        .tag("status", "success")
        .register(meterRegistry);

    private final Timer orderLatency = Timer.builder("order_latency")
        .description("Time to process orders")
        .register(meterRegistry);

    public Order processOrder(OrderRequest request) {
        return orderLatency.record(() -> {
            try {
                Order order = doProcessOrder(request);
                ordersTotal.increment();
                return order;
            } catch (Exception e) {
                Counter.builder("orders_total")
                    .tag("status", "error")
                    .tag("error", e.getClass().getSimpleName())
                    .register(meterRegistry)
                    .increment();
                throw e;
            }
        });
    }
}
```

**Key Metrics (RED Method for Services):**

- **Rate**: Requests per second
- **Errors**: Errors per second (or error rate)
- **Duration**: Latency distribution (p50, p95, p99)

```
# Prometheus metrics example
http_requests_total{service="orders", status="200"} 15234
http_requests_total{service="orders", status="500"} 23
http_request_duration_seconds{service="orders", quantile="0.99"} 0.234
```

**Key Metrics (USE Method for Resources):**

- **Utilization**: How busy is the resource?
- **Saturation**: How much work is queued?
- **Errors**: How many operations failed?

```
# System metrics
cpu_usage_percent{host="server1"} 78.5
memory_used_bytes{host="server1"} 14532608000
disk_io_queue_length{host="server1"} 12
```

### Logs

Structured event records:

```java
// Structured logging (JSON format)
public class OrderService {
    private final Logger log = LoggerFactory.getLogger(OrderService.class);

    public Order processOrder(String orderId, String userId) {
        // Structured log with context
        log.info("Processing order",
            kv("orderId", orderId),
            kv("userId", userId),
            kv("action", "order_started"));

        try {
            Order order = doProcess(orderId);

            log.info("Order completed",
                kv("orderId", orderId),
                kv("userId", userId),
                kv("action", "order_completed"),
                kv("totalAmount", order.getTotal()),
                kv("itemCount", order.getItems().size()));

            return order;
        } catch (Exception e) {
            log.error("Order failed",
                kv("orderId", orderId),
                kv("userId", userId),
                kv("action", "order_failed"),
                kv("error", e.getMessage()),
                e);  // Stack trace
            throw e;
        }
    }
}

// Output (JSON):
// {"timestamp":"2024-01-15T10:30:00Z","level":"INFO","message":"Processing order",
//  "orderId":"ORD-123","userId":"USR-456","action":"order_started"}
```

### Distributed Tracing

Follow a request across services:

```java
// Using OpenTelemetry
public class OrderService {
    private final Tracer tracer;

    public Order processOrder(OrderRequest request) {
        Span span = tracer.spanBuilder("processOrder")
            .setAttribute("order.id", request.getOrderId())
            .startSpan();

        try (Scope scope = span.makeCurrent()) {
            // This creates a child span
            InventoryResult inventory = inventoryService.reserve(request.getItems());
            span.addEvent("inventory_reserved");

            // Another child span
            PaymentResult payment = paymentService.charge(request.getPayment());
            span.addEvent("payment_charged");

            return createOrder(request, inventory, payment);
        } catch (Exception e) {
            span.recordException(e);
            span.setStatus(StatusCode.ERROR, e.getMessage());
            throw e;
        } finally {
            span.end();
        }
    }
}
```

**Trace visualization:**

```
Trace: abc123 (Order checkout)
├── [200ms] API Gateway: POST /checkout
│   ├── [50ms] Order Service: processOrder
│   │   ├── [30ms] Inventory Service: reserve
│   │   ├── [80ms] Payment Service: charge ← SLOW!
│   │   └── [20ms] Database: INSERT order
│   └── [10ms] Notification Service: sendEmail
```

### Alerting

Proactive notification when things go wrong:

```yaml
# Prometheus alerting rules
groups:
- name: service_alerts
  rules:
  - alert: HighErrorRate
    expr: rate(http_requests_total{status="500"}[5m]) / rate(http_requests_total[5m]) > 0.01
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "High error rate on {{ $labels.service }}"
      description: "Error rate is {{ $value | humanizePercentage }}"

  - alert: HighLatency
    expr: histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m])) > 1
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "High latency on {{ $labels.service }}"
```

### Dashboards

Visualize metrics for human understanding:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Order Service Dashboard                       │
├─────────────────────┬───────────────────────┬───────────────────┤
│  Request Rate       │  Error Rate           │  p99 Latency      │
│  ▄▄▄▄▄▄▄▄▄▄▄       │  ▁▁▁▁▁▁▁▁▁▄▄          │  ▂▂▂▂▂▂▂▃▃▃       │
│  1.5k req/s        │  0.3%                 │  234ms            │
├─────────────────────┴───────────────────────┴───────────────────┤
│  Downstream Services                                             │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐            │
│  │ Payment: OK  │ │Inventory: OK │ │Database: WARN│            │
│  │ 45ms avg     │ │ 12ms avg     │ │ 89ms avg ▲   │            │
│  └──────────────┘ └──────────────┘ └──────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

---

## The Trade-offs

### What Do We Sacrifice?

**1. Performance overhead**

Collecting metrics and traces has CPU and memory cost. Usually <1%, but it's not zero.

**2. Storage costs**

Metrics, logs, and traces consume significant storage. Terabytes per month for large systems.

**3. Complexity**

Another set of systems to operate: Prometheus, Grafana, Jaeger, ELK stack, etc.

**4. Alert fatigue**

Too many alerts and people ignore them. Tuning alerts is an ongoing effort.

### When to Invest More/Less

**More monitoring:**
- User-facing production systems
- Microservices (more components = more to monitor)
- Systems with strict SLAs

**Less monitoring:**
- Internal tools with lenient expectations
- Batch processing where failures can be retried
- Development environments

### Connection to Other Concepts

- **Fault Tolerance** (Chapter 18): Monitoring detects failures for automated response
- **Rate Limiting** (Chapter 8): Monitor to set appropriate limits
- **Load Balancing** (Chapter 1): Health checks are monitoring
- **Microservices** (Chapter 10): Distributed tracing is essential for microservices

---

## The Evolution

### Brief History

**1990s: Basic server monitoring**

Nagios, SNMP. Server up/down, disk space, CPU.

**2010s: Application Performance Monitoring**

New Relic, AppDynamics, Datadog. Deep application visibility.

**2015+: Observability movement**

Three pillars formalized. OpenTelemetry standardization. "Observability" replaces "monitoring."

### Modern Stack

**Metrics**: Prometheus, Datadog, CloudWatch
**Logs**: ELK (Elasticsearch, Logstash, Kibana), Splunk, Loki
**Traces**: Jaeger, Zipkin, Datadog APM
**All-in-one**: Grafana (with various data sources), Datadog

### Where It's Heading

**AI-powered anomaly detection**: ML models learning normal behavior, alerting on deviations.

**Continuous profiling**: Production profiling with minimal overhead.

**OpenTelemetry standard**: One instrumentation, all observability platforms.

---

## Interview Lens

### Common Interview Questions

1. **"How would you debug a slow API?"**
   - Check metrics: Is it recent? Specific endpoint? All users?
   - Check traces: Where is time being spent?
   - Check logs: Any errors? Unusual patterns?
   - Check dependencies: Database slow? External API slow?

2. **"What metrics would you track for a web service?"**
   - RED: Rate, Errors, Duration
   - Saturation: Queue depths, connection pools
   - Business metrics: Orders per minute, signups

3. **"How do you handle alert fatigue?"**
   - Only alert on actionable conditions
   - Use severity levels appropriately
   - Aggregate related alerts
   - Regular review and tuning of thresholds

### Red Flags (Shallow Understanding)

❌ "Just check the logs"

❌ Doesn't mention metrics or traces

❌ Can't explain what to measure

❌ No concept of alerting strategy

### How to Demonstrate Deep Understanding

✅ Explain the three pillars: metrics, logs, traces

✅ Discuss RED and USE methods for choosing metrics

✅ Mention distributed tracing for microservices

✅ Know about SLIs/SLOs/SLAs

✅ Discuss alert design (actionable, meaningful thresholds)

---

## Summary

**The Problem**: You can't fix what you can't see. Complex distributed systems fail in complex ways, and debugging without visibility is guessing.

**The Insight**: Monitoring answers questions. Good monitoring lets you quickly determine if there's a problem, what the problem is, and where it's happening.

**The Mechanism**: Three pillars—Metrics (aggregated measurements), Logs (event details), Traces (request flows). Dashboards for visualization, alerts for proactive notification.

**The Trade-off**: Performance overhead and operational complexity for visibility and faster incident response.

**The Evolution**: From basic server monitoring → application performance monitoring → observability with metrics, logs, and traces integrated.

**The First Principle**: Observability is not a feature you add—it's a property your system has. Build observable systems from the start.

---

*Next: [Chapter 20: Authentication & Authorization](./20-authn-authz.md)—where we learn how to know who users are and what they're allowed to do.*
