# Conditional Annotations

## Creating Beans Only When Conditions Are Met

---

## Overview

| Annotation | Condition |
|------------|-----------|
| `@ConditionalOnProperty` | Property value matches |
| `@ConditionalOnBean` | Bean exists |
| `@ConditionalOnMissingBean` | Bean doesn't exist |
| `@ConditionalOnClass` | Class on classpath |
| `@ConditionalOnMissingClass` | Class not on classpath |
| `@ConditionalOnWebApplication` | Web application context |
| `@ConditionalOnExpression` | SpEL expression is true |
| `@Conditional` | Custom condition |

---

## @ConditionalOnProperty - Property-Based

### Basic Usage

```java
@Configuration
public class FeatureConfig {

    // Created only if feature.enabled=true
    @Bean
    @ConditionalOnProperty(name = "feature.enabled", havingValue = "true")
    public FeatureService featureService() {
        return new FeatureService();
    }
}
```

### Match if Missing

```java
// Created if property is true OR missing
@Bean
@ConditionalOnProperty(
    name = "feature.enabled",
    havingValue = "true",
    matchIfMissing = true  // Default is true
)
public FeatureService featureService() {
    return new FeatureService();
}
```

### Prefix for Multiple Properties

```java
// Check: app.cache.enabled=true
@Bean
@ConditionalOnProperty(prefix = "app.cache", name = "enabled", havingValue = "true")
public CacheService cacheService() {
    return new CacheService();
}
```

### Multiple Properties

```java
// ALL properties must match
@Bean
@ConditionalOnProperty(
    name = { "feature.a.enabled", "feature.b.enabled" },
    havingValue = "true"
)
public CombinedFeature combinedFeature() {
    return new CombinedFeature();
}
```

### Different Values for Different Beans

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

    @Bean
    @ConditionalOnProperty(name = "storage.type", havingValue = "azure")
    public StorageService azureStorage() {
        return new AzureStorageService();
    }
}
```

---

## @ConditionalOnBean - Bean Presence

### Basic Usage

```java
@Configuration
public class CacheConfig {

    // Only create if DataSource exists
    @Bean
    @ConditionalOnBean(DataSource.class)
    public CacheService databaseBackedCache(DataSource dataSource) {
        return new DatabaseCacheService(dataSource);
    }
}
```

### By Bean Name

```java
@Bean
@ConditionalOnBean(name = "primaryDataSource")
public CacheService cache() {
    return new CacheService();
}
```

### By Annotation

```java
// Only if a @Repository bean exists
@Bean
@ConditionalOnBean(annotation = Repository.class)
public RepositoryMetrics repositoryMetrics() {
    return new RepositoryMetrics();
}
```

---

## @ConditionalOnMissingBean - Provide Defaults

### Basic Usage

```java
@Configuration
public class DefaultsConfig {

    // Create ONLY if no other CacheService exists
    @Bean
    @ConditionalOnMissingBean
    public CacheService defaultCacheService() {
        return new InMemoryCacheService();
    }
}
```

### Common Pattern: User Override

```java
// In your library/framework
@Configuration
public class FrameworkAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean
    public ObjectMapper objectMapper() {
        // Default configuration
        return new ObjectMapper();
    }
}

// In user's application (takes precedence)
@Configuration
public class AppConfig {

    @Bean
    public ObjectMapper objectMapper() {
        // Custom configuration - framework backs off
        return new ObjectMapper()
            .registerModule(new JavaTimeModule());
    }
}
```

### Specify Type

```java
// Only if no bean of this specific type
@Bean
@ConditionalOnMissingBean(type = "com.example.SpecialService")
public SpecialService defaultSpecialService() {
    return new DefaultSpecialService();
}
```

---

## @ConditionalOnClass - Classpath Detection

### Basic Usage

```java
@Configuration
public class JacksonConfig {

    // Only if Jackson is on classpath
    @Bean
    @ConditionalOnClass(ObjectMapper.class)
    public ObjectMapper objectMapper() {
        return new ObjectMapper();
    }
}
```

### Class Name String (Safer)

```java
// Safer when class might not be on classpath
@Bean
@ConditionalOnClass(name = "com.fasterxml.jackson.databind.ObjectMapper")
public JsonService jsonService() {
    return new JacksonJsonService();
}
```

### Multiple Classes

```java
// ALL classes must be present
@Bean
@ConditionalOnClass({
    DataSource.class,
    JdbcTemplate.class
})
public JdbcService jdbcService() {
    return new JdbcService();
}
```

---

## @ConditionalOnMissingClass - Missing Dependency

```java
@Configuration
public class FallbackConfig {

    // Use when Jackson is NOT available
    @Bean
    @ConditionalOnMissingClass("com.fasterxml.jackson.databind.ObjectMapper")
    public JsonService gsonJsonService() {
        return new GsonJsonService();
    }
}
```

---

## @ConditionalOnWebApplication - Web Context

```java
@Configuration
public class WebConfig {

    // Only in web applications
    @Bean
    @ConditionalOnWebApplication
    public SessionManager sessionManager() {
        return new SessionManager();
    }

    // Servlet web application specifically
    @Bean
    @ConditionalOnWebApplication(type = ConditionalOnWebApplication.Type.SERVLET)
    public ServletFilter servletFilter() {
        return new ServletFilter();
    }

    // Reactive web application
    @Bean
    @ConditionalOnWebApplication(type = ConditionalOnWebApplication.Type.REACTIVE)
    public WebFilter reactiveFilter() {
        return new ReactiveFilter();
    }
}

// NOT a web application
@Bean
@ConditionalOnNotWebApplication
public BatchProcessor batchProcessor() {
    return new BatchProcessor();
}
```

---

## @ConditionalOnExpression - SpEL Expressions

```java
@Configuration
public class ExpressionConfig {

    // Complex property expression
    @Bean
    @ConditionalOnExpression("${feature.enabled:true} and ${app.env} == 'production'")
    public ProductionFeature productionFeature() {
        return new ProductionFeature();
    }

    // Environment check
    @Bean
    @ConditionalOnExpression("#{'${spring.profiles.active}'.contains('prod')}")
    public ProductionService productionService() {
        return new ProductionService();
    }

    // Numerical comparison
    @Bean
    @ConditionalOnExpression("${cache.size:100} > 50")
    public LargeCache largeCache() {
        return new LargeCache();
    }
}
```

---

## @Conditional - Custom Conditions

### Define Custom Condition

```java
public class OnLinuxCondition implements Condition {

    @Override
    public boolean matches(ConditionContext context, AnnotatedTypeMetadata metadata) {
        String os = System.getProperty("os.name").toLowerCase();
        return os.contains("linux");
    }
}

// Usage
@Bean
@Conditional(OnLinuxCondition.class)
public LinuxSpecificService linuxService() {
    return new LinuxSpecificService();
}
```

### Reusable Custom Annotation

```java
@Target({ ElementType.TYPE, ElementType.METHOD })
@Retention(RetentionPolicy.RUNTIME)
@Conditional(OnLinuxCondition.class)
public @interface ConditionalOnLinux { }

// Usage
@Bean
@ConditionalOnLinux
public LinuxService linuxService() {
    return new LinuxService();
}
```

### Complex Custom Condition

```java
public class FeatureFlagCondition implements Condition {

    @Override
    public boolean matches(ConditionContext context, AnnotatedTypeMetadata metadata) {
        // Get annotation attributes
        Map<String, Object> attributes = metadata.getAnnotationAttributes(
            ConditionalOnFeatureFlag.class.getName()
        );

        String featureName = (String) attributes.get("value");

        // Check feature flag service, database, etc.
        FeatureFlagService service = getFeatureFlagService(context);
        return service.isEnabled(featureName);
    }

    private FeatureFlagService getFeatureFlagService(ConditionContext context) {
        // Get from context or create
        return context.getBeanFactory().getBean(FeatureFlagService.class);
    }
}

@Target({ ElementType.TYPE, ElementType.METHOD })
@Retention(RetentionPolicy.RUNTIME)
@Conditional(FeatureFlagCondition.class)
public @interface ConditionalOnFeatureFlag {
    String value();
}

// Usage
@Bean
@ConditionalOnFeatureFlag("new-checkout")
public NewCheckoutService newCheckout() {
    return new NewCheckoutService();
}
```

---

## Combining Conditions

### All Must Match

```java
// ALL conditions must be true
@Bean
@ConditionalOnProperty(name = "cache.enabled", havingValue = "true")
@ConditionalOnClass(RedisTemplate.class)
@ConditionalOnBean(RedisConnectionFactory.class)
public CacheService redisCacheService() {
    return new RedisCacheService();
}
```

### AllNestedConditions

```java
public class OnProductionEnvironment extends AllNestedConditions {

    public OnProductionEnvironment() {
        super(ConfigurationPhase.PARSE_CONFIGURATION);
    }

    @ConditionalOnProperty(name = "app.env", havingValue = "production")
    static class OnProductionProperty { }

    @ConditionalOnBean(DataSource.class)
    static class OnDatabaseAvailable { }
}

@Bean
@Conditional(OnProductionEnvironment.class)
public ProductionService productionService() {
    return new ProductionService();
}
```

### AnyNestedCondition

```java
public class OnDevOrTestEnvironment extends AnyNestedCondition {

    public OnDevOrTestEnvironment() {
        super(ConfigurationPhase.PARSE_CONFIGURATION);
    }

    @ConditionalOnProperty(name = "app.env", havingValue = "development")
    static class OnDevelopment { }

    @ConditionalOnProperty(name = "app.env", havingValue = "test")
    static class OnTest { }
}

@Bean
@Conditional(OnDevOrTestEnvironment.class)
public MockExternalService mockService() {
    return new MockExternalService();
}
```

---

## Order of Evaluation

Conditions are evaluated in a specific order:

1. `@ConditionalOnClass` / `@ConditionalOnMissingClass`
2. `@ConditionalOnBean` / `@ConditionalOnMissingBean`
3. `@ConditionalOnProperty`
4. `@ConditionalOnResource`
5. `@ConditionalOnWebApplication`
6. `@ConditionalOnExpression`
7. Custom `@Conditional`

---

## Debugging Conditions

### Enable Debug Output

```properties
# application.properties
debug=true
```

### Output

```
============================
CONDITIONS EVALUATION REPORT
============================

Positive matches:
-----------------
DataSourceAutoConfiguration matched:
  - @ConditionalOnClass found required class 'javax.sql.DataSource'
  - @ConditionalOnProperty (spring.datasource.type) matched

Negative matches:
-----------------
MongoAutoConfiguration:
  - @ConditionalOnClass did not find required class 'com.mongodb.client.MongoClient'
```

---

## Key Takeaways

1. **@ConditionalOnProperty** for feature flags
2. **@ConditionalOnMissingBean** for defaults that can be overridden
3. **@ConditionalOnClass** for optional dependencies
4. **Multiple conditions are AND-ed** together
5. **Use custom conditions** for complex logic
6. **Debug mode** shows why beans were/weren't created

---

*Next: [Creating Auto-Configuration](./16-auto-configuration.md)*
