# Chapter 7: The Traditional Way

> *"Programs must be written for people to read, and only incidentally for machines to execute."*
> — Harold Abelson

---

## The Problem: Object Creation Everywhere

Before we can appreciate what frameworks give us, we need to feel the pain of life without them.

Let's build an e-commerce application the traditional way—manually managing all object creation and wiring.

---

## A Simple Application (Not So Simple)

We need:
- `OrderService` to process orders
- `PaymentGateway` to charge credit cards
- `InventoryService` to check and update stock
- `NotificationService` to send emails
- `AuditLogger` to record all actions

Each service has its own dependencies:

```java
public class OrderService {
    private PaymentGateway paymentGateway;
    private InventoryService inventoryService;
    private NotificationService notificationService;
    private AuditLogger auditLogger;
}

public class PaymentGateway {
    private HttpClient httpClient;
    private PaymentConfig config;
    private RetryHandler retryHandler;
}

public class InventoryService {
    private DatabaseConnection database;
    private CacheService cache;
}

public class NotificationService {
    private EmailClient emailClient;
    private SmsClient smsClient;
    private TemplateEngine templateEngine;
}

public class AuditLogger {
    private FileWriter fileWriter;
    private AsyncExecutor executor;
}
```

---

## The Manual Wiring Nightmare

To create an `OrderService`, we need to create everything it depends on:

```java
public class Application {
    public static void main(String[] args) {
        // Level 3: Basic infrastructure
        FileWriter fileWriter = new FileWriter("/var/log/audit.log");
        AsyncExecutor asyncExecutor = new AsyncExecutor(4);
        HttpClient httpClient = new HttpClient();
        DatabaseConnection database = new DatabaseConnection(
            "jdbc:postgresql://localhost:5432/shop",
            "user",
            "password"
        );

        // Level 2: Configuration
        PaymentConfig paymentConfig = new PaymentConfig();
        paymentConfig.setApiKey(System.getenv("PAYMENT_API_KEY"));
        paymentConfig.setEndpoint("https://api.payments.com/v2");
        paymentConfig.setTimeout(30000);

        // Level 1: Intermediate services
        RetryHandler retryHandler = new RetryHandler(3, 1000);
        CacheService cache = new CacheService(1000, 300); // size, ttl

        EmailClient emailClient = new EmailClient(
            "smtp.email.com", 587, "apikey"
        );
        SmsClient smsClient = new SmsClient("twilio-sid", "twilio-auth");
        TemplateEngine templateEngine = new TemplateEngine("/templates");

        // Level 0: Our actual services
        PaymentGateway paymentGateway = new PaymentGateway(
            httpClient, paymentConfig, retryHandler
        );
        InventoryService inventoryService = new InventoryService(
            database, cache
        );
        NotificationService notificationService = new NotificationService(
            emailClient, smsClient, templateEngine
        );
        AuditLogger auditLogger = new AuditLogger(fileWriter, asyncExecutor);

        // Finally! The service we actually want
        OrderService orderService = new OrderService(
            paymentGateway,
            inventoryService,
            notificationService,
            auditLogger
        );

        // Now use it
        orderService.processOrder(new Order(...));
    }
}
```

**50+ lines just to create ONE service.** And we haven't even handled:
- Error handling during initialization
- Cleanup/shutdown
- Configuration from files/environment
- Different configurations for dev/test/prod

---

## The Problems Compound

### Problem 1: Rigid Dependency Order

You must create dependencies before dependents. Change one class's dependencies, and the creation order might need to change.

```java
// Before: PaymentGateway doesn't need AuditLogger
PaymentGateway gateway = new PaymentGateway(httpClient, config, retryHandler);

// After: Now it does! Must reorder.
AuditLogger auditLogger = new AuditLogger(...);  // Must create first now
PaymentGateway gateway = new PaymentGateway(
    httpClient, config, retryHandler, auditLogger  // New dependency
);
```

### Problem 2: Testing Becomes Painful

To unit test `OrderService`, you need to create (or mock) all its dependencies:

```java
@Test
void testProcessOrder() {
    // Must create ALL dependencies, even for a simple test
    PaymentGateway mockPayment = mock(PaymentGateway.class);
    InventoryService mockInventory = mock(InventoryService.class);
    NotificationService mockNotification = mock(NotificationService.class);
    AuditLogger mockAudit = mock(AuditLogger.class);

    OrderService service = new OrderService(
        mockPayment, mockInventory, mockNotification, mockAudit
    );

    // Now finally test something
    when(mockInventory.hasStock("SKU123", 2)).thenReturn(true);
    when(mockPayment.charge(any())).thenReturn(PaymentResult.SUCCESS);

    service.processOrder(testOrder);

    verify(mockPayment).charge(any());
}
```

Every test needs this setup. Miss one mock, and tests fail cryptically.

### Problem 3: No Singletons (Without Work)

What if multiple services need the same `DatabaseConnection`? You need to manage sharing manually:

```java
// Create once
DatabaseConnection database = new DatabaseConnection(...);

// Pass to everything that needs it
InventoryService inventory = new InventoryService(database, cache);
CustomerService customers = new CustomerService(database);
ReportService reports = new ReportService(database);
```

But now `database` is a variable you pass everywhere. Add a new service that needs the database? Find and update the creation code.

### Problem 4: No Flexibility at Runtime

What if you need different `PaymentGateway` implementations?

```java
PaymentGateway gateway;
if (environment.equals("test")) {
    gateway = new FakePaymentGateway();  // Doesn't charge real cards
} else if (environment.equals("development")) {
    gateway = new SandboxPaymentGateway(httpClient, sandboxConfig);
} else {
    gateway = new StripePaymentGateway(httpClient, prodConfig, retryHandler);
}
```

This logic spreads throughout your application, making it fragile.

### Problem 5: Circular Dependencies Impossible

What if `ServiceA` needs `ServiceB`, and `ServiceB` needs `ServiceA`?

```java
// This is impossible:
ServiceA a = new ServiceA(b);  // b doesn't exist yet!
ServiceB b = new ServiceB(a);  // a doesn't exist yet!

// You'd need something like:
ServiceA a = new ServiceA();
ServiceB b = new ServiceB(a);
a.setServiceB(b);  // Setter injection breaks immutability
```

---

## The Factory Pattern: A Partial Solution

One improvement: centralize object creation:

```java
public class ServiceFactory {
    private static ServiceFactory instance;
    private Map<Class<?>, Object> instances = new HashMap<>();

    public static ServiceFactory getInstance() {
        if (instance == null) {
            instance = new ServiceFactory();
            instance.initialize();
        }
        return instance;
    }

    private void initialize() {
        // Create all services in order
        DatabaseConnection database = new DatabaseConnection(...);
        instances.put(DatabaseConnection.class, database);

        CacheService cache = new CacheService(...);
        instances.put(CacheService.class, cache);

        InventoryService inventory = new InventoryService(database, cache);
        instances.put(InventoryService.class, inventory);

        // ... and so on
    }

    @SuppressWarnings("unchecked")
    public <T> T get(Class<T> clazz) {
        return (T) instances.get(clazz);
    }
}

// Usage
OrderService orderService = ServiceFactory.getInstance().get(OrderService.class);
```

**Better**, but:
- Initialization order is still manual
- Adding services requires modifying the factory
- Still tightly coupled to concrete implementations
- Testing is still difficult (must mock the factory)

---

## The Core Realization

Looking at all this code, a pattern emerges:

**We're doing the same thing over and over:**
1. Determine what class to instantiate
2. Determine what dependencies it needs
3. Get or create those dependencies
4. Call the constructor
5. Store the result for reuse

This is **mechanical work**. It doesn't require creativity or business knowledge. It's the same algorithm applied to different classes.

**What if we could automate it?**

What if we could:
1. Tell a system about our classes (via annotations)
2. Let the system figure out the dependency graph
3. Let the system create everything in the right order
4. Let the system inject dependencies automatically

This is the promise of **Inversion of Control** and **Dependency Injection**.

---

## The Insight: Don't Call Us, We'll Call You

Traditional code: **you** create your dependencies.

```java
public class OrderService {
    public OrderService() {
        this.paymentGateway = new PaymentGateway();  // YOU create it
        this.inventoryService = new InventoryService();  // YOU create it
    }
}
```

Inverted code: **someone else** gives you your dependencies.

```java
public class OrderService {
    public OrderService(PaymentGateway paymentGateway,
                       InventoryService inventoryService) {
        this.paymentGateway = paymentGateway;      // GIVEN to you
        this.inventoryService = inventoryService;  // GIVEN to you
    }
}
```

This is **Inversion of Control (IoC)**. The control of object creation has been inverted—it's no longer the responsibility of the object itself.

The "someone else" that provides dependencies is a **Container** or **IoC Container**.

---

## Benefits of Inversion

Once dependencies are provided externally:

### 1. Easy Testing

```java
@Test
void testOrderService() {
    // Inject test doubles directly
    OrderService service = new OrderService(
        new FakePaymentGateway(),
        new FakeInventoryService()
    );
    // Test without complex setup
}
```

### 2. Flexibility

```java
// The container can decide what to inject based on configuration
if (profile == "test") {
    inject(new FakePaymentGateway());
} else {
    inject(new StripePaymentGateway());
}
```

### 3. Decoupling

```java
// OrderService doesn't know or care about concrete implementations
public class OrderService {
    private final PaymentGateway paymentGateway;  // Just an interface!
}
```

### 4. Reuse

```java
// Container creates one DatabaseConnection, shares with all services
// Without any manual wiring
```

---

## What's Next

We've identified the problem: manual object creation and wiring is tedious, error-prone, and doesn't scale.

We've glimpsed the solution: Inversion of Control—letting something else manage dependencies.

In the next chapter, we'll build a simple IoC Container from scratch to understand exactly how it works. Then we'll see how Spring implements these concepts at scale.

---

## Key Takeaways

1. **Manual wiring doesn't scale** — even simple apps require lots of boilerplate
2. **Dependencies create ordering requirements** — change one class, update creation order
3. **Testing is hard** when you control your own dependencies
4. **The Factory pattern helps** but doesn't solve the fundamental problem
5. **Inversion of Control** moves dependency creation outside the class
6. **A Container** is the "something else" that manages object creation

---

*Next: [Chapter 8: The Container Pattern](./08-container-pattern.md)*
