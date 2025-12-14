# Chapter 3: Reflection—Looking in the Mirror

> *"In computer science, reflection is the ability of a program to examine and modify its own structure and behavior at runtime."*
> — Wikipedia

---

## The Problem: Code That Doesn't Know Itself

Consider this challenge: you want to write code that works with objects it has never seen before.

Not objects of type `User` or `Order`—those you can write at compile time. But *any* object. Objects from classes that don't exist yet. Objects from classes in libraries you'll never import.

How would you:
- Find all the fields of an unknown object?
- Call a method when you only know its name as a string?
- Create an instance of a class without using `new`?

These operations seem impossible. At compile time, you must know what type you're working with. The compiler enforces it.

And yet, frameworks do exactly this—all the time.

---

## The Answer: Reflection

Java's **Reflection API** provides the ability to inspect and manipulate code at runtime. It's like giving your program a mirror to look at itself.

With reflection, you can:
- Examine class structure (fields, methods, constructors)
- Create objects without knowing the class at compile time
- Call methods by name
- Access private members
- Read annotation metadata

This is the foundational mechanism that enables frameworks.

---

## The `Class` Object: Everything's Blueprint

Every class in Java has a corresponding `Class` object that describes it. This is your entry point to reflection.

### Getting a Class Object

```java
// Three ways to get a Class object

// 1. From an instance
User user = new User();
Class<?> clazz1 = user.getClass();

// 2. From the class literal
Class<?> clazz2 = User.class;

// 3. From the fully qualified name (most powerful)
Class<?> clazz3 = Class.forName("com.example.User");
```

The third approach—`Class.forName()`—is the most interesting. You can load a class using just a string. The class doesn't need to exist at compile time. This is how frameworks load classes they've never seen.

---

## Examining Class Structure

Once you have a `Class` object, you can examine everything about it:

### Getting Fields

```java
public class User {
    private Long id;
    private String name;
    public String email;
}

// Examine the fields
Class<?> clazz = User.class;

// Get all PUBLIC fields (including inherited)
Field[] publicFields = clazz.getFields();

// Get ALL declared fields (including private, excluding inherited)
Field[] allFields = clazz.getDeclaredFields();

for (Field field : allFields) {
    System.out.println(
        field.getName() + " : " +
        field.getType().getSimpleName() + " : " +
        Modifier.toString(field.getModifiers())
    );
}

// Output:
// id : Long : private
// name : String : private
// email : String : public
```

### Getting Methods

```java
public class UserService {
    public User findById(Long id) { ... }
    private void validate(User user) { ... }
}

Class<?> clazz = UserService.class;

// Get all methods
Method[] methods = clazz.getDeclaredMethods();

for (Method method : methods) {
    System.out.println(method.getName());

    // Get parameter types
    for (Class<?> paramType : method.getParameterTypes()) {
        System.out.println("  param: " + paramType.getSimpleName());
    }

    // Get return type
    System.out.println("  returns: " + method.getReturnType().getSimpleName());
}
```

### Getting Constructors

```java
public class User {
    public User() {}
    public User(String name) {}
    public User(String name, String email) {}
}

Class<?> clazz = User.class;
Constructor<?>[] constructors = clazz.getDeclaredConstructors();

for (Constructor<?> constructor : constructors) {
    System.out.println("Constructor with " +
        constructor.getParameterCount() + " params");
}
```

---

## Creating Objects Dynamically

Here's where it gets powerful. You can create objects without using `new`:

### Using Default Constructor

```java
Class<?> clazz = Class.forName("com.example.User");
Object instance = clazz.getDeclaredConstructor().newInstance();
// instance is now a User object!
```

### Using Parameterized Constructor

```java
Class<?> clazz = User.class;

// Find constructor that takes String, String
Constructor<?> constructor = clazz.getDeclaredConstructor(
    String.class, String.class
);

// Create instance
Object instance = constructor.newInstance("John", "john@example.com");
```

**Why this matters for frameworks:**

```java
// Framework reads a configuration file or annotation
String className = "com.example.UserService";

// Framework creates the instance without knowing the type at compile time
Object bean = Class.forName(className).getDeclaredConstructor().newInstance();

// Framework can now manage this bean
container.register(bean);
```

---

## Invoking Methods Dynamically

You can call methods when you only know the method name as a string:

```java
public class Calculator {
    public int add(int a, int b) {
        return a + b;
    }
}

// Get the method by name
Class<?> clazz = Calculator.class;
Method addMethod = clazz.getDeclaredMethod("add", int.class, int.class);

// Create an instance
Object calculator = clazz.getDeclaredConstructor().newInstance();

// Invoke the method
Object result = addMethod.invoke(calculator, 5, 3);
System.out.println(result); // 8
```

**Why this matters for frameworks:**

```java
// Framework sees @GetMapping("/users")
// It knows to call this method when GET /users arrives

@GetMapping("/users")
public List<User> getUsers() { ... }

// Framework code (simplified):
Method handler = findMethodWithAnnotation(GetMapping.class, "/users");
Object controller = container.getBean(handler.getDeclaringClass());
Object result = handler.invoke(controller);  // Call getUsers()
```

---

## Accessing Private Members

Normally, private members are inaccessible. Reflection bypasses this:

```java
public class Secret {
    private String password = "super-secret";
}

Secret secret = new Secret();
Class<?> clazz = secret.getClass();

// Get the private field
Field passwordField = clazz.getDeclaredField("password");

// Make it accessible (bypass private)
passwordField.setAccessible(true);

// Read the value
String value = (String) passwordField.get(secret);
System.out.println(value); // "super-secret"

// Write a new value
passwordField.set(secret, "new-password");
```

**Why this matters for frameworks:**

```java
@Service
public class UserService {
    @Autowired
    private UserRepository userRepository; // private field!
}

// Framework needs to inject the repository.
// Even though it's private, reflection can set it:

Field field = UserService.class.getDeclaredField("userRepository");
field.setAccessible(true);
field.set(userServiceInstance, repositoryInstance);
```

---

## Reading Annotations

Annotations are metadata, but reflection makes them accessible:

```java
@Retention(RetentionPolicy.RUNTIME)  // Important: must be RUNTIME
@Target(ElementType.TYPE)
public @interface Service {
    String value() default "";
}

@Service("userService")
public class UserService { ... }

// Read the annotation
Class<?> clazz = UserService.class;

if (clazz.isAnnotationPresent(Service.class)) {
    Service annotation = clazz.getAnnotation(Service.class);
    String name = annotation.value();
    System.out.println("Service name: " + name); // "userService"
}
```

Annotations on methods:

```java
public class UserController {
    @GetMapping("/users")
    public List<User> getUsers() { ... }
}

Method method = UserController.class.getDeclaredMethod("getUsers");
GetMapping mapping = method.getAnnotation(GetMapping.class);
String path = mapping.value()[0]; // "/users"
```

Annotations on parameters:

```java
public void search(@RequestParam("q") String query) { ... }

Method method = ...;
Parameter[] params = method.getParameters();
Annotation[][] annotations = method.getParameterAnnotations();

for (int i = 0; i < params.length; i++) {
    for (Annotation annotation : annotations[i]) {
        if (annotation instanceof RequestParam) {
            RequestParam rp = (RequestParam) annotation;
            System.out.println("Param name: " + rp.value());
        }
    }
}
```

---

## Putting It Together: A Mini Framework

Let's build a tiny dependency injection framework using reflection:

```java
// Our annotation
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.FIELD)
public @interface Inject {}

// Our simple container
public class MiniContainer {
    private Map<Class<?>, Object> beans = new HashMap<>();

    public void register(Class<?> clazz) throws Exception {
        // Create instance
        Object instance = clazz.getDeclaredConstructor().newInstance();

        // Find @Inject fields and inject dependencies
        for (Field field : clazz.getDeclaredFields()) {
            if (field.isAnnotationPresent(Inject.class)) {
                Class<?> fieldType = field.getType();

                // Get or create the dependency
                Object dependency = beans.get(fieldType);
                if (dependency == null) {
                    register(fieldType);  // Recursive!
                    dependency = beans.get(fieldType);
                }

                // Inject it
                field.setAccessible(true);
                field.set(instance, dependency);
            }
        }

        beans.put(clazz, instance);
    }

    @SuppressWarnings("unchecked")
    public <T> T getBean(Class<T> clazz) {
        return (T) beans.get(clazz);
    }
}

// Usage
public class UserRepository {
    public User findById(Long id) {
        return new User(id, "John");
    }
}

public class UserService {
    @Inject
    private UserRepository userRepository;

    public User getUser(Long id) {
        return userRepository.findById(id);
    }
}

// Bootstrap
MiniContainer container = new MiniContainer();
container.register(UserRepository.class);
container.register(UserService.class);

UserService service = container.getBean(UserService.class);
User user = service.getUser(1L);  // Works!
```

In ~30 lines, we've built basic dependency injection. Real frameworks do this with more sophistication, but the core mechanism is identical: **reflection**.

---

## The Performance Question

Reflection is slower than direct calls. How much slower?

```java
// Direct call
user.getName();  // ~1 nanosecond

// Reflection call
Method method = User.class.getMethod("getName");
method.invoke(user);  // ~100-1000 nanoseconds (first call)
                       // ~10 nanoseconds (after JIT optimization)
```

For most applications, this overhead is negligible. Framework code runs once at startup (scanning, wiring) and caches everything. Request handling rarely uses raw reflection—proxies and direct references are used instead.

---

## The Security Consideration

Reflection can bypass access modifiers. This is powerful but dangerous:

```java
// This can read ANY field, including private
field.setAccessible(true);
```

Java 9+ modules can restrict reflective access. When you see warnings like:

```
WARNING: An illegal reflective access operation has occurred
```

This is the module system protecting itself. Frameworks need to use `--add-opens` flags or update to newer APIs.

---

## The Deeper Truth

Reflection enables **metaprogramming**—programs that manipulate programs.

Without reflection, Java code can only work with types it knows at compile time. With reflection, code becomes data that can be examined and manipulated.

This is what distinguishes a library from a framework:
- A library provides functionality you call
- A framework uses reflection to call *you*

Every `@Autowired`, every `@GetMapping`, every `@Entity` works because somewhere, framework code is using reflection to find your class, read your annotation, and do something with it.

---

## Key Takeaways

1. **`Class` objects** are runtime blueprints of classes
2. **`Class.forName()`** loads classes by name—enabling dynamic discovery
3. **Field/Method/Constructor** objects let you examine and invoke any member
4. **`setAccessible(true)`** bypasses access modifiers
5. **Annotations are readable at runtime** through reflection
6. **Frameworks are built on reflection**—there's no magic, just `invoke()`

---

*Next: [Chapter 4: Annotations—Metadata That Matters](./04-annotations.md)*
