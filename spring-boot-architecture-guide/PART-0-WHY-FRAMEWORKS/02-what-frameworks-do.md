# Chapter 2: What Frameworks Actually Do

> *"A framework is a reusable design expressed as a set of abstract classes and the way their instances collaborate."*
> — Ralph Johnson, Gang of Four

---

## Beyond "Code Reuse"

When asked "what is a framework?", many developers say "reusable code" or "a library for common tasks." But this misses the essential nature of frameworks.

A **library** is code you call. A **framework** is code that calls you.

This distinction—called **Inversion of Control**—is the defining characteristic of frameworks. And it changes everything.

---

## Libraries vs. Frameworks

### Library Model: You're in Control

```java
// You call the library when YOU decide to
import com.google.gson.Gson;

public class MyApp {
    public static void main(String[] args) {
        Gson gson = new Gson();              // You create the object
        String json = gson.toJson(myObject); // You call the method
        System.out.println(json);            // You decide what to do with result
    }
}
```

You're the orchestrator. You decide when to create objects, when to call methods, what to do with results.

### Framework Model: The Framework is in Control

```java
// The framework calls YOUR code when IT decides to
@RestController
public class MyController {

    @GetMapping("/hello")  // You declare intent
    public String hello() {
        return "Hello";    // Framework calls this method
                           // Framework decides when
                           // Framework handles the return value
    }
}
```

You're a plugin. The framework orchestrates everything. You just fill in the blanks.

---

## The Five Jobs of a Framework

Every application framework does some combination of these five jobs:

### Job 1: Lifecycle Management

The framework manages when things start, run, and stop.

**Without framework:**
```java
public static void main(String[] args) {
    // You manage everything manually
    DatabaseConnection db = new DatabaseConnection();
    db.initialize();

    HttpServer server = new HttpServer();
    server.start();

    // Handle shutdown
    Runtime.getRuntime().addShutdownHook(new Thread(() -> {
        server.stop();
        db.close();
    }));
}
```

**With framework:**
```java
@SpringBootApplication
public class MyApp {
    public static void main(String[] args) {
        SpringApplication.run(MyApp.class, args);
        // Framework handles all lifecycle
    }
}
```

The framework decides:
- When to create objects
- In what order to initialize them
- How to handle dependencies between them
- When and how to shut down gracefully

### Job 2: Dependency Resolution

The framework figures out what objects need what other objects.

**Without framework:**
```java
public class OrderService {
    private final PaymentGateway paymentGateway;
    private final InventoryService inventoryService;
    private final NotificationService notificationService;
    private final AuditLogger auditLogger;

    // You wire everything together manually
    public OrderService() {
        this.paymentGateway = new StripePaymentGateway(
            new HttpClient(),
            new StripeConfig()
        );
        this.inventoryService = new InventoryService(
            new DatabaseConnection()
        );
        this.notificationService = new NotificationService(
            new EmailClient(),
            new SmsClient()
        );
        this.auditLogger = new AuditLogger(
            new FileWriter("audit.log")
        );
    }
}
```

**With framework:**
```java
@Service
public class OrderService {
    private final PaymentGateway paymentGateway;
    private final InventoryService inventoryService;
    private final NotificationService notificationService;
    private final AuditLogger auditLogger;

    // Framework wires everything
    @Autowired
    public OrderService(
            PaymentGateway paymentGateway,
            InventoryService inventoryService,
            NotificationService notificationService,
            AuditLogger auditLogger) {
        this.paymentGateway = paymentGateway;
        this.inventoryService = inventoryService;
        this.notificationService = notificationService;
        this.auditLogger = auditLogger;
    }
}
```

The framework:
- Finds all the dependencies
- Creates them in the right order
- Injects them where needed
- Handles circular dependencies
- Manages shared vs. unique instances

### Job 3: Configuration Abstraction

The framework provides a unified way to configure behavior.

**Without framework:**
```java
// Every component has its own configuration approach
Properties dbProps = new Properties();
dbProps.load(new FileInputStream("database.properties"));
String dbUrl = dbProps.getProperty("url");

Map<String, String> env = System.getenv();
String apiKey = env.get("API_KEY");

String cacheSize = System.getProperty("cache.size", "100");

// Configuration is scattered and inconsistent
```

**With framework:**
```yaml
# application.yml - One place, one format
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/mydb

myapp:
  api-key: ${API_KEY}
  cache-size: 100
```

```java
@ConfigurationProperties(prefix = "myapp")
public class MyAppConfig {
    private String apiKey;
    private int cacheSize;
    // Framework binds properties automatically
}
```

### Job 4: Cross-Cutting Concerns

The framework handles concerns that span multiple components.

**Without framework:**
```java
public class UserService {
    public User getUser(Long id) {
        long startTime = System.currentTimeMillis();
        logger.info("getUser called with id: " + id);

        try {
            // Start transaction
            connection.setAutoCommit(false);

            // Check authorization
            if (!securityContext.hasPermission("USER_READ")) {
                throw new UnauthorizedException();
            }

            // Actual business logic (finally!)
            User user = userRepository.findById(id);

            // Commit transaction
            connection.commit();

            return user;

        } catch (Exception e) {
            connection.rollback();
            logger.error("Error in getUser", e);
            throw e;
        } finally {
            long duration = System.currentTimeMillis() - startTime;
            metricsRecorder.record("getUser.duration", duration);
        }
    }
}
```

**With framework:**
```java
@Service
public class UserService {

    @Transactional(readOnly = true)
    @PreAuthorize("hasPermission('USER_READ')")
    @Timed("getUser.duration")
    public User getUser(Long id) {
        return userRepository.findById(id);
    }
}
```

The framework intercepts method calls and adds:
- Transaction management
- Security checks
- Metrics/logging
- Caching
- Retry logic
- ...without cluttering your business code

### Job 5: Protocol Handling

The framework translates between protocols and your code.

**Without framework:**
```java
// Parse raw HTTP, call your code, format response
String requestBody = readRequestBody(socket);
Map<String, Object> json = parseJson(requestBody);
User user = new User();
user.setName((String) json.get("name"));
user.setEmail((String) json.get("email"));

User savedUser = userService.save(user);

String responseJson = toJson(savedUser);
String httpResponse = "HTTP/1.1 201 Created\r\n"
    + "Content-Type: application/json\r\n"
    + "Content-Length: " + responseJson.length() + "\r\n"
    + "\r\n"
    + responseJson;
writeResponse(socket, httpResponse);
```

**With framework:**
```java
@PostMapping("/users")
public User createUser(@RequestBody User user) {
    return userService.save(user);
}
```

The framework:
- Parses HTTP requests
- Deserializes JSON to objects
- Calls your method
- Serializes return value to JSON
- Formats HTTP response
- Handles errors appropriately

---

## The Framework Contract

When you use a framework, you enter into a **contract**:

### What You Promise (to the Framework):
- Follow naming conventions
- Put classes in expected locations
- Use annotations correctly
- Don't fight the framework's design
- Configure things the framework's way

### What the Framework Promises (to You):
- Handle boilerplate correctly
- Manage resources properly
- Call your code at the right times
- Provide consistent behavior
- Handle edge cases you didn't think of

---

## The Three Ways Frameworks "See" Your Code

For a framework to call your code, it needs to find it. Frameworks discover your code through three mechanisms:

### 1. Configuration (Explicit)

You explicitly tell the framework about your code:

```xml
<!-- XML Configuration (old way) -->
<bean id="userService" class="com.example.UserService">
    <constructor-arg ref="userRepository"/>
</bean>
```

```java
// Java Configuration (newer way)
@Configuration
public class AppConfig {
    @Bean
    public UserService userService(UserRepository repo) {
        return new UserService(repo);
    }
}
```

### 2. Annotations (Declarative)

You mark your code with metadata that the framework scans for:

```java
@Service                    // "I'm a service, please manage me"
@Repository                 // "I'm a repository, handle my exceptions"
@Controller                 // "I handle web requests"
@GetMapping("/users")       // "Route GET /users to me"
```

### 3. Convention (Implicit)

The framework assumes based on naming/location:

```
src/main/resources/
    application.properties     <- Framework looks here for config
    static/                    <- Framework serves static files from here
    templates/                 <- Framework looks here for templates

src/main/java/com/example/
    MyApplication.java         <- @SpringBootApplication expected here
```

Spring Boot heavily uses convention: put things in the right place, name them correctly, and the framework figures out what you meant.

---

## How This Relates to Java

Here's the key insight: **None of this would be possible without specific Java features.**

| Framework Capability | Enabling Java Feature |
|---------------------|----------------------|
| Find annotated classes | Reflection + Classpath scanning |
| Read annotation values | Annotation reflection |
| Create objects dynamically | `Class.newInstance()`, `Constructor.newInstance()` |
| Call methods by name | `Method.invoke()` |
| Intercept method calls | Dynamic proxies, bytecode manipulation |
| Load classes at runtime | ClassLoaders |

The framework isn't doing magic. It's using Java features that most developers never directly touch.

---

## A Glimpse Behind the Curtain

When Spring sees:

```java
@Service
public class UserService {
    @Autowired
    private UserRepository userRepository;
}
```

It roughly does:

```java
// Pseudocode of what Spring does internally

// 1. Scan classpath for @Service classes
for (Class<?> clazz : scanClasspath("com.example")) {
    if (clazz.isAnnotationPresent(Service.class)) {

        // 2. Create instance using reflection
        Object instance = clazz.getDeclaredConstructor().newInstance();

        // 3. Find @Autowired fields
        for (Field field : clazz.getDeclaredFields()) {
            if (field.isAnnotationPresent(Autowired.class)) {

                // 4. Find matching bean
                Object dependency = container.getBean(field.getType());

                // 5. Inject using reflection
                field.setAccessible(true);
                field.set(instance, dependency);
            }
        }

        // 6. Register in container
        container.registerBean(clazz, instance);
    }
}
```

This is a massive simplification, but it shows the pattern: **reflection** enables everything.

---

## The Abstraction Stack

Remember our layers:

```
┌─────────────────────────────────────────┐
│  YOUR CODE                              │
│  @Service, @GetMapping, business logic  │
├─────────────────────────────────────────┤
│  SPRING BOOT                            │
│  Auto-configuration, conventions        │
├─────────────────────────────────────────┤
│  SPRING FRAMEWORK                       │
│  IoC container, DI, AOP                 │
├─────────────────────────────────────────┤
│  JAVA FEATURES                          │
│  Reflection, Annotations, ClassLoaders  │
└─────────────────────────────────────────┘
```

In Part 1, we'll dive deep into that bottom layer—the Java features that make everything above possible.

---

## Key Takeaways

1. **Frameworks invert control**: They call you, not the other way around
2. **Frameworks do five jobs**: Lifecycle, dependencies, configuration, cross-cutting concerns, protocol handling
3. **Frameworks discover your code** through configuration, annotations, or conventions
4. **Java reflection** is the key enabler—frameworks use it to find and manipulate your code at runtime

---

*Next: [Chapter 3: Reflection—Looking in the Mirror](../PART-1-JAVA-BUILDING-BLOCKS/03-reflection.md)*
