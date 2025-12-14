# Chapter 11: ApplicationContext—The Full Picture

> *"Make the common case fast and the rare case possible."*
> — Alan Kay

---

## Beyond BeanFactory

`BeanFactory` provides basic IoC functionality. But real applications need more:
- Loading configuration from files
- Internationalization (i18n)
- Event publishing
- Resource handling
- Environment abstraction

`ApplicationContext` extends `BeanFactory` with these enterprise features.

---

## The ApplicationContext Hierarchy

```java
public interface ApplicationContext extends
    BeanFactory,           // Core IoC functionality
    MessageSource,         // Internationalization
    ApplicationEventPublisher,  // Event system
    ResourcePatternResolver,    // Resource loading
    EnvironmentCapable {        // Environment/profiles

    String getId();
    String getApplicationName();
    String getDisplayName();
    long getStartupDate();
    ApplicationContext getParent();
}
```

`ApplicationContext` is the **full-featured container** that applications use.

---

## Types of ApplicationContext

Spring provides several implementations:

### ClassPathXmlApplicationContext

```java
// Load from XML on classpath
ApplicationContext context = new ClassPathXmlApplicationContext("beans.xml");
```

### FileSystemXmlApplicationContext

```java
// Load from filesystem
ApplicationContext context = new FileSystemXmlApplicationContext("/config/beans.xml");
```

### AnnotationConfigApplicationContext

```java
// Load from @Configuration classes
ApplicationContext context = new AnnotationConfigApplicationContext(AppConfig.class);
```

### GenericWebApplicationContext

```java
// For web applications
// Usually created by Spring MVC or Spring Boot automatically
```

---

## What ApplicationContext Adds

### 1. Automatic BeanPostProcessor Registration

With `BeanFactory`, you must register post-processors manually:

```java
// BeanFactory way (manual)
DefaultListableBeanFactory factory = new DefaultListableBeanFactory();
factory.addBeanPostProcessor(new AutowiredAnnotationBeanPostProcessor());
```

`ApplicationContext` does this automatically:

```java
// ApplicationContext way (automatic)
ApplicationContext context = new AnnotationConfigApplicationContext(AppConfig.class);
// All standard post-processors already registered
```

### 2. Event System

ApplicationContext includes an event publishing mechanism:

```java
// Define an event
public class OrderCreatedEvent extends ApplicationEvent {
    private final Order order;

    public OrderCreatedEvent(Object source, Order order) {
        super(source);
        this.order = order;
    }
}

// Publish events
@Service
public class OrderService {
    @Autowired
    private ApplicationEventPublisher publisher;

    public void createOrder(Order order) {
        // ... create order
        publisher.publishEvent(new OrderCreatedEvent(this, order));
    }
}

// Listen to events
@Component
public class InventoryListener {
    @EventListener
    public void onOrderCreated(OrderCreatedEvent event) {
        // Update inventory when order created
    }
}
```

This enables loose coupling—components communicate through events rather than direct calls.

### 3. Internationalization (i18n)

```java
// messages.properties
greeting.hello=Hello, {0}!

// messages_es.properties
greeting.hello=Hola, {0}!

// Usage
@Service
public class GreetingService {
    @Autowired
    private MessageSource messageSource;

    public String greet(String name, Locale locale) {
        return messageSource.getMessage("greeting.hello", new Object[]{name}, locale);
    }
}
```

### 4. Resource Loading

```java
@Service
public class ConfigLoader {
    @Autowired
    private ResourceLoader resourceLoader;

    public Properties loadConfig() throws IOException {
        Resource resource = resourceLoader.getResource("classpath:config.properties");
        Properties props = new Properties();
        props.load(resource.getInputStream());
        return props;
    }
}
```

Resources can come from:
- `classpath:` — classpath resources
- `file:` — filesystem
- `http:` — remote URLs
- `s3:` — AWS S3 (with Spring Cloud AWS)

### 5. Environment and Profiles

```java
@Service
public class FeatureService {
    @Autowired
    private Environment environment;

    public boolean isFeatureEnabled(String feature) {
        return environment.getProperty("feature." + feature, Boolean.class, false);
    }

    public boolean isProduction() {
        return Arrays.asList(environment.getActiveProfiles()).contains("prod");
    }
}
```

---

## ApplicationContext Lifecycle

When you create an `ApplicationContext`, a lot happens:

```java
ApplicationContext context = new AnnotationConfigApplicationContext(AppConfig.class);
```

### The Startup Sequence

```
1. CREATE CONTEXT
   └── Instantiate AnnotationConfigApplicationContext

2. REGISTER CONFIGURATION
   └── Register AppConfig.class as bean definition

3. REFRESH (the main work happens here)
   │
   ├── prepareRefresh()
   │   └── Initialize property sources, validate required properties
   │
   ├── obtainFreshBeanFactory()
   │   └── Create the internal BeanFactory
   │
   ├── prepareBeanFactory()
   │   └── Configure class loader, register default beans
   │
   ├── postProcessBeanFactory()
   │   └── Hook for subclasses
   │
   ├── invokeBeanFactoryPostProcessors()
   │   └── Execute BeanFactoryPostProcessors
   │   └── THIS IS WHERE COMPONENT SCANNING HAPPENS
   │
   ├── registerBeanPostProcessors()
   │   └── Register all BeanPostProcessors
   │
   ├── initMessageSource()
   │   └── Initialize i18n support
   │
   ├── initApplicationEventMulticaster()
   │   └── Initialize event system
   │
   ├── onRefresh()
   │   └── Hook for subclasses (e.g., start web server)
   │
   ├── registerListeners()
   │   └── Register ApplicationListeners
   │
   ├── finishBeanFactoryInitialization()
   │   └── CREATE ALL SINGLETON BEANS
   │   └── This triggers the full bean lifecycle
   │
   └── finishRefresh()
       └── Publish ContextRefreshedEvent
       └── Start lifecycle processors
```

### The Shutdown Sequence

```java
context.close();
```

```
1. publishEvent(ContextClosedEvent)
   └── Listeners can react to shutdown

2. Stop lifecycle beans
   └── Call Lifecycle.stop() on lifecycle beans

3. Destroy singletons
   └── Call @PreDestroy methods
   └── Call DisposableBean.destroy()
   └── Call custom destroy-methods

4. Close BeanFactory
```

---

## Hierarchical Contexts

ApplicationContexts can have parent-child relationships:

```java
// Parent context with shared beans
ApplicationContext parent = new AnnotationConfigApplicationContext(SharedConfig.class);

// Child context can access parent beans
AnnotationConfigApplicationContext child = new AnnotationConfigApplicationContext();
child.setParent(parent);
child.register(ChildConfig.class);
child.refresh();

// Child can get beans from parent
DataSource ds = child.getBean(DataSource.class);  // Found in parent
```

This is used in:
- Spring MVC (root context + servlet context)
- Plugin architectures
- Multi-tenant applications

```
┌─────────────────────────────────────────────────┐
│              ROOT APPLICATION CONTEXT           │
│                                                 │
│   • DataSource                                 │
│   • TransactionManager                         │
│   • Services                                   │
│                                                 │
└───────────────────┬─────────────────────────────┘
                    │ parent
    ┌───────────────┴───────────────┐
    │                               │
┌───▼───────────────────┐  ┌───────▼───────────────┐
│  WEB APP CONTEXT 1    │  │  WEB APP CONTEXT 2    │
│                       │  │                       │
│  • Controllers        │  │  • Controllers        │
│  • View Resolvers     │  │  • View Resolvers     │
│                       │  │                       │
└───────────────────────┘  └───────────────────────┘
```

---

## Context Events

ApplicationContext publishes events at key moments:

| Event | When Published |
|-------|---------------|
| `ContextRefreshedEvent` | After context is initialized/refreshed |
| `ContextStartedEvent` | After `context.start()` |
| `ContextStoppedEvent` | After `context.stop()` |
| `ContextClosedEvent` | After `context.close()` |

```java
@Component
public class StartupListener {
    @EventListener
    public void onStartup(ContextRefreshedEvent event) {
        System.out.println("Application started!");
        // Initialize caches, warm up connections, etc.
    }

    @EventListener
    public void onShutdown(ContextClosedEvent event) {
        System.out.println("Application shutting down!");
        // Clean up resources
    }
}
```

---

## Lazy vs Eager Initialization

By default, singletons are created eagerly (at startup):

```java
@Service
public class HeavyService {
    public HeavyService() {
        // This runs at startup, even if never used
        System.out.println("Heavy initialization...");
    }
}
```

Use `@Lazy` for on-demand creation:

```java
@Service
@Lazy
public class HeavyService {
    public HeavyService() {
        // This runs only when first accessed
        System.out.println("Heavy initialization...");
    }
}
```

Spring Boot 2.2+ added global lazy initialization:

```properties
spring.main.lazy-initialization=true
```

---

## Conditional Bean Creation

Beans can be created conditionally:

```java
@Configuration
public class DatabaseConfig {
    @Bean
    @ConditionalOnProperty(name = "db.type", havingValue = "postgres")
    public DataSource postgresDataSource() {
        return new PostgresDataSource();
    }

    @Bean
    @ConditionalOnProperty(name = "db.type", havingValue = "mysql")
    public DataSource mysqlDataSource() {
        return new MySqlDataSource();
    }
}
```

This is the foundation of Spring Boot's auto-configuration.

---

## The Refresh Method Deep Dive

The `refresh()` method is where everything happens. Let's examine key steps:

### Component Scanning

During `invokeBeanFactoryPostProcessors()`:

```java
// ConfigurationClassPostProcessor scans for @Component classes
@ComponentScan("com.example")
public class AppConfig { }

// The post-processor:
// 1. Reads the @ComponentScan annotation
// 2. Scans the package for @Component classes
// 3. Creates BeanDefinition for each
// 4. Registers them with the BeanFactory
```

### @Bean Method Processing

Also during `invokeBeanFactoryPostProcessors()`:

```java
@Configuration
public class AppConfig {
    @Bean
    public DataSource dataSource() { ... }
}

// The post-processor:
// 1. Finds @Configuration classes
// 2. Finds @Bean methods
// 3. Creates BeanDefinition with factory method info
// 4. Registers them
```

### Singleton Pre-instantiation

During `finishBeanFactoryInitialization()`:

```java
// For each non-lazy singleton bean definition:
for (String beanName : beanNames) {
    if (!isLazy(beanName) && isSingleton(beanName)) {
        getBean(beanName);  // This creates the bean
    }
}
```

This is why all your `@Service` beans are created at startup.

---

## Common Mistakes and Fixes

### Mistake: Injecting into @Configuration

```java
@Configuration
public class AppConfig {
    @Autowired  // PROBLEMATIC
    private SomeService service;

    @Bean
    public MyBean myBean() {
        return new MyBean(service);
    }
}
```

`@Configuration` classes are processed early, before some beans exist.

**Fix: Use method parameters**
```java
@Configuration
public class AppConfig {
    @Bean
    public MyBean myBean(SomeService service) {  // Injected as parameter
        return new MyBean(service);
    }
}
```

### Mistake: Calling @Bean Methods Directly

```java
@Configuration
public class AppConfig {
    @Bean
    public ServiceA serviceA() {
        return new ServiceA();
    }

    @Bean
    public ServiceB serviceB() {
        return new ServiceB(serviceA());  // Calling @Bean method directly
    }
}
```

This actually works! Spring proxies `@Configuration` classes so that `@Bean` method calls return the singleton. But it only works because of CGLIB proxying.

---

## Key Takeaways

1. **ApplicationContext extends BeanFactory** with enterprise features
2. **Events enable loose coupling** between components
3. **Environment provides property and profile access**
4. **The refresh() method is where startup happens** — scanning, processing, creating beans
5. **Contexts can be hierarchical** — child accesses parent beans
6. **Lifecycle events** let you hook into startup/shutdown
7. **Lazy initialization** defers bean creation until first use

---

*Next: [Chapter 12: Component Scanning—Finding Beans](./12-component-scanning.md)*
