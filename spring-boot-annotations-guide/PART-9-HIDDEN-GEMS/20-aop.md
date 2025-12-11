# AOP Annotations

## Aspect-Oriented Programming with Spring

---

## Overview

| Annotation | Purpose |
|------------|---------|
| `@Aspect` | Define an aspect |
| `@Before` | Run before method |
| `@After` | Run after method (always) |
| `@AfterReturning` | Run after successful return |
| `@AfterThrowing` | Run after exception |
| `@Around` | Wrap method execution |
| `@Pointcut` | Define reusable pointcut |

---

## Enabling AOP

```java
@Configuration
@EnableAspectJAutoProxy
public class AopConfig { }

// Or with Spring Boot - auto-enabled with spring-boot-starter-aop
```

---

## @Aspect - Defining Aspects

### Basic Aspect

```java
@Aspect
@Component
public class LoggingAspect {

    @Before("execution(* com.myapp.service.*.*(..))")
    public void logBefore(JoinPoint joinPoint) {
        log.info("Calling: {}", joinPoint.getSignature().getName());
    }
}
```

---

## Pointcut Expressions

### Method Execution

```java
// All methods in service package
@Before("execution(* com.myapp.service.*.*(..))")

// All methods in service package and subpackages
@Before("execution(* com.myapp.service..*.*(..))")

// Methods starting with "find"
@Before("execution(* find*(..))")

// Methods returning String
@Before("execution(String *(..))")

// Methods with specific parameter types
@Before("execution(* *..UserService.findById(Long))")

// Any public method
@Before("execution(public * *(..))")
```

### Within

```java
// All methods within a type
@Before("within(com.myapp.service.UserService)")

// All methods within a package
@Before("within(com.myapp.service..*)")
```

### Annotation-Based

```java
// Methods annotated with @Transactional
@Before("@annotation(org.springframework.transaction.annotation.Transactional)")

// Classes annotated with @Service
@Before("@within(org.springframework.stereotype.Service)")

// Target object annotated with @RestController
@Before("@target(org.springframework.web.bind.annotation.RestController)")
```

### Bean-Based

```java
// Specific bean
@Before("bean(userService)")

// Beans matching pattern
@Before("bean(*Service)")
```

### Combining Pointcuts

```java
// AND
@Before("execution(* com.myapp.service.*.*(..)) && @annotation(Logged)")

// OR
@Before("execution(* com.myapp.service.*.*(..)) || execution(* com.myapp.repository.*.*(..))")

// NOT
@Before("execution(* com.myapp.service.*.*(..)) && !execution(* *.internal*(..))")
```

---

## @Pointcut - Reusable Pointcuts

```java
@Aspect
@Component
public class PointcutDefinitions {

    @Pointcut("execution(* com.myapp.service.*.*(..))")
    public void serviceLayer() { }

    @Pointcut("execution(* com.myapp.repository.*.*(..))")
    public void repositoryLayer() { }

    @Pointcut("@annotation(com.myapp.annotation.Logged)")
    public void loggedMethods() { }

    @Pointcut("serviceLayer() || repositoryLayer()")
    public void dataAccessLayer() { }
}

// Use in aspects
@Aspect
@Component
public class LoggingAspect {

    @Before("com.myapp.aspect.PointcutDefinitions.serviceLayer()")
    public void logServiceCall(JoinPoint jp) {
        log.info("Service call: {}", jp.getSignature());
    }
}
```

---

## @Before - Run Before Method

```java
@Aspect
@Component
public class ValidationAspect {

    @Before("execution(* com.myapp.service.*.create*(..)) && args(request,..)")
    public void validateBeforeCreate(JoinPoint jp, Object request) {
        log.info("Validating before create: {}", request);
        // Validation logic
    }
}
```

---

## @After - Run After Method (Always)

```java
@Aspect
@Component
public class ResourceAspect {

    @After("execution(* com.myapp.service.*.*(..)))")
    public void cleanup(JoinPoint jp) {
        // Always runs - even if exception thrown
        log.debug("Method completed: {}", jp.getSignature().getName());
    }
}
```

---

## @AfterReturning - Run After Success

```java
@Aspect
@Component
public class AuditAspect {

    @AfterReturning(
        pointcut = "execution(* com.myapp.service.UserService.create*(..))",
        returning = "result"
    )
    public void auditUserCreation(JoinPoint jp, User result) {
        auditService.log("User created: " + result.getId());
    }

    @AfterReturning(
        pointcut = "execution(* com.myapp.service.*.*(..))",
        returning = "result"
    )
    public void logReturn(JoinPoint jp, Object result) {
        log.debug("{} returned: {}", jp.getSignature().getName(), result);
    }
}
```

---

## @AfterThrowing - Run After Exception

```java
@Aspect
@Component
public class ExceptionLoggingAspect {

    @AfterThrowing(
        pointcut = "execution(* com.myapp.service.*.*(..))",
        throwing = "ex"
    )
    public void logException(JoinPoint jp, Exception ex) {
        log.error("Exception in {}: {}",
            jp.getSignature().getName(),
            ex.getMessage()
        );
    }

    @AfterThrowing(
        pointcut = "execution(* com.myapp.service.*.*(..))",
        throwing = "ex"
    )
    public void handleSpecificException(JoinPoint jp, BusinessException ex) {
        // Only catches BusinessException
        alertService.notify("Business exception", ex);
    }
}
```

---

## @Around - Full Control

### Basic Around

```java
@Aspect
@Component
public class PerformanceAspect {

    @Around("execution(* com.myapp.service.*.*(..))")
    public Object measureTime(ProceedingJoinPoint pjp) throws Throwable {
        long start = System.currentTimeMillis();

        try {
            return pjp.proceed();  // Execute the method
        } finally {
            long duration = System.currentTimeMillis() - start;
            log.info("{} took {}ms", pjp.getSignature().getName(), duration);
        }
    }
}
```

### Modify Arguments

```java
@Aspect
@Component
public class InputSanitizerAspect {

    @Around("execution(* com.myapp.service.*.*(String, ..)) && args(input, ..)")
    public Object sanitizeInput(ProceedingJoinPoint pjp, String input) throws Throwable {
        // Sanitize input
        String sanitized = HtmlUtils.htmlEscape(input);

        // Create new args array with sanitized input
        Object[] args = pjp.getArgs();
        args[0] = sanitized;

        return pjp.proceed(args);
    }
}
```

### Modify Return Value

```java
@Aspect
@Component
public class ResponseWrapperAspect {

    @Around("@annotation(com.myapp.annotation.WrapResponse)")
    public Object wrapResponse(ProceedingJoinPoint pjp) throws Throwable {
        Object result = pjp.proceed();

        return new ApiResponse<>(
            "success",
            result,
            System.currentTimeMillis()
        );
    }
}
```

### Caching Example

```java
@Aspect
@Component
public class CachingAspect {

    private final Map<String, Object> cache = new ConcurrentHashMap<>();

    @Around("@annotation(cacheable)")
    public Object cache(ProceedingJoinPoint pjp, Cacheable cacheable) throws Throwable {
        String key = generateKey(pjp, cacheable);

        if (cache.containsKey(key)) {
            log.debug("Cache hit for {}", key);
            return cache.get(key);
        }

        Object result = pjp.proceed();
        cache.put(key, result);
        log.debug("Cached result for {}", key);

        return result;
    }

    private String generateKey(ProceedingJoinPoint pjp, Cacheable cacheable) {
        return pjp.getSignature().toShortString() +
               Arrays.toString(pjp.getArgs());
    }
}
```

---

## Common Use Cases

### Logging Aspect

```java
@Aspect
@Component
@Slf4j
public class LoggingAspect {

    @Around("@annotation(logged)")
    public Object log(ProceedingJoinPoint pjp, Logged logged) throws Throwable {
        String methodName = pjp.getSignature().toShortString();
        Object[] args = pjp.getArgs();

        log.info("Entering {} with args: {}", methodName, Arrays.toString(args));

        try {
            Object result = pjp.proceed();
            log.info("Exiting {} with result: {}", methodName, result);
            return result;
        } catch (Exception e) {
            log.error("Exception in {}: {}", methodName, e.getMessage());
            throw e;
        }
    }
}

// Usage
@Service
public class UserService {

    @Logged
    public User findById(Long id) {
        return userRepository.findById(id).orElseThrow();
    }
}
```

### Retry Aspect

```java
@Aspect
@Component
public class RetryAspect {

    @Around("@annotation(retryable)")
    public Object retry(ProceedingJoinPoint pjp, Retryable retryable) throws Throwable {
        int maxAttempts = retryable.maxAttempts();
        long delay = retryable.delay();
        Exception lastException = null;

        for (int attempt = 1; attempt <= maxAttempts; attempt++) {
            try {
                return pjp.proceed();
            } catch (Exception e) {
                lastException = e;
                log.warn("Attempt {} failed: {}", attempt, e.getMessage());

                if (attempt < maxAttempts) {
                    Thread.sleep(delay);
                }
            }
        }

        throw lastException;
    }
}

@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface Retryable {
    int maxAttempts() default 3;
    long delay() default 1000;
}

// Usage
@Retryable(maxAttempts = 5, delay = 2000)
public void callExternalService() { }
```

### Security Aspect

```java
@Aspect
@Component
public class SecurityAspect {

    @Before("@annotation(requiresRole)")
    public void checkRole(RequiresRole requiresRole) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();

        boolean hasRole = auth.getAuthorities().stream()
            .anyMatch(a -> a.getAuthority().equals("ROLE_" + requiresRole.value()));

        if (!hasRole) {
            throw new AccessDeniedException("Required role: " + requiresRole.value());
        }
    }
}

@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface RequiresRole {
    String value();
}

// Usage
@RequiresRole("ADMIN")
public void deleteUser(Long id) { }
```

---

## Aspect Ordering

```java
@Aspect
@Component
@Order(1)  // Runs first
public class SecurityAspect { }

@Aspect
@Component
@Order(2)  // Runs second
public class LoggingAspect { }

@Aspect
@Component
@Order(3)  // Runs third
public class PerformanceAspect { }
```

---

## Key Takeaways

1. **@Aspect + @Component** to define aspects
2. **Pointcuts** define where advice applies
3. **@Around** gives full control over method execution
4. **ProceedingJoinPoint.proceed()** executes the target method
5. **Order matters** - use @Order for multiple aspects
6. **AOP proxies** - be aware of self-invocation limitations
7. **Use for cross-cutting concerns** - logging, security, caching

---

*Next: [Actuator & Metrics](./21-actuator-metrics.md)*
