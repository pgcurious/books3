# Response Handling Annotations

## Controlling What Comes Back to the Client

---

## Overview

| Annotation | Purpose |
|------------|---------|
| `@ResponseBody` | Return data directly (not view name) |
| `@ResponseStatus` | Set HTTP status code |
| `@ExceptionHandler` | Handle exceptions in controllers |
| `@ControllerAdvice` | Global exception handling |
| `@RestControllerAdvice` | @ControllerAdvice + @ResponseBody |
| `@CrossOrigin` | Enable CORS |

---

## @ResponseBody - Return Data Directly

### Basic Usage

```java
@Controller
public class UserController {

    // Returns view name
    @GetMapping("/users")
    public String usersPage(Model model) {
        model.addAttribute("users", userService.findAll());
        return "users";  // View name
    }

    // Returns JSON
    @GetMapping("/api/users")
    @ResponseBody
    public List<User> usersApi() {
        return userService.findAll();  // Serialized to JSON
    }
}
```

### @RestController = @Controller + @ResponseBody

```java
// These are equivalent:
@Controller
public class UserController {
    @GetMapping("/users")
    @ResponseBody
    public List<User> findAll() { ... }
}

@RestController
public class UserController {
    @GetMapping("/users")
    public List<User> findAll() { ... }
}
```

---

## @ResponseStatus - Set HTTP Status

### On Methods

```java
@PostMapping("/users")
@ResponseStatus(HttpStatus.CREATED)  // 201
public User create(@RequestBody CreateUserRequest request) {
    return userService.create(request);
}

@DeleteMapping("/users/{id}")
@ResponseStatus(HttpStatus.NO_CONTENT)  // 204
public void delete(@PathVariable Long id) {
    userService.delete(id);
}
```

### On Exception Classes

```java
@ResponseStatus(HttpStatus.NOT_FOUND)
public class UserNotFoundException extends RuntimeException {
    public UserNotFoundException(Long id) {
        super("User not found: " + id);
    }
}

// When thrown, automatically returns 404
@GetMapping("/users/{id}")
public User findById(@PathVariable Long id) {
    return userService.findById(id)
        .orElseThrow(() -> new UserNotFoundException(id));
}
```

### Common Status Codes

```java
@ResponseStatus(HttpStatus.OK)           // 200 - Default for GET
@ResponseStatus(HttpStatus.CREATED)      // 201 - Resource created
@ResponseStatus(HttpStatus.ACCEPTED)     // 202 - Async processing started
@ResponseStatus(HttpStatus.NO_CONTENT)   // 204 - Success, no body
@ResponseStatus(HttpStatus.BAD_REQUEST)  // 400 - Client error
@ResponseStatus(HttpStatus.UNAUTHORIZED) // 401 - Not authenticated
@ResponseStatus(HttpStatus.FORBIDDEN)    // 403 - Not authorized
@ResponseStatus(HttpStatus.NOT_FOUND)    // 404 - Resource not found
@ResponseStatus(HttpStatus.CONFLICT)     // 409 - Conflict (e.g., duplicate)
```

---

## @ExceptionHandler - Handle Exceptions

### In Controller

```java
@RestController
@RequestMapping("/api/users")
public class UserController {

    @GetMapping("/{id}")
    public User findById(@PathVariable Long id) {
        return userService.findById(id)
            .orElseThrow(() -> new UserNotFoundException(id));
    }

    // Handles UserNotFoundException in THIS controller only
    @ExceptionHandler(UserNotFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public ErrorResponse handleUserNotFound(UserNotFoundException ex) {
        return new ErrorResponse(
            HttpStatus.NOT_FOUND.value(),
            ex.getMessage(),
            LocalDateTime.now()
        );
    }
}
```

### Multiple Exception Types

```java
@ExceptionHandler({ UserNotFoundException.class, OrderNotFoundException.class })
@ResponseStatus(HttpStatus.NOT_FOUND)
public ErrorResponse handleNotFound(RuntimeException ex) {
    return new ErrorResponse(404, ex.getMessage());
}
```

### Access to Request Details

```java
@ExceptionHandler(ValidationException.class)
public ResponseEntity<ErrorResponse> handleValidation(
    ValidationException ex,
    HttpServletRequest request,
    WebRequest webRequest
) {
    ErrorResponse error = new ErrorResponse(
        HttpStatus.BAD_REQUEST.value(),
        ex.getMessage(),
        request.getRequestURI()
    );
    return ResponseEntity.badRequest().body(error);
}
```

---

## @ControllerAdvice - Global Exception Handling

### Basic Global Handler

```java
@ControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(ResourceNotFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    @ResponseBody
    public ErrorResponse handleNotFound(ResourceNotFoundException ex) {
        return new ErrorResponse(404, ex.getMessage());
    }

    @ExceptionHandler(ValidationException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    @ResponseBody
    public ErrorResponse handleValidation(ValidationException ex) {
        return new ErrorResponse(400, ex.getMessage());
    }

    @ExceptionHandler(Exception.class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    @ResponseBody
    public ErrorResponse handleGeneric(Exception ex) {
        log.error("Unexpected error", ex);
        return new ErrorResponse(500, "Internal server error");
    }
}
```

### @RestControllerAdvice (Simpler)

```java
@RestControllerAdvice  // @ControllerAdvice + @ResponseBody
public class GlobalExceptionHandler {

    @ExceptionHandler(ResourceNotFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public ErrorResponse handleNotFound(ResourceNotFoundException ex) {
        return new ErrorResponse(404, ex.getMessage());
    }
}
```

### Scoped to Specific Controllers

```java
// Only for controllers in this package
@RestControllerAdvice(basePackages = "com.myapp.api")
public class ApiExceptionHandler { }

// Only for controllers with this annotation
@RestControllerAdvice(annotations = RestController.class)
public class RestExceptionHandler { }

// Only for specific controller classes
@RestControllerAdvice(assignableTypes = { UserController.class, OrderController.class })
public class UserOrderExceptionHandler { }
```

---

## Complete Exception Handling Setup

### Error Response DTO

```java
public class ErrorResponse {
    private int status;
    private String message;
    private String path;
    private LocalDateTime timestamp;
    private List<FieldError> errors;

    // Constructors, getters, setters

    public static class FieldError {
        private String field;
        private String message;

        public FieldError(String field, String message) {
            this.field = field;
            this.message = message;
        }
        // getters
    }
}
```

### Custom Exceptions

```java
@ResponseStatus(HttpStatus.NOT_FOUND)
public class ResourceNotFoundException extends RuntimeException {
    public ResourceNotFoundException(String resource, Long id) {
        super(String.format("%s not found with id: %d", resource, id));
    }
}

@ResponseStatus(HttpStatus.CONFLICT)
public class DuplicateResourceException extends RuntimeException {
    public DuplicateResourceException(String message) {
        super(message);
    }
}

@ResponseStatus(HttpStatus.BAD_REQUEST)
public class BusinessValidationException extends RuntimeException {
    private final List<String> errors;

    public BusinessValidationException(List<String> errors) {
        super("Validation failed");
        this.errors = errors;
    }

    public List<String> getErrors() {
        return errors;
    }
}
```

### Global Handler

```java
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    // Handle validation errors from @Valid
    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ErrorResponse handleValidationErrors(
        MethodArgumentNotValidException ex,
        HttpServletRequest request
    ) {
        List<ErrorResponse.FieldError> fieldErrors = ex.getBindingResult()
            .getFieldErrors()
            .stream()
            .map(error -> new ErrorResponse.FieldError(
                error.getField(),
                error.getDefaultMessage()
            ))
            .collect(Collectors.toList());

        ErrorResponse response = new ErrorResponse();
        response.setStatus(400);
        response.setMessage("Validation failed");
        response.setPath(request.getRequestURI());
        response.setTimestamp(LocalDateTime.now());
        response.setErrors(fieldErrors);

        return response;
    }

    // Handle constraint violations
    @ExceptionHandler(ConstraintViolationException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ErrorResponse handleConstraintViolation(
        ConstraintViolationException ex,
        HttpServletRequest request
    ) {
        List<ErrorResponse.FieldError> fieldErrors = ex.getConstraintViolations()
            .stream()
            .map(violation -> new ErrorResponse.FieldError(
                violation.getPropertyPath().toString(),
                violation.getMessage()
            ))
            .collect(Collectors.toList());

        return ErrorResponse.builder()
            .status(400)
            .message("Validation failed")
            .path(request.getRequestURI())
            .errors(fieldErrors)
            .build();
    }

    // Handle not found
    @ExceptionHandler(ResourceNotFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public ErrorResponse handleNotFound(
        ResourceNotFoundException ex,
        HttpServletRequest request
    ) {
        return ErrorResponse.builder()
            .status(404)
            .message(ex.getMessage())
            .path(request.getRequestURI())
            .build();
    }

    // Handle duplicates
    @ExceptionHandler(DuplicateResourceException.class)
    @ResponseStatus(HttpStatus.CONFLICT)
    public ErrorResponse handleDuplicate(
        DuplicateResourceException ex,
        HttpServletRequest request
    ) {
        return ErrorResponse.builder()
            .status(409)
            .message(ex.getMessage())
            .path(request.getRequestURI())
            .build();
    }

    // Catch-all for unexpected errors
    @ExceptionHandler(Exception.class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    public ErrorResponse handleUnexpected(
        Exception ex,
        HttpServletRequest request
    ) {
        log.error("Unexpected error at {}: {}", request.getRequestURI(), ex.getMessage(), ex);

        return ErrorResponse.builder()
            .status(500)
            .message("An unexpected error occurred")
            .path(request.getRequestURI())
            .build();
    }
}
```

---

## @CrossOrigin - CORS Configuration

### On Controller/Method

```java
@RestController
@RequestMapping("/api/users")
@CrossOrigin(origins = "http://localhost:3000")
public class UserController {

    @GetMapping
    public List<User> findAll() { ... }

    // Override at method level
    @CrossOrigin(origins = "*", maxAge = 3600)
    @GetMapping("/{id}")
    public User findById(@PathVariable Long id) { ... }
}
```

### All Options

```java
@CrossOrigin(
    origins = { "http://localhost:3000", "https://myapp.com" },
    methods = { RequestMethod.GET, RequestMethod.POST },
    allowedHeaders = { "Authorization", "Content-Type" },
    exposedHeaders = { "X-Custom-Header" },
    allowCredentials = "true",
    maxAge = 3600
)
```

### Global CORS Configuration

```java
@Configuration
public class CorsConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
            .allowedOrigins("http://localhost:3000")
            .allowedMethods("GET", "POST", "PUT", "DELETE")
            .allowedHeaders("*")
            .allowCredentials(true)
            .maxAge(3600);
    }
}
```

---

## ResponseEntity - Full Control

### Basic Usage

```java
@GetMapping("/users/{id}")
public ResponseEntity<User> findById(@PathVariable Long id) {
    return userService.findById(id)
        .map(ResponseEntity::ok)
        .orElse(ResponseEntity.notFound().build());
}
```

### With Custom Headers

```java
@GetMapping("/users/{id}")
public ResponseEntity<User> findById(@PathVariable Long id) {
    User user = userService.findById(id);

    return ResponseEntity.ok()
        .header("X-Custom-Header", "value")
        .header("Cache-Control", "max-age=3600")
        .body(user);
}
```

### Created with Location

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

### Common Patterns

```java
// 200 OK with body
return ResponseEntity.ok(user);

// 200 OK empty
return ResponseEntity.ok().build();

// 201 Created
return ResponseEntity.status(HttpStatus.CREATED).body(user);

// 204 No Content
return ResponseEntity.noContent().build();

// 400 Bad Request
return ResponseEntity.badRequest().body(error);

// 404 Not Found
return ResponseEntity.notFound().build();

// Custom status
return ResponseEntity.status(HttpStatus.I_AM_A_TEAPOT).build();
```

---

## Key Takeaways

1. **@ResponseStatus** sets the HTTP status code declaratively
2. **@ExceptionHandler** handles exceptions in the current controller
3. **@RestControllerAdvice** handles exceptions globally
4. **Scope @ControllerAdvice** to avoid catching too much
5. **ResponseEntity** gives full control over status, headers, and body
6. **@CrossOrigin** or global config for CORS

---

*Next: [Injection Annotations](../PART-3-DEPENDENCY-INJECTION/06-injection-annotations.md)*
