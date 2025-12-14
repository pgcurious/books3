# Chapter 13: AOP—Cross-Cutting Concerns

> *"Separation of concerns, even if not perfectly possible, is yet the only available technique for effective ordering of one's thoughts."*
> — Edsger W. Dijkstra

---

## The Problem: Code That Spreads Everywhere

Some concerns don't fit neatly into classes:

```java
public class UserService {
    public User getUser(Long id) {
        logger.info("getUser called");           // Logging
        checkPermission("USER_READ");            // Security
        long start = System.currentTimeMillis(); // Metrics

        try {
            Transaction tx = beginTransaction();  // Transaction
            try {
                User user = userRepository.findById(id);
                tx.commit();
                return user;
            } catch (Exception e) {
                tx.rollback();
                throw e;
            }
        } finally {
            long duration = System.currentTimeMillis() - start;
            metrics.record("getUser.duration", duration);  // Metrics
            logger.info("getUser completed in " + duration + "ms");  // Logging
        }
    }
}
```

The actual business logic is one line: `userRepository.findById(id)`. The rest is **cross-cutting concerns**—aspects that cut across multiple classes.

These concerns are:
- **Repeated** in many methods
- **Tangled** with business logic
- **Scattered** across the codebase

---

## What Is AOP?

**Aspect-Oriented Programming (AOP)** separates cross-cutting concerns from business logic.

Instead of:
```java
public void process() {
    log("start");        // Cross-cutting
    doBusinessLogic();   // Business
    log("end");          // Cross-cutting
}
```

You write:
```java
// Business code (clean)
public void process() {
    doBusinessLogic();
}

// Aspect (separate)
@Around("execution(* process())")
public void logAround(ProceedingJoinPoint pjp) {
    log("start");
    pjp.proceed();
    log("end");
}
```

The aspect is **woven** into the business code at runtime (or compile time).

---

## AOP Terminology

| Term | Meaning |
|------|---------|
| **Aspect** | A module encapsulating a cross-cutting concern |
| **Join Point** | A point in execution where aspect can be applied (method call, field access) |
| **Pointcut** | An expression that selects join points |
| **Advice** | Action taken at a join point (the actual code that runs) |
| **Weaving** | Process of applying aspects to target objects |

### Visual Representation

```
                    ASPECT: LoggingAspect
                    ┌────────────────────────────────────┐
                    │  @Around("execution(* service.*.*(..))")
                    │  public Object log(ProceedingJoinPoint pjp) {
                    │      logger.info("Before: " + pjp.getSignature());
    POINTCUT ───────│      Object result = pjp.proceed();
                    │      logger.info("After: " + pjp.getSignature());
                    │      return result;
                    │  }
                    └────────────────────────────────────┘
                                    │
                                    │ WEAVING
                                    ▼
        ┌─────────────────────────────────────────────────────┐
        │                  JOIN POINTS                         │
        │                                                      │
        │   UserService.getUser()  ─────┐                     │
        │   UserService.saveUser() ─────┼──── Matched by      │
        │   OrderService.create()  ─────┤     pointcut        │
        │   OrderService.cancel()  ─────┘                     │
        │                                                      │
        └─────────────────────────────────────────────────────┘
```

---

## Advice Types

### @Before: Run Before the Method

```java
@Aspect
@Component
public class SecurityAspect {
    @Before("execution(* com.example.service.*.*(..))")
    public void checkSecurity(JoinPoint joinPoint) {
        // Runs BEFORE the target method
        if (!SecurityContext.isAuthenticated()) {
            throw new SecurityException("Not authenticated");
        }
    }
}
```

### @After: Run After the Method (Finally)

```java
@Aspect
@Component
public class CleanupAspect {
    @After("execution(* com.example.service.*.*(..))")
    public void cleanup(JoinPoint joinPoint) {
        // Runs AFTER method, regardless of outcome (like finally)
        ThreadLocalContext.clear();
    }
}
```

### @AfterReturning: Run After Successful Return

```java
@Aspect
@Component
public class AuditAspect {
    @AfterReturning(
        pointcut = "execution(* com.example.service.*.save*(..))",
        returning = "result"
    )
    public void auditSave(JoinPoint joinPoint, Object result) {
        // Runs only if method returns successfully
        auditLog.record("Saved: " + result);
    }
}
```

### @AfterThrowing: Run After Exception

```java
@Aspect
@Component
public class ErrorHandlingAspect {
    @AfterThrowing(
        pointcut = "execution(* com.example.service.*.*(..))",
        throwing = "ex"
    )
    public void handleError(JoinPoint joinPoint, Exception ex) {
        // Runs only if method throws exception
        errorReporter.report(joinPoint.getSignature().toString(), ex);
    }
}
```

### @Around: Full Control

```java
@Aspect
@Component
public class PerformanceAspect {
    @Around("execution(* com.example.service.*.*(..))")
    public Object measureTime(ProceedingJoinPoint pjp) throws Throwable {
        long start = System.currentTimeMillis();
        try {
            return pjp.proceed();  // Call the actual method
        } finally {
            long duration = System.currentTimeMillis() - start;
            metrics.record(pjp.getSignature().getName() + ".duration", duration);
        }
    }
}
```

`@Around` is the most powerful—it can:
- Modify arguments
- Prevent the method from running
- Modify the return value
- Handle exceptions

---

## Pointcut Expressions

Pointcuts define *where* advice applies.

### Method Execution Patterns

```java
// All methods in service package
execution(* com.example.service.*.*(..))

// All public methods
execution(public * *(..))

// Methods returning String
execution(String *(..))

// Methods with specific name
execution(* save*(..))

// Methods with specific parameter
execution(* *(Long, ..))
```

### Annotation-Based Pointcuts

```java
// Methods annotated with @Transactional
@annotation(org.springframework.transaction.annotation.Transactional)

// Classes annotated with @Service
@within(org.springframework.stereotype.Service)

// Methods in classes annotated with @RestController
@target(org.springframework.web.bind.annotation.RestController)
```

### Combining Pointcuts

```java
@Pointcut("execution(* com.example.service.*.*(..))")
public void serviceLayer() {}

@Pointcut("execution(* com.example.repository.*.*(..))")
public void repositoryLayer() {}

@Pointcut("serviceLayer() || repositoryLayer()")
public void businessLayer() {}

@Around("businessLayer()")
public Object logBusinessCalls(ProceedingJoinPoint pjp) { ... }
```

---

## How Spring AOP Works

Spring AOP uses **proxies** (Chapter 6). When you apply aspects:

### For Interface-Based Beans (JDK Proxy)

```java
public interface UserService {
    User getUser(Long id);
}

@Service
public class UserServiceImpl implements UserService {
    public User getUser(Long id) { ... }
}
```

Spring creates:

```java
// Proxy implementing the interface
public class $Proxy123 implements UserService {
    private UserService target;
    private List<MethodInterceptor> interceptors;

    public User getUser(Long id) {
        // Run interceptors (aspects) before/around/after
        return invokeWithInterceptors(target::getUser, id);
    }
}
```

### For Class-Based Beans (CGLIB Proxy)

```java
@Service
public class OrderService {  // No interface
    public void process() { ... }
}
```

Spring creates:

```java
// Subclass proxy
public class OrderService$$EnhancerBySpringCGLIB extends OrderService {
    @Override
    public void process() {
        // Run interceptors (aspects) before/around/after
        invokeWithInterceptors(super::process);
    }
}
```

---

## Real-World Examples

### Example 1: @Transactional

```java
@Aspect
public class TransactionAspect {
    @Around("@annotation(transactional)")
    public Object handleTransaction(ProceedingJoinPoint pjp,
                                   Transactional transactional) throws Throwable {
        TransactionStatus tx = txManager.begin(transactional.readOnly());
        try {
            Object result = pjp.proceed();
            tx.commit();
            return result;
        } catch (Throwable t) {
            if (shouldRollback(transactional, t)) {
                tx.rollback();
            }
            throw t;
        }
    }
}
```

### Example 2: Method-Level Caching

```java
@Aspect
@Component
public class CacheAspect {
    private final Map<String, Object> cache = new ConcurrentHashMap<>();

    @Around("@annotation(cacheable)")
    public Object cacheResult(ProceedingJoinPoint pjp,
                             Cacheable cacheable) throws Throwable {
        String key = generateKey(pjp, cacheable);

        if (cache.containsKey(key)) {
            return cache.get(key);
        }

        Object result = pjp.proceed();
        cache.put(key, result);
        return result;
    }
}
```

### Example 3: Rate Limiting

```java
@Aspect
@Component
public class RateLimitAspect {
    private final RateLimiter limiter = RateLimiter.create(100); // 100 req/sec

    @Around("@annotation(RateLimited)")
    public Object rateLimit(ProceedingJoinPoint pjp) throws Throwable {
        if (!limiter.tryAcquire()) {
            throw new TooManyRequestsException();
        }
        return pjp.proceed();
    }
}
```

---

## AOP Limitations in Spring

### 1. Self-Invocation Doesn't Trigger Aspects

```java
@Service
public class UserService {
    @Transactional
    public void createUser(User user) {
        // ...
        notifyAdmins(user);  // Direct call - NO PROXY!
    }

    @Transactional(propagation = REQUIRES_NEW)
    public void notifyAdmins(User user) {
        // This transaction annotation is IGNORED
    }
}
```

**Fix: Inject self or use separate class**

### 2. Only Public Methods

Spring AOP only intercepts public methods. Private/protected methods are not proxied.

### 3. Final Classes/Methods

CGLIB can't proxy `final` classes or override `final` methods.

### 4. Runtime Only

Spring AOP is runtime-based (proxies). For compile-time weaving, use AspectJ directly.

---

## AspectJ vs Spring AOP

| Feature | Spring AOP | AspectJ |
|---------|------------|---------|
| Weaving | Runtime (proxies) | Compile/Load time |
| Join points | Method execution only | Method, field, constructor, etc. |
| Performance | Slight overhead | No runtime overhead |
| Self-invocation | Not intercepted | Intercepted |
| Complexity | Simple | More complex |

For most applications, Spring AOP is sufficient. Use AspectJ for:
- Performance-critical applications
- Need to intercept private methods
- Need field access interception

---

## Enabling AOP

### Spring Boot

```java
// Auto-configured, just add aspect
@Aspect
@Component
public class MyAspect { ... }
```

### Manual Configuration

```java
@Configuration
@EnableAspectJAutoProxy
public class AopConfig { }
```

With CGLIB proxying:
```java
@EnableAspectJAutoProxy(proxyTargetClass = true)
```

---

## Key Takeaways

1. **AOP separates cross-cutting concerns** from business logic
2. **Aspects encapsulate** concerns like logging, security, transactions
3. **Pointcuts select** where advice applies
4. **Advice types** control when code runs (before, after, around)
5. **Spring AOP uses proxies** — limited but simple
6. **Self-invocation bypasses aspects** — a common gotcha
7. **@Transactional, @Cacheable, @Async** all use AOP internally

---

*Next: [Chapter 14: The Problem Spring Boot Solves](../PART-4-SPRING-BOOT/14-spring-boot-problem.md)*
