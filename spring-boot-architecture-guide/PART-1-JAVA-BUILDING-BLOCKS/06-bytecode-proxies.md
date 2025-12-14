# Chapter 6: Bytecode and Proxies

> *"The best code is no code at all. The second best is code that writes itself."*
> — Pragmatic wisdom

---

## The Problem: Adding Behavior Without Changing Code

Consider this scenario: you have 100 service methods, and you want to add logging to all of them. You could:

**Option 1: Modify every method**
```java
public User getUser(Long id) {
    logger.info("getUser called with id: " + id);
    // actual logic
}
// Repeat 99 more times...
```

Tedious, error-prone, and violates DRY.

**Option 2: Use inheritance**
```java
public class LoggingUserService extends UserService {
    @Override
    public User getUser(Long id) {
        logger.info("getUser called");
        return super.getUser(id);
    }
}
```

Better, but you need to override every method. What if `UserService` is final?

**Option 3: Use a proxy**

What if you could wrap the service in an invisible layer that intercepts all method calls?

```java
UserService proxy = createLoggingProxy(userService);
proxy.getUser(1L);  // Logs automatically, then calls real method
```

This is the **Proxy Pattern**, and Java provides built-in support for it.

---

## The Proxy Pattern

A proxy is an object that stands in for another object, intercepting all interactions:

```
┌──────────┐       ┌──────────┐       ┌──────────────┐
│  Client  │──────▶│  Proxy   │──────▶│  Real Object │
│          │       │(intercept)│       │              │
└──────────┘       └──────────┘       └──────────────┘
```

The client thinks it's talking to the real object, but the proxy can:
- Log the call
- Check permissions
- Start transactions
- Cache results
- Modify arguments or return values
- Prevent the call entirely

---

## Java Dynamic Proxies

Java provides `java.lang.reflect.Proxy` for creating proxies at runtime.

### The InvocationHandler

To create a proxy, you implement `InvocationHandler`:

```java
public interface InvocationHandler {
    Object invoke(Object proxy, Method method, Object[] args) throws Throwable;
}
```

Every method call on the proxy goes through this single `invoke` method.

### Creating a Simple Proxy

```java
public interface UserService {
    User findById(Long id);
    void save(User user);
}

public class LoggingHandler implements InvocationHandler {
    private final Object target;

    public LoggingHandler(Object target) {
        this.target = target;
    }

    @Override
    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
        System.out.println("Calling: " + method.getName());

        long start = System.currentTimeMillis();
        try {
            // Call the real method
            return method.invoke(target, args);
        } finally {
            long duration = System.currentTimeMillis() - start;
            System.out.println(method.getName() + " took " + duration + "ms");
        }
    }
}

// Create the proxy
UserService realService = new UserServiceImpl();
UserService proxy = (UserService) Proxy.newProxyInstance(
    UserService.class.getClassLoader(),
    new Class<?>[] { UserService.class },
    new LoggingHandler(realService)
);

// Use the proxy
proxy.findById(1L);  // Output: "Calling: findById" and "findById took 5ms"
```

### The Limitation: Interfaces Only

Java's `Proxy` class only works with **interfaces**. You can't proxy a concrete class:

```java
// This works:
Proxy.newProxyInstance(loader, new Class<?>[] { UserService.class }, handler);

// This doesn't work:
Proxy.newProxyInstance(loader, new Class<?>[] { UserServiceImpl.class }, handler);
// Error: UserServiceImpl is not an interface
```

This is why Spring encourages programming to interfaces. But what if you need to proxy a class?

---

## CGLIB: Proxying Classes

**CGLIB** (Code Generation Library) creates proxies by generating a subclass at runtime:

```java
public class UserServiceImpl {
    public User findById(Long id) { ... }
}

// CGLIB generates (at runtime):
public class UserServiceImpl$$EnhancerByCGLIB$$abc123 extends UserServiceImpl {
    private MethodInterceptor interceptor;

    @Override
    public User findById(Long id) {
        // Delegate to interceptor
        return (User) interceptor.intercept(
            this,
            findByIdMethod,
            new Object[]{id},
            methodProxy
        );
    }
}
```

### Using CGLIB (via Spring's Wrapper)

```java
Enhancer enhancer = new Enhancer();
enhancer.setSuperclass(UserServiceImpl.class);
enhancer.setCallback(new MethodInterceptor() {
    @Override
    public Object intercept(Object obj, Method method, Object[] args,
                           MethodProxy proxy) throws Throwable {
        System.out.println("Before: " + method.getName());
        Object result = proxy.invokeSuper(obj, args);
        System.out.println("After: " + method.getName());
        return result;
    }
});

UserServiceImpl proxy = (UserServiceImpl) enhancer.create();
proxy.findById(1L);  // Interception works!
```

### CGLIB Limitation: Final Classes

Since CGLIB uses subclassing, it can't proxy `final` classes or `final` methods:

```java
public final class FinalService {  // Can't proxy this!
    public final void doSomething() { }  // Or this!
}
```

---

## How Spring Uses Proxies

Spring uses proxies extensively:

### 1. @Transactional

```java
@Service
public class OrderService {
    @Transactional
    public void placeOrder(Order order) { ... }
}
```

Spring creates a proxy:

```java
// Pseudo-code of what Spring generates
class OrderService$$Proxy extends OrderService {
    private TransactionManager txManager;
    private OrderService target;

    @Override
    public void placeOrder(Order order) {
        Transaction tx = txManager.begin();
        try {
            target.placeOrder(order);
            tx.commit();
        } catch (Exception e) {
            tx.rollback();
            throw e;
        }
    }
}
```

### 2. @Async

```java
@Async
public Future<Result> processAsync() { ... }
```

The proxy submits the method call to a thread pool instead of executing directly.

### 3. @Cacheable

```java
@Cacheable("users")
public User findById(Long id) { ... }
```

The proxy checks the cache before calling the real method.

### 4. AOP (Aspect-Oriented Programming)

```java
@Aspect
public class LoggingAspect {
    @Around("execution(* com.example.service.*.*(..))")
    public Object log(ProceedingJoinPoint pjp) throws Throwable {
        System.out.println("Before: " + pjp.getSignature());
        Object result = pjp.proceed();
        System.out.println("After: " + pjp.getSignature());
        return result;
    }
}
```

Spring weaves this aspect into proxies for all matching methods.

---

## The Proxy Choice: JDK vs CGLIB

Spring decides which proxy mechanism to use:

```java
// If class implements interface -> JDK Proxy
@Service
public class UserServiceImpl implements UserService {
    // JDK proxy created (proxies UserService interface)
}

// If class has no interface -> CGLIB
@Service
public class OrderService {
    // CGLIB proxy created (extends OrderService)
}
```

You can force CGLIB:

```java
@EnableAspectJAutoProxy(proxyTargetClass = true)  // Always use CGLIB
```

---

## Bytecode Manipulation Libraries

Proxies are one use of bytecode manipulation. Libraries can do more:

### ASM: Low-Level Bytecode

ASM reads and writes Java bytecode directly:

```java
ClassReader reader = new ClassReader("com.example.User");
ClassWriter writer = new ClassWriter(reader, 0);

ClassVisitor visitor = new ClassVisitor(ASM9, writer) {
    @Override
    public MethodVisitor visitMethod(int access, String name,
                                     String descriptor, String signature,
                                     String[] exceptions) {
        MethodVisitor mv = super.visitMethod(access, name, descriptor,
                                            signature, exceptions);
        // Wrap with custom visitor to modify method
        return new LoggingMethodVisitor(mv);
    }
};

reader.accept(visitor, 0);
byte[] modifiedClass = writer.toByteArray();
```

Spring uses ASM for:
- Reading class metadata without loading classes
- Component scanning optimization
- Annotation processing

### ByteBuddy: High-Level API

ByteBuddy provides a friendlier API:

```java
Class<?> dynamicType = new ByteBuddy()
    .subclass(Object.class)
    .name("com.example.Generated")
    .method(named("toString"))
    .intercept(FixedValue.value("Hello World!"))
    .make()
    .load(getClass().getClassLoader())
    .getLoaded();

Object instance = dynamicType.newInstance();
instance.toString();  // "Hello World!"
```

### Javassist: Source-Level Manipulation

Javassist lets you write "source code" that compiles to bytecode:

```java
ClassPool pool = ClassPool.getDefault();
CtClass cc = pool.get("com.example.User");

CtMethod m = cc.getDeclaredMethod("getName");
m.insertBefore("System.out.println(\"getName called\");");

Class<?> modified = cc.toClass();
```

---

## The Self-Invocation Problem

A common gotcha with proxies:

```java
@Service
public class OrderService {
    @Transactional
    public void processOrder(Order order) {
        // Some logic
        validateOrder(order);  // Direct call - NO PROXY!
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void validateOrder(Order order) {
        // This WON'T get a new transaction!
    }
}
```

When `processOrder` calls `validateOrder`, it's a direct method call (`this.validateOrder()`), not through the proxy. The `@Transactional` on `validateOrder` is ignored.

**Solution 1: Self-injection**
```java
@Service
public class OrderService {
    @Autowired
    private OrderService self;  // Inject the proxy

    public void processOrder(Order order) {
        self.validateOrder(order);  // Goes through proxy
    }
}
```

**Solution 2: Separate class**
```java
@Service
public class OrderValidationService {
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void validateOrder(Order order) { ... }
}
```

---

## How Bytecode Works (Simplified)

Java bytecode is a stack-based instruction set:

```java
public int add(int a, int b) {
    return a + b;
}
```

Compiles to:

```
iload_1       // Push 'a' onto stack
iload_2       // Push 'b' onto stack
iadd          // Pop both, add, push result
ireturn       // Return top of stack
```

Bytecode manipulation tools:
1. Parse `.class` files into instruction objects
2. Allow adding/removing/modifying instructions
3. Serialize back to valid `.class` files
4. Load modified bytecode via ClassLoaders

This enables:
- Adding logging to methods
- Replacing method implementations
- Creating entirely new classes
- Implementing interfaces on-the-fly

---

## Spring Boot and Proxies

Spring Boot auto-configures proxy behavior:

```yaml
# application.properties
spring.aop.proxy-target-class=true  # Use CGLIB everywhere

# For specific modules
spring.data.jpa.repositories.bootstrap-mode=deferred  # Lazy proxy init
```

Many Spring Boot features rely on proxies:
- `@ConfigurationProperties` binding
- `@ConditionalOnBean` checks
- Actuator endpoints
- Security filters

---

## The Deeper Truth

Proxies and bytecode manipulation enable **aspect-oriented programming (AOP)**—the ability to add behavior across many classes without modifying them.

This separates **cross-cutting concerns**:
- Transactions
- Logging
- Security
- Caching
- Metrics
- Error handling

From **business logic**:
- Your actual domain code

Without proxies, these concerns would be tangled together in every method. With proxies, they're defined once and applied automatically.

This is a fundamental architectural pattern: **separation of concerns through interception**.

---

## Key Takeaways

1. **Proxies intercept method calls** without modifying original code
2. **JDK Proxies** work with interfaces; **CGLIB** works with classes
3. **Spring uses proxies** for @Transactional, @Async, @Cacheable, etc.
4. **Self-invocation bypasses proxies** — a common gotcha
5. **Bytecode libraries** (ASM, ByteBuddy, Javassist) enable advanced manipulation
6. **Proxies enable AOP** — separating cross-cutting concerns from business logic

---

*Next: [Chapter 7: The Traditional Way](../PART-2-INVERSION-OF-CONTROL/07-traditional-way.md)*
