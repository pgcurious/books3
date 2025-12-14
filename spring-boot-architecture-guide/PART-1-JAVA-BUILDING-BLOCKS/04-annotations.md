# Chapter 4: Annotations—Metadata That Matters

> *"Metadata is data about data."*
> — Every CS textbook ever

---

## The Problem: Code That Describes Itself

Imagine you're building a web framework. Users write controller classes with methods that should handle HTTP requests. How do you know which method handles which URL?

**Option 1: Configuration files**
```xml
<route path="/users" method="GET" class="UserController" handler="getUsers"/>
<route path="/users" method="POST" class="UserController" handler="createUser"/>
```
Works, but you're duplicating information that's already in the code. Change a method name? Update two places.

**Option 2: Naming conventions**
```java
public class UserController {
    public void get_users() { ... }     // GET /users
    public void post_users() { ... }    // POST /users
}
```
Clever, but restrictive. What if you want `/users/{id}`? Conventions break down.

**Option 3: Annotations**
```java
public class UserController {
    @GetMapping("/users")
    public List<User> getUsers() { ... }

    @PostMapping("/users")
    public User createUser(@RequestBody User user) { ... }
}
```

The code describes itself. The metadata lives with the code it describes. This is the power of annotations.

---

## What Annotations Actually Are

An annotation is **structured metadata** attached to a code element. Think of it as a label with properties.

```java
@Override                           // Marker annotation (no properties)
@SuppressWarnings("unchecked")      // Single-value annotation
@RequestMapping(                    // Multi-value annotation
    path = "/users",
    method = RequestMethod.GET,
    produces = "application/json"
)
```

Critically, annotations are **not code**. They don't execute. They're just metadata that *something else* reads.

That "something else" might be:
- The Java compiler (for `@Override`, `@Deprecated`)
- An annotation processor (for code generation)
- A framework at runtime (for Spring, JPA, etc.)

---

## Defining Your Own Annotations

Annotations are defined with `@interface`:

```java
// A simple marker annotation
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
public @interface Service {
}

// An annotation with properties
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.METHOD)
public @interface GetMapping {
    String value() default "";     // shorthand: @GetMapping("/path")
    String path() default "";      // explicit: @GetMapping(path="/path")
    String[] produces() default {};
}
```

### Key Meta-Annotations

Every annotation needs meta-annotations that describe *how* it works:

#### `@Retention` — When is the annotation available?

```java
@Retention(RetentionPolicy.SOURCE)   // Discarded by compiler
@Retention(RetentionPolicy.CLASS)    // In .class file, not at runtime
@Retention(RetentionPolicy.RUNTIME)  // Available via reflection
```

**For frameworks, `RUNTIME` is essential.** If an annotation isn't retained at runtime, reflection can't see it.

#### `@Target` — Where can it be applied?

```java
@Target(ElementType.TYPE)           // Classes, interfaces, enums
@Target(ElementType.FIELD)          // Fields
@Target(ElementType.METHOD)         // Methods
@Target(ElementType.PARAMETER)      // Method parameters
@Target(ElementType.CONSTRUCTOR)    // Constructors
@Target(ElementType.ANNOTATION_TYPE) // Other annotations (meta)
@Target({ElementType.TYPE, ElementType.METHOD}) // Multiple targets
```

---

## How Frameworks Process Annotations

Let's trace how a framework uses annotations, step by step.

### Step 1: Scan for Annotated Classes

```java
// Framework needs to find all @Service classes
public List<Class<?>> findServiceClasses(String basePackage) {
    List<Class<?>> services = new ArrayList<>();

    // Scan all classes in package (we'll cover this in ClassLoaders chapter)
    for (Class<?> clazz : scanPackage(basePackage)) {
        if (clazz.isAnnotationPresent(Service.class)) {
            services.add(clazz);
        }
    }

    return services;
}
```

### Step 2: Read Annotation Values

```java
@Service("userService")
public class UserService { ... }

// Read the name
Class<?> clazz = UserService.class;
Service annotation = clazz.getAnnotation(Service.class);
String name = annotation.value();  // "userService"
```

### Step 3: Act on the Metadata

```java
// Framework creates and registers the bean
Object instance = clazz.getDeclaredConstructor().newInstance();
container.registerBean(name, instance);
```

### Step 4: Process Method Annotations

```java
@GetMapping("/users/{id}")
public User getUser(@PathVariable Long id) { ... }

// Framework reads method annotation
Method method = controller.getClass().getDeclaredMethod("getUser", Long.class);
GetMapping mapping = method.getAnnotation(GetMapping.class);
String pathPattern = mapping.value();  // "/users/{id}"

// Framework reads parameter annotations
Parameter[] params = method.getParameters();
Annotation[][] annotations = method.getParameterAnnotations();

for (int i = 0; i < params.length; i++) {
    for (Annotation ann : annotations[i]) {
        if (ann instanceof PathVariable) {
            // This parameter should be extracted from URL path
        }
    }
}
```

---

## The Annotation Inheritance Question

By default, annotations are **not inherited**:

```java
@Service
public class BaseService { }

public class UserService extends BaseService { }

UserService.class.isAnnotationPresent(Service.class);  // false!
```

To enable inheritance, use `@Inherited`:

```java
@Inherited
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
public @interface Service { }

// Now:
UserService.class.isAnnotationPresent(Service.class);  // true
```

Note: `@Inherited` only works for class annotations, not method annotations.

---

## Composed Annotations (Meta-Annotations)

Annotations can be composed by putting annotations on annotations:

```java
// Spring's @RestController is composed:
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Controller                        // <-- Has @Controller
@ResponseBody                      // <-- And @ResponseBody
public @interface RestController {
}

// So these are equivalent:
@Controller
@ResponseBody
public class MyController { ... }

@RestController
public class MyController { ... }
```

Frameworks check for annotations recursively:

```java
boolean hasControllerAnnotation(Class<?> clazz) {
    // Direct check
    if (clazz.isAnnotationPresent(Controller.class)) return true;

    // Check annotations on annotations (meta-annotations)
    for (Annotation ann : clazz.getAnnotations()) {
        Class<? extends Annotation> annType = ann.annotationType();
        if (annType.isAnnotationPresent(Controller.class)) {
            return true;  // Found @Controller as meta-annotation
        }
    }
    return false;
}
```

This is how `@RestController`, `@SpringBootApplication`, and other composed annotations work.

---

## Annotation Attributes Deep Dive

Annotation attributes have specific rules:

### Allowed Types
- Primitives (`int`, `boolean`, etc.)
- `String`
- `Class<?>`
- Enums
- Other annotations
- Arrays of any of the above

### NOT Allowed
- Objects (no `Object`, `List`, `Map`, etc.)
- `null` values

### Default Values

```java
public @interface RequestMapping {
    String path() default "";           // Empty string default
    RequestMethod method() default RequestMethod.GET;  // Enum default
    String[] produces() default {};     // Empty array default
}
```

### `value()` Shorthand

If an annotation has a single attribute named `value`, you can omit the name:

```java
public @interface Service {
    String value() default "";
}

// These are equivalent:
@Service(value = "userService")
@Service("userService")
```

---

## Real Framework Example: Building @Transactional

Let's see how a real annotation like `@Transactional` might work:

### 1. Define the Annotation

```java
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.METHOD, ElementType.TYPE})
public @interface Transactional {
    boolean readOnly() default false;
    Isolation isolation() default Isolation.DEFAULT;
    Propagation propagation() default Propagation.REQUIRED;
    Class<? extends Throwable>[] rollbackFor() default {};
}
```

### 2. Create a Proxy Handler

```java
public class TransactionHandler implements InvocationHandler {
    private final Object target;
    private final TransactionManager txManager;

    public TransactionHandler(Object target, TransactionManager txManager) {
        this.target = target;
        this.txManager = txManager;
    }

    @Override
    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
        // Check for @Transactional
        Method targetMethod = target.getClass().getMethod(
            method.getName(), method.getParameterTypes()
        );

        Transactional tx = targetMethod.getAnnotation(Transactional.class);

        if (tx == null) {
            // No annotation, just call the method
            return method.invoke(target, args);
        }

        // Start transaction
        Transaction transaction = txManager.begin(tx.readOnly(), tx.isolation());

        try {
            Object result = method.invoke(target, args);
            transaction.commit();
            return result;
        } catch (Throwable t) {
            // Check if we should rollback for this exception
            if (shouldRollback(tx, t)) {
                transaction.rollback();
            } else {
                transaction.commit();
            }
            throw t;
        }
    }

    private boolean shouldRollback(Transactional tx, Throwable t) {
        // By default, rollback for RuntimeException
        if (t instanceof RuntimeException) return true;

        // Check explicit rollbackFor
        for (Class<? extends Throwable> rollbackType : tx.rollbackFor()) {
            if (rollbackType.isInstance(t)) return true;
        }
        return false;
    }
}
```

### 3. Create Proxies for Annotated Beans

```java
public Object wrapIfNeeded(Object bean) {
    Class<?> clazz = bean.getClass();

    // Check if class or any method has @Transactional
    boolean needsProxy = clazz.isAnnotationPresent(Transactional.class);
    if (!needsProxy) {
        for (Method method : clazz.getDeclaredMethods()) {
            if (method.isAnnotationPresent(Transactional.class)) {
                needsProxy = true;
                break;
            }
        }
    }

    if (needsProxy) {
        return Proxy.newProxyInstance(
            clazz.getClassLoader(),
            clazz.getInterfaces(),
            new TransactionHandler(bean, transactionManager)
        );
    }

    return bean;
}
```

This is roughly how Spring's `@Transactional` works. The annotation itself does nothing—it's the framework's proxy mechanism that reads the annotation and adds behavior.

---

## Compile-Time vs. Runtime Annotation Processing

We've focused on runtime processing (reflection), but annotations can also be processed at compile time:

### Compile-Time Processing

```java
@Retention(RetentionPolicy.SOURCE)  // Doesn't need to exist at runtime
public @interface Getter {
}
```

Tools like Lombok use compile-time annotation processors to generate code:

```java
@Getter
public class User {
    private String name;
}

// Lombok generates (at compile time):
public String getName() {
    return this.name;
}
```

This is done via the `javax.annotation.processing` API, not reflection.

### When to Use Which

| Processing Time | Use Case | Example |
|-----------------|----------|---------|
| Compile-time | Code generation | Lombok, MapStruct |
| Runtime | Framework behavior | Spring, JPA, Jackson |

---

## The Deeper Truth

Annotations are a form of **declarative programming** within Java.

Instead of writing *how* to do something:
```java
// Imperative: HOW to validate
if (user.getName() == null || user.getName().isEmpty()) {
    throw new ValidationException("Name is required");
}
if (user.getEmail() == null || !user.getEmail().contains("@")) {
    throw new ValidationException("Valid email is required");
}
```

You declare *what* you want:
```java
// Declarative: WHAT is required
public class User {
    @NotBlank
    private String name;

    @Email
    private String email;
}
```

The framework handles the *how*. This separation is powerful because:
- Intent is clearer
- Implementation can change without changing declarations
- Framework can optimize or enhance behavior
- Behavior is consistent across the codebase

Annotations are the mechanism that makes declarative programming possible in Java. They're the bridge between your intent and the framework's implementation.

---

## Key Takeaways

1. **Annotations are structured metadata**, not code
2. **`@Retention(RUNTIME)`** is required for framework processing
3. **`@Target`** controls where annotations can be applied
4. **Frameworks scan for annotations** using reflection
5. **Composed annotations** enable clean, expressive APIs
6. **Annotations enable declarative programming** in Java

---

*Next: [Chapter 5: ClassLoaders—The Hidden Engine](./05-classloaders.md)*
