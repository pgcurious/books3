# Mocking & Test Configuration

## Creating Test Doubles and Custom Test Setups

---

## Overview

| Annotation | Purpose |
|------------|---------|
| `@MockBean` | Replace bean with Mockito mock |
| `@SpyBean` | Wrap bean with Mockito spy |
| `@TestConfiguration` | Test-specific beans |
| `@Import` | Import configuration into test |
| `@ActiveProfiles` | Activate test profiles |
| `@DirtiesContext` | Reset context after test |

---

## @MockBean - Replace with Mock

### Basic Usage

```java
@SpringBootTest
class OrderServiceTests {

    @Autowired
    private OrderService orderService;

    @MockBean  // Replaces real PaymentGateway with mock
    private PaymentGateway paymentGateway;

    @Test
    void shouldProcessOrder() {
        // Setup mock behavior
        when(paymentGateway.charge(any())).thenReturn(new PaymentResult(true));

        // Test
        Order order = orderService.processOrder(new CreateOrderRequest());

        // Verify
        assertThat(order.getStatus()).isEqualTo(Status.COMPLETED);
        verify(paymentGateway).charge(any());
    }
}
```

### In Web Tests

```java
@WebMvcTest(UserController.class)
class UserControllerTests {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private UserService userService;

    @MockBean
    private EmailService emailService;

    @Test
    void shouldReturnUsers() throws Exception {
        when(userService.findAll()).thenReturn(List.of(
            new User(1L, "John"),
            new User(2L, "Jane")
        ));

        mockMvc.perform(get("/api/users"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$", hasSize(2)));
    }
}
```

### Reset Behavior Between Tests

```java
@SpringBootTest
class StatefulMockTests {

    @MockBean
    private ExternalService externalService;

    @BeforeEach
    void resetMock() {
        reset(externalService);  // Clear interactions and stubbing
    }

    // Or use Mockito annotation
    @MockBean(reset = MockReset.BEFORE)  // Reset before each test
    private ExternalService externalService;
}
```

---

## @SpyBean - Partial Mocking

### Basic Usage

```java
@SpringBootTest
class NotificationServiceTests {

    @Autowired
    private NotificationService notificationService;

    @SpyBean  // Real implementation, but can verify/stub
    private EmailSender emailSender;

    @Test
    void shouldSendEmail() {
        notificationService.notifyUser(user, "Hello");

        // Verify real method was called
        verify(emailSender).send(eq(user.getEmail()), anyString());
    }

    @Test
    void shouldHandleEmailFailure() {
        // Stub specific method, others remain real
        doThrow(new EmailException("Server down"))
            .when(emailSender).send(anyString(), anyString());

        assertThatThrownBy(() -> notificationService.notifyUser(user, "Hello"))
            .isInstanceOf(NotificationException.class);
    }
}
```

### When to Use Spy vs Mock

```java
// Use @MockBean when:
// - You need complete control over behavior
// - The real implementation has side effects (DB, network)
// - You want to isolate the unit under test

// Use @SpyBean when:
// - You want real behavior but need to verify calls
// - You want to stub only specific methods
// - You're testing integration with partial isolation
```

---

## @TestConfiguration - Test-Specific Beans

### Inline Configuration

```java
@SpringBootTest
class OrderServiceTests {

    @TestConfiguration
    static class TestConfig {

        @Bean
        public PaymentGateway mockPaymentGateway() {
            PaymentGateway mock = mock(PaymentGateway.class);
            when(mock.charge(any())).thenReturn(new PaymentResult(true));
            return mock;
        }

        @Bean
        public Clock testClock() {
            return Clock.fixed(
                Instant.parse("2024-01-15T10:00:00Z"),
                ZoneOffset.UTC
            );
        }
    }

    @Autowired
    private OrderService orderService;

    @Test
    void shouldUseTestConfiguration() {
        // Uses mock PaymentGateway and fixed Clock
    }
}
```

### Separate Configuration Class

```java
// In test sources
@TestConfiguration
public class TestDatabaseConfig {

    @Bean
    public DataSource testDataSource() {
        return new EmbeddedDatabaseBuilder()
            .setType(EmbeddedDatabaseType.H2)
            .build();
    }
}

// In test
@SpringBootTest
@Import(TestDatabaseConfig.class)
class DatabaseTests {
    // Uses test DataSource
}
```

### @TestConfiguration vs @Configuration

```java
// @Configuration is scanned by @SpringBootTest automatically
// @TestConfiguration is NOT auto-scanned - must be imported or nested

@SpringBootTest
class MyTests {

    @TestConfiguration  // Must be nested or @Imported
    static class Config { }
}

// Or import explicitly
@SpringBootTest
@Import(MyTestConfiguration.class)
class MyTests { }
```

---

## @Import - Import Configurations

### Import Test Configuration

```java
@SpringBootTest
@Import({ TestSecurityConfig.class, TestMessagingConfig.class })
class IntegrationTests {
    // Both configs are loaded
}
```

### Import Multiple Configurations

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Import({
    TestSecurityConfig.class,
    TestDatabaseConfig.class,
    TestCacheConfig.class
})
public @interface IntegrationTestConfiguration { }

// Usage
@SpringBootTest
@IntegrationTestConfiguration
class MyIntegrationTests { }
```

---

## @ActiveProfiles - Test Profiles

### Activate Test Profile

```java
@SpringBootTest
@ActiveProfiles("test")
class TestProfileTests {
    // Uses application-test.properties/yml
    // Activates @Profile("test") beans
}
```

### Multiple Profiles

```java
@SpringBootTest
@ActiveProfiles({ "test", "integration" })
class MultiProfileTests {
    // Both profiles active
}
```

### Profile-Specific Test Beans

```java
@TestConfiguration
@Profile("test")
public class TestBeansConfig {

    @Bean
    public EmailService mockEmailService() {
        return new MockEmailService();
    }
}

// In main configuration
@Service
@Profile("!test")  // Not in test profile
public class RealEmailService implements EmailService { }
```

---

## @DirtiesContext - Reset Application Context

### When to Use

```java
@SpringBootTest
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_EACH_TEST_METHOD)
class StatefulTests {

    @Autowired
    private StatefulService service;

    @Test
    void test1() {
        service.addItem("item1");
        // Context is reset after this test
    }

    @Test
    void test2() {
        // Fresh context - service has no items
    }
}
```

### Class Modes

```java
// Reset after entire class
@DirtiesContext(classMode = ClassMode.AFTER_CLASS)

// Reset before class
@DirtiesContext(classMode = ClassMode.BEFORE_CLASS)

// Reset after each test method
@DirtiesContext(classMode = ClassMode.AFTER_EACH_TEST_METHOD)

// Reset before each test method
@DirtiesContext(classMode = ClassMode.BEFORE_EACH_TEST_METHOD)
```

### On Method Level

```java
@SpringBootTest
class MixedTests {

    @Test
    void normalTest() {
        // Context reused
    }

    @Test
    @DirtiesContext  // Reset after this test only
    void testThatModifiesContext() {
        // Modifies context state
    }
}
```

---

## Test Property Sources

### @TestPropertySource

```java
@SpringBootTest
@TestPropertySource(properties = {
    "app.feature.enabled=true",
    "app.timeout=1000"
})
class PropertyOverrideTests { }

// From file
@SpringBootTest
@TestPropertySource(locations = "classpath:test.properties")
class FilePropertyTests { }
```

### @DynamicPropertySource

```java
@SpringBootTest
@Testcontainers
class ContainerTests {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }
}
```

---

## Test Utilities

### @Autowired MockMvc

```java
@WebMvcTest
class ControllerTests {

    @Autowired
    private MockMvc mockMvc;

    // Pre-configured for the controller under test
}

// In @SpringBootTest
@SpringBootTest
@AutoConfigureMockMvc  // Required for @SpringBootTest
class IntegrationTests {

    @Autowired
    private MockMvc mockMvc;
}
```

### TestRestTemplate

```java
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
class RestTemplateTests {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void shouldGetUsers() {
        ResponseEntity<List<User>> response = restTemplate.exchange(
            "/api/users",
            HttpMethod.GET,
            null,
            new ParameterizedTypeReference<>() {}
        );

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }
}
```

### WebTestClient (WebFlux)

```java
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
class WebClientTests {

    @Autowired
    private WebTestClient webTestClient;

    @Test
    void shouldGetUsers() {
        webTestClient.get()
            .uri("/api/users")
            .exchange()
            .expectStatus().isOk()
            .expectBodyList(User.class)
            .hasSize(2);
    }
}
```

---

## Complete Test Example

```java
@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
@Testcontainers
class OrderIntegrationTests {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private TestRestTemplate restTemplate;

    @MockBean
    private PaymentGateway paymentGateway;

    @SpyBean
    private EmailService emailService;

    @BeforeEach
    void setUp() {
        when(paymentGateway.charge(any()))
            .thenReturn(new PaymentResult(true, "tx-123"));
    }

    @Test
    void shouldCreateOrderEndToEnd() {
        // Given
        CreateOrderRequest request = new CreateOrderRequest(
            List.of(new OrderItem("PROD-1", 2))
        );

        // When
        ResponseEntity<Order> response = restTemplate.postForEntity(
            "/api/orders",
            request,
            Order.class
        );

        // Then
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(response.getBody().getStatus()).isEqualTo(Status.COMPLETED);

        verify(paymentGateway).charge(any());
        verify(emailService).sendOrderConfirmation(any());
    }
}
```

---

## Key Takeaways

1. **@MockBean replaces** beans with mocks
2. **@SpyBean wraps** real beans for partial mocking
3. **@TestConfiguration** provides test-specific beans (not auto-scanned)
4. **@ActiveProfiles("test")** activates test profile
5. **@DirtiesContext** resets context (slow - use sparingly)
6. **@DynamicPropertySource** for runtime property configuration
7. **Combine strategies** for comprehensive testing

---

*Next: [Validation Annotations](../PART-9-HIDDEN-GEMS/19-validation.md)*
