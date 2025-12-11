# @SpringBootApplication - The Entry Point

## The One Annotation That Starts Everything

---

## What Is It?

`@SpringBootApplication` is a **meta-annotation** that combines three annotations into one:

```java
@SpringBootApplication
public class MyApplication {
    public static void main(String[] args) {
        SpringApplication.run(MyApplication.class, args);
    }
}
```

## What's Inside?

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Inherited
@SpringBootConfiguration
@EnableAutoConfiguration
@ComponentScan
public @interface SpringBootApplication { ... }
```

### The Three Components

| Annotation | What It Does |
|-----------|--------------|
| `@SpringBootConfiguration` | Marks this as a configuration class (specialized `@Configuration`) |
| `@EnableAutoConfiguration` | Enables Spring Boot's auto-configuration magic |
| `@ComponentScan` | Scans for components starting from this package |

---

## Deep Dive: Each Component

### 1. @SpringBootConfiguration

```java
// This is essentially @Configuration
// But signals "this is THE main configuration"
@SpringBootConfiguration
public class MyApplication { }

// Equivalent to:
@Configuration
public class MyApplication { }
```

**Why not just use @Configuration?**
- `@SpringBootConfiguration` indicates the *primary* configuration
- Testing tools look for this annotation specifically
- There should be only ONE per application

---

### 2. @EnableAutoConfiguration

This is where the magic happens. Spring Boot:

1. Scans the classpath for libraries
2. Loads matching auto-configuration classes
3. Creates beans automatically

```java
// If you have spring-boot-starter-web on classpath:
// - DispatcherServlet is configured
// - Tomcat is embedded
// - Jackson is set up for JSON

// If you have spring-boot-starter-data-jpa:
// - EntityManagerFactory is created
// - Transaction management is enabled
```

#### Excluding Auto-Configurations

```java
@SpringBootApplication(
    exclude = { DataSourceAutoConfiguration.class }
)
public class MyApplication { }

// Or via properties:
// spring.autoconfigure.exclude=org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration
```

#### Common Exclusions

```java
// Don't want embedded database?
exclude = { DataSourceAutoConfiguration.class }

// Don't want security?
exclude = { SecurityAutoConfiguration.class }

// Don't want JPA?
exclude = { HibernateJpaAutoConfiguration.class }
```

---

### 3. @ComponentScan

Scans for `@Component`, `@Service`, `@Repository`, `@Controller` starting from the main class's package.

```
com.myapp/
├── MyApplication.java       <- @SpringBootApplication here
├── controller/
│   └── UserController.java  <- Found and registered
├── service/
│   └── UserService.java     <- Found and registered
└── repository/
    └── UserRepository.java  <- Found and registered
```

#### Customizing Component Scan

```java
@SpringBootApplication(
    scanBasePackages = { "com.myapp", "com.shared.library" }
)
public class MyApplication { }
```

#### Excluding Specific Classes

```java
@SpringBootApplication
@ComponentScan(
    excludeFilters = @ComponentScan.Filter(
        type = FilterType.ASSIGNABLE_TYPE,
        classes = LegacyService.class
    )
)
public class MyApplication { }
```

---

## Advanced Patterns

### Pattern 1: Multiple Configuration Classes

```java
@SpringBootApplication
public class MyApplication { }

@Configuration
public class SecurityConfig { }

@Configuration
public class CacheConfig { }

// All @Configuration classes are picked up by @ComponentScan
```

### Pattern 2: Conditional Main Class

```java
@SpringBootApplication
public class MyApplication {
    public static void main(String[] args) {
        SpringApplication app = new SpringApplication(MyApplication.class);

        // Customize before running
        app.setBannerMode(Banner.Mode.OFF);
        app.setAdditionalProfiles("production");

        app.run(args);
    }
}
```

### Pattern 3: Programmatic Bean Registration

```java
@SpringBootApplication
public class MyApplication {
    public static void main(String[] args) {
        SpringApplication app = new SpringApplication(MyApplication.class);

        app.addInitializers(context -> {
            context.getBeanFactory().registerSingleton(
                "customBean",
                new CustomService()
            );
        });

        app.run(args);
    }
}
```

---

## Common Mistakes

### Mistake 1: Placing Main Class in Wrong Package

```
# BAD - Main class too deep
com.myapp.config.MyApplication.java
com.myapp.service.UserService.java  <- NOT scanned!

# GOOD - Main class at root
com.myapp.MyApplication.java
com.myapp.config.AppConfig.java     <- Scanned
com.myapp.service.UserService.java  <- Scanned
```

### Mistake 2: Multiple @SpringBootApplication

```java
// BAD - Confusing and problematic
@SpringBootApplication
public class AppOne { }

@SpringBootApplication
public class AppTwo { }

// GOOD - One entry point
@SpringBootApplication
public class MyApplication { }
```

### Mistake 3: Not Understanding Auto-Configuration

```java
// You add a DataSource bean
@Bean
public DataSource dataSource() {
    return new HikariDataSource();
}

// Spring Boot's DataSourceAutoConfiguration sees your bean
// and backs off (doesn't create its own)
// This is INTENTIONAL and GOOD
```

---

## Debugging Auto-Configuration

### See What's Being Auto-Configured

```properties
# In application.properties
debug=true
```

This prints:
```
============================
CONDITIONS EVALUATION REPORT
============================

Positive matches:
-----------------
DataSourceAutoConfiguration matched:
  - @ConditionalOnClass found required classes 'javax.sql.DataSource'

Negative matches:
-----------------
MongoAutoConfiguration:
  - @ConditionalOnClass did not find required class 'com.mongodb.client.MongoClient'
```

### List All Auto-Configuration Classes

```java
@SpringBootApplication
public class MyApplication implements CommandLineRunner {

    @Autowired
    private ApplicationContext context;

    @Override
    public void run(String... args) {
        String[] autoConfigs = context.getBeanNamesForAnnotation(
            EnableAutoConfiguration.class
        );
        Arrays.stream(autoConfigs).forEach(System.out::println);
    }
}
```

---

## Key Takeaways

1. **@SpringBootApplication = @Configuration + @EnableAutoConfiguration + @ComponentScan**
2. **Place it at the root package** of your application
3. **Use `exclude`** to disable unwanted auto-configurations
4. **Use `scanBasePackages`** if you need to scan external packages
5. **Enable debug mode** to understand what's being auto-configured

---

## Quick Reference

```java
// Basic
@SpringBootApplication
public class App { }

// With exclusions
@SpringBootApplication(exclude = { SecurityAutoConfiguration.class })
public class App { }

// With custom scan
@SpringBootApplication(scanBasePackages = { "com.main", "com.shared" })
public class App { }

// Everything custom
@SpringBootApplication(
    exclude = { DataSourceAutoConfiguration.class },
    scanBasePackages = { "com.myapp" },
    scanBasePackageClasses = { SharedConfig.class }
)
public class App { }
```

---

*Next: [@Component Family - The Building Blocks](./02-component-family.md)*
