# Test Slice Annotations

## Testing Specific Layers in Isolation

---

## Overview

| Annotation | Tests | Loads |
|------------|-------|-------|
| `@SpringBootTest` | Full application | Everything |
| `@WebMvcTest` | Controllers | Web layer only |
| `@WebFluxTest` | Reactive controllers | WebFlux layer |
| `@DataJpaTest` | JPA repositories | JPA + DB |
| `@DataJdbcTest` | JDBC repositories | JDBC + DB |
| `@DataMongoTest` | MongoDB repositories | MongoDB |
| `@JsonTest` | JSON serialization | Jackson |
| `@RestClientTest` | REST clients | RestTemplate/WebClient |

---

## @SpringBootTest - Full Integration Tests

### Basic Usage

```java
@SpringBootTest
class ApplicationTests {

    @Autowired
    private UserService userService;

    @Test
    void contextLoads() {
        assertThat(userService).isNotNull();
    }
}
```

### Web Environment Options

```java
// Default: MOCK environment (no real server)
@SpringBootTest
class MockTests { }

// Random port (for real HTTP tests)
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class RandomPortTests {

    @LocalServerPort
    private int port;

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void shouldReturnUsers() {
        ResponseEntity<List<User>> response = restTemplate.exchange(
            "/api/users",
            HttpMethod.GET,
            null,
            new ParameterizedTypeReference<>() {}
        );
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }
}

// Defined port
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.DEFINED_PORT)
class DefinedPortTests { }

// No web environment
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.NONE)
class NoWebTests { }
```

### Custom Properties

```java
@SpringBootTest(properties = {
    "app.feature.enabled=true",
    "spring.datasource.url=jdbc:h2:mem:testdb"
})
class CustomPropertiesTests { }
```

### Custom Configuration

```java
@SpringBootTest(classes = { TestConfig.class, Application.class })
class CustomConfigTests { }

@TestConfiguration
class TestConfig {

    @Bean
    public ExternalService mockExternalService() {
        return new MockExternalService();
    }
}
```

---

## @WebMvcTest - Controller Layer Tests

### Basic Usage

```java
@WebMvcTest(UserController.class)
class UserControllerTests {

    @Autowired
    private MockMvc mockMvc;

    @MockBean  // Mock dependencies
    private UserService userService;

    @Test
    void shouldReturnUser() throws Exception {
        User user = new User(1L, "John", "john@example.com");
        when(userService.findById(1L)).thenReturn(Optional.of(user));

        mockMvc.perform(get("/api/users/1"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("John"))
            .andExpect(jsonPath("$.email").value("john@example.com"));
    }

    @Test
    void shouldReturn404WhenNotFound() throws Exception {
        when(userService.findById(999L)).thenReturn(Optional.empty());

        mockMvc.perform(get("/api/users/999"))
            .andExpect(status().isNotFound());
    }
}
```

### Testing POST Requests

```java
@WebMvcTest(UserController.class)
class UserControllerPostTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private UserService userService;

    @Test
    void shouldCreateUser() throws Exception {
        CreateUserRequest request = new CreateUserRequest("John", "john@example.com");
        User created = new User(1L, "John", "john@example.com");

        when(userService.create(any())).thenReturn(created);

        mockMvc.perform(post("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").value(1));
    }

    @Test
    void shouldRejectInvalidRequest() throws Exception {
        CreateUserRequest invalid = new CreateUserRequest("", "not-an-email");

        mockMvc.perform(post("/api/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(invalid)))
            .andExpect(status().isBadRequest());
    }
}
```

### With Security

```java
@WebMvcTest(UserController.class)
class SecuredControllerTests {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private UserService userService;

    @Test
    @WithMockUser(roles = "ADMIN")
    void adminCanAccessUsers() throws Exception {
        mockMvc.perform(get("/api/users"))
            .andExpect(status().isOk());
    }

    @Test
    @WithMockUser(roles = "USER")
    void regularUserDenied() throws Exception {
        mockMvc.perform(get("/api/admin/users"))
            .andExpect(status().isForbidden());
    }

    @Test
    void unauthenticatedUserRedirected() throws Exception {
        mockMvc.perform(get("/api/users"))
            .andExpect(status().isUnauthorized());
    }
}
```

---

## @DataJpaTest - Repository Layer Tests

### Basic Usage

```java
@DataJpaTest
class UserRepositoryTests {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private TestEntityManager entityManager;

    @Test
    void shouldFindByEmail() {
        // Given
        User user = new User("John", "john@example.com");
        entityManager.persistAndFlush(user);

        // When
        Optional<User> found = userRepository.findByEmail("john@example.com");

        // Then
        assertThat(found).isPresent();
        assertThat(found.get().getName()).isEqualTo("John");
    }

    @Test
    void shouldReturnEmptyWhenNotFound() {
        Optional<User> found = userRepository.findByEmail("nonexistent@example.com");

        assertThat(found).isEmpty();
    }
}
```

### Using Real Database

```java
// By default, @DataJpaTest uses embedded H2
// To use real database:
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class RealDatabaseTests {

    @Autowired
    private UserRepository userRepository;

    @Test
    void shouldWorkWithRealDatabase() {
        // Tests against actual configured database
    }
}
```

### With Testcontainers

```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
class PostgresRepositoryTests {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private UserRepository userRepository;

    @Test
    void shouldWorkWithPostgres() {
        User user = userRepository.save(new User("John", "john@example.com"));
        assertThat(user.getId()).isNotNull();
    }
}
```

### Transaction Behavior

```java
@DataJpaTest
class TransactionalTests {

    // Each test runs in a transaction that rolls back
    // Data is isolated between tests

    @Test
    void test1() {
        userRepository.save(new User("Test1"));
        // Rolled back after test
    }

    @Test
    void test2() {
        // Doesn't see data from test1
        assertThat(userRepository.count()).isZero();
    }
}

// To persist data between tests:
@DataJpaTest
@Transactional(propagation = Propagation.NOT_SUPPORTED)
class NonTransactionalTests {
    // Data persists (cleanup manually)
}
```

---

## @JsonTest - JSON Serialization Tests

```java
@JsonTest
class UserJsonTests {

    @Autowired
    private JacksonTester<User> json;

    @Test
    void shouldSerialize() throws Exception {
        User user = new User(1L, "John", "john@example.com");

        assertThat(json.write(user))
            .hasJsonPathNumberValue("$.id")
            .hasJsonPathStringValue("$.name")
            .extractingJsonPathStringValue("$.email")
            .isEqualTo("john@example.com");
    }

    @Test
    void shouldDeserialize() throws Exception {
        String content = """
            {
                "id": 1,
                "name": "John",
                "email": "john@example.com"
            }
            """;

        assertThat(json.parse(content))
            .usingRecursiveComparison()
            .isEqualTo(new User(1L, "John", "john@example.com"));
    }

    @Test
    void shouldSerializeList() throws Exception {
        @Autowired
        JacksonTester<List<User>> jsonList;

        List<User> users = List.of(
            new User(1L, "John", "john@example.com"),
            new User(2L, "Jane", "jane@example.com")
        );

        assertThat(jsonList.write(users))
            .hasJsonPathArrayValue("$")
            .extractingJsonPathArrayValue("$")
            .hasSize(2);
    }
}
```

---

## @RestClientTest - REST Client Tests

### With RestTemplate

```java
@RestClientTest(UserClient.class)
class UserClientTests {

    @Autowired
    private UserClient userClient;

    @Autowired
    private MockRestServiceServer server;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void shouldFetchUser() throws Exception {
        User expectedUser = new User(1L, "John", "john@example.com");

        server.expect(requestTo("/users/1"))
            .andExpect(method(HttpMethod.GET))
            .andRespond(withSuccess(
                objectMapper.writeValueAsString(expectedUser),
                MediaType.APPLICATION_JSON
            ));

        User user = userClient.getUser(1L);

        assertThat(user.getName()).isEqualTo("John");
        server.verify();
    }

    @Test
    void shouldHandleError() {
        server.expect(requestTo("/users/999"))
            .andRespond(withStatus(HttpStatus.NOT_FOUND));

        assertThatThrownBy(() -> userClient.getUser(999L))
            .isInstanceOf(UserNotFoundException.class);
    }
}
```

### With WebClient

```java
@RestClientTest
class WebClientTests {

    @Autowired
    private WebClient.Builder webClientBuilder;

    private MockWebServer mockServer;

    @BeforeEach
    void setUp() throws IOException {
        mockServer = new MockWebServer();
        mockServer.start();
    }

    @AfterEach
    void tearDown() throws IOException {
        mockServer.shutdown();
    }

    @Test
    void shouldFetchUser() {
        mockServer.enqueue(new MockResponse()
            .setBody("""
                {"id": 1, "name": "John"}
                """)
            .setHeader("Content-Type", "application/json"));

        WebClient client = webClientBuilder
            .baseUrl(mockServer.url("/").toString())
            .build();

        User user = client.get()
            .uri("/users/1")
            .retrieve()
            .bodyToMono(User.class)
            .block();

        assertThat(user.getName()).isEqualTo("John");
    }
}
```

---

## Custom Test Slices

### Define Custom Slice

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Inherited
@BootstrapWith(DataJpaTestContextBootstrapper.class)
@ExtendWith(SpringExtension.class)
@OverrideAutoConfiguration(enabled = false)
@TypeExcludeFilters(DataJpaTypeExcludeFilter.class)
@Transactional
@AutoConfigureCache
@AutoConfigureDataJpa
@AutoConfigureTestDatabase
@AutoConfigureTestEntityManager
@ImportAutoConfiguration
public @interface CustomDataTest {
    // Your custom configuration
}
```

### Simpler: Compose Existing Slices

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@DataJpaTest
@Import(TestSecurityConfig.class)
@AutoConfigureTestDatabase(replace = Replace.NONE)
public @interface SecuredDataJpaTest { }

// Usage
@SecuredDataJpaTest
class MyRepositoryTests { }
```

---

## Key Takeaways

1. **@SpringBootTest** for full integration tests
2. **@WebMvcTest** for controller-only tests (fast)
3. **@DataJpaTest** for repository tests with rollback
4. **@JsonTest** for serialization logic
5. **Test slices load minimal context** - faster tests
6. **Use @MockBean** for dependencies not in slice
7. **Testcontainers** for real database testing

---

*Next: [Mocking & Test Configuration](./18-mocking-config.md)*
