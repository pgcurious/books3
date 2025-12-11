# Async Processing

## Running Tasks in Background Threads

---

## Overview

| Annotation | Purpose |
|------------|---------|
| `@Async` | Execute method asynchronously |
| `@EnableAsync` | Enable async processing |
| `@AsyncResult` | Wrap async return values |

---

## @EnableAsync - Enable Async Support

### Basic Setup

```java
@Configuration
@EnableAsync
public class AsyncConfig {
    // Async is now enabled
}
```

### With Custom Executor

```java
@Configuration
@EnableAsync
public class AsyncConfig implements AsyncConfigurer {

    @Override
    public Executor getAsyncExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(5);
        executor.setMaxPoolSize(10);
        executor.setQueueCapacity(25);
        executor.setThreadNamePrefix("Async-");
        executor.initialize();
        return executor;
    }

    @Override
    public AsyncUncaughtExceptionHandler getAsyncUncaughtExceptionHandler() {
        return (throwable, method, objects) -> {
            log.error("Async error in {}: {}", method.getName(), throwable.getMessage());
        };
    }
}
```

### Multiple Executors

```java
@Configuration
@EnableAsync
public class AsyncConfig {

    @Bean("emailExecutor")
    public Executor emailExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(2);
        executor.setMaxPoolSize(5);
        executor.setThreadNamePrefix("Email-");
        executor.initialize();
        return executor;
    }

    @Bean("reportExecutor")
    public Executor reportExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(1);
        executor.setMaxPoolSize(2);
        executor.setThreadNamePrefix("Report-");
        executor.initialize();
        return executor;
    }
}
```

---

## @Async - Asynchronous Methods

### Fire and Forget

```java
@Service
public class NotificationService {

    @Async
    public void sendEmail(String to, String subject, String body) {
        // Runs in background thread
        emailClient.send(to, subject, body);
        log.info("Email sent to {}", to);
    }

    @Async
    public void sendSms(String phone, String message) {
        smsClient.send(phone, message);
    }
}

// Usage
@Service
public class OrderService {

    private final NotificationService notificationService;

    public Order createOrder(CreateOrderRequest request) {
        Order order = orderRepository.save(new Order(request));

        // These run in background - method returns immediately
        notificationService.sendEmail(order.getUserEmail(), "Order Confirmed", "...");
        notificationService.sendSms(order.getUserPhone(), "Order #" + order.getId());

        return order;  // Returns before emails/sms are sent
    }
}
```

### With Specific Executor

```java
@Service
public class ReportService {

    @Async("reportExecutor")  // Use specific executor
    public void generateLargeReport(ReportRequest request) {
        // Heavy processing
    }

    @Async("emailExecutor")
    public void emailReport(String email, byte[] report) {
        // Send report via email
    }
}
```

### Returning Results with Future

```java
@Service
public class PricingService {

    @Async
    public Future<BigDecimal> calculatePrice(Product product) {
        BigDecimal price = complexCalculation(product);
        return new AsyncResult<>(price);
    }
}

// Usage
@Service
public class OrderService {

    public OrderTotal calculateTotal(List<Product> products) throws Exception {
        List<Future<BigDecimal>> futures = products.stream()
            .map(pricingService::calculatePrice)
            .collect(Collectors.toList());

        BigDecimal total = BigDecimal.ZERO;
        for (Future<BigDecimal> future : futures) {
            total = total.add(future.get());  // Blocks until complete
        }

        return new OrderTotal(total);
    }
}
```

### Returning CompletableFuture (Recommended)

```java
@Service
public class ExternalApiService {

    @Async
    public CompletableFuture<User> fetchUser(Long userId) {
        User user = externalApi.getUser(userId);
        return CompletableFuture.completedFuture(user);
    }

    @Async
    public CompletableFuture<List<Order>> fetchOrders(Long userId) {
        List<Order> orders = externalApi.getOrders(userId);
        return CompletableFuture.completedFuture(orders);
    }
}

// Usage with composition
@Service
public class UserProfileService {

    public CompletableFuture<UserProfile> buildProfile(Long userId) {
        CompletableFuture<User> userFuture = externalApiService.fetchUser(userId);
        CompletableFuture<List<Order>> ordersFuture = externalApiService.fetchOrders(userId);

        return userFuture.thenCombine(ordersFuture, (user, orders) -> {
            return new UserProfile(user, orders);
        });
    }

    // Or wait for all
    public UserProfile buildProfileBlocking(Long userId) {
        CompletableFuture<User> userFuture = externalApiService.fetchUser(userId);
        CompletableFuture<List<Order>> ordersFuture = externalApiService.fetchOrders(userId);

        CompletableFuture.allOf(userFuture, ordersFuture).join();

        return new UserProfile(userFuture.join(), ordersFuture.join());
    }
}
```

### Returning ListenableFuture

```java
@Service
public class AsyncService {

    @Async
    public ListenableFuture<String> processData(String input) {
        String result = heavyProcessing(input);
        return new AsyncResult<>(result);
    }
}

// Usage with callbacks
asyncService.processData("input").addCallback(
    result -> log.info("Success: {}", result),
    error -> log.error("Failed: {}", error.getMessage())
);
```

---

## Exception Handling

### For void Methods

```java
@Configuration
@EnableAsync
public class AsyncConfig implements AsyncConfigurer {

    @Override
    public AsyncUncaughtExceptionHandler getAsyncUncaughtExceptionHandler() {
        return new CustomAsyncExceptionHandler();
    }
}

public class CustomAsyncExceptionHandler implements AsyncUncaughtExceptionHandler {

    @Override
    public void handleUncaughtException(Throwable ex, Method method, Object... params) {
        log.error("Async exception in method {}: {}", method.getName(), ex.getMessage());

        // Send alert, record metric, etc.
        alertService.sendAlert("Async failure", ex);
    }
}
```

### For Future-Returning Methods

```java
@Service
public class DataService {

    @Async
    public CompletableFuture<Data> fetchData(String id) {
        try {
            Data data = externalService.fetch(id);
            return CompletableFuture.completedFuture(data);
        } catch (Exception e) {
            CompletableFuture<Data> future = new CompletableFuture<>();
            future.completeExceptionally(e);
            return future;
        }
    }
}

// Handling
dataService.fetchData("123")
    .exceptionally(ex -> {
        log.error("Failed to fetch data", ex);
        return defaultData();
    })
    .thenAccept(data -> process(data));
```

---

## Common Pitfalls

### Self-Invocation Doesn't Work

```java
@Service
public class MyService {

    // WRONG: @Async is ignored when called from same class
    public void methodA() {
        methodB();  // Runs synchronously!
    }

    @Async
    public void methodB() {
        // This should be async, but isn't when called from methodA
    }
}

// FIX: Inject self or separate into another service
@Service
public class MyService {

    @Autowired
    private MyService self;  // Inject proxy

    public void methodA() {
        self.methodB();  // Now async works!
    }

    @Async
    public void methodB() { }
}
```

### Transaction Context Lost

```java
@Service
public class OrderService {

    @Transactional
    public void createOrder(CreateOrderRequest request) {
        Order order = orderRepository.save(new Order(request));

        // PROBLEM: @Async method loses transaction context
        notificationService.sendConfirmation(order);
    }
}

// FIX: Pass only IDs, fetch fresh in async method
@Service
public class NotificationService {

    @Async
    @Transactional  // New transaction
    public void sendConfirmation(Long orderId) {
        Order order = orderRepository.findById(orderId).orElseThrow();
        // Now has fresh transaction context
    }
}
```

### Security Context Lost

```java
// Security context is lost in async methods by default
@Async
public void processUserData() {
    // SecurityContextHolder.getContext() is empty!
}

// FIX: Configure security context propagation
@Configuration
@EnableAsync
public class AsyncConfig {

    @Bean
    public Executor taskExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(5);
        executor.setMaxPoolSize(10);
        executor.initialize();
        return new DelegatingSecurityContextExecutor(executor);
    }
}
```

---

## Best Practices

### 1. Configure Proper Thread Pool

```java
@Bean
public Executor asyncExecutor() {
    ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();

    // Size based on task type
    // CPU-bound: cores + 1
    // I/O-bound: cores * 2 or more

    int cores = Runtime.getRuntime().availableProcessors();
    executor.setCorePoolSize(cores);
    executor.setMaxPoolSize(cores * 2);

    // Queue size - consider memory
    executor.setQueueCapacity(100);

    // Rejection policy
    executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());

    // Graceful shutdown
    executor.setWaitForTasksToCompleteOnShutdown(true);
    executor.setAwaitTerminationSeconds(30);

    executor.setThreadNamePrefix("Async-");
    executor.initialize();

    return executor;
}
```

### 2. Use CompletableFuture for Composition

```java
@Service
public class AggregatorService {

    @Async
    public CompletableFuture<UserData> fetchUserData(Long userId) {
        return CompletableFuture.completedFuture(userApi.fetch(userId));
    }

    @Async
    public CompletableFuture<List<Order>> fetchOrders(Long userId) {
        return CompletableFuture.completedFuture(orderApi.fetch(userId));
    }

    @Async
    public CompletableFuture<Preferences> fetchPreferences(Long userId) {
        return CompletableFuture.completedFuture(prefApi.fetch(userId));
    }

    public CompletableFuture<UserProfile> buildProfile(Long userId) {
        return fetchUserData(userId)
            .thenCombine(fetchOrders(userId), (user, orders) ->
                new PartialProfile(user, orders))
            .thenCombine(fetchPreferences(userId), (partial, prefs) ->
                new UserProfile(partial.user(), partial.orders(), prefs));
    }
}
```

### 3. Add Timeout Handling

```java
@Service
public class TimeoutAwareService {

    @Async
    public CompletableFuture<Data> fetchWithTimeout(String id) {
        return CompletableFuture.completedFuture(slowService.fetch(id));
    }

    public Data fetchSafely(String id) {
        try {
            return fetchWithTimeout(id)
                .orTimeout(5, TimeUnit.SECONDS)
                .join();
        } catch (CompletionException e) {
            if (e.getCause() instanceof TimeoutException) {
                return defaultData();
            }
            throw e;
        }
    }
}
```

---

## Key Takeaways

1. **@EnableAsync required** to activate @Async
2. **Configure thread pool** - don't rely on defaults
3. **Use CompletableFuture** for composable async operations
4. **Self-invocation bypasses @Async** - inject self or separate classes
5. **Transaction/Security context** is lost - handle explicitly
6. **Handle exceptions** via AsyncUncaughtExceptionHandler or Future

---

*Next: [Scheduling & Cron](./13-scheduling.md)*
