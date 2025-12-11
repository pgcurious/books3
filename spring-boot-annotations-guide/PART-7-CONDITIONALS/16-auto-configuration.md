# Creating Auto-Configuration

## Build Your Own Spring Boot Starters

---

## Overview

| Annotation | Purpose |
|------------|---------|
| `@AutoConfiguration` | Mark auto-configuration class |
| `@EnableAutoConfiguration` | Enable auto-configuration (usually via @SpringBootApplication) |
| `@AutoConfigureBefore` | Order: run before another auto-config |
| `@AutoConfigureAfter` | Order: run after another auto-config |
| `@AutoConfigureOrder` | Numeric ordering |

---

## Auto-Configuration Basics

### What Is Auto-Configuration?

Auto-configuration automatically configures beans based on:
- Classes on the classpath
- Existing beans
- Property values

```java
// Spring Boot sees Jackson on classpath
// Automatically creates ObjectMapper bean

// Spring Boot sees spring-boot-starter-web
// Automatically configures Tomcat, DispatcherServlet, etc.
```

### Creating an Auto-Configuration

```java
@AutoConfiguration
@ConditionalOnClass(MyLibrary.class)
public class MyLibraryAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean
    public MyLibrary myLibrary() {
        return new MyLibrary();
    }
}
```

---

## Registration (Spring Boot 3.x)

### META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports

```
com.mylib.autoconfigure.MyLibraryAutoConfiguration
com.mylib.autoconfigure.AnotherAutoConfiguration
```

### Registration (Spring Boot 2.x - Legacy)

```
# META-INF/spring.factories
org.springframework.boot.autoconfigure.EnableAutoConfiguration=\
  com.mylib.autoconfigure.MyLibraryAutoConfiguration,\
  com.mylib.autoconfigure.AnotherAutoConfiguration
```

---

## Complete Auto-Configuration Example

### The Library Code

```java
// Main library class
public class NotificationService {

    private final NotificationProperties properties;
    private final List<NotificationChannel> channels;

    public NotificationService(NotificationProperties properties,
                               List<NotificationChannel> channels) {
        this.properties = properties;
        this.channels = channels;
    }

    public void send(Notification notification) {
        channels.stream()
            .filter(NotificationChannel::isEnabled)
            .forEach(channel -> channel.send(notification));
    }
}

public interface NotificationChannel {
    void send(Notification notification);
    boolean isEnabled();
}

public class EmailChannel implements NotificationChannel { ... }
public class SmsChannel implements NotificationChannel { ... }
public class SlackChannel implements NotificationChannel { ... }
```

### Configuration Properties

```java
@ConfigurationProperties(prefix = "notification")
public class NotificationProperties {

    private boolean enabled = true;
    private Email email = new Email();
    private Sms sms = new Sms();
    private Slack slack = new Slack();

    public static class Email {
        private boolean enabled = false;
        private String from;
        private String smtpHost;
        // getters, setters
    }

    public static class Sms {
        private boolean enabled = false;
        private String provider;
        private String apiKey;
        // getters, setters
    }

    public static class Slack {
        private boolean enabled = false;
        private String webhookUrl;
        // getters, setters
    }

    // getters, setters
}
```

### Auto-Configuration Class

```java
@AutoConfiguration
@ConditionalOnClass(NotificationService.class)
@ConditionalOnProperty(prefix = "notification", name = "enabled", havingValue = "true", matchIfMissing = true)
@EnableConfigurationProperties(NotificationProperties.class)
public class NotificationAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean
    public NotificationService notificationService(
            NotificationProperties properties,
            List<NotificationChannel> channels) {
        return new NotificationService(properties, channels);
    }

    @Configuration
    @ConditionalOnProperty(prefix = "notification.email", name = "enabled", havingValue = "true")
    public static class EmailChannelConfiguration {

        @Bean
        @ConditionalOnMissingBean(EmailChannel.class)
        public EmailChannel emailChannel(NotificationProperties properties) {
            return new EmailChannel(properties.getEmail());
        }
    }

    @Configuration
    @ConditionalOnProperty(prefix = "notification.sms", name = "enabled", havingValue = "true")
    public static class SmsChannelConfiguration {

        @Bean
        @ConditionalOnMissingBean(SmsChannel.class)
        public SmsChannel smsChannel(NotificationProperties properties) {
            return new SmsChannel(properties.getSms());
        }
    }

    @Configuration
    @ConditionalOnProperty(prefix = "notification.slack", name = "enabled", havingValue = "true")
    @ConditionalOnClass(name = "com.slack.api.Slack")
    public static class SlackChannelConfiguration {

        @Bean
        @ConditionalOnMissingBean(SlackChannel.class)
        public SlackChannel slackChannel(NotificationProperties properties) {
            return new SlackChannel(properties.getSlack());
        }
    }
}
```

---

## Ordering Auto-Configurations

### @AutoConfigureBefore / @AutoConfigureAfter

```java
@AutoConfiguration
@AutoConfigureBefore(DataSourceAutoConfiguration.class)
public class DatabaseInitializerAutoConfiguration {
    // Runs BEFORE DataSourceAutoConfiguration
}

@AutoConfiguration
@AutoConfigureAfter(DataSourceAutoConfiguration.class)
public class DatabaseMigrationAutoConfiguration {
    // Runs AFTER DataSourceAutoConfiguration
}
```

### @AutoConfigureOrder

```java
@AutoConfiguration
@AutoConfigureOrder(Ordered.HIGHEST_PRECEDENCE)
public class EarlyAutoConfiguration {
    // Runs very early
}

@AutoConfiguration
@AutoConfigureOrder(Ordered.LOWEST_PRECEDENCE)
public class LateAutoConfiguration {
    // Runs very late
}
```

---

## Building a Starter

### Project Structure

```
my-spring-boot-starter/
├── my-library/                          # Core library (no Spring deps)
│   ├── src/main/java/
│   │   └── com/mylib/
│   │       └── NotificationService.java
│   └── pom.xml
│
├── my-library-spring-boot-autoconfigure/  # Auto-configuration module
│   ├── src/main/java/
│   │   └── com/mylib/autoconfigure/
│   │       ├── NotificationAutoConfiguration.java
│   │       └── NotificationProperties.java
│   ├── src/main/resources/
│   │   └── META-INF/
│   │       └── spring/
│   │           └── org.springframework.boot.autoconfigure.AutoConfiguration.imports
│   └── pom.xml
│
└── my-library-spring-boot-starter/       # Starter (just dependencies)
    └── pom.xml
```

### Starter POM

```xml
<!-- my-library-spring-boot-starter/pom.xml -->
<project>
    <artifactId>my-library-spring-boot-starter</artifactId>

    <dependencies>
        <dependency>
            <groupId>com.mylib</groupId>
            <artifactId>my-library</artifactId>
        </dependency>
        <dependency>
            <groupId>com.mylib</groupId>
            <artifactId>my-library-spring-boot-autoconfigure</artifactId>
        </dependency>
    </dependencies>
</project>
```

### Auto-Configure POM

```xml
<!-- my-library-spring-boot-autoconfigure/pom.xml -->
<project>
    <artifactId>my-library-spring-boot-autoconfigure</artifactId>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-autoconfigure</artifactId>
        </dependency>

        <dependency>
            <groupId>com.mylib</groupId>
            <artifactId>my-library</artifactId>
            <optional>true</optional>
        </dependency>

        <!-- For IDE support -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-configuration-processor</artifactId>
            <optional>true</optional>
        </dependency>
    </dependencies>
</project>
```

---

## Configuration Metadata

### Generate Automatically

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-configuration-processor</artifactId>
    <optional>true</optional>
</dependency>
```

### Additional Metadata

```json
// META-INF/additional-spring-configuration-metadata.json
{
  "properties": [
    {
      "name": "notification.email.from",
      "type": "java.lang.String",
      "description": "Email sender address"
    }
  ],
  "hints": [
    {
      "name": "notification.sms.provider",
      "values": [
        { "value": "twilio", "description": "Twilio SMS provider" },
        { "value": "nexmo", "description": "Nexmo SMS provider" }
      ]
    }
  ]
}
```

---

## Failure Analyzers

### Custom Failure Analyzer

```java
public class NotificationServiceFailureAnalyzer
        extends AbstractFailureAnalyzer<NotificationConfigurationException> {

    @Override
    protected FailureAnalysis analyze(Throwable rootFailure,
                                      NotificationConfigurationException cause) {
        return new FailureAnalysis(
            "Notification service configuration is invalid: " + cause.getMessage(),
            "Check your notification.* properties in application.properties",
            cause
        );
    }
}
```

### Register Failure Analyzer

```
# META-INF/spring.factories
org.springframework.boot.diagnostics.FailureAnalyzer=\
  com.mylib.autoconfigure.NotificationServiceFailureAnalyzer
```

---

## Testing Auto-Configuration

```java
class NotificationAutoConfigurationTest {

    private final ApplicationContextRunner contextRunner =
        new ApplicationContextRunner()
            .withConfiguration(
                AutoConfigurations.of(NotificationAutoConfiguration.class)
            );

    @Test
    void shouldCreateServiceWhenEnabled() {
        contextRunner
            .withPropertyValues("notification.enabled=true")
            .run(context -> {
                assertThat(context).hasSingleBean(NotificationService.class);
            });
    }

    @Test
    void shouldNotCreateServiceWhenDisabled() {
        contextRunner
            .withPropertyValues("notification.enabled=false")
            .run(context -> {
                assertThat(context).doesNotHaveBean(NotificationService.class);
            });
    }

    @Test
    void shouldBackOffWhenCustomBeanProvided() {
        contextRunner
            .withUserConfiguration(CustomNotificationConfig.class)
            .run(context -> {
                assertThat(context).hasSingleBean(NotificationService.class);
                assertThat(context.getBean(NotificationService.class))
                    .isInstanceOf(CustomNotificationService.class);
            });
    }

    @Configuration
    static class CustomNotificationConfig {
        @Bean
        public NotificationService notificationService() {
            return new CustomNotificationService();
        }
    }
}
```

---

## Best Practices

### 1. Always Use @ConditionalOnMissingBean

```java
@Bean
@ConditionalOnMissingBean  // Let users override
public MyService myService() {
    return new DefaultMyService();
}
```

### 2. Check for Required Classes

```java
@AutoConfiguration
@ConditionalOnClass(RequiredLibrary.class)  // Fail gracefully if not present
public class MyAutoConfiguration { }
```

### 3. Separate Core Library from Auto-Configuration

```
my-library/              # No Spring dependencies
my-library-autoconfigure/  # Spring integration
my-library-starter/        # Pulls both together
```

### 4. Provide Sensible Defaults

```java
@ConfigurationProperties(prefix = "mylib")
public class MyLibProperties {

    private boolean enabled = true;  // Default: enabled
    private Duration timeout = Duration.ofSeconds(30);  // Default: 30s
    private int maxRetries = 3;  // Default: 3 retries
}
```

---

## Key Takeaways

1. **@AutoConfiguration** marks auto-config classes
2. **Register in** `META-INF/spring/...AutoConfiguration.imports`
3. **Use conditionals** for flexible bean creation
4. **@ConditionalOnMissingBean** allows user overrides
5. **Three-module structure** for starters
6. **Configuration metadata** for IDE support
7. **Test with ApplicationContextRunner**

---

*Next: [Test Slice Annotations](../PART-8-TESTING/17-test-slices.md)*
