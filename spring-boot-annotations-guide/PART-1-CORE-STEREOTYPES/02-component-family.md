# @Component Family - The Building Blocks

## The Stereotype Annotations That Structure Your Application

---

## The Hierarchy

```
@Component (base annotation)
    ├── @Service      (business logic)
    ├── @Repository   (data access)
    ├── @Controller   (web layer)
    └── @Configuration (bean definitions)
```

All stereotype annotations are essentially `@Component` with semantic meaning.

---

## @Component - The Generic Bean

### Basic Usage

```java
@Component
public class EmailValidator {

    public boolean isValid(String email) {
        return email != null && email.contains("@");
    }
}
```

### With Custom Name

```java
@Component("emailChecker")  // Bean name is "emailChecker"
public class EmailValidator { }

// Usage
@Autowired
@Qualifier("emailChecker")
private EmailValidator validator;
```

### When to Use @Component

Use for classes that don't fit other categories:
- Utility classes
- Adapters
- Generic helpers

---

## @Service - Business Logic Layer

### Purpose

Marks a class as holding **business logic**. No special behavior—purely semantic.

```java
@Service
public class OrderService {

    private final OrderRepository orderRepository;
    private final PaymentGateway paymentGateway;

    public OrderService(OrderRepository orderRepository,
                        PaymentGateway paymentGateway) {
        this.orderRepository = orderRepository;
        this.paymentGateway = paymentGateway;
    }

    public Order placeOrder(Cart cart) {
        // Validate
        if (cart.isEmpty()) {
            throw new InvalidOrderException("Cart is empty");
        }

        // Process payment
        PaymentResult result = paymentGateway.charge(cart.getTotal());

        // Create order
        Order order = new Order(cart, result.getTransactionId());
        return orderRepository.save(order);
    }
}
```

### Service Layer Patterns

```java
@Service
public class UserService {

    // Transaction boundary typically at service layer
    @Transactional
    public User createUser(CreateUserRequest request) {
        // Validation logic
        // Business rules
        // Persistence
    }

    @Transactional(readOnly = true)
    public User findById(Long id) {
        // Read-only transaction
    }
}
```

---

## @Repository - Data Access Layer

### Purpose

Marks a class for **data access**. Has special behavior!

```java
@Repository
public class UserRepository {

    @PersistenceContext
    private EntityManager em;

    public User findById(Long id) {
        return em.find(User.class, id);
    }

    public void save(User user) {
        em.persist(user);
    }
}
```

### The Special Behavior: Exception Translation

`@Repository` enables **automatic exception translation**:

```java
// Without @Repository
public void save(User user) {
    em.persist(user);  // Throws JPA-specific PersistenceException
}

// With @Repository
@Repository
public void save(User user) {
    em.persist(user);  // PersistenceException → DataAccessException
}
```

**Why this matters:**
- `DataAccessException` is Spring's unified exception hierarchy
- Your service layer doesn't depend on JPA/JDBC specifics
- Easy to swap database technologies

### Exception Translation Table

| Database Exception | Spring Exception |
|-------------------|------------------|
| SQLException | DataAccessException |
| PersistenceException | DataAccessException |
| HibernateException | DataAccessException |
| Duplicate key | DataIntegrityViolationException |
| Connection failed | DataAccessResourceFailureException |

### Modern Usage: Spring Data

With Spring Data JPA, you rarely write `@Repository` classes:

```java
// Spring Data creates the implementation automatically
public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByEmail(String email);

    List<User> findByStatus(Status status);

    @Query("SELECT u FROM User u WHERE u.createdAt > :date")
    List<User> findRecentUsers(@Param("date") LocalDateTime date);
}
```

---

## @Controller - Web MVC Layer

### Purpose

Marks a class as a **web controller** handling HTTP requests.

```java
@Controller
public class HomeController {

    @GetMapping("/")
    public String home(Model model) {
        model.addAttribute("message", "Welcome!");
        return "home";  // Returns view name
    }

    @GetMapping("/users")
    public String users(Model model) {
        model.addAttribute("users", userService.findAll());
        return "users";  // Returns view name
    }
}
```

### Returning Views vs JSON

```java
@Controller
public class MixedController {

    // Returns a view
    @GetMapping("/page")
    public String page() {
        return "page";
    }

    // Returns JSON (need @ResponseBody)
    @GetMapping("/api/data")
    @ResponseBody
    public Data getData() {
        return new Data();
    }
}
```

---

## @RestController - REST API Layer

### Purpose

Combines `@Controller` + `@ResponseBody`. Every method returns data, not views.

```java
@RestController
@RequestMapping("/api/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @GetMapping
    public List<User> findAll() {
        return userService.findAll();  // Returns JSON
    }

    @GetMapping("/{id}")
    public User findById(@PathVariable Long id) {
        return userService.findById(id);  // Returns JSON
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public User create(@RequestBody CreateUserRequest request) {
        return userService.create(request);  // Returns JSON
    }
}
```

### @RestController vs @Controller

```java
// These are equivalent:
@Controller
@ResponseBody
public class ApiController { }

@RestController
public class ApiController { }
```

---

## @Configuration - Bean Factory

### Purpose

Marks a class that **defines beans** via `@Bean` methods.

```java
@Configuration
public class AppConfig {

    @Bean
    public RestTemplate restTemplate() {
        return new RestTemplateBuilder()
            .setConnectTimeout(Duration.ofSeconds(5))
            .setReadTimeout(Duration.ofSeconds(10))
            .build();
    }

    @Bean
    public ObjectMapper objectMapper() {
        return new ObjectMapper()
            .registerModule(new JavaTimeModule())
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
    }
}
```

### Full vs Lite Mode

```java
@Configuration  // Full mode - method calls are intercepted
public class FullConfig {

    @Bean
    public ServiceA serviceA() {
        return new ServiceA(commonDependency());  // Returns SAME instance
    }

    @Bean
    public ServiceB serviceB() {
        return new ServiceB(commonDependency());  // Returns SAME instance
    }

    @Bean
    public CommonDependency commonDependency() {
        return new CommonDependency();
    }
}
```

```java
@Component  // Lite mode - method calls create new instances
public class LiteConfig {

    @Bean
    public ServiceA serviceA() {
        return new ServiceA(commonDependency());  // NEW instance!
    }

    @Bean
    public ServiceB serviceB() {
        return new ServiceB(commonDependency());  // DIFFERENT instance!
    }

    @Bean
    public CommonDependency commonDependency() {
        return new CommonDependency();
    }
}
```

**Full mode** (with `@Configuration`):
- Uses CGLIB proxying
- Method calls return the same bean instance
- Standard Spring behavior

---

## Choosing the Right Stereotype

| Annotation | Layer | Use When |
|------------|-------|----------|
| `@Component` | Any | Generic component that doesn't fit elsewhere |
| `@Service` | Business | Business logic, orchestration, transactions |
| `@Repository` | Data | Data access (or use Spring Data interfaces) |
| `@Controller` | Web | MVC controllers returning views |
| `@RestController` | Web | REST APIs returning JSON/XML |
| `@Configuration` | Config | Defining beans with `@Bean` methods |

---

## Custom Stereotypes

### Creating Your Own

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Service  // Meta-annotated with @Service
public @interface UseCase {
    String value() default "";
}
```

### Usage

```java
@UseCase
public class CreateOrderUseCase {
    public Order execute(CreateOrderCommand command) {
        // ...
    }
}

// Spring treats this as @Service
// Clean architecture style
```

### Real-World Custom Stereotypes

```java
// For scheduled jobs
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Component
public @interface ScheduledJob { }

// For message listeners
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Component
public @interface MessageHandler { }

// For adapters (hexagonal architecture)
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Component
public @interface Adapter { }
```

---

## Common Patterns

### Pattern 1: Interface + Implementation

```java
public interface PaymentGateway {
    PaymentResult charge(Money amount);
}

@Service
public class StripePaymentGateway implements PaymentGateway {
    @Override
    public PaymentResult charge(Money amount) {
        // Stripe implementation
    }
}
```

### Pattern 2: Profile-Based Implementations

```java
@Service
@Profile("production")
public class RealEmailService implements EmailService {
    // Sends real emails
}

@Service
@Profile("development")
public class MockEmailService implements EmailService {
    // Logs emails, doesn't send
}
```

### Pattern 3: Conditional Components

```java
@Service
@ConditionalOnProperty(name = "feature.newAlgorithm", havingValue = "true")
public class NewAlgorithmService implements AlgorithmService {
    // New implementation
}

@Service
@ConditionalOnProperty(name = "feature.newAlgorithm", havingValue = "false", matchIfMissing = true)
public class LegacyAlgorithmService implements AlgorithmService {
    // Legacy implementation
}
```

---

## Key Takeaways

1. **All stereotypes are @Component** with added semantics
2. **@Repository has special behavior** - exception translation
3. **@Configuration enables full mode** - method interception for singletons
4. **@RestController = @Controller + @ResponseBody**
5. **Choose stereotypes by layer** - it's about code organization
6. **Create custom stereotypes** for domain-specific patterns

---

## Quick Reference

```java
@Component          // Generic bean
@Service            // Business logic
@Repository         // Data access (+ exception translation)
@Controller         // MVC (returns views)
@RestController     // REST API (returns JSON)
@Configuration      // Bean definitions
```

---

*Next: [Request Mapping Annotations](../PART-2-WEB-LAYER/03-request-mapping.md)*
