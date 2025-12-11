# Configuration Basics

## Defining Beans and Application Setup

---

## Overview

| Annotation | Purpose |
|------------|---------|
| `@Configuration` | Marks class as source of bean definitions |
| `@Bean` | Declares a method as a bean factory |
| `@Import` | Import other configuration classes |
| `@ImportResource` | Import XML configuration |
| `@PropertySource` | Load properties files |

---

## @Configuration - Bean Definition Source

### Basic Usage

```java
@Configuration
public class AppConfig {

    @Bean
    public UserService userService() {
        return new UserServiceImpl();
    }

    @Bean
    public EmailService emailService() {
        return new EmailServiceImpl();
    }
}
```

### Why Use @Configuration?

```java
@Configuration  // Full mode - CGLIB proxying
public class AppConfig {

    @Bean
    public ServiceA serviceA() {
        // Calls serviceB() - returns SAME instance (singleton)
        return new ServiceA(serviceB());
    }

    @Bean
    public ServiceB serviceB() {
        return new ServiceB();
    }

    @Bean
    public ServiceC serviceC() {
        // Also gets the SAME serviceB instance
        return new ServiceC(serviceB());
    }
}
```

Without `@Configuration` (lite mode):
```java
@Component  // Lite mode - no proxying
public class AppConfig {

    @Bean
    public ServiceA serviceA() {
        // Creates NEW ServiceB instance (not singleton!)
        return new ServiceA(serviceB());
    }

    @Bean
    public ServiceB serviceB() {
        return new ServiceB();
    }
}
```

### proxyBeanMethods

```java
// Explicitly disable proxying (lite mode)
@Configuration(proxyBeanMethods = false)
public class LiteConfig {

    @Bean
    public RestTemplate restTemplate() {
        // No inter-bean references, so lite mode is fine
        return new RestTemplate();
    }
}
```

Use `proxyBeanMethods = false` when:
- Beans don't call other @Bean methods
- You want faster startup
- You don't need singleton guarantees between @Bean methods

---

## @Bean - Bean Factory Methods

### Basic Usage

```java
@Configuration
public class AppConfig {

    @Bean
    public ObjectMapper objectMapper() {
        return new ObjectMapper()
            .registerModule(new JavaTimeModule())
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
    }
}
```

### Custom Bean Name

```java
@Bean("customMapper")
public ObjectMapper objectMapper() {
    return new ObjectMapper();
}

// Multiple names (aliases)
@Bean({ "mapper", "jsonMapper", "objectMapper" })
public ObjectMapper objectMapper() {
    return new ObjectMapper();
}
```

### Init and Destroy Methods

```java
@Bean(initMethod = "init", destroyMethod = "cleanup")
public ConnectionPool connectionPool() {
    return new ConnectionPool();
}

public class ConnectionPool {
    public void init() {
        // Called after bean creation
    }

    public void cleanup() {
        // Called before bean destruction
    }
}
```

### Destroy Method Inference

```java
// Spring auto-detects close() and shutdown() methods
@Bean
public DataSource dataSource() {
    HikariDataSource ds = new HikariDataSource();
    // close() will be called automatically on shutdown
    return ds;
}

// Disable auto-detection
@Bean(destroyMethod = "")
public ExternalResource externalResource() {
    return new ExternalResource();
}
```

### Dependencies Between Beans

```java
@Configuration
public class AppConfig {

    @Bean
    public UserRepository userRepository(DataSource dataSource) {
        // DataSource is injected automatically
        return new JdbcUserRepository(dataSource);
    }

    @Bean
    public UserService userService(UserRepository userRepository,
                                   EmailService emailService) {
        return new UserServiceImpl(userRepository, emailService);
    }
}
```

### Conditional Beans

```java
@Configuration
public class StorageConfig {

    @Bean
    @ConditionalOnProperty(name = "storage.type", havingValue = "s3")
    public StorageService s3Storage() {
        return new S3StorageService();
    }

    @Bean
    @ConditionalOnProperty(name = "storage.type", havingValue = "local")
    public StorageService localStorage() {
        return new LocalStorageService();
    }
}
```

---

## @Import - Combining Configurations

### Import Configuration Classes

```java
@Configuration
@Import({ SecurityConfig.class, CacheConfig.class, SchedulingConfig.class })
public class AppConfig {
    // Beans from imported configs are available
}
```

### Import Regular Classes

```java
// Regular class (not @Configuration)
public class UtilityBeans {
    @Bean
    public Clock clock() {
        return Clock.systemUTC();
    }
}

@Configuration
@Import(UtilityBeans.class)
public class AppConfig { }
```

### ImportSelector

```java
public class FeatureImportSelector implements ImportSelector {

    @Override
    public String[] selectImports(AnnotationMetadata metadata) {
        // Dynamically decide what to import
        List<String> imports = new ArrayList<>();

        if (isFeatureEnabled("cache")) {
            imports.add(CacheConfig.class.getName());
        }
        if (isFeatureEnabled("metrics")) {
            imports.add(MetricsConfig.class.getName());
        }

        return imports.toArray(new String[0]);
    }
}

@Configuration
@Import(FeatureImportSelector.class)
public class AppConfig { }
```

### DeferredImportSelector

```java
// Imported AFTER all other configurations
public class AutoConfigImportSelector implements DeferredImportSelector {

    @Override
    public String[] selectImports(AnnotationMetadata metadata) {
        // Load from META-INF/spring.factories or similar
        return loadAutoConfigurations();
    }
}
```

---

## @ImportResource - XML Configuration

### Import XML Files

```java
@Configuration
@ImportResource("classpath:legacy-beans.xml")
public class AppConfig { }

// Multiple files
@Configuration
@ImportResource({
    "classpath:legacy-beans.xml",
    "classpath:integration-beans.xml"
})
public class AppConfig { }
```

### Pattern Matching

```java
@ImportResource("classpath*:com/myapp/**/beans.xml")
public class AppConfig { }
```

---

## @PropertySource - Load Properties

### Basic Usage

```java
@Configuration
@PropertySource("classpath:custom.properties")
public class AppConfig {

    @Value("${custom.property}")
    private String customProperty;
}
```

### Multiple Sources

```java
@Configuration
@PropertySources({
    @PropertySource("classpath:default.properties"),
    @PropertySource("classpath:override.properties")  // Later overrides earlier
})
public class AppConfig { }
```

### Optional Properties

```java
@Configuration
@PropertySource(
    value = "classpath:optional.properties",
    ignoreResourceNotFound = true
)
public class AppConfig { }
```

### YAML Support (Spring Boot)

```java
// For YAML files, use Spring Boot's mechanism
// application.yml is loaded automatically

// Or use PropertySourceFactory
@Configuration
@PropertySource(
    value = "classpath:custom.yml",
    factory = YamlPropertySourceFactory.class
)
public class AppConfig { }

public class YamlPropertySourceFactory implements PropertySourceFactory {
    @Override
    public PropertySource<?> createPropertySource(String name, EncodedResource resource) {
        YamlPropertiesFactoryBean factory = new YamlPropertiesFactoryBean();
        factory.setResources(resource.getResource());
        Properties properties = factory.getObject();
        return new PropertiesPropertySource(
            resource.getResource().getFilename(),
            properties
        );
    }
}
```

---

## Configuration Patterns

### Modular Configuration

```java
// Database configuration
@Configuration
public class DatabaseConfig {

    @Bean
    public DataSource dataSource() { ... }

    @Bean
    public TransactionManager transactionManager() { ... }
}

// Security configuration
@Configuration
public class SecurityConfig {

    @Bean
    public PasswordEncoder passwordEncoder() { ... }

    @Bean
    public AuthenticationManager authManager() { ... }
}

// Web configuration
@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry registry) { ... }
}

// Main configuration imports all
@Configuration
@Import({ DatabaseConfig.class, SecurityConfig.class, WebConfig.class })
public class AppConfig { }
```

### Environment-Specific Beans

```java
@Configuration
public class DataSourceConfig {

    @Bean
    @Profile("development")
    public DataSource devDataSource() {
        return new EmbeddedDatabaseBuilder()
            .setType(EmbeddedDatabaseType.H2)
            .build();
    }

    @Bean
    @Profile("production")
    public DataSource prodDataSource() {
        HikariDataSource ds = new HikariDataSource();
        ds.setJdbcUrl(jdbcUrl);
        ds.setUsername(username);
        ds.setPassword(password);
        return ds;
    }
}
```

### Configuration with Interfaces

```java
public interface StorageConfiguration {
    StorageService storageService();
}

@Configuration
@Profile("cloud")
public class S3StorageConfig implements StorageConfiguration {
    @Bean
    @Override
    public StorageService storageService() {
        return new S3StorageService();
    }
}

@Configuration
@Profile("local")
public class LocalStorageConfig implements StorageConfiguration {
    @Bean
    @Override
    public StorageService storageService() {
        return new LocalStorageService();
    }
}
```

---

## Best Practices

### 1. Keep Configurations Focused

```java
// Good - focused responsibility
@Configuration
public class JpaConfig {
    // Only JPA-related beans
}

@Configuration
public class CacheConfig {
    // Only cache-related beans
}

// Bad - mixed concerns
@Configuration
public class AllConfig {
    // Database, cache, security, web... everything
}
```

### 2. Use Constructor Injection in @Bean Methods

```java
@Configuration
public class AppConfig {

    // Dependencies injected as parameters
    @Bean
    public UserService userService(UserRepository repo, EmailService email) {
        return new UserServiceImpl(repo, email);
    }
}
```

### 3. Document Bean Purpose

```java
@Configuration
public class AppConfig {

    /**
     * Configured ObjectMapper for JSON serialization.
     * - Java 8 date/time support
     * - ISO date format (not timestamps)
     * - Pretty printing in dev
     */
    @Bean
    public ObjectMapper objectMapper() {
        return new ObjectMapper()
            .registerModule(new JavaTimeModule())
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
    }
}
```

---

## Key Takeaways

1. **@Configuration enables CGLIB proxying** for singleton guarantees
2. **@Bean methods are bean factories** - Spring calls them once
3. **Use `proxyBeanMethods = false`** for faster startup when safe
4. **@Import combines configurations** modularly
5. **@PropertySource loads custom** properties files
6. **Keep configurations focused** on single responsibilities

---

*Next: [Properties & Profiles](./09-properties-profiles.md)*
