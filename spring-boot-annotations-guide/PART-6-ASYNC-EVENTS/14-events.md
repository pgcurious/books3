# Event-Driven Architecture

## Decoupling Components with Application Events

---

## Overview

| Annotation | Purpose |
|------------|---------|
| `@EventListener` | Handle application events |
| `@TransactionalEventListener` | Handle events with transaction awareness |
| `@Async` + `@EventListener` | Handle events asynchronously |

---

## Application Events Basics

### Publishing Events

```java
// Define an event
public class UserCreatedEvent {
    private final User user;

    public UserCreatedEvent(User user) {
        this.user = user;
    }

    public User getUser() {
        return user;
    }
}

// Publish event
@Service
public class UserService {

    private final ApplicationEventPublisher eventPublisher;

    public User createUser(CreateUserRequest request) {
        User user = userRepository.save(new User(request));

        // Publish event
        eventPublisher.publishEvent(new UserCreatedEvent(user));

        return user;
    }
}
```

### Listening to Events

```java
@Component
public class UserEventListeners {

    @EventListener
    public void handleUserCreated(UserCreatedEvent event) {
        User user = event.getUser();
        log.info("User created: {}", user.getEmail());
        // Send welcome email, initialize preferences, etc.
    }
}
```

---

## @EventListener - Annotation-Based Listeners

### Basic Usage

```java
@Component
public class NotificationListener {

    @EventListener
    public void onUserCreated(UserCreatedEvent event) {
        emailService.sendWelcomeEmail(event.getUser());
    }

    @EventListener
    public void onOrderPlaced(OrderPlacedEvent event) {
        smsService.sendOrderConfirmation(event.getOrder());
    }
}
```

### Conditional Listening

```java
@Component
public class ConditionalListener {

    // Only handle events matching condition
    @EventListener(condition = "#event.user.role == 'ADMIN'")
    public void onAdminCreated(UserCreatedEvent event) {
        securityAudit.logAdminCreation(event.getUser());
    }

    @EventListener(condition = "#event.order.total > 1000")
    public void onHighValueOrder(OrderPlacedEvent event) {
        vipService.processHighValueOrder(event.getOrder());
    }
}
```

### Multiple Event Types

```java
@Component
public class AuditListener {

    // Listen to multiple event types
    @EventListener({ UserCreatedEvent.class, UserDeletedEvent.class })
    public void onUserChange(Object event) {
        auditService.log(event);
    }

    // Or use common interface
    @EventListener
    public void onAuditableEvent(AuditableEvent event) {
        auditService.log(event.getDescription());
    }
}
```

### Returning Events (Event Chaining)

```java
@Component
public class EventChainListener {

    // Return event triggers another event
    @EventListener
    public OrderShippedEvent onOrderPaid(OrderPaidEvent event) {
        shipmentService.ship(event.getOrder());
        return new OrderShippedEvent(event.getOrder());
    }

    // Return multiple events
    @EventListener
    public List<Object> onUserCreated(UserCreatedEvent event) {
        return List.of(
            new WelcomeEmailEvent(event.getUser()),
            new AccountSetupEvent(event.getUser())
        );
    }
}
```

---

## @TransactionalEventListener - Transaction-Aware Events

### After Commit (Default)

```java
@Component
public class TransactionalListener {

    // Runs AFTER transaction commits successfully
    @TransactionalEventListener
    public void afterUserCommitted(UserCreatedEvent event) {
        // Safe - user is definitely in the database
        emailService.sendWelcomeEmail(event.getUser());
    }
}
```

### Transaction Phases

```java
@Component
public class TransactionAwareListener {

    // After successful commit (default)
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void afterCommit(OrderPlacedEvent event) {
        // Transaction committed, order is saved
        notificationService.sendConfirmation(event.getOrder());
    }

    // After rollback
    @TransactionalEventListener(phase = TransactionPhase.AFTER_ROLLBACK)
    public void afterRollback(OrderPlacedEvent event) {
        // Transaction failed
        log.error("Order failed: {}", event.getOrder().getId());
        alertService.notifyOrderFailure(event.getOrder());
    }

    // After completion (commit OR rollback)
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMPLETION)
    public void afterCompletion(OrderPlacedEvent event) {
        // Always runs
        metricsService.recordOrderAttempt(event.getOrder());
    }

    // Before commit (during transaction)
    @TransactionalEventListener(phase = TransactionPhase.BEFORE_COMMIT)
    public void beforeCommit(OrderPlacedEvent event) {
        // Runs while transaction is still active
        // Can still cause rollback by throwing exception
        validationService.finalValidation(event.getOrder());
    }
}
```

### Fallback for Non-Transactional Context

```java
@Component
public class RobustListener {

    // Handle even when no transaction exists
    @TransactionalEventListener(fallbackExecution = true)
    public void handleEvent(UserCreatedEvent event) {
        // Runs even if publisher wasn't in a transaction
    }
}
```

---

## Async Event Handling

### Async Listeners

```java
@Component
public class AsyncEventListeners {

    @Async
    @EventListener
    public void onUserCreatedAsync(UserCreatedEvent event) {
        // Runs in separate thread
        // Does not block the publisher
        heavyProcessing(event.getUser());
    }
}
```

### Async Transactional Events

```java
@Component
public class AsyncTransactionalListener {

    @Async
    @TransactionalEventListener
    public void afterCommitAsync(OrderPlacedEvent event) {
        // Runs async AFTER transaction commits
        // Best of both worlds
        sendNotifications(event.getOrder());
    }
}
```

---

## Spring Built-in Events

### Application Lifecycle Events

```java
@Component
public class ApplicationEventListeners {

    @EventListener
    public void onStartup(ApplicationReadyEvent event) {
        log.info("Application is ready");
    }

    @EventListener
    public void onContextRefreshed(ContextRefreshedEvent event) {
        log.info("Context refreshed");
    }

    @EventListener
    public void onContextClosed(ContextClosedEvent event) {
        log.info("Context closing");
    }

    @EventListener
    public void onStarted(ApplicationStartedEvent event) {
        log.info("Application started");
    }
}
```

### Servlet Events

```java
@Component
public class SessionEventListeners {

    @EventListener
    public void onSessionCreated(HttpSessionCreatedEvent event) {
        log.info("Session created: {}", event.getSession().getId());
    }

    @EventListener
    public void onSessionDestroyed(HttpSessionDestroyedEvent event) {
        log.info("Session destroyed: {}", event.getSession().getId());
    }
}
```

---

## Event Design Patterns

### Rich Domain Events

```java
// Event carries all needed data
public class OrderPlacedEvent {
    private final Long orderId;
    private final Long customerId;
    private final BigDecimal total;
    private final List<OrderItem> items;
    private final Instant timestamp;

    // Constructor, getters
}

@Service
public class OrderService {

    @Transactional
    public Order placeOrder(CreateOrderRequest request) {
        Order order = orderRepository.save(new Order(request));

        // Event contains snapshot of data
        eventPublisher.publishEvent(new OrderPlacedEvent(
            order.getId(),
            order.getCustomerId(),
            order.getTotal(),
            order.getItems(),
            Instant.now()
        ));

        return order;
    }
}
```

### Event with ID Only

```java
// Event carries only ID, listener fetches fresh data
public record OrderPlacedEvent(Long orderId) { }

@Component
public class OrderEventListener {

    @Async
    @TransactionalEventListener
    public void onOrderPlaced(OrderPlacedEvent event) {
        // Fetch fresh data in new transaction
        Order order = orderRepository.findById(event.orderId())
            .orElseThrow();
        processOrder(order);
    }
}
```

### Base Event Class

```java
public abstract class DomainEvent {
    private final String eventId = UUID.randomUUID().toString();
    private final Instant timestamp = Instant.now();

    public String getEventId() { return eventId; }
    public Instant getTimestamp() { return timestamp; }
}

public class UserCreatedEvent extends DomainEvent {
    private final Long userId;

    public UserCreatedEvent(Long userId) {
        this.userId = userId;
    }
}
```

---

## Ordering Listeners

```java
@Component
public class OrderedListeners {

    @EventListener
    @Order(1)  // Runs first
    public void firstHandler(MyEvent event) {
        log.info("First handler");
    }

    @EventListener
    @Order(2)  // Runs second
    public void secondHandler(MyEvent event) {
        log.info("Second handler");
    }

    @EventListener
    @Order(Ordered.LOWEST_PRECEDENCE)  // Runs last
    public void lastHandler(MyEvent event) {
        log.info("Last handler");
    }
}
```

---

## Exception Handling

```java
@Component
public class ErrorAwareListener {

    @EventListener
    public void handleEvent(ImportantEvent event) {
        try {
            process(event);
        } catch (TransientException e) {
            // Log and continue
            log.warn("Transient error: {}", e.getMessage());
        } catch (Exception e) {
            // Log but don't propagate (event already published)
            log.error("Error handling event", e);
            errorReportService.report(event, e);
        }
    }
}
```

### Global Exception Handler

```java
@Component
public class EventExceptionHandler implements ApplicationListener<PayloadApplicationEvent<?>> {

    @Override
    public void onApplicationEvent(PayloadApplicationEvent<?> event) {
        // Handle or log
    }
}
```

---

## Testing Events

```java
@SpringBootTest
class OrderServiceTest {

    @Autowired
    private OrderService orderService;

    @MockBean
    private ApplicationEventPublisher eventPublisher;

    @Test
    void shouldPublishEventWhenOrderPlaced() {
        orderService.placeOrder(request);

        verify(eventPublisher).publishEvent(any(OrderPlacedEvent.class));
    }
}

// Or capture events
@SpringBootTest
class EventCaptureTest {

    @Autowired
    private ApplicationEventPublisher publisher;

    @Autowired
    private RecordingEventListener recorder;

    @Test
    void shouldPublishCorrectEvent() {
        publisher.publishEvent(new UserCreatedEvent(user));

        assertThat(recorder.getEvents())
            .hasSize(1)
            .first()
            .isInstanceOf(UserCreatedEvent.class);
    }
}

@Component
@Profile("test")
class RecordingEventListener {
    private final List<Object> events = new ArrayList<>();

    @EventListener
    public void capture(Object event) {
        events.add(event);
    }

    public List<Object> getEvents() { return events; }
    public void clear() { events.clear(); }
}
```

---

## Key Takeaways

1. **ApplicationEventPublisher** for publishing events
2. **@EventListener** for simple synchronous handling
3. **@TransactionalEventListener** for transaction-aware handling
4. **AFTER_COMMIT is default** - ensures data is persisted
5. **Combine @Async + @TransactionalEventListener** for best practice
6. **Events decouple components** - publishers don't know listeners
7. **Don't propagate exceptions** from listeners

---

*Next: [Conditional Annotations](../PART-7-CONDITIONALS/15-conditional-annotations.md)*
