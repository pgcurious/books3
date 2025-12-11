# Injection Annotations

## Wiring Your Application Together

---

## Overview

| Annotation | Purpose |
|------------|---------|
| `@Autowired` | Inject dependencies automatically |
| `@Qualifier` | Specify which bean to inject |
| `@Primary` | Mark a bean as the default choice |
| `@Value` | Inject property values |
| `@Resource` | JSR-250 injection by name |
| `@Inject` | JSR-330 standard injection |

---

## @Autowired - Automatic Dependency Injection

### Constructor Injection (Recommended)

```java
@Service
public class OrderService {

    private final UserRepository userRepository;
    private final PaymentGateway paymentGateway;
    private final EmailService emailService;

    // @Autowired is optional on single constructor (Spring 4.3+)
    public OrderService(
        UserRepository userRepository,
        PaymentGateway paymentGateway,
        EmailService emailService
    ) {
        this.userRepository = userRepository;
        this.paymentGateway = paymentGateway;
        this.emailService = emailService;
    }
}
```

**Why constructor injection is best:**
- Dependencies are explicit
- Fields can be `final`
- Easy to test (just pass mocks)
- Fails fast if dependency is missing

### Field Injection (Not Recommended)

```java
@Service
public class OrderService {

    @Autowired
    private UserRepository userRepository;  // Not final, harder to test

    @Autowired
    private PaymentGateway paymentGateway;
}
```

**Why field injection is discouraged:**
- Can't make fields `final`
- Harder to test (need reflection)
- Hides dependencies
- Can create circular dependencies silently

### Setter Injection (Optional Dependencies)

```java
@Service
public class OrderService {

    private final UserRepository userRepository;
    private NotificationService notificationService;

    public OrderService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    // Optional dependency
    @Autowired(required = false)
    public void setNotificationService(NotificationService notificationService) {
        this.notificationService = notificationService;
    }
}
```

### Method Injection

```java
@Service
public class CacheService {

    private CacheManager cacheManager;

    @Autowired
    public void configure(CacheManager cacheManager) {
        this.cacheManager = cacheManager;
        // Can do additional setup here
    }
}
```

### Collection Injection

```java
@Service
public class NotificationService {

    private final List<NotificationChannel> channels;

    // Injects ALL beans implementing NotificationChannel
    public NotificationService(List<NotificationChannel> channels) {
        this.channels = channels;
    }

    public void notify(String message) {
        channels.forEach(channel -> channel.send(message));
    }
}

@Component
class EmailChannel implements NotificationChannel { ... }

@Component
class SmsChannel implements NotificationChannel { ... }

@Component
class SlackChannel implements NotificationChannel { ... }
```

### Map Injection

```java
@Service
public class PaymentService {

    private final Map<String, PaymentGateway> gateways;

    // Injects ALL beans as Map<beanName, bean>
    public PaymentService(Map<String, PaymentGateway> gateways) {
        this.gateways = gateways;
    }

    public void process(String gatewayName, Payment payment) {
        PaymentGateway gateway = gateways.get(gatewayName);
        if (gateway == null) {
            throw new IllegalArgumentException("Unknown gateway: " + gatewayName);
        }
        gateway.process(payment);
    }
}
```

---

## @Qualifier - Choosing Between Multiple Beans

### Problem: Multiple Implementations

```java
public interface PaymentGateway {
    void process(Payment payment);
}

@Component
class StripeGateway implements PaymentGateway { ... }

@Component
class PayPalGateway implements PaymentGateway { ... }

@Service
public class PaymentService {
    // ERROR: Which one to inject?
    public PaymentService(PaymentGateway gateway) { }
}
```

### Solution: @Qualifier

```java
@Component("stripe")
class StripeGateway implements PaymentGateway { ... }

@Component("paypal")
class PayPalGateway implements PaymentGateway { ... }

@Service
public class PaymentService {

    private final PaymentGateway gateway;

    public PaymentService(@Qualifier("stripe") PaymentGateway gateway) {
        this.gateway = gateway;
    }
}
```

### Custom Qualifier Annotations

```java
// Define custom qualifiers
@Qualifier
@Retention(RetentionPolicy.RUNTIME)
@Target({ ElementType.FIELD, ElementType.PARAMETER, ElementType.TYPE })
public @interface Stripe { }

@Qualifier
@Retention(RetentionPolicy.RUNTIME)
@Target({ ElementType.FIELD, ElementType.PARAMETER, ElementType.TYPE })
public @interface PayPal { }

// Use on beans
@Component
@Stripe
class StripeGateway implements PaymentGateway { ... }

@Component
@PayPal
class PayPalGateway implements PaymentGateway { ... }

// Use in injection
@Service
public class PaymentService {
    public PaymentService(@Stripe PaymentGateway gateway) { }
}
```

---

## @Primary - Default Bean Selection

### Basic Usage

```java
@Component
@Primary  // This is the default
class StripeGateway implements PaymentGateway { ... }

@Component
class PayPalGateway implements PaymentGateway { ... }

@Service
public class PaymentService {
    // Gets StripeGateway (the @Primary)
    public PaymentService(PaymentGateway gateway) { }
}

@Service
public class AlternativeService {
    // Override with @Qualifier
    public AlternativeService(@Qualifier("payPalGateway") PaymentGateway gateway) { }
}
```

### @Primary with @Bean

```java
@Configuration
public class GatewayConfig {

    @Bean
    @Primary
    public PaymentGateway stripeGateway() {
        return new StripeGateway();
    }

    @Bean
    public PaymentGateway paypalGateway() {
        return new PayPalGateway();
    }
}
```

---

## @Value - Property Injection

### From application.properties

```properties
# application.properties
app.name=My Application
app.timeout=30
app.enabled=true
app.api.url=https://api.example.com
```

```java
@Service
public class AppService {

    @Value("${app.name}")
    private String appName;

    @Value("${app.timeout}")
    private int timeout;

    @Value("${app.enabled}")
    private boolean enabled;

    @Value("${app.api.url}")
    private String apiUrl;
}
```

### With Default Values

```java
@Value("${app.name:Default App}")
private String appName;

@Value("${app.timeout:60}")
private int timeout;

@Value("${app.feature.enabled:false}")
private boolean featureEnabled;
```

### In Constructor

```java
@Service
public class ApiClient {

    private final String apiUrl;
    private final int timeout;

    public ApiClient(
        @Value("${api.url}") String apiUrl,
        @Value("${api.timeout:30}") int timeout
    ) {
        this.apiUrl = apiUrl;
        this.timeout = timeout;
    }
}
```

### SpEL Expressions

```java
// System properties
@Value("#{systemProperties['user.home']}")
private String userHome;

// Environment variables
@Value("#{environment['PATH']}")
private String path;

// Other beans
@Value("#{configBean.apiUrl}")
private String apiUrl;

// Expressions
@Value("#{${app.timeout} * 1000}")  // Convert seconds to milliseconds
private int timeoutMs;

@Value("#{${app.enabled} ? 'yes' : 'no'}")
private String enabledText;

// List from comma-separated
@Value("#{'${app.allowed-origins}'.split(',')}")
private List<String> allowedOrigins;
```

### Arrays and Lists

```properties
# application.properties
app.admins=alice,bob,charlie
app.ports=8080,8081,8082
```

```java
// As array
@Value("${app.admins}")
private String[] admins;

// As list (with SpEL)
@Value("#{'${app.admins}'.split(',')}")
private List<String> adminList;

@Value("${app.ports}")
private int[] ports;
```

---

## @Resource and @Inject - JSR Standards

### @Resource (JSR-250)

```java
@Service
public class PaymentService {

    @Resource(name = "stripeGateway")  // Inject by name
    private PaymentGateway gateway;
}
```

**@Resource vs @Autowired:**
- `@Resource` matches by name first, then by type
- `@Autowired` matches by type first, then by name
- `@Resource` is a Java standard (JSR-250)

### @Inject (JSR-330)

```java
@Service
public class PaymentService {

    @Inject  // Same as @Autowired
    private PaymentGateway gateway;

    @Inject
    @Named("stripe")  // Same as @Qualifier
    private PaymentGateway stripeGateway;
}
```

**@Inject vs @Autowired:**
- `@Inject` doesn't have `required` attribute
- `@Inject` uses `@Named` instead of `@Qualifier`
- `@Inject` is a Java standard (JSR-330)

---

## ObjectProvider - Lazy/Optional Injection

### Lazy Injection

```java
@Service
public class OrderService {

    private final ObjectProvider<ExpensiveService> expensiveServiceProvider;

    public OrderService(ObjectProvider<ExpensiveService> expensiveServiceProvider) {
        this.expensiveServiceProvider = expensiveServiceProvider;
    }

    public void process() {
        // Only created when actually needed
        ExpensiveService service = expensiveServiceProvider.getObject();
        service.doWork();
    }
}
```

### Optional Injection

```java
@Service
public class NotificationService {

    private final ObjectProvider<SmsService> smsProvider;

    public NotificationService(ObjectProvider<SmsService> smsProvider) {
        this.smsProvider = smsProvider;
    }

    public void notify(String message) {
        // Doesn't fail if SmsService doesn't exist
        smsProvider.ifAvailable(sms -> sms.send(message));
    }
}
```

### Getting All Beans

```java
@Service
public class ValidatorService {

    private final ObjectProvider<Validator> validators;

    public ValidatorService(ObjectProvider<Validator> validators) {
        this.validators = validators;
    }

    public void validate(Object obj) {
        validators.stream().forEach(v -> v.validate(obj));
    }
}
```

---

## Injection Patterns Comparison

```java
// Constructor injection (BEST)
@Service
public class ServiceA {
    private final Dependency dep;

    public ServiceA(Dependency dep) {
        this.dep = dep;
    }
}

// Field injection (AVOID)
@Service
public class ServiceB {
    @Autowired
    private Dependency dep;
}

// Setter injection (for optional)
@Service
public class ServiceC {
    private Dependency dep;

    @Autowired(required = false)
    public void setDep(Dependency dep) {
        this.dep = dep;
    }
}

// ObjectProvider (lazy/optional)
@Service
public class ServiceD {
    private final ObjectProvider<Dependency> depProvider;

    public ServiceD(ObjectProvider<Dependency> depProvider) {
        this.depProvider = depProvider;
    }
}
```

---

## Key Takeaways

1. **Use constructor injection** - it's explicit, testable, and supports final fields
2. **@Autowired is optional** on single constructors
3. **@Qualifier picks specific beans** when multiple exist
4. **@Primary marks the default** bean
5. **@Value injects properties** - use defaults for safety
6. **ObjectProvider for lazy/optional** dependencies
7. **Collections are injected automatically** with all matching beans

---

*Next: [Scope & Lifecycle](./07-scope-lifecycle.md)*
