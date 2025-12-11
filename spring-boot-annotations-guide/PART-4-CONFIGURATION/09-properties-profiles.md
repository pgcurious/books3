# Properties & Profiles

## Externalizing Configuration Like a Pro

---

## Overview

| Annotation | Purpose |
|------------|---------|
| `@ConfigurationProperties` | Bind properties to POJOs |
| `@EnableConfigurationProperties` | Enable configuration properties |
| `@Profile` | Activate beans for specific environments |
| `@ActiveProfiles` | Activate profiles in tests |
| `@Value` | Inject individual property values |

---

## @ConfigurationProperties - Type-Safe Configuration

### Basic Usage

```yaml
# application.yml
app:
  name: My Application
  description: A sample application
  timeout: 30
  enabled: true
  api:
    url: https://api.example.com
    key: secret-key
```

```java
@Configuration
@ConfigurationProperties(prefix = "app")
public class AppProperties {

    private String name;
    private String description;
    private int timeout;
    private boolean enabled;
    private Api api = new Api();

    // Getters and setters required!

    public static class Api {
        private String url;
        private String key;

        // Getters and setters
    }
}
```

### Enable Configuration Properties

```java
// Option 1: On the properties class
@Configuration
@ConfigurationProperties(prefix = "app")
public class AppProperties { }

// Option 2: Via @EnableConfigurationProperties
@Configuration
@EnableConfigurationProperties(AppProperties.class)
public class AppConfig { }

// Option 3: @ConfigurationPropertiesScan (Spring Boot 2.2+)
@SpringBootApplication
@ConfigurationPropertiesScan("com.myapp.config")
public class Application { }
```

### Immutable Configuration Properties (Recommended)

```java
@ConfigurationProperties(prefix = "app")
public class AppProperties {

    private final String name;
    private final String description;
    private final int timeout;
    private final Api api;

    @ConstructorBinding  // Required for constructor binding before Spring Boot 3.0
    public AppProperties(String name, String description, int timeout, Api api) {
        this.name = name;
        this.description = description;
        this.timeout = timeout;
        this.api = api;
    }

    // Only getters, no setters - immutable!

    public record Api(String url, String key) { }
}
```

### With Validation

```java
@ConfigurationProperties(prefix = "app")
@Validated
public class AppProperties {

    @NotBlank
    private String name;

    @Min(1)
    @Max(300)
    private int timeout = 30;

    @Valid
    @NotNull
    private Api api;

    public static class Api {
        @NotBlank
        @URL
        private String url;

        @NotBlank
        private String key;
    }
}
```

### Collections and Maps

```yaml
# application.yml
app:
  servers:
    - host: server1.example.com
      port: 8080
    - host: server2.example.com
      port: 8081
  endpoints:
    users: /api/users
    orders: /api/orders
  features:
    dark-mode: true
    beta-features: false
```

```java
@ConfigurationProperties(prefix = "app")
public class AppProperties {

    private List<Server> servers = new ArrayList<>();
    private Map<String, String> endpoints = new HashMap<>();
    private Map<String, Boolean> features = new HashMap<>();

    public static class Server {
        private String host;
        private int port;
        // getters, setters
    }
}
```

### Duration and DataSize

```yaml
app:
  connection-timeout: 30s
  read-timeout: 2m
  max-upload-size: 10MB
  buffer-size: 256KB
```

```java
@ConfigurationProperties(prefix = "app")
public class AppProperties {

    private Duration connectionTimeout;  // 30 seconds
    private Duration readTimeout;        // 2 minutes

    @DataSizeUnit(DataUnit.MEGABYTES)
    private DataSize maxUploadSize;      // 10 MB

    private DataSize bufferSize;         // 256 KB
}
```

---

## @Value vs @ConfigurationProperties

### @Value - Simple Properties

```java
@Service
public class ApiClient {

    @Value("${api.url}")
    private String apiUrl;

    @Value("${api.timeout:30}")
    private int timeout;
}
```

### @ConfigurationProperties - Complex Properties

```java
@ConfigurationProperties(prefix = "api")
public class ApiProperties {
    private String url;
    private int timeout;
    private Retry retry;
    private List<String> allowedOrigins;

    public static class Retry {
        private int maxAttempts;
        private Duration backoff;
    }
}
```

### When to Use Which

| Feature | @Value | @ConfigurationProperties |
|---------|--------|-------------------------|
| Simple values | Yes | Yes |
| Nested objects | No | Yes |
| Lists/Maps | Limited | Yes |
| Validation | Manual | Built-in |
| Documentation | No | IDE support |
| Type safety | No | Yes |
| Relaxed binding | No | Yes |

---

## @Profile - Environment-Specific Beans

### Basic Usage

```java
@Service
@Profile("development")
public class MockPaymentService implements PaymentService {
    // Mock implementation for dev
}

@Service
@Profile("production")
public class StripePaymentService implements PaymentService {
    // Real implementation for prod
}
```

### Multiple Profiles

```java
// Active in dev OR test
@Service
@Profile({ "development", "test" })
public class InMemoryCache implements Cache { }

// Active in production AND secure
@Service
@Profile("production & secure")
public class SecureVault implements Vault { }

// Active when NOT production
@Service
@Profile("!production")
public class DebugService { }
```

### Profile Expressions

```java
// AND operator
@Profile("cloud & aws")

// OR operator
@Profile("local | development")

// NOT operator
@Profile("!production")

// Complex expression
@Profile("(production | staging) & secure")
```

### Profile on Configuration Class

```java
@Configuration
@Profile("production")
public class ProductionConfig {

    @Bean
    public DataSource dataSource() {
        // Production database
    }

    @Bean
    public Cache cache() {
        // Distributed cache
    }
}

@Configuration
@Profile("development")
public class DevelopmentConfig {

    @Bean
    public DataSource dataSource() {
        // In-memory database
    }

    @Bean
    public Cache cache() {
        // Local cache
    }
}
```

### Activating Profiles

```properties
# application.properties
spring.profiles.active=development,debug

# Or environment variable
SPRING_PROFILES_ACTIVE=production,secure

# Or command line
java -jar app.jar --spring.profiles.active=production
```

### Profile Groups (Spring Boot 2.4+)

```properties
# application.properties
spring.profiles.group.production=proddb,prodmq,monitoring
spring.profiles.group.development=devdb,devmq
```

```bash
# Activates proddb, prodmq, and monitoring
java -jar app.jar --spring.profiles.active=production
```

---

## Profile-Specific Properties

### File Naming Convention

```
application.properties          # Default
application-development.properties
application-production.properties
application-test.properties
```

### Profile-Specific YAML

```yaml
# application.yml - default
spring:
  datasource:
    url: jdbc:h2:mem:testdb

---
spring:
  config:
    activate:
      on-profile: production

  datasource:
    url: jdbc:postgresql://prod-server/mydb

---
spring:
  config:
    activate:
      on-profile: development

  datasource:
    url: jdbc:h2:file:./devdb
```

---

## Property Source Precedence

Spring Boot loads properties in this order (later overrides earlier):

1. Default properties (`SpringApplication.setDefaultProperties`)
2. `@PropertySource` annotations
3. `application.properties` / `application.yml`
4. Profile-specific properties (`application-{profile}.properties`)
5. OS environment variables
6. Java system properties (`-Dkey=value`)
7. Command-line arguments (`--key=value`)

### Example

```properties
# application.properties
server.port=8080

# application-production.properties
server.port=80
```

```bash
# This uses port 9000 (command line wins)
java -jar app.jar --server.port=9000 --spring.profiles.active=production
```

---

## Relaxed Binding

Spring Boot matches properties flexibly:

```yaml
# These all bind to myProperty
my-property: value1
myProperty: value2
MY_PROPERTY: value3
my_property: value4
```

```java
@ConfigurationProperties(prefix = "my")
public class MyProperties {
    private String property;  // Matches all above
}
```

### Environment Variable Binding

```bash
# Environment variable
export APP_DATABASE_URL=jdbc:postgresql://localhost/db
export APP_API_KEYS_0=key1
export APP_API_KEYS_1=key2
```

```java
@ConfigurationProperties(prefix = "app")
public class AppProperties {
    private String databaseUrl;      // APP_DATABASE_URL
    private List<String> apiKeys;    // APP_API_KEYS_0, APP_API_KEYS_1
}
```

---

## Configuration Metadata

### Generate IDE Support

```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-configuration-processor</artifactId>
    <optional>true</optional>
</dependency>
```

### Custom Metadata

```json
// META-INF/additional-spring-configuration-metadata.json
{
  "properties": [
    {
      "name": "app.mode",
      "type": "java.lang.String",
      "description": "Application running mode",
      "defaultValue": "normal",
      "deprecation": {
        "reason": "Use app.execution-mode instead",
        "replacement": "app.execution-mode"
      }
    }
  ],
  "hints": [
    {
      "name": "app.mode",
      "values": [
        { "value": "normal", "description": "Normal operation" },
        { "value": "maintenance", "description": "Maintenance mode" }
      ]
    }
  ]
}
```

---

## Complete Example

```yaml
# application.yml
app:
  name: MyApp
  environment: ${ENVIRONMENT:development}

  database:
    url: jdbc:h2:mem:testdb
    pool-size: 5

  api:
    timeout: 30s
    retry:
      max-attempts: 3
      backoff: 1s

  features:
    new-ui: false
    dark-mode: true

---
spring:
  config:
    activate:
      on-profile: production

app:
  database:
    url: ${DATABASE_URL}
    pool-size: 20

  api:
    timeout: 10s

  features:
    new-ui: true
```

```java
@ConfigurationProperties(prefix = "app")
@Validated
public class AppProperties {

    @NotBlank
    private String name;

    private String environment;

    @Valid
    @NotNull
    private Database database;

    @Valid
    @NotNull
    private Api api;

    private Map<String, Boolean> features = new HashMap<>();

    @Data
    public static class Database {
        @NotBlank
        private String url;

        @Min(1) @Max(100)
        private int poolSize = 10;
    }

    @Data
    public static class Api {
        private Duration timeout = Duration.ofSeconds(30);

        @Valid
        private Retry retry = new Retry();
    }

    @Data
    public static class Retry {
        @Min(0) @Max(10)
        private int maxAttempts = 3;

        private Duration backoff = Duration.ofSeconds(1);
    }
}
```

---

## Key Takeaways

1. **@ConfigurationProperties over @Value** for complex configuration
2. **Use immutable properties** with constructor binding
3. **Validate with @Validated** and JSR-303 annotations
4. **Profile-specific files** for environment configuration
5. **Relaxed binding** makes env vars work seamlessly
6. **Generate metadata** for IDE autocomplete support

---

*Next: [JPA Entity Annotations](../PART-5-DATA-PERSISTENCE/10-jpa-entities.md)*
