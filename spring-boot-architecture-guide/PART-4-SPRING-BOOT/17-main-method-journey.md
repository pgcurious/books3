# Chapter 17: The Main Method Journey

> *"In the beginning, there was main()..."*
> — Every Java programmer

---

## The Entry Point

Every Spring Boot application starts the same way:

```java
@SpringBootApplication
public class MyApplication {
    public static void main(String[] args) {
        SpringApplication.run(MyApplication.class, args);
    }
}
```

This simple line triggers an incredibly sophisticated startup sequence. Let's trace every step.

---

## Phase 1: SpringApplication Instantiation

```java
SpringApplication.run(MyApplication.class, args);
```

This static method does two things:
1. Creates a `SpringApplication` instance
2. Calls `run()` on it

### Constructor

```java
public SpringApplication(Class<?>... primarySources) {
    this.primarySources = new LinkedHashSet<>(Arrays.asList(primarySources));

    // Detect application type (SERVLET, REACTIVE, or NONE)
    this.webApplicationType = WebApplicationType.deduceFromClasspath();

    // Load ApplicationContextInitializers from spring.factories
    this.initializers = loadSpringFactories(ApplicationContextInitializer.class);

    // Load ApplicationListeners from spring.factories
    this.listeners = loadSpringFactories(ApplicationListener.class);

    // Find the main class (for banner, etc.)
    this.mainApplicationClass = deduceMainApplicationClass();
}
```

**Web application type detection:**
```java
static WebApplicationType deduceFromClasspath() {
    if (ClassUtils.isPresent("org.springframework.web.reactive.DispatcherHandler", null)
            && !ClassUtils.isPresent("org.springframework.web.servlet.DispatcherServlet", null)) {
        return WebApplicationType.REACTIVE;
    }
    if (ClassUtils.isPresent("javax.servlet.Servlet", null)
            && ClassUtils.isPresent("org.springframework.web.context.ConfigurableWebApplicationContext", null)) {
        return WebApplicationType.SERVLET;
    }
    return WebApplicationType.NONE;
}
```

Spring Boot looks at what's on the classpath to decide what type of application to start.

---

## Phase 2: The Run Method

```java
public ConfigurableApplicationContext run(String... args) {
    // 1. Start timing
    StopWatch stopWatch = new StopWatch();
    stopWatch.start();

    // 2. Create bootstrap context
    DefaultBootstrapContext bootstrapContext = createBootstrapContext();

    ConfigurableApplicationContext context = null;

    // 3. Configure headless mode
    configureHeadlessProperty();

    // 4. Get and start listeners
    SpringApplicationRunListeners listeners = getRunListeners(args);
    listeners.starting(bootstrapContext, this.mainApplicationClass);

    try {
        // 5. Parse command line arguments
        ApplicationArguments applicationArguments = new DefaultApplicationArguments(args);

        // 6. Prepare environment
        ConfigurableEnvironment environment = prepareEnvironment(listeners, bootstrapContext, applicationArguments);

        // 7. Print banner
        Banner printedBanner = printBanner(environment);

        // 8. Create application context
        context = createApplicationContext();

        // 9. Prepare context
        prepareContext(bootstrapContext, context, environment, listeners, applicationArguments, printedBanner);

        // 10. Refresh context (THE BIG ONE)
        refreshContext(context);

        // 11. Post-refresh actions
        afterRefresh(context, applicationArguments);

        // 12. Stop timing
        stopWatch.stop();
        if (this.logStartupInfo) {
            new StartupInfoLogger(this.mainApplicationClass).logStarted(getApplicationLog(), stopWatch);
        }

        // 13. Notify listeners
        listeners.started(context);

        // 14. Run application runners
        callRunners(context, applicationArguments);

    } catch (Throwable ex) {
        handleRunFailure(context, ex, listeners);
        throw new IllegalStateException(ex);
    }

    try {
        listeners.running(context);
    } catch (Throwable ex) {
        handleRunFailure(context, ex, null);
        throw new IllegalStateException(ex);
    }

    return context;
}
```

Let's examine each phase.

---

## Phase 3: Environment Preparation

```java
private ConfigurableEnvironment prepareEnvironment(
        SpringApplicationRunListeners listeners,
        DefaultBootstrapContext bootstrapContext,
        ApplicationArguments applicationArguments) {

    // Create environment based on application type
    ConfigurableEnvironment environment = getOrCreateEnvironment();

    // Configure property sources and profiles
    configureEnvironment(environment, applicationArguments.getSourceArgs());

    // Attach ConfigurationPropertySources
    ConfigurationPropertySources.attach(environment);

    // Notify listeners (they can modify environment)
    listeners.environmentPrepared(bootstrapContext, environment);

    // Bind spring.main.* properties to SpringApplication
    bindToSpringApplication(environment);

    return environment;
}
```

The environment is where properties come from:
- `application.properties` / `application.yml`
- Environment variables
- Command line arguments
- System properties

Property sources are ordered by priority:
1. Command line arguments
2. Servlet init parameters
3. OS environment variables
4. application.properties/yml
5. Default properties

---

## Phase 4: Context Creation

```java
protected ConfigurableApplicationContext createApplicationContext() {
    return this.applicationContextFactory.create(this.webApplicationType);
}
```

Based on application type:
- **SERVLET**: `AnnotationConfigServletWebServerApplicationContext`
- **REACTIVE**: `AnnotationConfigReactiveWebServerApplicationContext`
- **NONE**: `AnnotationConfigApplicationContext`

---

## Phase 5: Context Preparation

```java
private void prepareContext(
        DefaultBootstrapContext bootstrapContext,
        ConfigurableApplicationContext context,
        ConfigurableEnvironment environment,
        SpringApplicationRunListeners listeners,
        ApplicationArguments applicationArguments,
        Banner printedBanner) {

    // Set environment
    context.setEnvironment(environment);

    // Post-process context (register beans, etc.)
    postProcessApplicationContext(context);

    // Apply initializers
    applyInitializers(context);

    // Notify listeners
    listeners.contextPrepared(context);

    // Close bootstrap context
    bootstrapContext.close(context);

    // Log startup info
    if (this.logStartupInfo) {
        logStartupInfo(context.getParent() == null);
        logStartupProfileInfo(context);
    }

    // Register special beans
    ConfigurableListableBeanFactory beanFactory = context.getBeanFactory();
    beanFactory.registerSingleton("springApplicationArguments", applicationArguments);
    if (printedBanner != null) {
        beanFactory.registerSingleton("springBootBanner", printedBanner);
    }

    // Load sources (your @SpringBootApplication class)
    Set<Object> sources = getAllSources();
    load(context, sources.toArray(new Object[0]));

    // Notify listeners
    listeners.contextLoaded(context);
}
```

---

## Phase 6: Context Refresh (The Big One)

This is where everything happens:

```java
private void refreshContext(ConfigurableApplicationContext context) {
    refresh(context);
}

protected void refresh(ConfigurableApplicationContext applicationContext) {
    applicationContext.refresh();
}
```

The `refresh()` method (from Chapter 11) does:

```
├── prepareRefresh()
├── obtainFreshBeanFactory()
├── prepareBeanFactory()
├── postProcessBeanFactory()
├── invokeBeanFactoryPostProcessors()
│   └── COMPONENT SCANNING HAPPENS HERE
│   └── AUTO-CONFIGURATION HAPPENS HERE
├── registerBeanPostProcessors()
├── initMessageSource()
├── initApplicationEventMulticaster()
├── onRefresh()
│   └── WEB SERVER STARTS HERE
├── registerListeners()
├── finishBeanFactoryInitialization()
│   └── ALL BEANS CREATED HERE
└── finishRefresh()
    └── ContextRefreshedEvent published
```

### The onRefresh Hook

For web applications, this is where the server starts:

```java
// In ServletWebServerApplicationContext
@Override
protected void onRefresh() {
    super.onRefresh();
    try {
        createWebServer();  // Start Tomcat/Jetty/Undertow
    } catch (Throwable ex) {
        throw new ApplicationContextException("Unable to start web server", ex);
    }
}

private void createWebServer() {
    WebServerFactory factory = getWebServerFactory();
    this.webServer = factory.getWebServer(getSelfInitializer());
}
```

---

## Phase 7: Runners

After refresh, Spring Boot runs ApplicationRunner and CommandLineRunner beans:

```java
private void callRunners(ApplicationContext context, ApplicationArguments args) {
    List<Object> runners = new ArrayList<>();
    runners.addAll(context.getBeansOfType(ApplicationRunner.class).values());
    runners.addAll(context.getBeansOfType(CommandLineRunner.class).values());

    AnnotationAwareOrderComparator.sort(runners);

    for (Object runner : runners) {
        if (runner instanceof ApplicationRunner) {
            ((ApplicationRunner) runner).run(args);
        }
        if (runner instanceof CommandLineRunner) {
            ((CommandLineRunner) runner).run(args.getSourceArgs());
        }
    }
}
```

Use these for initialization tasks:

```java
@Component
public class DataInitializer implements ApplicationRunner {
    @Override
    public void run(ApplicationArguments args) {
        // Initialize data after context is ready
    }
}
```

---

## The Complete Timeline

```
┌────────────────────────────────────────────────────────────────────┐
│                    SPRING BOOT STARTUP TIMELINE                     │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  0ms     main() called                                             │
│  │                                                                  │
│  ▼                                                                  │
│  5ms     SpringApplication created                                 │
│  │       ├── Detect web application type                           │
│  │       └── Load initializers and listeners                       │
│  │                                                                  │
│  ▼                                                                  │
│  10ms    Environment prepared                                      │
│  │       ├── Load application.properties                           │
│  │       ├── Process environment variables                         │
│  │       └── Parse command line args                               │
│  │                                                                  │
│  ▼                                                                  │
│  15ms    Banner printed                                            │
│  │                                                                  │
│  ▼                                                                  │
│  20ms    ApplicationContext created                                │
│  │                                                                  │
│  ▼                                                                  │
│  50ms    Context preparation                                       │
│  │       ├── Apply initializers                                    │
│  │       └── Load primary sources                                  │
│  │                                                                  │
│  ▼                                                                  │
│  100ms   BeanFactory post-processing                               │
│  │       ├── Component scanning                                    │
│  │       ├── Process @Configuration                                │
│  │       └── Auto-configuration                                    │
│  │                                                                  │
│  ▼                                                                  │
│  300ms   Bean post-processors registered                           │
│  │                                                                  │
│  ▼                                                                  │
│  350ms   Web server created and started                            │
│  │       └── Tomcat/Jetty/Undertow starts                          │
│  │                                                                  │
│  ▼                                                                  │
│  500ms   Singleton beans instantiated                              │
│  │       ├── All @Component beans created                          │
│  │       ├── Dependencies injected                                 │
│  │       └── @PostConstruct methods called                         │
│  │                                                                  │
│  ▼                                                                  │
│  800ms   ContextRefreshedEvent published                           │
│  │                                                                  │
│  ▼                                                                  │
│  850ms   Runners executed                                          │
│  │                                                                  │
│  ▼                                                                  │
│  900ms   ApplicationStartedEvent published                         │
│  │                                                                  │
│  ▼                                                                  │
│  950ms   Application ready                                         │
│          └── "Started MyApplication in 0.95 seconds"               │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
```

---

## Customization Points

### ApplicationContextInitializer

```java
public class MyInitializer implements ApplicationContextInitializer<ConfigurableApplicationContext> {
    @Override
    public void initialize(ConfigurableApplicationContext context) {
        // Modify context before refresh
    }
}
```

Register in `spring.factories` or:
```java
SpringApplication app = new SpringApplication(MyApplication.class);
app.addInitializers(new MyInitializer());
app.run(args);
```

### ApplicationListener

```java
@Component
public class MyListener implements ApplicationListener<ApplicationReadyEvent> {
    @Override
    public void onApplicationEvent(ApplicationReadyEvent event) {
        // Application is ready to serve requests
    }
}
```

### SpringApplicationRunListener

```java
public class MyRunListener implements SpringApplicationRunListener {
    @Override
    public void starting(ConfigurableBootstrapContext bootstrapContext) { }

    @Override
    public void environmentPrepared(ConfigurableBootstrapContext bootstrapContext,
                                   ConfigurableEnvironment environment) { }

    @Override
    public void contextPrepared(ConfigurableApplicationContext context) { }

    @Override
    public void contextLoaded(ConfigurableApplicationContext context) { }

    @Override
    public void started(ConfigurableApplicationContext context) { }

    @Override
    public void running(ConfigurableApplicationContext context) { }

    @Override
    public void failed(ConfigurableApplicationContext context, Throwable exception) { }
}
```

---

## Debugging Startup

### Startup Logging

```properties
debug=true
logging.level.org.springframework.boot=DEBUG
```

### Startup Actuator Endpoint

```properties
management.endpoint.startup.enabled=true
management.endpoints.web.exposure.include=startup
```

Then: `GET /actuator/startup`

### Application Startup Tracking

```java
@SpringBootApplication
public class MyApplication {
    public static void main(String[] args) {
        SpringApplication app = new SpringApplication(MyApplication.class);
        app.setApplicationStartup(new BufferingApplicationStartup(2048));
        app.run(args);
    }
}
```

---

## Key Takeaways

1. **`SpringApplication.run()` orchestrates everything**
2. **Environment is prepared first** — properties loaded
3. **Context type is chosen** based on classpath
4. **`refresh()` is where the work happens** — scanning, auto-config, bean creation
5. **Web server starts during `onRefresh()`**
6. **Runners execute after context is ready**
7. **Many customization points** — initializers, listeners, runners

---

*Next: [Chapter 18: Tracing a Request Through All Layers](../PART-5-SYNTHESIS/18-request-journey.md)*
