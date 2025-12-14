# Chapter 19: Building Your Own Mini-Framework

> *"I hear and I forget. I see and I remember. I do and I understand."*
> — Confucius

---

## Learning by Building

The best way to understand frameworks is to build one. We'll create a mini dependency injection framework that demonstrates all the concepts we've learned.

Our framework will:
- Scan packages for components
- Read annotations
- Create and wire beans
- Handle injection
- Support simple AOP

---

## The Annotations

First, let's define our annotations:

```java
// Mark a class as a managed component
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
public @interface Component {
    String value() default "";
}

// Mark a field for injection
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.FIELD)
public @interface Inject {
}

// Mark a method to run after injection
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.METHOD)
public @interface PostConstruct {
}

// Mark a method for logging aspect
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.METHOD)
public @interface Logged {
}
```

---

## The Bean Definition

Store metadata about beans:

```java
public class BeanDefinition {
    private final Class<?> beanClass;
    private final String beanName;
    private Object instance;
    private boolean singleton = true;

    public BeanDefinition(Class<?> beanClass) {
        this.beanClass = beanClass;
        this.beanName = generateBeanName(beanClass);
    }

    private String generateBeanName(Class<?> clazz) {
        Component annotation = clazz.getAnnotation(Component.class);
        if (annotation != null && !annotation.value().isEmpty()) {
            return annotation.value();
        }
        // Decapitalize class name
        String simpleName = clazz.getSimpleName();
        return Character.toLowerCase(simpleName.charAt(0)) + simpleName.substring(1);
    }

    // Getters and setters
    public Class<?> getBeanClass() { return beanClass; }
    public String getBeanName() { return beanName; }
    public Object getInstance() { return instance; }
    public void setInstance(Object instance) { this.instance = instance; }
    public boolean isSingleton() { return singleton; }
}
```

---

## The Container

The heart of our framework:

```java
public class MiniContainer {
    private final Map<String, BeanDefinition> beanDefinitions = new HashMap<>();
    private final Map<String, Object> singletons = new HashMap<>();
    private final Set<String> currentlyCreating = new HashSet<>();

    // Scan a package for @Component classes
    public void scan(String basePackage) {
        Set<Class<?>> classes = findClassesInPackage(basePackage);

        for (Class<?> clazz : classes) {
            if (clazz.isAnnotationPresent(Component.class)) {
                BeanDefinition definition = new BeanDefinition(clazz);
                beanDefinitions.put(definition.getBeanName(), definition);
                System.out.println("Registered bean: " + definition.getBeanName());
            }
        }
    }

    // Get a bean by type
    @SuppressWarnings("unchecked")
    public <T> T getBean(Class<T> type) {
        for (BeanDefinition def : beanDefinitions.values()) {
            if (type.isAssignableFrom(def.getBeanClass())) {
                return (T) getBean(def.getBeanName());
            }
        }
        throw new RuntimeException("No bean of type: " + type.getName());
    }

    // Get a bean by name
    public Object getBean(String name) {
        BeanDefinition definition = beanDefinitions.get(name);
        if (definition == null) {
            throw new RuntimeException("No bean named: " + name);
        }

        // Return cached singleton
        if (definition.isSingleton() && singletons.containsKey(name)) {
            return singletons.get(name);
        }

        return createBean(name, definition);
    }

    private Object createBean(String name, BeanDefinition definition) {
        // Circular dependency check
        if (currentlyCreating.contains(name)) {
            throw new RuntimeException("Circular dependency detected: " + name);
        }
        currentlyCreating.add(name);

        try {
            Class<?> clazz = definition.getBeanClass();

            // 1. Instantiate
            Object instance = instantiate(clazz);

            // 2. Inject dependencies
            injectDependencies(instance);

            // 3. Create proxy if needed (for @Logged)
            instance = wrapWithProxy(instance);

            // 4. Call @PostConstruct
            invokePostConstruct(instance);

            // 5. Cache singleton
            if (definition.isSingleton()) {
                singletons.put(name, instance);
            }

            return instance;

        } finally {
            currentlyCreating.remove(name);
        }
    }

    private Object instantiate(Class<?> clazz) {
        try {
            Constructor<?> constructor = clazz.getDeclaredConstructor();
            constructor.setAccessible(true);
            return constructor.newInstance();
        } catch (Exception e) {
            throw new RuntimeException("Failed to instantiate: " + clazz.getName(), e);
        }
    }

    private void injectDependencies(Object instance) {
        Class<?> clazz = instance.getClass();

        for (Field field : clazz.getDeclaredFields()) {
            if (field.isAnnotationPresent(Inject.class)) {
                Object dependency = getBean(field.getType());
                field.setAccessible(true);
                try {
                    field.set(instance, dependency);
                } catch (IllegalAccessException e) {
                    throw new RuntimeException("Failed to inject: " + field.getName(), e);
                }
            }
        }
    }

    private void invokePostConstruct(Object instance) {
        for (Method method : instance.getClass().getDeclaredMethods()) {
            if (method.isAnnotationPresent(PostConstruct.class)) {
                method.setAccessible(true);
                try {
                    method.invoke(instance);
                } catch (Exception e) {
                    throw new RuntimeException("PostConstruct failed", e);
                }
            }
        }
    }
}
```

---

## Package Scanning

Finding classes in a package:

```java
private Set<Class<?>> findClassesInPackage(String packageName) {
    Set<Class<?>> classes = new HashSet<>();
    String path = packageName.replace('.', '/');

    try {
        ClassLoader classLoader = Thread.currentThread().getContextClassLoader();
        Enumeration<URL> resources = classLoader.getResources(path);

        while (resources.hasMoreElements()) {
            URL resource = resources.nextElement();

            if (resource.getProtocol().equals("file")) {
                File directory = new File(resource.toURI());
                findClassesInDirectory(directory, packageName, classes);
            }
        }
    } catch (Exception e) {
        throw new RuntimeException("Failed to scan package: " + packageName, e);
    }

    return classes;
}

private void findClassesInDirectory(File directory, String packageName,
                                    Set<Class<?>> classes) {
    if (!directory.exists()) return;

    for (File file : directory.listFiles()) {
        if (file.isDirectory()) {
            findClassesInDirectory(file, packageName + "." + file.getName(), classes);
        } else if (file.getName().endsWith(".class")) {
            String className = packageName + "." +
                file.getName().replace(".class", "");
            try {
                classes.add(Class.forName(className));
            } catch (ClassNotFoundException e) {
                // Skip
            }
        }
    }
}
```

---

## Simple AOP with Proxies

Add logging aspect for @Logged methods:

```java
private Object wrapWithProxy(Object instance) {
    Class<?> clazz = instance.getClass();

    // Check if any method has @Logged
    boolean needsProxy = false;
    for (Method method : clazz.getDeclaredMethods()) {
        if (method.isAnnotationPresent(Logged.class)) {
            needsProxy = true;
            break;
        }
    }

    if (!needsProxy) {
        return instance;
    }

    // Create proxy
    return Proxy.newProxyInstance(
        clazz.getClassLoader(),
        clazz.getInterfaces(),
        new LoggingInvocationHandler(instance)
    );
}

private static class LoggingInvocationHandler implements InvocationHandler {
    private final Object target;

    public LoggingInvocationHandler(Object target) {
        this.target = target;
    }

    @Override
    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
        // Find the method on target class (to check annotation)
        Method targetMethod = target.getClass().getMethod(
            method.getName(), method.getParameterTypes()
        );

        if (targetMethod.isAnnotationPresent(Logged.class)) {
            System.out.println("[LOG] Entering: " + method.getName());
            long start = System.currentTimeMillis();
            try {
                return method.invoke(target, args);
            } finally {
                long duration = System.currentTimeMillis() - start;
                System.out.println("[LOG] Exiting: " + method.getName() +
                    " (took " + duration + "ms)");
            }
        }

        return method.invoke(target, args);
    }
}
```

---

## Using Our Framework

Let's create some components:

```java
// Repository interface and implementation
public interface UserRepository {
    void save(String user);
    String find(String id);
}

@Component
public class InMemoryUserRepository implements UserRepository {
    private final Map<String, String> users = new HashMap<>();

    @Override
    public void save(String user) {
        String id = String.valueOf(users.size() + 1);
        users.put(id, user);
        System.out.println("Saved user: " + user + " with id: " + id);
    }

    @Override
    public String find(String id) {
        return users.get(id);
    }
}

// Service interface and implementation
public interface UserService {
    void createUser(String name);
}

@Component
public class UserServiceImpl implements UserService {
    @Inject
    private UserRepository userRepository;

    @PostConstruct
    public void init() {
        System.out.println("UserService initialized!");
    }

    @Override
    @Logged
    public void createUser(String name) {
        userRepository.save(name);
    }
}

// Controller
@Component
public class UserController {
    @Inject
    private UserService userService;

    @Logged
    public void handleCreateUser(String name) {
        System.out.println("Controller handling request for: " + name);
        userService.createUser(name);
    }
}
```

---

## Bootstrap and Run

```java
public class MiniApplication {
    public static void main(String[] args) {
        // Create container
        MiniContainer container = new MiniContainer();

        // Scan for components
        container.scan("com.example");

        // Get controller and use it
        UserController controller = container.getBean(UserController.class);
        controller.handleCreateUser("Alice");
    }
}
```

Output:
```
Registered bean: inMemoryUserRepository
Registered bean: userServiceImpl
Registered bean: userController
UserService initialized!
[LOG] Entering: handleCreateUser
Controller handling request for: Alice
[LOG] Entering: createUser
Saved user: Alice with id: 1
[LOG] Exiting: createUser (took 2ms)
[LOG] Exiting: handleCreateUser (took 5ms)
```

---

## What We've Implemented

Our mini-framework demonstrates:

| Concept | Implementation |
|---------|---------------|
| Component Scanning | `findClassesInPackage()` |
| Annotation Processing | `isAnnotationPresent()`, `getAnnotation()` |
| Reflection | `newInstance()`, `field.set()`, `method.invoke()` |
| Dependency Injection | `injectDependencies()` |
| Bean Lifecycle | `@PostConstruct` support |
| AOP | `LoggingInvocationHandler` proxy |
| Circular Dependency Detection | `currentlyCreating` set |
| Singleton Pattern | `singletons` cache |

---

## What's Missing (In Real Frameworks)

Our mini-framework is ~200 lines. Spring is millions. What's missing?

### Bean Features
- Constructor injection
- Setter injection
- `@Qualifier` for multiple beans
- Scopes (prototype, request, session)
- Factory methods (`@Bean`)
- Conditional beans

### Lifecycle
- `DisposableBean` / `@PreDestroy`
- `BeanPostProcessor`
- `BeanFactoryPostProcessor`
- Event system

### AOP
- CGLIB for class proxies
- Pointcut expressions
- Multiple aspect ordering
- Advice types (before, after, around, etc.)

### Configuration
- Property sources
- Profiles
- YAML support
- Type conversion

### Error Handling
- Detailed error messages
- Stack trace filtering
- Graceful degradation

---

## The Framework Mindset

Building this framework teaches important lessons:

### 1. Metadata is Powerful
Annotations are just metadata. The power comes from code that reads and acts on that metadata.

### 2. Reflection Enables Everything
Without reflection, frameworks couldn't inspect and manipulate your code.

### 3. Proxies Enable Interception
Cross-cutting concerns work because proxies intercept method calls.

### 4. Conventions Reduce Configuration
Smart defaults (like bean names from class names) reduce boilerplate.

### 5. Layers Enable Complexity
Each layer handles one concern. Composition builds sophistication.

---

## Exercises

Try extending the mini-framework:

1. **Add Constructor Injection**: Analyze constructor parameters and inject dependencies.

2. **Add @Qualifier**: Handle multiple beans of the same type.

3. **Add Prototype Scope**: Create new instances instead of caching.

4. **Add @Transactional**: Create a proxy that wraps methods in try/commit/rollback.

5. **Add Property Injection**: Support `@Value("${property}")` for configuration.

---

## Key Takeaways

1. **Frameworks are built on Java fundamentals**: reflection, proxies, annotations
2. **The core pattern is simple**: scan → analyze → create → wire → proxy
3. **Complexity comes from edge cases**: error handling, scopes, ordering
4. **Building a framework deepens understanding**: you truly understand what you can build
5. **Spring is this pattern at scale**: same concepts, industrial strength

---

*Next: [Chapter 20: The Framework Mindset](./20-framework-mindset.md)*
