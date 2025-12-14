# Chapter 18: Tracing a Request Through All Layers

> *"The devil is in the details, but so is salvation."*
> — Hyman Rickover

---

## The Complete Picture

We've examined each layer in isolation. Now let's trace a single HTTP request through every layer—from network socket to your code and back.

This will cement your understanding of how all the pieces fit together.

---

## The Scenario

A client sends:
```http
POST /api/users HTTP/1.1
Host: localhost:8080
Content-Type: application/json

{"name": "Alice", "email": "alice@example.com"}
```

Our Spring Boot application:

```java
@RestController
@RequestMapping("/api/users")
public class UserController {

    @Autowired
    private UserService userService;

    @PostMapping
    @Transactional
    public ResponseEntity<User> createUser(@Valid @RequestBody User user) {
        User saved = userService.create(user);
        return ResponseEntity.status(HttpStatus.CREATED).body(saved);
    }
}

@Service
public class UserService {
    @Autowired
    private UserRepository userRepository;

    public User create(User user) {
        return userRepository.save(user);
    }
}

@Repository
public interface UserRepository extends JpaRepository<User, Long> {
}
```

Let's trace every step.

---

## Layer 1: Network and Operating System

```
┌─────────────────────────────────────────────────────────────────┐
│  CLIENT                           │  SERVER                     │
│                                   │                             │
│  Browser/curl sends request ──────┼──► TCP packet received      │
│                                   │    by OS kernel             │
│                                   │         │                   │
│                                   │         ▼                   │
│                                   │    Socket accept()          │
│                                   │    returns connection       │
│                                   │                             │
└───────────────────────────────────┴─────────────────────────────┘
```

1. Client establishes TCP connection to port 8080
2. OS kernel accepts the connection
3. Tomcat's acceptor thread receives the socket

---

## Layer 2: Embedded Tomcat

Tomcat was started during Spring Boot's `onRefresh()`. Now it handles the request:

```
┌─────────────────────────────────────────────────────────────────┐
│  TOMCAT                                                          │
│                                                                  │
│  1. Acceptor thread accepts connection                          │
│         │                                                        │
│         ▼                                                        │
│  2. Hand off to worker thread from pool                         │
│         │                                                        │
│         ▼                                                        │
│  3. Worker thread reads HTTP request from socket                │
│         │                                                        │
│         ▼                                                        │
│  4. Parse HTTP: method=POST, path=/api/users                    │
│         │                                                        │
│         ▼                                                        │
│  5. Create HttpServletRequest and HttpServletResponse           │
│         │                                                        │
│         ▼                                                        │
│  6. Pass to Servlet (DispatcherServlet)                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

Key points:
- Thread pool manages concurrent requests
- HTTP parsing happens in Tomcat
- `HttpServletRequest` wraps the raw request

---

## Layer 3: Spring MVC DispatcherServlet

The DispatcherServlet is Spring's front controller:

```
┌─────────────────────────────────────────────────────────────────┐
│  DISPATCHER SERVLET                                              │
│                                                                  │
│  doDispatch(request, response):                                 │
│                                                                  │
│  1. getHandler(request)                                         │
│     │  └── HandlerMapping finds: UserController.createUser()    │
│     │                                                            │
│     ▼                                                            │
│  2. getHandlerAdapter(handler)                                  │
│     │  └── RequestMappingHandlerAdapter selected                │
│     │                                                            │
│     ▼                                                            │
│  3. applyPreHandle(interceptors)                                │
│     │  └── Run interceptors (security, logging, etc.)           │
│     │                                                            │
│     ▼                                                            │
│  4. handler.handle(request, response)                           │
│     │  └── Invoke controller method                             │
│     │                                                            │
│     ▼                                                            │
│  5. applyPostHandle(interceptors)                               │
│     │                                                            │
│     ▼                                                            │
│  6. processDispatchResult(response)                             │
│        └── Convert return value to HTTP response                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Handler Mapping

How does Spring know `POST /api/users` maps to `UserController.createUser()`?

At startup:
```java
// RequestMappingHandlerMapping scans for @RequestMapping
// For each controller method, it builds a mapping:
// POST + /api/users → UserController.createUser()
```

At request time:
```java
// HandlerMapping.getHandler():
// 1. Extract path: /api/users
// 2. Extract method: POST
// 3. Look up in mapping registry
// 4. Return HandlerMethod for UserController.createUser()
```

---

## Layer 4: Argument Resolution

Before invoking your method, Spring must prepare the arguments:

```java
public ResponseEntity<User> createUser(@Valid @RequestBody User user)
```

```
┌─────────────────────────────────────────────────────────────────┐
│  ARGUMENT RESOLUTION                                             │
│                                                                  │
│  For parameter: @Valid @RequestBody User user                   │
│                                                                  │
│  1. Find resolver for @RequestBody                              │
│     └── RequestResponseBodyMethodProcessor                      │
│                                                                  │
│  2. Read request body                                           │
│     └── InputStream → byte[] → String (JSON)                    │
│                                                                  │
│  3. Find HttpMessageConverter for JSON                          │
│     └── MappingJackson2HttpMessageConverter                     │
│                                                                  │
│  4. Deserialize JSON to User object                             │
│     │  ObjectMapper.readValue(json, User.class)                 │
│     │      │                                                     │
│     │      ▼                                                     │
│     │  User user = new User();                                  │
│     │  user.setName("Alice");                                   │
│     │  user.setEmail("alice@example.com");                      │
│     │                                                            │
│  5. Validate (because @Valid)                                   │
│     └── Hibernate Validator checks constraints                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

Jackson uses reflection:
```java
// Jackson internally does something like:
Class<?> clazz = User.class;
Object instance = clazz.getDeclaredConstructor().newInstance();

Field nameField = clazz.getDeclaredField("name");
nameField.setAccessible(true);
nameField.set(instance, jsonNode.get("name").asText());
// ... for each field
```

---

## Layer 5: Controller Method Invocation

Now Spring invokes your controller method:

```
┌─────────────────────────────────────────────────────────────────┐
│  METHOD INVOCATION                                               │
│                                                                  │
│  // The controller is actually a PROXY (for @Transactional)     │
│                                                                  │
│  1. TransactionInterceptor.invoke()                             │
│     │  └── @Transactional detected                              │
│     │                                                            │
│  2. Begin transaction                                           │
│     │  └── DataSourceTransactionManager.getTransaction()        │
│     │  └── Get connection from pool                             │
│     │  └── connection.setAutoCommit(false)                      │
│     │                                                            │
│  3. Invoke actual method via reflection                         │
│     │  Method.invoke(controllerInstance, user)                  │
│     │      │                                                     │
│     │      ▼                                                     │
│     │  // Your code runs here:                                  │
│     │  User saved = userService.create(user);                   │
│     │                                                            │
│  4. Commit transaction                                          │
│     └── connection.commit()                                     │
│     └── Return connection to pool                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Layer 6: Service and Repository

Inside your service:

```
┌─────────────────────────────────────────────────────────────────┐
│  SERVICE LAYER                                                   │
│                                                                  │
│  userService.create(user):                                      │
│      │                                                           │
│      ▼                                                           │
│  userRepository.save(user)                                      │
│      │                                                           │
│      │  // UserRepository is a PROXY generated by Spring Data   │
│      │                                                           │
│      ▼                                                           │
│  SimpleJpaRepository.save(user):                                │
│      │                                                           │
│      ▼                                                           │
│  entityManager.persist(user)                                    │
│      │                                                           │
│      │  // Hibernate ORM                                        │
│      │                                                           │
│      ▼                                                           │
│  Generate SQL:                                                  │
│  INSERT INTO users (name, email) VALUES (?, ?)                  │
│      │                                                           │
│      ▼                                                           │
│  PreparedStatement.executeUpdate()                              │
│      │                                                           │
│      ▼                                                           │
│  JDBC driver sends to PostgreSQL                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

Note how many proxies are involved:
- Controller proxy (for @Transactional)
- Repository proxy (for Spring Data JPA)
- Connection proxy (for connection pooling)

---

## Layer 7: Response Rendering

After your method returns:

```
┌─────────────────────────────────────────────────────────────────┐
│  RESPONSE RENDERING                                              │
│                                                                  │
│  Return value: ResponseEntity<User>                             │
│                                                                  │
│  1. HandlerMethodReturnValueHandler processes return            │
│     └── HttpEntityMethodProcessor handles ResponseEntity        │
│                                                                  │
│  2. Set response status                                         │
│     └── response.setStatus(201) // CREATED                      │
│                                                                  │
│  3. Find HttpMessageConverter                                   │
│     └── MappingJackson2HttpMessageConverter for JSON            │
│                                                                  │
│  4. Serialize User to JSON                                      │
│     │  ObjectMapper.writeValueAsString(user)                    │
│     │      │                                                     │
│     │      ▼                                                     │
│     │  {"id": 1, "name": "Alice", "email": "alice@example.com"} │
│     │                                                            │
│  5. Write to response                                           │
│     └── response.getWriter().write(json)                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Layer 8: Back Through Tomcat

```
┌─────────────────────────────────────────────────────────────────┐
│  TOMCAT RESPONSE                                                 │
│                                                                  │
│  1. DispatcherServlet completes                                 │
│     └── Returns to Tomcat                                       │
│                                                                  │
│  2. Tomcat builds HTTP response                                 │
│     HTTP/1.1 201 Created                                        │
│     Content-Type: application/json                              │
│     Content-Length: 52                                          │
│                                                                  │
│     {"id": 1, "name": "Alice", "email": "alice@..."}            │
│                                                                  │
│  3. Write to socket                                             │
│     └── socket.getOutputStream().write(responseBytes)           │
│                                                                  │
│  4. Worker thread returns to pool                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## The Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│  CLIENT                                                          │
│  POST /api/users                                                │
│  {"name": "Alice", "email": "alice@example.com"}                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  OS KERNEL / TCP STACK                                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  TOMCAT                                                          │
│  • Thread pool                                                  │
│  • HTTP parsing                                                 │
│  • Servlet container                                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  SPRING MVC                                                      │
│  • DispatcherServlet                                            │
│  • HandlerMapping                                               │
│  • ArgumentResolvers                                            │
│  • MessageConverters (Jackson)                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  YOUR CODE (via PROXY)                                          │
│  • @Transactional interceptor                                   │
│  • UserController.createUser()                                  │
│  • UserService.create()                                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  SPRING DATA JPA (PROXY)                                        │
│  • UserRepository (generated impl)                              │
│  • SimpleJpaRepository                                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  HIBERNATE                                                       │
│  • EntityManager                                                │
│  • SQL generation                                               │
│  • First-level cache                                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  HIKARICP (Connection Pool)                                     │
│  • Connection proxy                                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  JDBC DRIVER                                                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  DATABASE                                                        │
│  INSERT INTO users (name, email) VALUES ('Alice', 'alice@...')  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Reflection and Proxies Count

In this single request:
- **Reflection calls**: ~50+ (argument resolution, invocation, ORM)
- **Proxy layers**: 3-5 (controller, service, repository, connection)
- **Interceptor invocations**: 5-10 (transaction, validation, etc.)

Yet the request completes in milliseconds because:
- JIT compilation optimizes hot paths
- Proxies are cached and reused
- Reflection metadata is cached
- Connection pools eliminate connection overhead

---

## Key Takeaways

1. **Many layers work together** — each handling specific concerns
2. **Proxies are everywhere** — enabling transactions, AOP, etc.
3. **Reflection powers everything** — from deserialization to invocation
4. **Spring orchestrates the flow** — you write business logic
5. **Understanding the layers helps debugging** — know where to look

---

*Next: [Chapter 19: Building Your Own Mini-Framework](./19-build-your-own.md)*
