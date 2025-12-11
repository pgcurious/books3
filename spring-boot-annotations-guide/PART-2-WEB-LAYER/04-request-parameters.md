# Request Parameter Annotations

## Extracting Data from HTTP Requests

---

## Overview

| Annotation | Source | Example |
|------------|--------|---------|
| `@PathVariable` | URL path | `/users/{id}` |
| `@RequestParam` | Query string | `?name=john` |
| `@RequestBody` | Request body | JSON payload |
| `@RequestHeader` | HTTP headers | `Authorization` |
| `@CookieValue` | Cookies | `sessionId` |
| `@ModelAttribute` | Form data | Form submission |
| `@RequestPart` | Multipart | File uploads |

---

## @PathVariable - URL Segments

### Basic Usage

```java
// GET /users/123
@GetMapping("/users/{id}")
public User findById(@PathVariable Long id) {
    return userService.findById(id);
}
```

### Different Parameter Name

```java
// When URL variable name differs from parameter name
@GetMapping("/users/{userId}")
public User findById(@PathVariable("userId") Long id) {
    return userService.findById(id);
}
```

### Multiple Path Variables

```java
// GET /users/123/orders/456
@GetMapping("/users/{userId}/orders/{orderId}")
public Order findOrder(
    @PathVariable Long userId,
    @PathVariable Long orderId
) {
    return orderService.findByUserAndOrder(userId, orderId);
}
```

### Optional Path Variable

```java
// Matches both /users and /users/123
@GetMapping({ "/users", "/users/{id}" })
public Object findUsers(@PathVariable(required = false) Long id) {
    if (id != null) {
        return userService.findById(id);
    }
    return userService.findAll();
}
```

### Path Variable as Map

```java
// GET /users/123/orders/456
@GetMapping("/users/{userId}/orders/{orderId}")
public Order findOrder(@PathVariable Map<String, String> pathVariables) {
    Long userId = Long.parseLong(pathVariables.get("userId"));
    Long orderId = Long.parseLong(pathVariables.get("orderId"));
    return orderService.findByUserAndOrder(userId, orderId);
}
```

---

## @RequestParam - Query Parameters

### Basic Usage

```java
// GET /users/search?name=john
@GetMapping("/users/search")
public List<User> search(@RequestParam String name) {
    return userService.findByName(name);
}
```

### Optional Parameter

```java
@GetMapping("/users/search")
public List<User> search(
    @RequestParam String name,
    @RequestParam(required = false) String email
) {
    return userService.search(name, email);
}
```

### Default Value

```java
@GetMapping("/users")
public Page<User> findAll(
    @RequestParam(defaultValue = "0") int page,
    @RequestParam(defaultValue = "20") int size,
    @RequestParam(defaultValue = "id") String sortBy
) {
    return userService.findAll(PageRequest.of(page, size, Sort.by(sortBy)));
}
```

### Multiple Values (Array/List)

```java
// GET /users?ids=1,2,3  or  /users?ids=1&ids=2&ids=3
@GetMapping("/users")
public List<User> findByIds(@RequestParam List<Long> ids) {
    return userService.findAllById(ids);
}

// As array
@GetMapping("/users")
public List<User> findByIds(@RequestParam Long[] ids) {
    return userService.findAllById(Arrays.asList(ids));
}
```

### All Parameters as Map

```java
// GET /search?name=john&email=john@example.com&active=true
@GetMapping("/search")
public List<User> search(@RequestParam Map<String, String> params) {
    return userService.search(params);
}

// With multiple values per key
@GetMapping("/search")
public List<User> search(@RequestParam MultiValueMap<String, String> params) {
    // params.get("role") could return ["admin", "user"]
    return userService.search(params);
}
```

---

## @RequestBody - JSON/XML Payload

### Basic Usage

```java
@PostMapping("/users")
public User create(@RequestBody CreateUserRequest request) {
    return userService.create(request);
}
```

### With Validation

```java
@PostMapping("/users")
public User create(@RequestBody @Valid CreateUserRequest request) {
    return userService.create(request);
}

// DTO with validation
public class CreateUserRequest {
    @NotBlank(message = "Name is required")
    private String name;

    @Email(message = "Invalid email format")
    @NotBlank(message = "Email is required")
    private String email;

    @Size(min = 8, message = "Password must be at least 8 characters")
    private String password;

    // getters, setters
}
```

### Optional Request Body

```java
@PostMapping("/users")
public User create(@RequestBody(required = false) CreateUserRequest request) {
    if (request == null) {
        request = new CreateUserRequest(); // defaults
    }
    return userService.create(request);
}
```

### Generic Types

```java
@PostMapping("/batch")
public List<User> createBatch(@RequestBody List<CreateUserRequest> requests) {
    return requests.stream()
        .map(userService::create)
        .collect(Collectors.toList());
}
```

---

## @RequestHeader - HTTP Headers

### Basic Usage

```java
@GetMapping("/users")
public List<User> findAll(@RequestHeader("Authorization") String auth) {
    // Validate auth header
    return userService.findAll();
}
```

### Optional Header

```java
@GetMapping("/users")
public List<User> findAll(
    @RequestHeader(value = "X-Correlation-ID", required = false) String correlationId
) {
    if (correlationId != null) {
        MDC.put("correlationId", correlationId);
    }
    return userService.findAll();
}
```

### Default Value

```java
@GetMapping("/users")
public List<User> findAll(
    @RequestHeader(value = "Accept-Language", defaultValue = "en") String language
) {
    return userService.findAllLocalized(language);
}
```

### All Headers as Map

```java
@GetMapping("/debug")
public Map<String, String> debugHeaders(@RequestHeader Map<String, String> headers) {
    return headers;
}

// With multiple values per header
@GetMapping("/debug")
public void debugHeaders(@RequestHeader MultiValueMap<String, String> headers) {
    headers.forEach((key, values) -> {
        System.out.println(key + ": " + values);
    });
}
```

### Common Headers

```java
@GetMapping("/users")
public List<User> findAll(
    @RequestHeader("Authorization") String authorization,
    @RequestHeader("User-Agent") String userAgent,
    @RequestHeader("Accept") String accept,
    @RequestHeader("Content-Type") String contentType,
    @RequestHeader("X-Request-ID") String requestId
) {
    // Process with headers
    return userService.findAll();
}
```

---

## @CookieValue - HTTP Cookies

### Basic Usage

```java
@GetMapping("/user")
public User getCurrentUser(@CookieValue("sessionId") String sessionId) {
    return sessionService.getUserBySession(sessionId);
}
```

### Optional Cookie

```java
@GetMapping("/preferences")
public Preferences getPreferences(
    @CookieValue(value = "theme", defaultValue = "light") String theme,
    @CookieValue(value = "language", required = false) String language
) {
    return new Preferences(theme, language != null ? language : "en");
}
```

### Cookie Object

```java
@GetMapping("/debug")
public String debugCookie(@CookieValue("JSESSIONID") Cookie cookie) {
    return String.format(
        "Name: %s, Value: %s, MaxAge: %d",
        cookie.getName(),
        cookie.getValue(),
        cookie.getMaxAge()
    );
}
```

---

## @ModelAttribute - Form Data & Model

### Form Data Binding

```java
// POST with application/x-www-form-urlencoded
@PostMapping("/users")
public String createUser(@ModelAttribute User user) {
    userService.save(user);
    return "redirect:/users";
}

// HTML form:
// <form method="post">
//   <input name="name" />
//   <input name="email" />
//   <button type="submit">Create</button>
// </form>
```

### With Validation

```java
@PostMapping("/users")
public String createUser(
    @ModelAttribute @Valid User user,
    BindingResult result,
    Model model
) {
    if (result.hasErrors()) {
        return "user-form";  // Return to form with errors
    }
    userService.save(user);
    return "redirect:/users";
}
```

### Pre-populating Model

```java
@Controller
public class UserController {

    // Called before EVERY request handler in this controller
    @ModelAttribute("countries")
    public List<Country> populateCountries() {
        return countryService.findAll();
    }

    @GetMapping("/users/new")
    public String showForm(Model model) {
        // "countries" is already in model
        model.addAttribute("user", new User());
        return "user-form";
    }
}
```

### Named Model Attribute

```java
@ModelAttribute("currentUser")
public User getCurrentUser(Principal principal) {
    return userService.findByUsername(principal.getName());
}

// Available in all views as ${currentUser}
```

---

## @RequestPart - Multipart Requests

### File Upload

```java
@PostMapping(
    value = "/upload",
    consumes = MediaType.MULTIPART_FORM_DATA_VALUE
)
public String uploadFile(@RequestPart("file") MultipartFile file) {
    String filename = file.getOriginalFilename();
    long size = file.getSize();
    String contentType = file.getContentType();

    // Save file
    storageService.store(file);

    return "File uploaded: " + filename;
}
```

### File + JSON Data

```java
@PostMapping(
    value = "/users",
    consumes = MediaType.MULTIPART_FORM_DATA_VALUE
)
public User createWithAvatar(
    @RequestPart("user") @Valid CreateUserRequest user,
    @RequestPart("avatar") MultipartFile avatar
) {
    User created = userService.create(user);
    storageService.storeAvatar(created.getId(), avatar);
    return created;
}

// Request:
// Content-Type: multipart/form-data
// Part 1: name="user", Content-Type: application/json, body: {"name":"john",...}
// Part 2: name="avatar", Content-Type: image/png, body: <binary>
```

### Multiple Files

```java
@PostMapping("/upload-multiple")
public String uploadMultiple(@RequestPart("files") List<MultipartFile> files) {
    files.forEach(storageService::store);
    return "Uploaded " + files.size() + " files";
}
```

### Optional File

```java
@PostMapping("/users")
public User create(
    @RequestPart("user") CreateUserRequest user,
    @RequestPart(value = "avatar", required = false) MultipartFile avatar
) {
    User created = userService.create(user);
    if (avatar != null && !avatar.isEmpty()) {
        storageService.storeAvatar(created.getId(), avatar);
    }
    return created;
}
```

---

## Type Conversion

Spring automatically converts parameters to these types:

### Primitive Types

```java
@GetMapping("/users/{id}")
public User findById(@PathVariable Long id) { }

@GetMapping("/search")
public List<User> search(
    @RequestParam int page,
    @RequestParam boolean active,
    @RequestParam double minScore
) { }
```

### Date/Time Types

```java
@GetMapping("/events")
public List<Event> findByDate(
    @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date
) { }

@GetMapping("/events")
public List<Event> findByDateTime(
    @RequestParam @DateTimeFormat(pattern = "yyyy-MM-dd HH:mm") LocalDateTime dateTime
) { }
```

### Enums

```java
public enum Status { ACTIVE, INACTIVE, PENDING }

@GetMapping("/users")
public List<User> findByStatus(@RequestParam Status status) {
    return userService.findByStatus(status);
}
// GET /users?status=ACTIVE
```

### Custom Converters

```java
@Component
public class StringToUserConverter implements Converter<String, User> {
    @Override
    public User convert(String id) {
        return userService.findById(Long.parseLong(id));
    }
}

// Now this works
@GetMapping("/orders")
public List<Order> findOrders(@RequestParam User user) { }
// GET /orders?user=123  <- Spring converts "123" to User entity
```

---

## Complete Example

```java
@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    @GetMapping("/{id}")
    public User findById(
        @PathVariable Long id,
        @RequestHeader("Authorization") String auth,
        @RequestHeader(value = "X-Include-Details", defaultValue = "false") boolean includeDetails
    ) {
        User user = userService.findById(id);
        if (includeDetails) {
            user = userService.loadDetails(user);
        }
        return user;
    }

    @GetMapping("/search")
    public Page<User> search(
        @RequestParam(required = false) String name,
        @RequestParam(required = false) String email,
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "20") int size,
        @RequestParam(defaultValue = "createdAt") String sortBy,
        @RequestParam(defaultValue = "desc") String sortDir
    ) {
        Sort sort = sortDir.equalsIgnoreCase("asc")
            ? Sort.by(sortBy).ascending()
            : Sort.by(sortBy).descending();

        return userService.search(name, email, PageRequest.of(page, size, sort));
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public User create(
        @RequestPart("user") @Valid CreateUserRequest request,
        @RequestPart(value = "avatar", required = false) MultipartFile avatar,
        @CookieValue(value = "referrer", required = false) String referrer
    ) {
        User user = userService.create(request);
        if (avatar != null) {
            storageService.storeAvatar(user.getId(), avatar);
        }
        if (referrer != null) {
            referralService.trackReferral(referrer, user.getId());
        }
        return user;
    }
}
```

---

## Key Takeaways

1. **@PathVariable** for REST resource identifiers
2. **@RequestParam** for filtering, pagination, search
3. **@RequestBody** for JSON payloads (use with `@Valid`)
4. **@RequestHeader** for auth tokens, correlation IDs
5. **@CookieValue** for session data
6. **@ModelAttribute** for form submissions
7. **@RequestPart** for file uploads with metadata
8. **Spring auto-converts** types including dates and enums

---

*Next: [Response Handling Annotations](./05-response-handling.md)*
