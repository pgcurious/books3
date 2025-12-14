# Chapter 12: Component Scanning—Finding Beans

> *"Naming things is one of the two hard problems in computer science."*
> — Phil Karlton

---

## The Problem: How Does Spring Find Your Beans?

When you write:

```java
@Service
public class UserService { ... }
```

How does Spring know this class exists? You didn't explicitly tell it. There's no configuration file listing all your classes.

Yet somehow, Spring finds it, creates a `BeanDefinition`, and manages it.

This is **component scanning**.

---

## The @ComponentScan Annotation

Component scanning starts with `@ComponentScan`:

```java
@Configuration
@ComponentScan("com.example")
public class AppConfig { }
```

Or, more commonly with Spring Boot:

```java
@SpringBootApplication  // Includes @ComponentScan
public class MyApplication { }
```

`@SpringBootApplication` includes `@ComponentScan` with the default base package being the package of the annotated class.

---

## What Gets Scanned

By default, these annotations trigger registration:

| Annotation | Purpose |
|------------|---------|
| `@Component` | Generic managed component |
| `@Service` | Service layer component |
| `@Repository` | Data access component |
| `@Controller` | Web controller |
| `@RestController` | REST web controller |
| `@Configuration` | Configuration class |

All of these are variants of `@Component`:

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Component  // <-- Service IS a Component
public @interface Service {
    String value() default "";
}
```

---

## How Scanning Works Internally

Let's trace the scanning process:

### Step 1: Find the Base Packages

```java
@ComponentScan(basePackages = {"com.example.service", "com.example.repository"})
```

Or:

```java
@ComponentScan(basePackageClasses = {ServiceMarker.class, RepositoryMarker.class})
// Uses the packages of these classes
```

### Step 2: Scan for Candidate Classes

Spring uses `ClassPathScanningCandidateComponentProvider`:

```java
// Simplified version of what Spring does
public Set<BeanDefinition> findCandidates(String basePackage) {
    Set<BeanDefinition> candidates = new LinkedHashSet<>();

    // Convert package to path: com.example -> com/example
    String path = basePackage.replace('.', '/');

    // Find all .class files in this path
    Resource[] resources = resourceResolver.getResources(
        "classpath*:" + path + "/**/*.class"
    );

    for (Resource resource : resources) {
        // Read class metadata WITHOUT loading the class
        MetadataReader reader = metadataReaderFactory.getMetadataReader(resource);

        // Check if it's a candidate (has @Component or derived annotation)
        if (isCandidateComponent(reader)) {
            BeanDefinition definition = new ScannedGenericBeanDefinition(reader);
            candidates.add(definition);
        }
    }

    return candidates;
}
```

### Step 3: Use ASM to Read Metadata

Here's the clever part: Spring doesn't load classes to scan them. It uses **ASM** to read bytecode directly:

```java
// Spring reads .class file metadata WITHOUT Class.forName()
MetadataReader reader = new SimpleMetadataReader(resource, classLoader);

// Check annotations without loading the class
AnnotationMetadata metadata = reader.getAnnotationMetadata();
boolean isComponent = metadata.hasAnnotation(Component.class.getName());
```

Why not just load the classes?

1. **Performance**: Loading thousands of classes is slow
2. **Side effects**: Static initializers would run
3. **Dependencies**: Classes might have unavailable dependencies

### Step 4: Create Bean Definitions

```java
for (BeanDefinition candidate : candidates) {
    // Generate bean name: UserService -> userService
    String beanName = beanNameGenerator.generateBeanName(candidate, registry);

    // Apply defaults
    if (candidate instanceof AnnotatedBeanDefinition) {
        AnnotationConfigUtils.processCommonDefinitionAnnotations(candidate);
    }

    // Register with the BeanFactory
    registry.registerBeanDefinition(beanName, candidate);
}
```

---

## Filtering What Gets Scanned

You can include or exclude classes:

### Include Filters

```java
@ComponentScan(
    basePackages = "com.example",
    includeFilters = @Filter(type = FilterType.ANNOTATION, classes = MyCustomAnnotation.class)
)
```

### Exclude Filters

```java
@ComponentScan(
    basePackages = "com.example",
    excludeFilters = {
        @Filter(type = FilterType.ANNOTATION, classes = Controller.class),
        @Filter(type = FilterType.REGEX, pattern = ".*Test.*")
    }
)
```

### Filter Types

| FilterType | Matches |
|------------|---------|
| `ANNOTATION` | Classes with specific annotation |
| `ASSIGNABLE_TYPE` | Classes assignable to specific type |
| `ASPECTJ` | AspectJ type pattern |
| `REGEX` | Regex on class name |
| `CUSTOM` | Custom TypeFilter implementation |

---

## Bean Naming

How does `UserService` become `userService`?

### Default Naming

```java
// Default: decapitalize simple class name
public class AnnotationBeanNameGenerator {
    protected String buildDefaultBeanName(BeanDefinition definition) {
        String shortClassName = ClassUtils.getShortName(definition.getBeanClassName());
        return Introspector.decapitalize(shortClassName);
    }
}

// Examples:
// UserService -> userService
// HTMLParser -> HTMLParser (acronym preserved)
// URLValidator -> URLValidator
```

### Explicit Naming

```java
@Service("myUserService")
public class UserService { }

// Bean name: myUserService
```

### Custom Naming Strategy

```java
@ComponentScan(
    basePackages = "com.example",
    nameGenerator = MyBeanNameGenerator.class
)
```

---

## Multiple @ComponentScans

You can scan multiple packages differently:

```java
@Configuration
@ComponentScans({
    @ComponentScan(
        basePackages = "com.example.api",
        includeFilters = @Filter(RestController.class)
    ),
    @ComponentScan(
        basePackages = "com.example.internal",
        excludeFilters = @Filter(RestController.class)
    )
})
public class AppConfig { }
```

---

## Lazy Component Scanning

By default, all candidates are found at startup. With Spring Boot 2.2+:

```properties
spring.main.lazy-initialization=true
```

Beans are still scanned and registered, but not instantiated until needed.

---

## Index-Based Scanning

For large applications, classpath scanning can be slow. Spring 5 introduced **component index**:

### Generate Index at Build Time

Add dependency:
```xml
<dependency>
    <groupId>org.springframework</groupId>
    <artifactId>spring-context-indexer</artifactId>
    <optional>true</optional>
</dependency>
```

At compile time, this generates `META-INF/spring.components`:
```
com.example.service.UserService=org.springframework.stereotype.Component
com.example.service.OrderService=org.springframework.stereotype.Component
```

### Use Index at Runtime

Spring automatically uses the index if present:
```java
// Instead of scanning all .class files...
// Spring reads the pre-computed index
```

**30-40% faster startup** for large applications.

---

## How @Configuration Classes Are Found

`@Configuration` classes get special treatment:

```java
@Configuration
public class DatabaseConfig {
    @Bean
    public DataSource dataSource() { ... }
}
```

1. **Scanned like @Component** (because @Configuration has @Component)
2. **Enhanced via CGLIB** (to handle @Bean method calls)
3. **@Bean methods processed** by `ConfigurationClassPostProcessor`

```java
// Spring creates a CGLIB proxy:
public class DatabaseConfig$$EnhancerBySpringCGLIB extends DatabaseConfig {
    @Override
    public DataSource dataSource() {
        // Check if bean already exists
        if (beanExists("dataSource")) {
            return getBean("dataSource");
        }
        // Otherwise, call super and cache
        return super.dataSource();
    }
}
```

This is why calling `@Bean` methods directly returns the singleton.

---

## Debugging Component Scanning

### See What's Being Scanned

```properties
logging.level.org.springframework.context.annotation=DEBUG
```

Output:
```
Identified candidate component class: file [.../UserService.class]
Identified candidate component class: file [.../OrderService.class]
```

### List All Beans

```java
@EventListener(ContextRefreshedEvent.class)
public void listBeans(ContextRefreshedEvent event) {
    String[] beans = event.getApplicationContext().getBeanDefinitionNames();
    Arrays.stream(beans).sorted().forEach(System.out::println);
}
```

### Check Why a Bean Wasn't Found

Common reasons:
1. **Wrong package**: Class not in scanned package
2. **Missing annotation**: No `@Component` or derivative
3. **Excluded by filter**: Matches an exclude filter
4. **Abstract class**: Can't instantiate abstract classes
5. **Inner class**: Non-static inner classes can't be components

---

## Best Practices

### 1. Narrow Your Base Packages

```java
// BAD: scans everything
@ComponentScan("com")

// GOOD: specific packages
@ComponentScan("com.example.myapp")
```

### 2. Use Package Structure

```
com.example.myapp
├── MyApplication.java  // @SpringBootApplication here
├── controller/
├── service/
├── repository/
└── config/
```

With `@SpringBootApplication` in the root package, all sub-packages are scanned automatically.

### 3. Consider Component Indexes for Large Apps

If startup time matters and you have 1000+ components, use Spring's component indexer.

### 4. Be Explicit When Needed

If behavior is unclear, be explicit:

```java
@Configuration
@ComponentScan(
    basePackages = "com.example",
    useDefaultFilters = false,  // Disable default @Component scanning
    includeFilters = @Filter(Service.class)  // Only scan @Service
)
```

---

## Key Takeaways

1. **@ComponentScan tells Spring where to look** for components
2. **ASM reads bytecode** without loading classes—fast and safe
3. **Filters control** what gets included/excluded
4. **Bean names are auto-generated** but can be customized
5. **@Configuration classes are CGLIB-enhanced** for singleton @Bean methods
6. **Component indexes** accelerate startup for large applications
7. **Debug logging** reveals scanning behavior

---

*Next: [Chapter 13: AOP—Cross-Cutting Concerns](./13-aop.md)*
