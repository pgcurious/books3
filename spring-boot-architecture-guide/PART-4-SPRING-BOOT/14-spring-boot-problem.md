# Chapter 14: The Problem Spring Boot Solves

> *"Perfection is achieved, not when there is nothing more to add, but when there is nothing left to take away."*
> — Antoine de Saint-Exupéry

---

## Spring Framework: Powerful but Complex

Spring Framework solves the IoC and DI problems beautifully. But using Spring meant dealing with significant complexity:

### XML Configuration Hell (Pre-Spring 3)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xmlns:context="http://www.springframework.org/schema/context"
       xmlns:tx="http://www.springframework.org/schema/tx"
       xmlns:aop="http://www.springframework.org/schema/aop"
       xsi:schemaLocation="
           http://www.springframework.org/schema/beans
           http://www.springframework.org/schema/beans/spring-beans.xsd
           http://www.springframework.org/schema/context
           http://www.springframework.org/schema/context/spring-context.xsd
           http://www.springframework.org/schema/tx
           http://www.springframework.org/schema/tx/spring-tx.xsd
           http://www.springframework.org/schema/aop
           http://www.springframework.org/schema/aop/spring-aop.xsd">

    <!-- Component scanning -->
    <context:component-scan base-package="com.example"/>

    <!-- Property placeholder -->
    <context:property-placeholder location="classpath:application.properties"/>

    <!-- Data source -->
    <bean id="dataSource" class="com.zaxxer.hikari.HikariDataSource">
        <property name="jdbcUrl" value="${database.url}"/>
        <property name="username" value="${database.username}"/>
        <property name="password" value="${database.password}"/>
        <property name="maximumPoolSize" value="10"/>
    </bean>

    <!-- Entity Manager Factory -->
    <bean id="entityManagerFactory"
          class="org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean">
        <property name="dataSource" ref="dataSource"/>
        <property name="packagesToScan" value="com.example.entity"/>
        <property name="jpaVendorAdapter">
            <bean class="org.springframework.orm.jpa.vendor.HibernateJpaVendorAdapter"/>
        </property>
        <property name="jpaProperties">
            <props>
                <prop key="hibernate.dialect">org.hibernate.dialect.PostgreSQLDialect</prop>
                <prop key="hibernate.show_sql">true</prop>
            </props>
        </property>
    </bean>

    <!-- Transaction Manager -->
    <bean id="transactionManager"
          class="org.springframework.orm.jpa.JpaTransactionManager">
        <property name="entityManagerFactory" ref="entityManagerFactory"/>
    </bean>

    <!-- Enable annotation-driven transactions -->
    <tx:annotation-driven transaction-manager="transactionManager"/>

    <!-- ... 100+ more lines for a real application -->
</beans>
```

This was for **basic database access**. Add web, security, caching, and you'd have thousands of lines of XML.

### Java Configuration (Spring 3+)

Java configuration improved things:

```java
@Configuration
@ComponentScan("com.example")
@EnableTransactionManagement
@EnableJpaRepositories("com.example.repository")
public class AppConfig {

    @Bean
    public DataSource dataSource() {
        HikariDataSource ds = new HikariDataSource();
        ds.setJdbcUrl(env.getProperty("database.url"));
        ds.setUsername(env.getProperty("database.username"));
        ds.setPassword(env.getProperty("database.password"));
        ds.setMaximumPoolSize(10);
        return ds;
    }

    @Bean
    public LocalContainerEntityManagerFactoryBean entityManagerFactory() {
        LocalContainerEntityManagerFactoryBean em =
            new LocalContainerEntityManagerFactoryBean();
        em.setDataSource(dataSource());
        em.setPackagesToScan("com.example.entity");
        em.setJpaVendorAdapter(new HibernateJpaVendorAdapter());

        Properties props = new Properties();
        props.setProperty("hibernate.dialect",
            "org.hibernate.dialect.PostgreSQLDialect");
        em.setJpaProperties(props);

        return em;
    }

    @Bean
    public PlatformTransactionManager transactionManager() {
        return new JpaTransactionManager(entityManagerFactory().getObject());
    }
}
```

Better, but still verbose. And you had to know:
- Which beans to create
- What properties each bean needs
- How beans relate to each other
- Which @Enable annotations to use

### The Dependency Problem

And that's just configuration. The `pom.xml` was worse:

```xml
<dependencies>
    <!-- Spring Core -->
    <dependency>
        <groupId>org.springframework</groupId>
        <artifactId>spring-context</artifactId>
        <version>5.3.10</version>
    </dependency>

    <!-- Spring Web -->
    <dependency>
        <groupId>org.springframework</groupId>
        <artifactId>spring-webmvc</artifactId>
        <version>5.3.10</version>
    </dependency>

    <!-- Spring Data JPA -->
    <dependency>
        <groupId>org.springframework.data</groupId>
        <artifactId>spring-data-jpa</artifactId>
        <version>2.5.5</version>
    </dependency>

    <!-- Hibernate -->
    <dependency>
        <groupId>org.hibernate</groupId>
        <artifactId>hibernate-core</artifactId>
        <version>5.5.7.Final</version>
    </dependency>

    <!-- Connection Pool -->
    <dependency>
        <groupId>com.zaxxer</groupId>
        <artifactId>HikariCP</artifactId>
        <version>4.0.3</version>
    </dependency>

    <!-- Database Driver -->
    <dependency>
        <groupId>org.postgresql</groupId>
        <artifactId>postgresql</artifactId>
        <version>42.2.24</version>
    </dependency>

    <!-- Jackson for JSON -->
    <dependency>
        <groupId>com.fasterxml.jackson.core</groupId>
        <artifactId>jackson-databind</artifactId>
        <version>2.12.5</version>
    </dependency>

    <!-- Servlet API -->
    <dependency>
        <groupId>javax.servlet</groupId>
        <artifactId>javax.servlet-api</artifactId>
        <version>4.0.1</version>
        <scope>provided</scope>
    </dependency>

    <!-- ... many more -->
</dependencies>
```

Questions you had to answer:
- Which versions are compatible?
- What transitive dependencies are needed?
- What scope should each dependency have?
- Did you miss something?

### The Deployment Problem

After all that, deploying meant:
1. Build a WAR file
2. Install and configure Tomcat/Jetty
3. Deploy the WAR
4. Configure the container
5. Pray it works

---

## The Spring Boot Vision

Spring Boot's creators asked: **What if the framework just worked?**

What if:
- Dependencies were curated and pre-tested together?
- Configuration had sensible defaults?
- The framework detected what you're trying to do and configured itself?
- Deployment was `java -jar app.jar`?

This is the **opinionated framework** approach.

---

## The Four Pillars of Spring Boot

### Pillar 1: Starter Dependencies

Instead of listing every dependency:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
</dependency>

<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-jpa</artifactId>
</dependency>
```

**That's it.**

`spring-boot-starter-web` brings:
- Spring MVC
- Embedded Tomcat
- Jackson for JSON
- Validation
- Logging

All with compatible versions, tested together.

### Pillar 2: Auto-Configuration

Instead of manual bean configuration:

```java
// Just add spring-boot-starter-data-jpa to classpath
// and configure your database:

# application.properties
spring.datasource.url=jdbc:postgresql://localhost:5432/mydb
spring.datasource.username=user
spring.datasource.password=secret
```

Spring Boot:
- Detects JPA on classpath
- Detects PostgreSQL driver
- Creates `DataSource`
- Creates `EntityManagerFactory`
- Creates `TransactionManager`
- Enables `@EnableTransactionManagement`
- Sets up JPA repositories

**Zero Java configuration required.**

### Pillar 3: Embedded Servers

No external Tomcat installation:

```java
@SpringBootApplication
public class MyApplication {
    public static void main(String[] args) {
        SpringApplication.run(MyApplication.class, args);
    }
}
```

```bash
java -jar myapp.jar
```

The server is **inside** your JAR. Configure it like any other property:

```properties
server.port=8080
server.tomcat.max-threads=200
```

### Pillar 4: Production-Ready Features

Out of the box:
- Health checks (`/actuator/health`)
- Metrics (`/actuator/metrics`)
- Environment info (`/actuator/env`)
- Log configuration
- Externalized configuration
- Profile management

---

## Before and After

### Before Spring Boot: A Web Application

```xml
<!-- pom.xml: 100+ lines of dependencies -->
```

```xml
<!-- web.xml -->
<web-app>
    <servlet>
        <servlet-name>dispatcher</servlet-name>
        <servlet-class>
            org.springframework.web.servlet.DispatcherServlet
        </servlet-class>
        <init-param>
            <param-name>contextConfigLocation</param-name>
            <param-value>/WEB-INF/spring/dispatcher-config.xml</param-value>
        </init-param>
        <load-on-startup>1</load-on-startup>
    </servlet>
    <servlet-mapping>
        <servlet-name>dispatcher</servlet-name>
        <url-pattern>/</url-pattern>
    </servlet-mapping>
    <context-param>
        <param-name>contextConfigLocation</param-name>
        <param-value>/WEB-INF/spring/root-config.xml</param-value>
    </context-param>
    <listener>
        <listener-class>
            org.springframework.web.context.ContextLoaderListener
        </listener-class>
    </listener>
</web-app>
```

```java
// Multiple @Configuration classes
// Bean definitions
// Enable annotations
```

### After Spring Boot: The Same Application

```xml
<!-- pom.xml -->
<parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.2.0</version>
</parent>

<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
</dependencies>
```

```java
@SpringBootApplication
public class MyApplication {
    public static void main(String[] args) {
        SpringApplication.run(MyApplication.class, args);
    }
}

@RestController
public class HelloController {
    @GetMapping("/hello")
    public String hello() {
        return "Hello, World!";
    }
}
```

**Done.** Run it, and you have a web server.

---

## The Magic Question

This raises the question that drives the next chapters:

**How does Spring Boot know what to configure?**

When you add `spring-boot-starter-web`:
- How does it know to start Tomcat?
- How does it know to configure Spring MVC?
- How does it know to set up JSON serialization?

When you add `spring-boot-starter-data-jpa`:
- How does it find your database properties?
- How does it know to create a DataSource?
- How does it know which JPA provider to use?

The answer is **auto-configuration**—and it's built entirely on the Spring features we've learned:
- Reflection
- Annotations
- Conditional beans
- Component scanning

There's no new magic. Just clever application of existing tools.

---

## Key Takeaways

1. **Spring Framework was powerful but verbose** — lots of configuration
2. **Spring Boot provides opinionated defaults** — convention over configuration
3. **Starters bundle dependencies** — no more version management
4. **Auto-configuration detects and configures** — based on classpath
5. **Embedded servers simplify deployment** — `java -jar` is all you need
6. **The same Spring underneath** — just with smarter defaults

---

*Next: [Chapter 15: Auto-Configuration Explained](./15-auto-configuration.md)*
