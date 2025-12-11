# Request Mapping Annotations

## Routing HTTP Requests to Your Code

---

## The @RequestMapping Family

```
@RequestMapping (parent)
    ├── @GetMapping     (GET requests)
    ├── @PostMapping    (POST requests)
    ├── @PutMapping     (PUT requests)
    ├── @DeleteMapping  (DELETE requests)
    └── @PatchMapping   (PATCH requests)
```

---

## @RequestMapping - The Foundation

### Basic Usage

```java
@RestController
@RequestMapping("/api/v1")  // Base path for all methods
public class UserController {

    @RequestMapping("/users")  // GET /api/v1/users (default is GET)
    public List<User> findAll() {
        return userService.findAll();
    }

    @RequestMapping(value = "/users", method = RequestMethod.POST)
    public User create(@RequestBody User user) {
        return userService.save(user);
    }
}
```

### All Attributes

```java
@RequestMapping(
    value = "/users",           // URL path(s)
    method = RequestMethod.GET, // HTTP method(s)
    params = "active=true",     // Required parameters
    headers = "X-API-KEY",      // Required headers
    consumes = "application/json",   // Request content type
    produces = "application/json"    // Response content type
)
public List<User> findActive() { ... }
```

---

## @GetMapping - Read Operations

### Simple GET

```java
@GetMapping("/users")
public List<User> findAll() {
    return userService.findAll();
}
```

### With Path Variable

```java
@GetMapping("/users/{id}")
public User findById(@PathVariable Long id) {
    return userService.findById(id)
        .orElseThrow(() -> new UserNotFoundException(id));
}
```

### With Query Parameters

```java
@GetMapping("/users/search")
public List<User> search(
    @RequestParam String name,
    @RequestParam(required = false) String email,
    @RequestParam(defaultValue = "0") int page,
    @RequestParam(defaultValue = "20") int size
) {
    return userService.search(name, email, page, size);
}
```

### Multiple Paths

```java
@GetMapping({ "/users", "/members", "/people" })
public List<User> findAll() {
    return userService.findAll();
}
```

---

## @PostMapping - Create Operations

### Simple POST

```java
@PostMapping("/users")
@ResponseStatus(HttpStatus.CREATED)
public User create(@RequestBody @Valid CreateUserRequest request) {
    return userService.create(request);
}
```

### With URI Location Header

```java
@PostMapping("/users")
public ResponseEntity<User> create(@RequestBody CreateUserRequest request) {
    User created = userService.create(request);

    URI location = ServletUriComponentsBuilder
        .fromCurrentRequest()
        .path("/{id}")
        .buildAndExpand(created.getId())
        .toUri();

    return ResponseEntity.created(location).body(created);
}
```

### Consuming Different Content Types

```java
// JSON only
@PostMapping(value = "/users", consumes = MediaType.APPLICATION_JSON_VALUE)
public User createFromJson(@RequestBody User user) { ... }

// Form data
@PostMapping(value = "/users", consumes = MediaType.APPLICATION_FORM_URLENCODED_VALUE)
public User createFromForm(@ModelAttribute User user) { ... }

// Multipart (file upload)
@PostMapping(value = "/users", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
public User createWithAvatar(
    @RequestPart("user") User user,
    @RequestPart("avatar") MultipartFile avatar
) { ... }
```

---

## @PutMapping - Full Update Operations

### Simple PUT

```java
@PutMapping("/users/{id}")
public User update(
    @PathVariable Long id,
    @RequestBody @Valid UpdateUserRequest request
) {
    return userService.update(id, request);
}
```

### Idempotent Upsert

```java
@PutMapping("/users/{id}")
public ResponseEntity<User> upsert(
    @PathVariable Long id,
    @RequestBody User user
) {
    boolean exists = userService.existsById(id);
    User saved = userService.save(id, user);

    return exists
        ? ResponseEntity.ok(saved)
        : ResponseEntity.status(HttpStatus.CREATED).body(saved);
}
```

---

## @PatchMapping - Partial Update Operations

### Simple PATCH

```java
@PatchMapping("/users/{id}")
public User partialUpdate(
    @PathVariable Long id,
    @RequestBody Map<String, Object> updates
) {
    return userService.partialUpdate(id, updates);
}
```

### JSON Patch Standard

```java
@PatchMapping(
    value = "/users/{id}",
    consumes = "application/json-patch+json"
)
public User jsonPatch(
    @PathVariable Long id,
    @RequestBody JsonPatch patch
) {
    User user = userService.findById(id);
    User patched = applyPatch(patch, user);
    return userService.save(patched);
}
```

### Merge Patch

```java
@PatchMapping(
    value = "/users/{id}",
    consumes = "application/merge-patch+json"
)
public User mergePatch(
    @PathVariable Long id,
    @RequestBody JsonMergePatch patch
) {
    User user = userService.findById(id);
    User patched = applyMergePatch(patch, user);
    return userService.save(patched);
}
```

---

## @DeleteMapping - Delete Operations

### Simple DELETE

```java
@DeleteMapping("/users/{id}")
@ResponseStatus(HttpStatus.NO_CONTENT)
public void delete(@PathVariable Long id) {
    userService.delete(id);
}
```

### With Response Body

```java
@DeleteMapping("/users/{id}")
public ResponseEntity<Void> delete(@PathVariable Long id) {
    boolean existed = userService.delete(id);

    return existed
        ? ResponseEntity.noContent().build()
        : ResponseEntity.notFound().build();
}
```

### Bulk Delete

```java
@DeleteMapping("/users")
@ResponseStatus(HttpStatus.NO_CONTENT)
public void deleteMany(@RequestParam List<Long> ids) {
    userService.deleteAll(ids);
}
```

---

## Advanced Mapping Patterns

### Path Variables with Regex

```java
// Only numeric IDs
@GetMapping("/users/{id:\\d+}")
public User findById(@PathVariable Long id) { ... }

// Only UUID format
@GetMapping("/users/{id:[a-f0-9\\-]{36}}")
public User findByUuid(@PathVariable UUID id) { ... }

// Version prefix
@GetMapping("/v{version:\\d+}/users")
public List<User> findAll(@PathVariable int version) { ... }
```

### Matrix Variables

```java
// GET /users/filter;status=active;role=admin
@GetMapping("/users/filter")
public List<User> filter(
    @MatrixVariable String status,
    @MatrixVariable String role
) {
    return userService.filter(status, role);
}

// Enable in config
@Configuration
public class WebConfig implements WebMvcConfigurer {
    @Override
    public void configurePathMatch(PathMatchConfigurer configurer) {
        UrlPathHelper urlPathHelper = new UrlPathHelper();
        urlPathHelper.setRemoveSemicolonContent(false);
        configurer.setUrlPathHelper(urlPathHelper);
    }
}
```

### Content Negotiation

```java
@GetMapping(
    value = "/users/{id}",
    produces = { MediaType.APPLICATION_JSON_VALUE, MediaType.APPLICATION_XML_VALUE }
)
public User findById(@PathVariable Long id) {
    return userService.findById(id);
}

// Client can request:
// Accept: application/json -> JSON response
// Accept: application/xml  -> XML response
```

### Parameter-Based Routing

```java
// GET /users?version=1
@GetMapping(value = "/users", params = "version=1")
public List<UserV1> findAllV1() { ... }

// GET /users?version=2
@GetMapping(value = "/users", params = "version=2")
public List<UserV2> findAllV2() { ... }
```

### Header-Based Routing

```java
// X-API-Version: 1
@GetMapping(value = "/users", headers = "X-API-Version=1")
public List<UserV1> findAllV1() { ... }

// X-API-Version: 2
@GetMapping(value = "/users", headers = "X-API-Version=2")
public List<UserV2> findAllV2() { ... }
```

---

## URL Pattern Matching

### Wildcards

```java
// Matches: /files/document.txt, /files/image.png
@GetMapping("/files/{filename:.+}")
public Resource getFile(@PathVariable String filename) { ... }

// Matches: /files/a, /files/a/b, /files/a/b/c
@GetMapping("/files/**")
public List<String> listFiles(HttpServletRequest request) {
    String path = (String) request.getAttribute(
        HandlerMapping.PATH_WITHIN_HANDLER_MAPPING_ATTRIBUTE
    );
    return fileService.list(path);
}
```

### Ant-Style Patterns

| Pattern | Matches |
|---------|---------|
| `/users/*` | `/users/john` (one segment) |
| `/users/**` | `/users/john/orders/123` (any segments) |
| `/users/{id}` | `/users/123` (captures `id=123`) |
| `/files/{*path}` | `/files/a/b/c` (captures `path=a/b/c`) |

---

## Complete REST Controller Example

```java
@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    // GET /api/v1/users
    @GetMapping
    public List<User> findAll() {
        return userService.findAll();
    }

    // GET /api/v1/users/123
    @GetMapping("/{id}")
    public User findById(@PathVariable Long id) {
        return userService.findById(id)
            .orElseThrow(() -> new UserNotFoundException(id));
    }

    // GET /api/v1/users/search?name=john
    @GetMapping("/search")
    public List<User> search(@RequestParam String name) {
        return userService.findByName(name);
    }

    // POST /api/v1/users
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public User create(@RequestBody @Valid CreateUserRequest request) {
        return userService.create(request);
    }

    // PUT /api/v1/users/123
    @PutMapping("/{id}")
    public User update(
        @PathVariable Long id,
        @RequestBody @Valid UpdateUserRequest request
    ) {
        return userService.update(id, request);
    }

    // PATCH /api/v1/users/123
    @PatchMapping("/{id}")
    public User partialUpdate(
        @PathVariable Long id,
        @RequestBody Map<String, Object> updates
    ) {
        return userService.partialUpdate(id, updates);
    }

    // DELETE /api/v1/users/123
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        userService.delete(id);
    }
}
```

---

## Key Takeaways

1. **Use specific annotations** (`@GetMapping`) over generic (`@RequestMapping`)
2. **`@RequestMapping` on class** sets the base path
3. **Path variables with regex** prevent invalid input early
4. **Content negotiation** via `produces` and `consumes`
5. **Matrix variables** for complex filtering (rarely used but powerful)
6. **Ant-style patterns** for flexible routing

---

*Next: [Request Parameter Annotations](./04-request-parameters.md)*
