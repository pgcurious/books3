# Scope & Lifecycle Annotations

## Controlling Bean Creation and Destruction

---

## Overview

| Annotation | Purpose |
|------------|---------|
| `@Scope` | Define bean scope (singleton, prototype, etc.) |
| `@Lazy` | Delay bean creation until first use |
| `@PostConstruct` | Run after bean is created |
| `@PreDestroy` | Run before bean is destroyed |
| `@DependsOn` | Ensure beans are created in order |
| `@Order` | Control bean ordering in collections |

---

## @Scope - Bean Scopes

### Singleton (Default)

```java
@Component
// @Scope("singleton")  // This is the default
public class ConfigService {
    // One instance for entire application
    // Shared by all threads
}
```

### Prototype

```java
@Component
@Scope("prototype")
public class ShoppingCart {
    private List<Item> items = new ArrayList<>();

    // New instance created for EACH injection
    public void addItem(Item item) {
        items.add(item);
    }
}

@Service
public class CheckoutService {

    private final ObjectProvider<ShoppingCart> cartProvider;

    public CheckoutService(ObjectProvider<ShoppingCart> cartProvider) {
        this.cartProvider = cartProvider;
    }

    public void checkout() {
        // Get fresh cart each time
        ShoppingCart cart = cartProvider.getObject();
    }
}
```

**Important:** Prototype beans injected into singleton beans are created once. Use `ObjectProvider` for fresh instances.

### Request Scope (Web)

```java
@Component
@Scope(value = WebApplicationContext.SCOPE_REQUEST, proxyMode = ScopedProxyMode.TARGET_CLASS)
public class RequestContext {
    private String correlationId;
    private LocalDateTime startTime;

    // Fresh instance for each HTTP request
}

// Or using shorthand
@Component
@RequestScope
public class RequestContext { }
```

### Session Scope (Web)

```java
@Component
@Scope(value = WebApplicationContext.SCOPE_SESSION, proxyMode = ScopedProxyMode.TARGET_CLASS)
public class UserSession {
    private User currentUser;
    private List<String> recentlyViewed;

    // Instance per HTTP session
}

// Or using shorthand
@Component
@SessionScope
public class UserSession { }
```

### Application Scope (Web)

```java
@Component
@Scope(value = WebApplicationContext.SCOPE_APPLICATION, proxyMode = ScopedProxyMode.TARGET_CLASS)
public class ApplicationStats {
    private AtomicLong requestCount = new AtomicLong();

    // One instance per ServletContext
}

// Or using shorthand
@Component
@ApplicationScope
public class ApplicationStats { }
```

### Custom Scope

```java
// Define scope
public class TenantScope implements Scope {
    private Map<String, Map<String, Object>> scopedObjects = new ConcurrentHashMap<>();

    @Override
    public Object get(String name, ObjectFactory<?> objectFactory) {
        String tenantId = TenantContext.getCurrentTenant();
        Map<String, Object> tenantBeans = scopedObjects
            .computeIfAbsent(tenantId, k -> new ConcurrentHashMap<>());
        return tenantBeans.computeIfAbsent(name, k -> objectFactory.getObject());
    }

    @Override
    public Object remove(String name) {
        String tenantId = TenantContext.getCurrentTenant();
        Map<String, Object> tenantBeans = scopedObjects.get(tenantId);
        return tenantBeans != null ? tenantBeans.remove(name) : null;
    }

    // ... other methods
}

// Register scope
@Configuration
public class ScopeConfig implements BeanFactoryPostProcessor {
    @Override
    public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) {
        beanFactory.registerScope("tenant", new TenantScope());
    }
}

// Use scope
@Component
@Scope("tenant")
public class TenantConfiguration { }
```

---

## @Lazy - Delayed Initialization

### On Component

```java
@Component
@Lazy
public class ExpensiveService {

    public ExpensiveService() {
        // This constructor runs only when bean is first used
        System.out.println("Creating ExpensiveService...");
        loadLargeDataset();
    }
}
```

### On Injection Point

```java
@Service
public class MainService {

    private final ExpensiveService expensiveService;

    // Inject lazily even if ExpensiveService isn't @Lazy
    public MainService(@Lazy ExpensiveService expensiveService) {
        this.expensiveService = expensiveService;
    }

    public void process() {
        // ExpensiveService created HERE, on first use
        expensiveService.doWork();
    }
}
```

### Global Lazy Initialization

```properties
# application.properties
spring.main.lazy-initialization=true
```

**Caution:** Global lazy init means errors are detected at runtime, not startup.

### @Lazy with @Configuration

```java
@Configuration
public class AppConfig {

    @Bean
    @Lazy
    public ExpensiveClient expensiveClient() {
        return new ExpensiveClient();  // Created on first use
    }
}
```

---

## @PostConstruct - Initialization Callback

### Basic Usage

```java
@Component
public class CacheService {

    private Map<String, Object> cache;

    @PostConstruct
    public void init() {
        System.out.println("Initializing cache...");
        cache = new ConcurrentHashMap<>();
        preloadCache();
    }

    private void preloadCache() {
        // Load frequently used data
    }
}
```

### Execution Order

```java
@Component
public class OrderedInitBean {

    private final Dependency dep;

    // 1. Constructor called first
    public OrderedInitBean(Dependency dep) {
        this.dep = dep;
        System.out.println("1. Constructor");
    }

    // 2. Dependencies injected (if using setter injection)

    // 3. @PostConstruct called
    @PostConstruct
    public void init() {
        System.out.println("3. PostConstruct");
        // Safe to use all dependencies here
    }
}
```

### With @Bean

```java
@Configuration
public class AppConfig {

    @Bean(initMethod = "init")  // Alternative to @PostConstruct
    public CacheService cacheService() {
        return new CacheService();
    }
}

public class CacheService {
    public void init() {  // Called after bean creation
        preloadCache();
    }
}
```

---

## @PreDestroy - Cleanup Callback

### Basic Usage

```java
@Component
public class ConnectionPool {

    private List<Connection> connections;

    @PostConstruct
    public void init() {
        connections = createConnections(10);
    }

    @PreDestroy
    public void cleanup() {
        System.out.println("Closing connections...");
        connections.forEach(Connection::close);
    }
}
```

### With @Bean

```java
@Configuration
public class AppConfig {

    @Bean(destroyMethod = "close")  // Alternative to @PreDestroy
    public ConnectionPool connectionPool() {
        return new ConnectionPool();
    }
}
```

### Graceful Shutdown

```java
@Component
public class TaskProcessor {

    private ExecutorService executor;
    private volatile boolean running = true;

    @PostConstruct
    public void start() {
        executor = Executors.newFixedThreadPool(4);
        // Start processing
    }

    @PreDestroy
    public void shutdown() {
        running = false;
        executor.shutdown();
        try {
            // Wait for tasks to complete
            if (!executor.awaitTermination(30, TimeUnit.SECONDS)) {
                executor.shutdownNow();
            }
        } catch (InterruptedException e) {
            executor.shutdownNow();
            Thread.currentThread().interrupt();
        }
    }
}
```

---

## @DependsOn - Explicit Dependencies

### Basic Usage

```java
@Component("databaseMigration")
public class DatabaseMigration {
    @PostConstruct
    public void migrate() {
        System.out.println("Running migrations...");
    }
}

@Component
@DependsOn("databaseMigration")  // Wait for migrations
public class UserRepository {
    // Created AFTER DatabaseMigration
}
```

### Multiple Dependencies

```java
@Component
@DependsOn({ "databaseMigration", "cacheWarmer", "configLoader" })
public class ApplicationService {
    // Created after all listed beans
}
```

### With @Bean

```java
@Configuration
public class AppConfig {

    @Bean
    public DatabaseMigration databaseMigration() {
        return new DatabaseMigration();
    }

    @Bean
    @DependsOn("databaseMigration")
    public UserRepository userRepository() {
        return new UserRepository();
    }
}
```

---

## @Order and @Priority - Bean Ordering

### @Order in Collections

```java
public interface Plugin {
    void execute();
}

@Component
@Order(1)
public class SecurityPlugin implements Plugin {
    public void execute() {
        System.out.println("Security check");
    }
}

@Component
@Order(2)
public class LoggingPlugin implements Plugin {
    public void execute() {
        System.out.println("Logging");
    }
}

@Component
@Order(3)
public class CachingPlugin implements Plugin {
    public void execute() {
        System.out.println("Caching");
    }
}

@Service
public class PluginService {

    private final List<Plugin> plugins;

    public PluginService(List<Plugin> plugins) {
        this.plugins = plugins;  // Ordered by @Order
    }

    public void run() {
        plugins.forEach(Plugin::execute);
        // Output: Security check, Logging, Caching
    }
}
```

### Order Constants

```java
@Order(Ordered.HIGHEST_PRECEDENCE)  // Integer.MIN_VALUE
public class FirstPlugin { }

@Order(Ordered.LOWEST_PRECEDENCE)   // Integer.MAX_VALUE
public class LastPlugin { }

@Order(Ordered.HIGHEST_PRECEDENCE + 1)  // Almost first
public class AlmostFirstPlugin { }
```

### @Priority (JSR-250)

```java
@Component
@Priority(1)  // Lower number = higher priority
public class ImportantBean { }

@Component
@Priority(100)
public class LessImportantBean { }
```

**@Priority vs @Order:**
- `@Priority` affects which bean is selected when multiple match
- `@Order` affects ordering within collections

---

## Lifecycle Summary

```java
@Component
public class LifecycleDemo {

    // 1. Bean instantiation
    public LifecycleDemo() {
        System.out.println("1. Constructor");
    }

    // 2. Dependency injection
    @Autowired
    public void setDependency(Dependency dep) {
        System.out.println("2. Setter injection");
    }

    // 3. Aware interfaces (BeanNameAware, ApplicationContextAware, etc.)

    // 4. BeanPostProcessor.postProcessBeforeInitialization()

    // 5. @PostConstruct
    @PostConstruct
    public void postConstruct() {
        System.out.println("3. PostConstruct");
    }

    // 6. InitializingBean.afterPropertiesSet()

    // 7. Custom init-method

    // 8. BeanPostProcessor.postProcessAfterInitialization()

    // --- Bean is ready ---

    // 9. @PreDestroy (on shutdown)
    @PreDestroy
    public void preDestroy() {
        System.out.println("4. PreDestroy");
    }

    // 10. DisposableBean.destroy()

    // 11. Custom destroy-method
}
```

---

## Key Takeaways

1. **Singleton is default** - one instance shared by all
2. **Prototype creates new instances** - use `ObjectProvider` for dynamic creation
3. **Request/Session scopes** need `proxyMode` for injection into singletons
4. **@Lazy delays creation** until first use
5. **@PostConstruct runs after** all dependencies are injected
6. **@PreDestroy runs before** context shutdown
7. **@DependsOn for explicit** creation ordering
8. **@Order controls collection** ordering

---

*Next: [Configuration Basics](../PART-4-CONFIGURATION/08-configuration-basics.md)*
