# Chapter 8: The Container Pattern

> *"Any fool can write code that a computer can understand. Good programmers write code that humans can understand."*
> — Martin Fowler

---

## The Goal: Automatic Wiring

We want a system where we:
1. Declare our classes and their dependencies
2. Let the system figure out the rest

```java
// Just mark the class as managed
@Component
public class OrderService {
    // Just declare dependencies
    private final PaymentGateway paymentGateway;
    private final InventoryService inventoryService;

    // Let the container provide them
    public OrderService(PaymentGateway paymentGateway,
                       InventoryService inventoryService) {
        this.paymentGateway = paymentGateway;
        this.inventoryService = inventoryService;
    }
}
```

No manual wiring. No factory code. Just declare and use.

---

## Building a Container from Scratch

Let's build a simple IoC container to understand how it works.

### Step 1: Define What We Store

```java
public class BeanDefinition {
    private Class<?> beanClass;
    private String name;
    private List<Class<?>> constructorArgs;
    private Object instance;  // The actual created object

    public BeanDefinition(Class<?> beanClass) {
        this.beanClass = beanClass;
        this.name = beanClass.getSimpleName();
        this.constructorArgs = analyzeConstructor(beanClass);
    }

    private List<Class<?>> analyzeConstructor(Class<?> clazz) {
        // Find the first public constructor
        Constructor<?>[] constructors = clazz.getConstructors();
        if (constructors.length == 0) {
            return Collections.emptyList();
        }

        Constructor<?> constructor = constructors[0];
        return Arrays.asList(constructor.getParameterTypes());
    }
}
```

### Step 2: Build the Container

```java
public class SimpleContainer {
    private Map<Class<?>, BeanDefinition> definitions = new HashMap<>();

    // Register a class with the container
    public void register(Class<?> clazz) {
        BeanDefinition definition = new BeanDefinition(clazz);
        definitions.put(clazz, definition);
    }

    // Get an instance (create if needed)
    @SuppressWarnings("unchecked")
    public <T> T getBean(Class<T> clazz) {
        BeanDefinition definition = definitions.get(clazz);
        if (definition == null) {
            throw new RuntimeException("No bean registered for: " + clazz);
        }

        // Return existing instance if already created (singleton)
        if (definition.getInstance() != null) {
            return (T) definition.getInstance();
        }

        // Create new instance
        T instance = createInstance(definition);
        definition.setInstance(instance);
        return instance;
    }

    private <T> T createInstance(BeanDefinition definition) {
        Class<?> clazz = definition.getBeanClass();
        List<Class<?>> argTypes = definition.getConstructorArgs();

        try {
            if (argTypes.isEmpty()) {
                // No-arg constructor
                return (T) clazz.getDeclaredConstructor().newInstance();
            }

            // Resolve dependencies recursively
            Object[] args = new Object[argTypes.size()];
            for (int i = 0; i < argTypes.size(); i++) {
                args[i] = getBean(argTypes.get(i));  // Recursive!
            }

            // Find matching constructor
            Constructor<?> constructor = clazz.getConstructor(
                argTypes.toArray(new Class<?>[0])
            );

            return (T) constructor.newInstance(args);

        } catch (Exception e) {
            throw new RuntimeException("Failed to create bean: " + clazz, e);
        }
    }
}
```

### Step 3: Use the Container

```java
// Define our classes
public class DatabaseConnection {
    public DatabaseConnection() {
        System.out.println("DatabaseConnection created");
    }
}

public class UserRepository {
    private final DatabaseConnection database;

    public UserRepository(DatabaseConnection database) {
        this.database = database;
        System.out.println("UserRepository created with " + database);
    }
}

public class UserService {
    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
        System.out.println("UserService created with " + userRepository);
    }
}

// Bootstrap the container
SimpleContainer container = new SimpleContainer();
container.register(DatabaseConnection.class);
container.register(UserRepository.class);
container.register(UserService.class);

// Get a bean - all dependencies created automatically!
UserService service = container.getBean(UserService.class);

// Output:
// DatabaseConnection created
// UserRepository created with DatabaseConnection@12345
// UserService created with UserRepository@67890
```

**That's dependency injection!** The container:
1. Knew `UserService` needs `UserRepository`
2. Knew `UserRepository` needs `DatabaseConnection`
3. Created them in the right order
4. Injected dependencies automatically

---

## Enhancing the Container

Our simple container works, but real containers do more. Let's add features:

### Feature 1: Interface-to-Implementation Mapping

```java
public class SimpleContainer {
    private Map<Class<?>, BeanDefinition> definitions = new HashMap<>();
    private Map<Class<?>, Class<?>> interfaces = new HashMap<>();

    // Register implementation for an interface
    public void register(Class<?> interfaceClass, Class<?> implClass) {
        register(implClass);
        interfaces.put(interfaceClass, implClass);
    }

    public <T> T getBean(Class<T> clazz) {
        // Check if it's an interface with registered impl
        if (clazz.isInterface() && interfaces.containsKey(clazz)) {
            clazz = (Class<T>) interfaces.get(clazz);
        }
        // ... rest of getBean
    }
}

// Usage
container.register(PaymentGateway.class, StripePaymentGateway.class);
PaymentGateway gateway = container.getBean(PaymentGateway.class);
// Returns StripePaymentGateway instance
```

### Feature 2: Annotation-Based Registration

```java
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
public @interface Component { }

public class SimpleContainer {
    public void scan(String packageName) {
        // Find all classes in package (simplified)
        for (Class<?> clazz : findClassesInPackage(packageName)) {
            if (clazz.isAnnotationPresent(Component.class)) {
                register(clazz);
            }
        }
    }
}

// Usage
@Component
public class UserService { ... }

container.scan("com.example");  // Finds and registers @Component classes
```

### Feature 3: Lifecycle Hooks

```java
public interface InitializingBean {
    void afterPropertiesSet();
}

public interface DisposableBean {
    void destroy();
}

public class SimpleContainer {
    private <T> T createInstance(BeanDefinition definition) {
        T instance = // ... create as before

        // Call init hook
        if (instance instanceof InitializingBean) {
            ((InitializingBean) instance).afterPropertiesSet();
        }

        return instance;
    }

    public void close() {
        for (BeanDefinition def : definitions.values()) {
            if (def.getInstance() instanceof DisposableBean) {
                ((DisposableBean) def.getInstance()).destroy();
            }
        }
    }
}

// Usage
@Component
public class DatabaseConnection implements InitializingBean, DisposableBean {
    @Override
    public void afterPropertiesSet() {
        System.out.println("Opening connection pool");
    }

    @Override
    public void destroy() {
        System.out.println("Closing connection pool");
    }
}
```

### Feature 4: Scope (Singleton vs Prototype)

```java
public enum Scope { SINGLETON, PROTOTYPE }

@Retention(RetentionPolicy.RUNTIME)
public @interface Bean {
    Scope scope() default Scope.SINGLETON;
}

public <T> T getBean(Class<T> clazz) {
    BeanDefinition definition = definitions.get(clazz);

    // Check scope
    Scope scope = definition.getScope();

    if (scope == Scope.SINGLETON) {
        // Return existing or create once
        if (definition.getInstance() == null) {
            definition.setInstance(createInstance(definition));
        }
        return (T) definition.getInstance();
    } else {
        // Always create new
        return createInstance(definition);
    }
}
```

---

## Handling Circular Dependencies

What happens with this?

```java
@Component
public class ServiceA {
    public ServiceA(ServiceB b) { }
}

@Component
public class ServiceB {
    public ServiceB(ServiceA a) { }
}
```

Our container would overflow:
1. Creating ServiceA needs ServiceB
2. Creating ServiceB needs ServiceA
3. Creating ServiceA needs ServiceB...

**Solutions:**

### Solution 1: Detect and Fail

```java
public class SimpleContainer {
    private Set<Class<?>> currentlyCreating = new HashSet<>();

    private <T> T createInstance(BeanDefinition definition) {
        Class<?> clazz = definition.getBeanClass();

        if (currentlyCreating.contains(clazz)) {
            throw new RuntimeException("Circular dependency detected: " + clazz);
        }

        currentlyCreating.add(clazz);
        try {
            // Create instance...
        } finally {
            currentlyCreating.remove(clazz);
        }
    }
}
```

### Solution 2: Allow via Setter Injection

```java
@Component
public class ServiceA {
    private ServiceB b;

    public ServiceA() { }  // No-arg constructor

    @Autowired
    public void setServiceB(ServiceB b) {
        this.b = b;
    }
}
```

The container can:
1. Create ServiceA (no dependencies in constructor)
2. Create ServiceB (no dependencies in constructor)
3. Inject ServiceB into ServiceA via setter
4. Inject ServiceA into ServiceB via setter

### Solution 3: Lazy Proxies

```java
@Component
public class ServiceA {
    private final ServiceB b;

    public ServiceA(@Lazy ServiceB b) {
        this.b = b;  // This is actually a proxy!
    }
}
```

The container injects a proxy that doesn't resolve until first use, breaking the cycle.

---

## The Container as Central Authority

Once you have a container, it becomes the **single source of truth** for object creation:

```
┌────────────────────────────────────────────────────────┐
│                    APPLICATION                          │
│                                                         │
│   ┌─────────────────────────────────────────────────┐  │
│   │                  CONTAINER                       │  │
│   │                                                  │  │
│   │   BeanDefinition ─────▶ Instance                │  │
│   │   BeanDefinition ─────▶ Instance                │  │
│   │   BeanDefinition ─────▶ Instance                │  │
│   │                                                  │  │
│   │   • Knows all components                        │  │
│   │   • Manages lifecycle                           │  │
│   │   • Resolves dependencies                       │  │
│   │   • Handles configuration                       │  │
│   │                                                  │  │
│   └─────────────────────────────────────────────────┘  │
│                          │                              │
│              getBean()   │                              │
│                          ▼                              │
│                   Your Application Code                 │
│                                                         │
└────────────────────────────────────────────────────────┘
```

Benefits:
- **Centralized configuration**: Change wiring in one place
- **Consistent lifecycle**: All beans created/destroyed properly
- **Testability**: Replace container contents for testing
- **Flexibility**: Swap implementations without code changes

---

## From Our Container to Spring

Our `SimpleContainer` demonstrates the core concepts. Spring's `ApplicationContext` is the same idea, vastly more sophisticated:

| Our Container | Spring's ApplicationContext |
|---------------|----------------------------|
| `register(Class)` | Component scanning, `@Bean` methods |
| `getBean(Class)` | `getBean()` with type safety, qualifiers |
| Constructor analysis | Multiple injection strategies |
| Singleton caching | Multiple scopes, proxied scopes |
| Simple lifecycle | Full lifecycle with many hooks |
| Basic interface mapping | Sophisticated type matching |

---

## Key Takeaways

1. **A container is a registry** of bean definitions and instances
2. **Dependency resolution is recursive**: to create A, create its dependencies first
3. **Reflection enables automatic wiring**: analyze constructors to find dependencies
4. **Singletons are cached**: created once, shared everywhere
5. **Lifecycle hooks** let beans participate in startup/shutdown
6. **Circular dependencies** require special handling
7. **The container is the central authority** for object management

---

*Next: [Chapter 9: Dependency Injection Demystified](./09-dependency-injection.md)*
