# Chapter 9: Dependency Injection Demystified

> *"Dependency Injection is a 25-dollar term for a 5-cent concept."*
> — James Shore

---

## What Is Dependency Injection, Really?

Dependency Injection (DI) sounds complex. It's not.

**DI means: objects receive their dependencies instead of creating them.**

That's it.

```java
// Without DI: object creates its dependency
public class OrderService {
    private PaymentGateway gateway = new StripePaymentGateway();
}

// With DI: object receives its dependency
public class OrderService {
    private PaymentGateway gateway;

    public OrderService(PaymentGateway gateway) {
        this.gateway = gateway;
    }
}
```

The second version is "doing dependency injection." Someone else (the **injector**) provides the dependency.

---

## The Three Types of Injection

Dependencies can be injected in three ways:

### 1. Constructor Injection

```java
@Service
public class OrderService {
    private final PaymentGateway paymentGateway;
    private final InventoryService inventoryService;

    // Dependencies provided via constructor
    public OrderService(PaymentGateway paymentGateway,
                       InventoryService inventoryService) {
        this.paymentGateway = paymentGateway;
        this.inventoryService = inventoryService;
    }
}
```

**Pros:**
- Dependencies are **immutable** (final fields)
- Dependencies are **required** (can't create object without them)
- Easy to see all dependencies at a glance
- Easy to test (just pass mocks to constructor)

**Cons:**
- Many dependencies = many constructor parameters
- Can't handle circular dependencies

**Best for:** Most cases. This is the recommended approach.

### 2. Setter Injection

```java
@Service
public class OrderService {
    private PaymentGateway paymentGateway;
    private InventoryService inventoryService;

    // Dependencies provided via setters
    @Autowired
    public void setPaymentGateway(PaymentGateway gateway) {
        this.paymentGateway = gateway;
    }

    @Autowired
    public void setInventoryService(InventoryService service) {
        this.inventoryService = service;
    }
}
```

**Pros:**
- Dependencies can be optional
- Can handle circular dependencies
- Can be reconfigured after creation

**Cons:**
- Dependencies are mutable (can be changed)
- Object can exist in invalid state (before setters called)
- Dependencies not obvious from constructor

**Best for:** Optional dependencies, circular dependency workarounds.

### 3. Field Injection

```java
@Service
public class OrderService {
    @Autowired
    private PaymentGateway paymentGateway;

    @Autowired
    private InventoryService inventoryService;
}
```

**Pros:**
- Concise, less boilerplate

**Cons:**
- Hides dependencies (not visible without reading field annotations)
- Can't make fields final
- Hard to test without reflection or Spring context
- Violates encapsulation

**Best for:** Tests, simple prototypes. **Avoid in production code.**

---

## How the Container Performs Injection

Let's trace what happens when Spring injects a dependency:

### Constructor Injection Flow

```java
@Service
public class OrderService {
    private final PaymentGateway paymentGateway;

    public OrderService(PaymentGateway paymentGateway) {
        this.paymentGateway = paymentGateway;
    }
}
```

Spring's process (simplified):

```java
// 1. Analyze the class
Class<?> clazz = OrderService.class;
Constructor<?>[] constructors = clazz.getConstructors();
Constructor<?> constructor = constructors[0];

// 2. Get parameter types
Class<?>[] paramTypes = constructor.getParameterTypes();
// [PaymentGateway.class]

// 3. Resolve each parameter
Object[] args = new Object[paramTypes.length];
for (int i = 0; i < paramTypes.length; i++) {
    args[i] = container.getBean(paramTypes[i]);  // Get PaymentGateway bean
}

// 4. Create instance
Object instance = constructor.newInstance(args);
```

### Field Injection Flow

```java
@Service
public class OrderService {
    @Autowired
    private PaymentGateway paymentGateway;
}
```

Spring's process:

```java
// 1. Create instance (no-arg or other constructor)
Object instance = clazz.getDeclaredConstructor().newInstance();

// 2. Find @Autowired fields
for (Field field : clazz.getDeclaredFields()) {
    if (field.isAnnotationPresent(Autowired.class)) {
        // 3. Resolve dependency
        Object dependency = container.getBean(field.getType());

        // 4. Inject via reflection
        field.setAccessible(true);
        field.set(instance, dependency);
    }
}
```

---

## Qualifying Dependencies

What if multiple beans match the same type?

```java
@Service
public class StripePaymentGateway implements PaymentGateway { }

@Service
public class PayPalPaymentGateway implements PaymentGateway { }

@Service
public class OrderService {
    // Which PaymentGateway should be injected?
    public OrderService(PaymentGateway gateway) { }
}
```

### Solution 1: @Primary

```java
@Service
@Primary  // This one wins when multiple candidates exist
public class StripePaymentGateway implements PaymentGateway { }
```

### Solution 2: @Qualifier

```java
@Service
@Qualifier("stripe")
public class StripePaymentGateway implements PaymentGateway { }

@Service
@Qualifier("paypal")
public class PayPalPaymentGateway implements PaymentGateway { }

@Service
public class OrderService {
    public OrderService(@Qualifier("stripe") PaymentGateway gateway) {
        // Gets StripePaymentGateway
    }
}
```

### Solution 3: By Name

```java
@Service
public class OrderService {
    // Field name matches bean name
    @Autowired
    private PaymentGateway stripePaymentGateway;
}
```

---

## Optional Dependencies

What if a dependency might not exist?

### Using Optional<>

```java
@Service
public class NotificationService {
    private final Optional<SmsClient> smsClient;

    public NotificationService(Optional<SmsClient> smsClient) {
        this.smsClient = smsClient;
    }

    public void notify(String message) {
        smsClient.ifPresent(client -> client.send(message));
    }
}
```

### Using @Autowired(required = false)

```java
@Service
public class NotificationService {
    @Autowired(required = false)
    private SmsClient smsClient;  // Will be null if no bean exists
}
```

### Using Default Values

```java
@Service
public class NotificationService {
    private final SmsClient smsClient;

    public NotificationService(
            @Autowired(required = false) SmsClient smsClient) {
        this.smsClient = smsClient != null ? smsClient : new NoOpSmsClient();
    }
}
```

---

## Injection Patterns in Practice

### Pattern 1: Configuration Injection

```java
@Service
public class PaymentService {
    private final String apiKey;
    private final String endpoint;

    public PaymentService(
            @Value("${payment.api-key}") String apiKey,
            @Value("${payment.endpoint}") String endpoint) {
        this.apiKey = apiKey;
        this.endpoint = endpoint;
    }
}
```

### Pattern 2: List Injection

```java
// Inject ALL beans of a type
@Service
public class CompositeValidator implements Validator {
    private final List<Validator> validators;

    public CompositeValidator(List<Validator> validators) {
        this.validators = validators;  // All Validator beans!
    }

    public void validate(Object obj) {
        validators.forEach(v -> v.validate(obj));
    }
}
```

### Pattern 3: Map Injection

```java
// Inject ALL beans of a type as a map
@Service
public class PaymentRouter {
    private final Map<String, PaymentGateway> gateways;

    public PaymentRouter(Map<String, PaymentGateway> gateways) {
        // Key = bean name, Value = bean instance
        this.gateways = gateways;
    }

    public PaymentGateway getGateway(String name) {
        return gateways.get(name);
    }
}
```

### Pattern 4: Provider/ObjectFactory for Lazy Loading

```java
@Service
public class ExpensiveServiceUser {
    private final ObjectProvider<ExpensiveService> expensiveProvider;

    public ExpensiveServiceUser(ObjectProvider<ExpensiveService> provider) {
        this.expensiveProvider = provider;
        // ExpensiveService NOT created yet
    }

    public void doWork() {
        // Created on first access
        ExpensiveService service = expensiveProvider.getObject();
        service.process();
    }
}
```

---

## The Dependency Inversion Principle

DI relates to the **Dependency Inversion Principle** (the "D" in SOLID):

> High-level modules should not depend on low-level modules. Both should depend on abstractions.

```java
// WRONG: High-level depends on low-level
public class OrderService {
    private StripePaymentGateway gateway;  // Concrete class!
}

// RIGHT: Both depend on abstraction
public class OrderService {
    private PaymentGateway gateway;  // Interface!
}

public class StripePaymentGateway implements PaymentGateway { }
```

DI makes this natural:
- Define interfaces for dependencies
- Let the container inject concrete implementations
- High-level code never knows about low-level implementations

---

## Testing with Dependency Injection

DI makes testing dramatically easier:

### Without DI

```java
public class OrderService {
    private PaymentGateway gateway = new StripePaymentGateway();

    // How do you test without charging real cards?
}
```

### With DI

```java
public class OrderService {
    private final PaymentGateway gateway;

    public OrderService(PaymentGateway gateway) {
        this.gateway = gateway;
    }
}

// Test
@Test
void testOrderProcessing() {
    // Use a fake/mock
    PaymentGateway mockGateway = mock(PaymentGateway.class);
    when(mockGateway.charge(any())).thenReturn(PaymentResult.SUCCESS);

    OrderService service = new OrderService(mockGateway);
    service.processOrder(testOrder);

    verify(mockGateway).charge(any());
}
```

Constructor injection means you can test without Spring context at all.

---

## Common DI Mistakes

### Mistake 1: Service Locator Anti-Pattern

```java
// BAD: Reaching into container
@Service
public class OrderService {
    @Autowired
    private ApplicationContext context;

    public void process() {
        PaymentGateway gateway = context.getBean(PaymentGateway.class);
        // This hides the dependency!
    }
}
```

### Mistake 2: Too Many Dependencies

```java
// BAD: God object with many dependencies
@Service
public class MegaService {
    public MegaService(
            ServiceA a, ServiceB b, ServiceC c, ServiceD d,
            ServiceE e, ServiceF f, ServiceG g, ServiceH h) {
        // 8+ dependencies = design problem
    }
}
```

If you have many dependencies, the class is probably doing too much.

### Mistake 3: Circular Dependencies

```java
// BAD: A needs B, B needs A
@Service
public class ServiceA {
    public ServiceA(ServiceB b) { }
}

@Service
public class ServiceB {
    public ServiceB(ServiceA a) { }
}
```

Usually indicates a design problem. Consider:
- Extracting shared functionality to a third service
- Using events instead of direct calls
- Restructuring the dependency graph

---

## Key Takeaways

1. **DI = receiving dependencies instead of creating them**
2. **Constructor injection is preferred**: immutable, required, testable
3. **Field injection is convenient but problematic**: use sparingly
4. **Qualifiers resolve ambiguity** when multiple beans match
5. **Optional/Provider handle conditional dependencies**
6. **DI enables the Dependency Inversion Principle**
7. **DI makes testing easy**: just pass mock objects

---

*Next: [Chapter 10: The BeanFactory—Spring's Heart](../PART-3-SPRING-CORE/10-bean-factory.md)*
