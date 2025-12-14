# Chapter 10: The BeanFactory—Spring's Heart

> *"Simplicity is the ultimate sophistication."*
> — Leonardo da Vinci

---

## From Concept to Spring

We've built mental models of containers and dependency injection. Now let's see how Spring implements these concepts.

At Spring's core is the **BeanFactory** interface—the simplest form of Spring's IoC container.

---

## The BeanFactory Interface

```java
public interface BeanFactory {
    // Get a bean by name
    Object getBean(String name);

    // Get a bean by name and type
    <T> T getBean(String name, Class<T> requiredType);

    // Get a bean by type
    <T> T getBean(Class<T> requiredType);

    // Check if a bean exists
    boolean containsBean(String name);

    // Check if a bean is a singleton
    boolean isSingleton(String name);

    // Check if a bean is a prototype
    boolean isPrototype(String name);

    // Get the type of a bean
    Class<?> getType(String name);
}
```

That's it. The core of Spring's IoC is remarkably simple: **a registry that creates and returns beans by name or type.**

---

## BeanDefinition: The Blueprint

Before a bean can be created, Spring needs to know *how* to create it. This information is stored in a `BeanDefinition`:

```java
public interface BeanDefinition {
    // What class to instantiate?
    String getBeanClassName();
    void setBeanClassName(String beanClassName);

    // Singleton or Prototype?
    String getScope();
    void setScope(String scope);

    // Is it lazy-initialized?
    boolean isLazyInit();
    void setLazyInit(boolean lazyInit);

    // What are its dependencies?
    String[] getDependsOn();
    void setDependsOn(String... dependsOn);

    // Constructor arguments
    ConstructorArgumentValues getConstructorArgumentValues();

    // Property values (for setter injection)
    MutablePropertyValues getPropertyValues();

    // Init and destroy methods
    String getInitMethodName();
    String getDestroyMethodName();
}
```

A `BeanDefinition` is metadata describing:
- What class to instantiate
- How to instantiate it (constructor args, factory method)
- What dependencies to inject
- Lifecycle callbacks
- Scope and other behaviors

---

## DefaultListableBeanFactory

The main implementation of `BeanFactory` is `DefaultListableBeanFactory`:

```java
// Simplified view of DefaultListableBeanFactory
public class DefaultListableBeanFactory implements BeanFactory {
    // Bean definitions by name
    private final Map<String, BeanDefinition> beanDefinitionMap = new ConcurrentHashMap<>();

    // Singleton instances cache
    private final Map<String, Object> singletonObjects = new ConcurrentHashMap<>();

    // Currently being created (for circular dependency detection)
    private final Set<String> singletonsCurrentlyInCreation = new HashSet<>();

    // Register a bean definition
    public void registerBeanDefinition(String name, BeanDefinition definition) {
        beanDefinitionMap.put(name, definition);
    }

    @Override
    public Object getBean(String name) {
        // Check singleton cache first
        Object singleton = singletonObjects.get(name);
        if (singleton != null) {
            return singleton;
        }

        // Get the definition
        BeanDefinition definition = beanDefinitionMap.get(name);
        if (definition == null) {
            throw new NoSuchBeanDefinitionException(name);
        }

        // Create the bean
        return createBean(name, definition);
    }

    private Object createBean(String name, BeanDefinition definition) {
        // Check for circular dependency
        if (singletonsCurrentlyInCreation.contains(name)) {
            throw new BeanCurrentlyInCreationException(name);
        }

        singletonsCurrentlyInCreation.add(name);
        try {
            // 1. Instantiate
            Object instance = instantiate(definition);

            // 2. Populate properties (inject dependencies)
            populateBean(instance, definition);

            // 3. Initialize (call init methods)
            instance = initializeBean(instance, definition);

            // 4. Cache if singleton
            if (definition.isSingleton()) {
                singletonObjects.put(name, instance);
            }

            return instance;
        } finally {
            singletonsCurrentlyInCreation.remove(name);
        }
    }
}
```

---

## The Bean Lifecycle

When `getBean()` is called, a bean goes through a detailed lifecycle:

```
┌─────────────────────────────────────────────────────────────────┐
│                      BEAN LIFECYCLE                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. INSTANTIATION                                               │
│     └── Create instance (constructor or factory method)         │
│                          │                                       │
│                          ▼                                       │
│  2. PROPERTY POPULATION                                         │
│     └── Inject dependencies (@Autowired, setters)               │
│                          │                                       │
│                          ▼                                       │
│  3. BEAN NAME AWARE                                             │
│     └── setBeanName() if BeanNameAware                          │
│                          │                                       │
│                          ▼                                       │
│  4. BEAN FACTORY AWARE                                          │
│     └── setBeanFactory() if BeanFactoryAware                    │
│                          │                                       │
│                          ▼                                       │
│  5. PRE-INITIALIZATION (BeanPostProcessors)                     │
│     └── postProcessBeforeInitialization()                       │
│                          │                                       │
│                          ▼                                       │
│  6. INITIALIZATION                                              │
│     ├── @PostConstruct method                                   │
│     ├── InitializingBean.afterPropertiesSet()                   │
│     └── Custom init-method                                      │
│                          │                                       │
│                          ▼                                       │
│  7. POST-INITIALIZATION (BeanPostProcessors)                    │
│     └── postProcessAfterInitialization()                        │
│                          │                                       │
│                          ▼                                       │
│  8. BEAN IS READY                                               │
│     └── Bean can now be used                                    │
│                          │                                       │
│                          ▼                                       │
│  9. DESTRUCTION (on container shutdown)                         │
│     ├── @PreDestroy method                                      │
│     ├── DisposableBean.destroy()                                │
│     └── Custom destroy-method                                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## BeanPostProcessor: The Extension Point

`BeanPostProcessor` is how Spring's magic happens. It allows modification of beans during creation:

```java
public interface BeanPostProcessor {
    // Called before initialization
    default Object postProcessBeforeInitialization(Object bean, String beanName) {
        return bean;
    }

    // Called after initialization
    default Object postProcessAfterInitialization(Object bean, String beanName) {
        return bean;
    }
}
```

### Example: Auto-Logging PostProcessor

```java
@Component
public class LoggingBeanPostProcessor implements BeanPostProcessor {

    @Override
    public Object postProcessAfterInitialization(Object bean, String beanName) {
        // Wrap services with logging proxy
        if (bean.getClass().isAnnotationPresent(Service.class)) {
            return createLoggingProxy(bean);
        }
        return bean;
    }

    private Object createLoggingProxy(Object bean) {
        return Proxy.newProxyInstance(
            bean.getClass().getClassLoader(),
            bean.getClass().getInterfaces(),
            (proxy, method, args) -> {
                System.out.println("Calling: " + method.getName());
                return method.invoke(bean, args);
            }
        );
    }
}
```

### Spring's Built-in PostProcessors

| PostProcessor | What It Does |
|--------------|--------------|
| `AutowiredAnnotationBeanPostProcessor` | Processes @Autowired, @Value |
| `CommonAnnotationBeanPostProcessor` | Processes @PostConstruct, @PreDestroy, @Resource |
| `AsyncAnnotationBeanPostProcessor` | Creates proxies for @Async methods |
| `ScheduledAnnotationBeanPostProcessor` | Registers @Scheduled methods |

**This is how annotations work!** They're just markers. PostProcessors read them and add behavior.

---

## BeanFactoryPostProcessor: Modifying Definitions

While `BeanPostProcessor` modifies bean instances, `BeanFactoryPostProcessor` modifies bean *definitions* before any beans are created:

```java
public interface BeanFactoryPostProcessor {
    void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory);
}
```

### Example: Property Placeholder Resolution

```java
// This is how ${property.name} placeholders work
@Component
public class PropertyPlaceholderPostProcessor implements BeanFactoryPostProcessor {

    @Override
    public void postProcessBeanFactory(ConfigurableListableBeanFactory factory) {
        Properties props = loadProperties();

        for (String beanName : factory.getBeanDefinitionNames()) {
            BeanDefinition definition = factory.getBeanDefinition(beanName);

            // Replace placeholders in property values
            MutablePropertyValues pvs = definition.getPropertyValues();
            for (PropertyValue pv : pvs.getPropertyValues()) {
                Object value = pv.getValue();
                if (value instanceof String) {
                    String resolved = resolvePlaceholders((String) value, props);
                    pvs.add(pv.getName(), resolved);
                }
            }
        }
    }

    private String resolvePlaceholders(String value, Properties props) {
        // Replace ${key} with props.get(key)
        // ...
    }
}
```

---

## Putting It Together: How @Autowired Works

Let's trace exactly what happens:

```java
@Service
public class OrderService {
    @Autowired
    private PaymentGateway paymentGateway;
}
```

**Step 1: Component Scanning** finds `OrderService` and registers a `BeanDefinition`

**Step 2: Container starts creating beans**

**Step 3: `OrderService` bean is requested**

**Step 4: Instantiation**
```java
Object instance = OrderService.class.getDeclaredConstructor().newInstance();
```

**Step 5: `AutowiredAnnotationBeanPostProcessor` runs**
```java
// Inside the post-processor
for (Field field : targetClass.getDeclaredFields()) {
    if (field.isAnnotationPresent(Autowired.class)) {
        Object dependency = beanFactory.getBean(field.getType());
        field.setAccessible(true);
        field.set(instance, dependency);
    }
}
```

**Step 6: Bean is ready**

The `@Autowired` annotation does nothing by itself. It's just a marker. The `AutowiredAnnotationBeanPostProcessor` does all the work.

---

## Scope: Singleton vs Prototype

BeanFactory handles different scopes:

### Singleton (Default)

```java
@Service  // Singleton by default
public class UserService { }
```

- One instance per container
- Cached in `singletonObjects` map
- Shared by all requesters

### Prototype

```java
@Service
@Scope("prototype")
public class RequestHandler { }
```

- New instance every time `getBean()` is called
- Not cached
- Container doesn't manage destruction

### Request/Session (Web)

```java
@Service
@Scope(value = "request", proxyMode = ScopedProxyMode.TARGET_CLASS)
public class RequestContext { }
```

- Tied to HTTP request/session lifecycle
- Uses proxies to inject request-scoped bean into singleton

---

## Factory Methods and @Bean

Not all beans are created by calling constructors. Factory methods provide more control:

```java
@Configuration
public class AppConfig {
    @Bean
    public DataSource dataSource() {
        HikariDataSource ds = new HikariDataSource();
        ds.setJdbcUrl("jdbc:postgresql://localhost/db");
        ds.setUsername("user");
        ds.setPassword("password");
        return ds;
    }
}
```

Spring registers this as a `BeanDefinition` with:
- Bean name: "dataSource"
- Factory bean: the `@Configuration` class
- Factory method: "dataSource"

When `getBean("dataSource")` is called:
```java
// Spring does (simplified):
Object configInstance = getBean(AppConfig.class);
Method factoryMethod = AppConfig.class.getMethod("dataSource");
Object bean = factoryMethod.invoke(configInstance);
```

---

## Why Understanding BeanFactory Matters

When things go wrong, understanding BeanFactory helps:

### NoSuchBeanDefinitionException
```
No qualifying bean of type 'com.example.PaymentGateway' available
```
**Meaning:** No `BeanDefinition` registered for that type
**Fix:** Add `@Component` or `@Bean` method

### BeanCurrentlyInCreationException
```
Requested bean is currently in creation: is there an unresolvable circular reference?
```
**Meaning:** Circular dependency detected during creation
**Fix:** Restructure dependencies or use setter injection

### UnsatisfiedDependencyException
```
Error creating bean with name 'orderService': Unsatisfied dependency expressed through constructor parameter 0
```
**Meaning:** Couldn't find bean to inject
**Fix:** Ensure dependency bean exists and is scannable

---

## Key Takeaways

1. **BeanFactory is the core interface** — it's a registry that creates beans
2. **BeanDefinition is the blueprint** — metadata about how to create a bean
3. **Bean lifecycle has many steps** — instantiation, population, initialization, destruction
4. **BeanPostProcessor enables annotation magic** — it processes beans during creation
5. **BeanFactoryPostProcessor modifies definitions** — before any beans exist
6. **@Autowired is just a marker** — the PostProcessor does the actual injection
7. **Scopes control instance creation** — singleton, prototype, request, session

---

*Next: [Chapter 11: ApplicationContext—The Full Picture](./11-application-context.md)*
