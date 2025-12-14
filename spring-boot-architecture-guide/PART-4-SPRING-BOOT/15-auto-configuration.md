# Chapter 15: Auto-Configuration Explained

> *"Any sufficiently advanced technology is indistinguishable from magic."*
> — Arthur C. Clarke

---

## The Mystery of Auto-Configuration

You add a dependency, set a few properties, and Spring Boot configures everything. How?

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-jpa</artifactId>
</dependency>
```

```properties
spring.datasource.url=jdbc:postgresql://localhost/mydb
spring.datasource.username=user
spring.datasource.password=secret
```

Suddenly you have:
- A configured `DataSource`
- An `EntityManagerFactory`
- A `TransactionManager`
- Repository implementations

**Let's demystify this.**

---

## The @SpringBootApplication Entry Point

Everything starts here:

```java
@SpringBootApplication
public class MyApplication {
    public static void main(String[] args) {
        SpringApplication.run(MyApplication.class, args);
    }
}
```

`@SpringBootApplication` is a composed annotation:

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@SpringBootConfiguration        // This is a @Configuration class
@EnableAutoConfiguration        // THE KEY ANNOTATION
@ComponentScan                  // Scan for components
public @interface SpringBootApplication {
}
```

The magic is in `@EnableAutoConfiguration`.

---

## How @EnableAutoConfiguration Works

```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@AutoConfigurationPackage
@Import(AutoConfigurationImportSelector.class)  // This does the work
public @interface EnableAutoConfiguration {
}
```

`AutoConfigurationImportSelector` is a special Spring component that:
1. Finds all auto-configuration classes
2. Filters them based on conditions
3. Imports the matching ones

### Finding Auto-Configuration Classes

Auto-configuration classes are listed in a special file:

```
META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports
```

(Pre-Spring Boot 3.0: `META-INF/spring.factories`)

This file contains class names:

```
org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration
org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration
org.springframework.boot.autoconfigure.web.servlet.WebMvcAutoConfiguration
org.springframework.boot.autoconfigure.jackson.JacksonAutoConfiguration
# ... hundreds more
```

Spring Boot loads this file from every JAR on the classpath and considers each class.

---

## Conditional Configuration: The Real Magic

Having hundreds of auto-configuration classes doesn't mean they all activate. Each class has **conditions**:

```java
@AutoConfiguration
@ConditionalOnClass(DataSource.class)  // Only if DataSource is on classpath
@ConditionalOnMissingBean(DataSource.class)  // Only if no DataSource already exists
@EnableConfigurationProperties(DataSourceProperties.class)
public class DataSourceAutoConfiguration {

    @Bean
    @ConditionalOnProperty(prefix = "spring.datasource", name = "url")
    public DataSource dataSource(DataSourceProperties properties) {
        return DataSourceBuilder.create()
            .url(properties.getUrl())
            .username(properties.getUsername())
            .password(properties.getPassword())
            .build();
    }
}
```

### Common Condition Annotations

| Annotation | Meaning |
|------------|---------|
| `@ConditionalOnClass` | Activate if class is on classpath |
| `@ConditionalOnMissingClass` | Activate if class is NOT on classpath |
| `@ConditionalOnBean` | Activate if bean exists |
| `@ConditionalOnMissingBean` | Activate if bean doesn't exist |
| `@ConditionalOnProperty` | Activate if property has specific value |
| `@ConditionalOnResource` | Activate if resource exists |
| `@ConditionalOnWebApplication` | Activate in web application |
| `@ConditionalOnNotWebApplication` | Activate in non-web application |
| `@ConditionalOnExpression` | Activate based on SpEL expression |

---

## A Complete Auto-Configuration Example

Let's examine `DataSourceAutoConfiguration`:

```java
@AutoConfiguration(before = SqlInitializationAutoConfiguration.class)
@ConditionalOnClass({ DataSource.class, EmbeddedDatabaseType.class })
@ConditionalOnMissingBean(type = "io.r2dbc.spi.ConnectionFactory")
@EnableConfigurationProperties(DataSourceProperties.class)
@Import({
    DataSourcePoolMetadataProvidersConfiguration.class,
    DataSourceCheckpointRestoreConfiguration.class
})
public class DataSourceAutoConfiguration {

    @Configuration(proxyBeanMethods = false)
    @Conditional(EmbeddedDatabaseCondition.class)
    @ConditionalOnMissingBean({ DataSource.class, XADataSource.class })
    @Import(EmbeddedDataSourceConfiguration.class)
    protected static class EmbeddedDatabaseConfiguration {
    }

    @Configuration(proxyBeanMethods = false)
    @Conditional(PooledDataSourceCondition.class)
    @ConditionalOnMissingBean({ DataSource.class, XADataSource.class })
    @Import({
        HikariPoolDataSourceMetadataProviderConfiguration.class,
        DataSourceConfiguration.Hikari.class,
        DataSourceConfiguration.Tomcat.class,
        DataSourceConfiguration.Dbcp2.class,
        // ... other connection pools
    })
    protected static class PooledDataSourceConfiguration {
    }
}
```

This class:
1. **Only activates** if `DataSource` class exists (JDBC is on classpath)
2. **Doesn't activate** if R2DBC is being used (reactive database)
3. **Imports embedded DB config** if conditions match (H2, HSQLDB, Derby)
4. **Imports pooled datasource config** if conditions match (HikariCP, Tomcat, etc.)
5. **Skips everything** if you've defined your own `DataSource` bean

---

## The Condition Evaluation Process

When Spring Boot starts:

```
1. Load all auto-configuration class names from imports file
   └── Hundreds of candidates

2. For each candidate, evaluate class-level conditions
   └── @ConditionalOnClass first (cheapest check)
   └── Most classes filtered out here

3. For surviving candidates, evaluate bean-level conditions
   └── @ConditionalOnBean, @ConditionalOnMissingBean
   └── @ConditionalOnProperty

4. Register beans from classes that pass all conditions
```

### Viewing Condition Evaluation

Enable debug mode:

```properties
debug=true
```

Output shows what was evaluated:

```
============================
CONDITIONS EVALUATION REPORT
============================

Positive matches:
-----------------

   DataSourceAutoConfiguration matched:
      - @ConditionalOnClass found required classes 'javax.sql.DataSource',
        'org.springframework.jdbc.datasource.embedded.EmbeddedDatabaseType'
      - @ConditionalOnMissingBean did not find any beans of type
        'io.r2dbc.spi.ConnectionFactory'

   DataSourceAutoConfiguration.PooledDataSourceConfiguration matched:
      - PooledDataSourceCondition found supported DataSource

Negative matches:
-----------------

   RabbitAutoConfiguration:
      Did not match:
         - @ConditionalOnClass did not find required class
           'com.rabbitmq.client.Channel'

   RedisAutoConfiguration:
      Did not match:
         - @ConditionalOnClass did not find required class
           'org.springframework.data.redis.core.RedisOperations'
```

---

## Writing Your Own Auto-Configuration

You can create auto-configuration for your own libraries:

### Step 1: Create the Auto-Configuration Class

```java
@AutoConfiguration
@ConditionalOnClass(MyLibrary.class)
@EnableConfigurationProperties(MyLibraryProperties.class)
public class MyLibraryAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean
    public MyLibraryClient myLibraryClient(MyLibraryProperties properties) {
        return new MyLibraryClient(
            properties.getEndpoint(),
            properties.getApiKey()
        );
    }
}
```

### Step 2: Create Configuration Properties

```java
@ConfigurationProperties(prefix = "mylib")
public class MyLibraryProperties {
    private String endpoint = "https://api.mylib.com";
    private String apiKey;

    // getters and setters
}
```

### Step 3: Register in imports file

Create `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`:

```
com.example.MyLibraryAutoConfiguration
```

### Step 4: Users Just Add Dependency

```xml
<dependency>
    <groupId>com.example</groupId>
    <artifactId>mylib-spring-boot-starter</artifactId>
</dependency>
```

```properties
mylib.api-key=secret123
```

Done! The library auto-configures itself.

---

## Auto-Configuration Order

Auto-configurations can specify ordering:

```java
@AutoConfiguration(
    after = DataSourceAutoConfiguration.class,
    before = JpaRepositoriesAutoConfiguration.class
)
public class HibernateJpaAutoConfiguration {
    // This runs after DataSource is configured
    // but before repositories are set up
}
```

This ensures:
1. `DataSource` exists before JPA configuration
2. JPA configuration exists before Repository configuration

---

## The @ConditionalOnMissingBean Pattern

This pattern is crucial for customization:

```java
@Bean
@ConditionalOnMissingBean
public ObjectMapper objectMapper() {
    return new ObjectMapper()
        .configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
}
```

**If you don't define a bean**, Spring Boot creates one with sensible defaults.

**If you define your own**, Spring Boot backs off:

```java
@Configuration
public class MyConfig {
    @Bean
    public ObjectMapper objectMapper() {
        return new ObjectMapper()
            .registerModule(new JavaTimeModule())
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
    }
}
```

Now your `ObjectMapper` is used instead of the default.

---

## Property Binding with @ConfigurationProperties

Auto-configuration heavily uses configuration properties:

```java
@ConfigurationProperties(prefix = "spring.datasource")
public class DataSourceProperties {
    private String url;
    private String username;
    private String password;
    private String driverClassName;

    // getters and setters
}
```

Properties bind automatically:

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost/mydb
    username: user
    password: secret
```

Type conversion, validation, nested objects—all handled automatically.

---

## Disabling Auto-Configuration

Sometimes you need to turn off auto-configuration:

### Exclude Specific Classes

```java
@SpringBootApplication(exclude = {
    DataSourceAutoConfiguration.class,
    HibernateJpaAutoConfiguration.class
})
public class MyApplication { }
```

### Via Properties

```properties
spring.autoconfigure.exclude=\
  org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,\
  org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration
```

---

## The Complete Flow

Let's trace what happens when you add JPA:

1. **Add starter dependency**
   ```xml
   <dependency>
       <groupId>org.springframework.boot</groupId>
       <artifactId>spring-boot-starter-data-jpa</artifactId>
   </dependency>
   ```

2. **Classes appear on classpath**
   - `DataSource`, `EntityManager`, `JpaRepository`, etc.

3. **Application starts**
   - `SpringApplication.run()` → refresh() → import auto-configurations

4. **Auto-configurations evaluated**
   - `DataSourceAutoConfiguration`: ✓ `DataSource` on classpath → creates `DataSource` bean
   - `HibernateJpaAutoConfiguration`: ✓ `EntityManager` on classpath, `DataSource` exists → creates `EntityManagerFactory`
   - `TransactionAutoConfiguration`: ✓ `TransactionManager` on classpath → creates `JpaTransactionManager`
   - `JpaRepositoriesAutoConfiguration`: ✓ `JpaRepository` on classpath → enables `@EnableJpaRepositories`

5. **Beans created**
   - `DataSource` (HikariCP by default)
   - `EntityManagerFactory`
   - `JpaTransactionManager`
   - Your repository implementations

6. **Application ready**
   - You can `@Autowired UserRepository` and it just works

---

## Key Takeaways

1. **`@EnableAutoConfiguration` triggers auto-configuration**
2. **Auto-config classes are listed** in special META-INF files
3. **Conditions determine** which configurations activate
4. **`@ConditionalOnMissingBean`** enables customization
5. **Properties bind via `@ConfigurationProperties`**
6. **Debug output** shows exactly what matched and why
7. **You can write your own** auto-configurations

---

*Next: [Chapter 16: Starters and Dependencies](./16-starters.md)*
