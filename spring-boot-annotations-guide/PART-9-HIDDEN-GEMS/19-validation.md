# Validation Annotations

## Ensuring Data Integrity at Every Layer

---

## Overview

| Annotation | Purpose |
|------------|---------|
| `@Valid` | Trigger validation |
| `@Validated` | Enable validation + groups |
| `@NotNull` | Must not be null |
| `@NotBlank` | Must have non-whitespace content |
| `@Size` | Length/size constraints |
| `@Pattern` | Regex pattern matching |
| `@Email` | Email format validation |
| `@Min` / `@Max` | Numeric bounds |
| Custom | Create your own validators |

---

## Basic Validation Annotations

### Common Constraints

```java
public class CreateUserRequest {

    @NotNull(message = "Name is required")
    @Size(min = 2, max = 50, message = "Name must be 2-50 characters")
    private String name;

    @NotBlank(message = "Email is required")
    @Email(message = "Invalid email format")
    private String email;

    @NotNull
    @Size(min = 8, message = "Password must be at least 8 characters")
    @Pattern(
        regexp = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).+$",
        message = "Password must contain uppercase, lowercase, and digit"
    )
    private String password;

    @Min(value = 18, message = "Must be at least 18 years old")
    @Max(value = 120, message = "Age seems invalid")
    private Integer age;

    @Past(message = "Birth date must be in the past")
    private LocalDate birthDate;

    @Future(message = "Expiry date must be in the future")
    private LocalDate expiryDate;
}
```

### String Constraints

```java
@NotNull      // Not null (but can be empty "")
@NotEmpty     // Not null AND not empty (length > 0)
@NotBlank     // Not null AND has non-whitespace chars

// Examples:
String field;
// null   -> @NotNull fails, @NotEmpty fails, @NotBlank fails
// ""     -> @NotNull passes, @NotEmpty fails, @NotBlank fails
// "   "  -> @NotNull passes, @NotEmpty passes, @NotBlank fails
// "abc"  -> @NotNull passes, @NotEmpty passes, @NotBlank passes
```

### Numeric Constraints

```java
@Min(0)                    // >= 0
@Max(100)                  // <= 100
@Positive                  // > 0
@PositiveOrZero            // >= 0
@Negative                  // < 0
@NegativeOrZero            // <= 0
@DecimalMin("0.01")        // >= 0.01 (for BigDecimal)
@DecimalMax("999.99")      // <= 999.99
@Digits(integer = 5, fraction = 2)  // Max 5 integer, 2 fraction digits
```

### Date/Time Constraints

```java
@Past          // Before current time
@PastOrPresent // Before or equal to current time
@Future        // After current time
@FutureOrPresent // After or equal to current time
```

### Collection Constraints

```java
@Size(min = 1, max = 10)              // Collection size
@NotEmpty                              // Not null and not empty
private List<String> items;
```

---

## Triggering Validation

### In Controllers with @Valid

```java
@RestController
@RequestMapping("/api/users")
public class UserController {

    @PostMapping
    public ResponseEntity<User> create(@Valid @RequestBody CreateUserRequest request) {
        // Only reaches here if validation passes
        return ResponseEntity.status(HttpStatus.CREATED)
            .body(userService.create(request));
    }
}
```

### Handling Validation Errors

```java
@RestControllerAdvice
public class ValidationExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Map<String, Object> handleValidation(MethodArgumentNotValidException ex) {
        Map<String, String> errors = new HashMap<>();

        ex.getBindingResult().getFieldErrors().forEach(error -> {
            errors.put(error.getField(), error.getDefaultMessage());
        });

        return Map.of(
            "status", 400,
            "message", "Validation failed",
            "errors", errors
        );
    }
}
```

---

## @Validated - Method-Level Validation

### On Service Methods

```java
@Service
@Validated  // Enable method parameter validation
public class UserService {

    public User findById(@NotNull Long id) {
        return userRepository.findById(id).orElseThrow();
    }

    public List<User> search(
        @NotBlank String query,
        @Min(0) int page,
        @Min(1) @Max(100) int size
    ) {
        return userRepository.search(query, PageRequest.of(page, size));
    }

    public User create(@Valid CreateUserRequest request) {
        // @Valid validates the entire object
        return userRepository.save(new User(request));
    }
}
```

### Return Value Validation

```java
@Service
@Validated
public class UserService {

    @Valid  // Validate returned object
    @NotNull
    public User findById(Long id) {
        return userRepository.findById(id).orElse(null);  // Would fail if null
    }
}
```

---

## Validation Groups

### Define Groups

```java
public interface ValidationGroups {
    interface Create { }
    interface Update { }
}
```

### Apply Groups to Constraints

```java
public class UserDto {

    @Null(groups = ValidationGroups.Create.class, message = "ID must be null for creation")
    @NotNull(groups = ValidationGroups.Update.class, message = "ID required for update")
    private Long id;

    @NotBlank(groups = { ValidationGroups.Create.class, ValidationGroups.Update.class })
    private String name;

    @NotBlank(groups = ValidationGroups.Create.class, message = "Email required for creation")
    private String email;  // Only required on create
}
```

### Trigger Specific Group

```java
@RestController
public class UserController {

    @PostMapping("/users")
    public User create(
        @Validated(ValidationGroups.Create.class) @RequestBody UserDto dto
    ) {
        return userService.create(dto);
    }

    @PutMapping("/users/{id}")
    public User update(
        @PathVariable Long id,
        @Validated(ValidationGroups.Update.class) @RequestBody UserDto dto
    ) {
        return userService.update(id, dto);
    }
}
```

---

## Nested Object Validation

### @Valid for Nested Objects

```java
public class OrderRequest {

    @NotNull
    @Valid  // Validate nested object
    private CustomerInfo customer;

    @NotEmpty
    @Valid  // Validate each item in list
    private List<OrderItem> items;
}

public class CustomerInfo {
    @NotBlank
    private String name;

    @Email
    private String email;
}

public class OrderItem {
    @NotBlank
    private String productId;

    @Positive
    private int quantity;
}
```

---

## Custom Validation

### Custom Constraint Annotation

```java
@Target({ ElementType.FIELD, ElementType.PARAMETER })
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = PhoneNumberValidator.class)
@Documented
public @interface PhoneNumber {
    String message() default "Invalid phone number";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};

    String region() default "US";
}
```

### Custom Validator

```java
public class PhoneNumberValidator implements ConstraintValidator<PhoneNumber, String> {

    private String region;

    @Override
    public void initialize(PhoneNumber annotation) {
        this.region = annotation.region();
    }

    @Override
    public boolean isValid(String value, ConstraintValidatorContext context) {
        if (value == null) {
            return true;  // Use @NotNull for null checks
        }

        // Validation logic
        return PhoneNumberUtil.getInstance()
            .isValidNumber(PhoneNumberUtil.getInstance().parse(value, region));
    }
}
```

### Usage

```java
public class ContactInfo {

    @PhoneNumber(region = "US")
    private String phone;

    @PhoneNumber(region = "UK", message = "Invalid UK phone number")
    private String ukPhone;
}
```

### Class-Level Validation

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = PasswordMatchValidator.class)
public @interface PasswordMatch {
    String message() default "Passwords do not match";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}

public class PasswordMatchValidator
        implements ConstraintValidator<PasswordMatch, PasswordChangeRequest> {

    @Override
    public boolean isValid(PasswordChangeRequest request, ConstraintValidatorContext context) {
        if (request.getPassword() == null) {
            return true;
        }
        return request.getPassword().equals(request.getConfirmPassword());
    }
}

@PasswordMatch
public class PasswordChangeRequest {
    @NotBlank
    private String password;

    @NotBlank
    private String confirmPassword;
}
```

---

## Cross-Field Validation

### Using Class-Level Constraint

```java
@DateRange(startField = "startDate", endField = "endDate")
public class DateRangeRequest {

    @NotNull
    private LocalDate startDate;

    @NotNull
    private LocalDate endDate;
}

@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = DateRangeValidator.class)
public @interface DateRange {
    String message() default "End date must be after start date";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
    String startField();
    String endField();
}

public class DateRangeValidator implements ConstraintValidator<DateRange, Object> {

    private String startField;
    private String endField;

    @Override
    public void initialize(DateRange annotation) {
        this.startField = annotation.startField();
        this.endField = annotation.endField();
    }

    @Override
    public boolean isValid(Object value, ConstraintValidatorContext context) {
        try {
            LocalDate start = (LocalDate) PropertyUtils.getProperty(value, startField);
            LocalDate end = (LocalDate) PropertyUtils.getProperty(value, endField);

            if (start == null || end == null) {
                return true;
            }

            return !end.isBefore(start);
        } catch (Exception e) {
            return false;
        }
    }
}
```

---

## Programmatic Validation

```java
@Service
public class ValidationService {

    private final Validator validator;

    public ValidationService(Validator validator) {
        this.validator = validator;
    }

    public <T> void validate(T object) {
        Set<ConstraintViolation<T>> violations = validator.validate(object);

        if (!violations.isEmpty()) {
            throw new ValidationException(
                violations.stream()
                    .map(v -> v.getPropertyPath() + ": " + v.getMessage())
                    .collect(Collectors.joining(", "))
            );
        }
    }

    public <T> void validate(T object, Class<?>... groups) {
        Set<ConstraintViolation<T>> violations = validator.validate(object, groups);
        // Handle violations
    }
}
```

---

## Key Takeaways

1. **@Valid on @RequestBody** triggers validation
2. **@Validated on class** enables method parameter validation
3. **@NotNull vs @NotEmpty vs @NotBlank** - know the difference
4. **Validation groups** for context-specific rules
5. **@Valid on nested objects** validates recursively
6. **Custom validators** for domain-specific rules
7. **Handle MethodArgumentNotValidException** for user-friendly errors

---

*Next: [AOP Annotations](./20-aop.md)*
