# Obscure But Powerful Annotations

## Hidden Gems Most Developers Don't Know Exist

---

## @Lookup - Method Injection

### Problem: Prototype into Singleton

```java
@Component
@Scope("prototype")
public class PrototypeBean {
    // New instance each time
}

@Service
public class SingletonService {

    @Autowired
    private PrototypeBean prototypeBean;  // PROBLEM: Same instance always!
}
```

### Solution: @Lookup

```java
@Service
public abstract class SingletonService {

    // Spring overrides this to return new instance each time
    @Lookup
    protected abstract PrototypeBean getPrototypeBean();

    public void doSomething() {
        PrototypeBean bean = getPrototypeBean();  // Fresh instance!
    }
}
```

---

## @RefreshScope - Dynamic Configuration

### For Spring Cloud Config

```java
@Service
@RefreshScope  // Bean recreated when config changes
public class ConfigurableService {

    @Value("${app.feature.enabled}")
    private boolean featureEnabled;

    // When /actuator/refresh is called, this bean is recreated
    // with new property values
}
```

### Trigger Refresh

```bash
curl -X POST http://localhost:8080/actuator/refresh
```

---

## @Retryable - Automatic Retries

### Enable

```xml
<dependency>
    <groupId>org.springframework.retry</groupId>
    <artifactId>spring-retry</artifactId>
</dependency>
```

```java
@Configuration
@EnableRetry
public class RetryConfig { }
```

### Usage

```java
@Service
public class ExternalApiService {

    @Retryable(
        retryFor = { ServiceUnavailableException.class, TimeoutException.class },
        maxAttempts = 3,
        backoff = @Backoff(delay = 1000, multiplier = 2)
    )
    public Response callApi(Request request) {
        return restTemplate.postForObject("/api", request, Response.class);
    }

    @Recover  // Called when all retries fail
    public Response fallback(ServiceUnavailableException e, Request request) {
        return Response.defaultResponse();
    }
}
```

---

## @Cacheable / @CacheEvict - Caching

### Enable

```java
@Configuration
@EnableCaching
public class CacheConfig { }
```

### @Cacheable - Cache Results

```java
@Service
public class UserService {

    @Cacheable(value = "users", key = "#id")
    public User findById(Long id) {
        // Only called if not in cache
        return userRepository.findById(id).orElseThrow();
    }

    @Cacheable(value = "users", key = "#email", unless = "#result == null")
    public User findByEmail(String email) {
        return userRepository.findByEmail(email).orElse(null);
    }

    @Cacheable(value = "users", condition = "#id > 0")
    public User findByIdConditional(Long id) {
        return userRepository.findById(id).orElseThrow();
    }
}
```

### @CacheEvict - Clear Cache

```java
@Service
public class UserService {

    @CacheEvict(value = "users", key = "#user.id")
    public User update(User user) {
        return userRepository.save(user);
    }

    @CacheEvict(value = "users", allEntries = true)
    public void clearAllUserCache() {
        // Clears entire cache
    }
}
```

### @CachePut - Update Cache

```java
@CachePut(value = "users", key = "#result.id")
public User create(CreateUserRequest request) {
    return userRepository.save(new User(request));
}
```

### @Caching - Multiple Operations

```java
@Caching(
    evict = {
        @CacheEvict(value = "users", key = "#user.id"),
        @CacheEvict(value = "usersByEmail", key = "#user.email")
    },
    put = @CachePut(value = "users", key = "#result.id")
)
public User update(User user) {
    return userRepository.save(user);
}
```

---

## @SpyBean and @MockBean (Testing)

Already covered in Testing, but worth repeating:

```java
@SpringBootTest
class ServiceTests {

    @SpyBean  // Real implementation, can verify
    private UserRepository userRepository;

    @MockBean  // Mock, must stub
    private ExternalService externalService;
}
```

---

## @JsonView - API Response Filtering

### Define Views

```java
public class Views {
    public interface Summary { }
    public interface Detailed extends Summary { }
    public interface Admin extends Detailed { }
}
```

### Apply to Entity

```java
public class User {

    @JsonView(Views.Summary.class)
    private Long id;

    @JsonView(Views.Summary.class)
    private String name;

    @JsonView(Views.Detailed.class)
    private String email;

    @JsonView(Views.Admin.class)
    private String password;

    @JsonView(Views.Admin.class)
    private List<Role> roles;
}
```

### Use in Controllers

```java
@RestController
public class UserController {

    @GetMapping("/users")
    @JsonView(Views.Summary.class)
    public List<User> listUsers() {
        return userService.findAll();
        // Returns: { "id": 1, "name": "John" }
    }

    @GetMapping("/users/{id}")
    @JsonView(Views.Detailed.class)
    public User getUser(@PathVariable Long id) {
        return userService.findById(id);
        // Returns: { "id": 1, "name": "John", "email": "john@example.com" }
    }

    @GetMapping("/admin/users/{id}")
    @JsonView(Views.Admin.class)
    public User adminGetUser(@PathVariable Long id) {
        return userService.findById(id);
        // Returns everything including password and roles
    }
}
```

---

## @ControllerAdvice Attributes

### Scope to Specific Controllers

```java
// Only for REST controllers
@RestControllerAdvice(annotations = RestController.class)
public class RestExceptionHandler { }

// Only for specific package
@RestControllerAdvice(basePackages = "com.myapp.api.v2")
public class V2ExceptionHandler { }

// Only for specific controllers
@RestControllerAdvice(assignableTypes = { UserController.class, OrderController.class })
public class UserOrderExceptionHandler { }
```

---

## @ConditionalOnExpression - Complex Conditions

```java
@Bean
@ConditionalOnExpression(
    "${feature.enabled:false} and '${app.environment}' == 'production'"
)
public FeatureService featureService() {
    return new FeatureService();
}

@Bean
@ConditionalOnExpression("#{'${spring.profiles.active}'.contains('dev')}")
public DebugService debugService() {
    return new DebugService();
}
```

---

## @DependsOn - Explicit Bean Ordering

```java
@Component("databaseInitializer")
public class DatabaseInitializer {
    @PostConstruct
    public void init() {
        // Run migrations
    }
}

@Component
@DependsOn("databaseInitializer")
public class DataLoader {
    // Runs after DatabaseInitializer
}
```

---

## @EntityGraph - JPA Eager Loading

```java
public interface UserRepository extends JpaRepository<User, Long> {

    // Avoid N+1 queries by loading orders eagerly
    @EntityGraph(attributePaths = { "orders", "orders.items" })
    Optional<User> findWithOrdersById(Long id);

    // Named entity graph
    @EntityGraph(value = "User.withRoles")
    List<User> findByStatus(Status status);
}

@Entity
@NamedEntityGraph(
    name = "User.withRoles",
    attributeNodes = @NamedAttributeNode("roles")
)
public class User { }
```

---

## @Immutable - Hibernate Read-Only Entities

```java
@Entity
@Immutable  // Hibernate won't track changes
public class AuditLog {

    @Id
    private Long id;

    private String action;
    private LocalDateTime timestamp;

    // Changes to this entity are ignored
}
```

---

## @Formula - Computed Columns

```java
@Entity
public class Order {

    @Id
    private Long id;

    @OneToMany
    private List<OrderItem> items;

    @Formula("(SELECT COALESCE(SUM(oi.price * oi.quantity), 0) FROM order_items oi WHERE oi.order_id = id)")
    private BigDecimal total;  // Computed on load
}
```

---

## @NaturalId - Business Key

```java
@Entity
public class Book {

    @Id
    @GeneratedValue
    private Long id;

    @NaturalId
    private String isbn;  // Business key

    // findByNaturalId() works efficiently
}

// Usage
Book book = session.byNaturalId(Book.class)
    .using("isbn", "978-0-123456-47-2")
    .load();
```

---

## @RestClientTest - Testing REST Clients

```java
@RestClientTest(UserClient.class)
class UserClientTests {

    @Autowired
    private UserClient userClient;

    @Autowired
    private MockRestServiceServer server;

    @Test
    void shouldFetchUser() {
        server.expect(requestTo("/users/1"))
            .andRespond(withSuccess("{\"id\":1}", MediaType.APPLICATION_JSON));

        User user = userClient.getUser(1L);
        assertThat(user.getId()).isEqualTo(1L);
    }
}
```

---

## @Sql - Database Setup in Tests

```java
@DataJpaTest
@Sql("/test-data.sql")  // Runs before each test
class UserRepositoryTests {

    @Test
    @Sql("/additional-data.sql")  // Additional data for this test
    void shouldFindAllUsers() { }

    @Test
    @Sql(
        scripts = "/cleanup.sql",
        executionPhase = Sql.ExecutionPhase.AFTER_TEST_METHOD
    )
    void testWithCleanup() { }
}
```

---

## @RegisterExtension - JUnit 5

```java
class MyTests {

    @RegisterExtension
    static WireMockExtension wireMock = WireMockExtension.newInstance()
        .options(wireMockConfig().dynamicPort())
        .build();

    @Test
    void shouldCallApi() {
        wireMock.stubFor(get("/api").willReturn(ok()));
        // Test with WireMock
    }
}
```

---

## @RepeatableContainers - Testcontainers

```java
@SpringBootTest
@Testcontainers
class MultiContainerTests {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15");

    @Container
    static GenericContainer<?> redis = new GenericContainer<>("redis:7")
        .withExposedPorts(6379);

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.redis.host", redis::getHost);
        registry.add("spring.redis.port", redis::getFirstMappedPort);
    }
}
```

---

## Summary: The Really Obscure Ones

| Annotation | Use Case |
|------------|----------|
| `@Lookup` | Prototype into singleton |
| `@RefreshScope` | Dynamic config reload |
| `@Retryable` | Automatic retry with backoff |
| `@Cacheable` | Method-level caching |
| `@JsonView` | Filter JSON response fields |
| `@EntityGraph` | Avoid N+1 queries |
| `@Formula` | Computed JPA fields |
| `@NaturalId` | Business key lookup |
| `@Sql` | Test database setup |

---

## Key Takeaways

1. **@Lookup solves** prototype-in-singleton problem
2. **@RefreshScope** for dynamic configuration
3. **@Retryable/@Recover** for resilient external calls
4. **@Cacheable** family for declarative caching
5. **@JsonView** for API response filtering
6. **@EntityGraph** to solve N+1 queries
7. **These annotations exist** - use them instead of reimplementing!

---

*Congratulations! You've completed the Spring Boot Annotations Guide.*

*Return to [Table of Contents](../README.md)*
