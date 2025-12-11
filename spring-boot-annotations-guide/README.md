# Spring Boot Annotations: From Common to Obscure

## A Deep Dive Into Every Annotation You Need to Know

---

> *"Annotations are metadata that provides data about a program but is not part of the program itself."*
> — Oracle Java Documentation

---

## Why This Guide Exists

Most Spring Boot tutorials show you `@RestController` and `@Autowired`, then move on. But Spring Boot has **hundreds of annotations**, and many powerful ones remain undiscovered by most developers.

**This guide will:**

- Start with annotations everyone knows
- Progress to annotations most developers *should* know
- End with hidden gems that can transform your code
- Explain the *why* behind each annotation
- Provide copy-paste code snippets you can use immediately

## Who This Guide Is For

This guide is for developers who:

- Know basic Spring Boot but want to go deeper
- Keep seeing unfamiliar annotations in production code
- Want to write cleaner, more idiomatic Spring applications
- Enjoy understanding the *why* behind the *what*

---

## Guide Structure

| Part | Theme | Depth Level |
|------|-------|-------------|
| 1 | Core Stereotypes | Beginner |
| 2 | Web Layer | Beginner |
| 3 | Dependency Injection | Intermediate |
| 4 | Configuration | Intermediate |
| 5 | Data & Persistence | Intermediate |
| 6 | Async, Scheduling & Events | Advanced |
| 7 | Conditionals & Auto-Config | Advanced |
| 8 | Testing | Advanced |
| 9 | Hidden Gems | Expert |

---

## Quick Reference: Annotation Categories

### Stereotype Annotations
```
@Component, @Service, @Repository, @Controller, @RestController, @Configuration
```

### Web Annotations
```
@RequestMapping, @GetMapping, @PostMapping, @PutMapping, @DeleteMapping,
@PathVariable, @RequestParam, @RequestBody, @ResponseBody, @ResponseStatus
```

### DI Annotations
```
@Autowired, @Qualifier, @Primary, @Lazy, @Scope, @Value
```

### Configuration Annotations
```
@Configuration, @Bean, @PropertySource, @ConfigurationProperties,
@Profile, @EnableAutoConfiguration
```

### Data Annotations
```
@Entity, @Table, @Column, @Id, @GeneratedValue, @Transactional,
@Query, @Modifying, @EnableJpaRepositories
```

### Async & Scheduling
```
@Async, @EnableAsync, @Scheduled, @EnableScheduling,
@EventListener, @TransactionalEventListener
```

### Conditional Annotations
```
@Conditional, @ConditionalOnProperty, @ConditionalOnBean,
@ConditionalOnMissingBean, @ConditionalOnClass
```

### Testing Annotations
```
@SpringBootTest, @WebMvcTest, @DataJpaTest, @MockBean,
@SpyBean, @TestConfiguration
```

---

## Table of Contents

### Part 1: Core Stereotypes
- [01. @SpringBootApplication - The Entry Point](./PART-1-CORE-STEREOTYPES/01-springboot-application.md)
- [02. @Component Family - The Building Blocks](./PART-1-CORE-STEREOTYPES/02-component-family.md)

### Part 2: Web Layer
- [03. Request Mapping Annotations](./PART-2-WEB-LAYER/03-request-mapping.md)
- [04. Request Parameter Annotations](./PART-2-WEB-LAYER/04-request-parameters.md)
- [05. Response Handling Annotations](./PART-2-WEB-LAYER/05-response-handling.md)

### Part 3: Dependency Injection
- [06. Injection Annotations](./PART-3-DEPENDENCY-INJECTION/06-injection-annotations.md)
- [07. Scope & Lifecycle](./PART-3-DEPENDENCY-INJECTION/07-scope-lifecycle.md)

### Part 4: Configuration
- [08. Configuration Basics](./PART-4-CONFIGURATION/08-configuration-basics.md)
- [09. Properties & Profiles](./PART-4-CONFIGURATION/09-properties-profiles.md)

### Part 5: Data & Persistence
- [10. JPA Entity Annotations](./PART-5-DATA-PERSISTENCE/10-jpa-entities.md)
- [11. Repository & Transaction Annotations](./PART-5-DATA-PERSISTENCE/11-repository-transactions.md)

### Part 6: Async, Scheduling & Events
- [12. Async Processing](./PART-6-ASYNC-EVENTS/12-async-processing.md)
- [13. Scheduling & Cron](./PART-6-ASYNC-EVENTS/13-scheduling.md)
- [14. Event-Driven Architecture](./PART-6-ASYNC-EVENTS/14-events.md)

### Part 7: Conditionals & Auto-Configuration
- [15. Conditional Annotations](./PART-7-CONDITIONALS/15-conditional-annotations.md)
- [16. Creating Auto-Configuration](./PART-7-CONDITIONALS/16-auto-configuration.md)

### Part 8: Testing
- [17. Test Slice Annotations](./PART-8-TESTING/17-test-slices.md)
- [18. Mocking & Test Configuration](./PART-8-TESTING/18-mocking-config.md)

### Part 9: Hidden Gems
- [19. Validation Annotations](./PART-9-HIDDEN-GEMS/19-validation.md)
- [20. AOP Annotations](./PART-9-HIDDEN-GEMS/20-aop.md)
- [21. Actuator & Metrics](./PART-9-HIDDEN-GEMS/21-actuator-metrics.md)
- [22. Obscure But Powerful](./PART-9-HIDDEN-GEMS/22-obscure-powerful.md)

---

## How to Use This Guide

### For Beginners
Start with Parts 1-2. These cover the annotations you'll use in every project.

### For Intermediate Developers
Skip to Parts 3-5. These annotations separate good code from great code.

### For Advanced Developers
Parts 6-9 contain the annotations that most developers don't know exist.

### As a Reference
Use the Quick Reference above to jump directly to what you need.

---

## Prerequisites

- Basic Java knowledge
- Spring Boot project setup (Maven or Gradle)
- Familiarity with REST APIs

---

*Let's go beyond @Autowired and @RestController.*
