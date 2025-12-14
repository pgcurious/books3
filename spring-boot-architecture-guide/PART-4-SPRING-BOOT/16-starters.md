# Chapter 16: Starters and Dependencies

> *"Dependency management is like housework: if you don't do it constantly, it becomes an overwhelming mess."*
> — Anonymous Developer

---

## The Dependency Problem

Before Spring Boot, a typical `pom.xml` looked like this:

```xml
<dependencies>
    <dependency>
        <groupId>org.springframework</groupId>
        <artifactId>spring-core</artifactId>
        <version>5.3.10</version>
    </dependency>
    <dependency>
        <groupId>org.springframework</groupId>
        <artifactId>spring-context</artifactId>
        <version>5.3.10</version>
    </dependency>
    <dependency>
        <groupId>org.springframework</groupId>
        <artifactId>spring-web</artifactId>
        <version>5.3.10</version>
    </dependency>
    <dependency>
        <groupId>org.springframework</groupId>
        <artifactId>spring-webmvc</artifactId>
        <version>5.3.10</version>
    </dependency>
    <dependency>
        <groupId>com.fasterxml.jackson.core</groupId>
        <artifactId>jackson-databind</artifactId>
        <version>2.12.5</version>
    </dependency>
    <dependency>
        <groupId>javax.servlet</groupId>
        <artifactId>javax.servlet-api</artifactId>
        <version>4.0.1</version>
        <scope>provided</scope>
    </dependency>
    <!-- Many more... -->
</dependencies>
```

Problems:
- **Version management**: Which versions work together?
- **Transitive dependencies**: What else does each library need?
- **Completeness**: Did I include everything?
- **Conflicts**: What if two libraries need different versions of a third?

---

## Starters: Curated Dependency Sets

A **starter** is a dependency that brings in a curated set of compatible dependencies:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
</dependency>
```

This single dependency brings:
- `spring-boot-starter` (core)
- `spring-boot-starter-json` (Jackson)
- `spring-boot-starter-tomcat` (embedded server)
- `spring-web`
- `spring-webmvc`
- And their transitive dependencies

All versions tested together by the Spring team.

---

## What's Inside a Starter

Starters themselves are **mostly empty**. They're just POMs that declare dependencies.

Let's look at `spring-boot-starter-web`:

```xml
<!-- spring-boot-starter-web's pom.xml (simplified) -->
<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-json</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-tomcat</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework</groupId>
        <artifactId>spring-web</artifactId>
    </dependency>
    <dependency>
        <groupId>org.springframework</groupId>
        <artifactId>spring-webmvc</artifactId>
    </dependency>
</dependencies>
```

No code—just dependencies. The starter is a **convenience wrapper**.

---

## The Starter Parent

Most Spring Boot projects use the starter parent:

```xml
<parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.2.0</version>
</parent>
```

The parent provides:

### 1. Dependency Management

```xml
<!-- You write: -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
    <!-- No version needed! -->
</dependency>

<!-- Parent has: -->
<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
            <version>3.2.0</version>
        </dependency>
        <!-- Hundreds more... -->
    </dependencies>
</dependencyManagement>
```

### 2. Plugin Configuration

```xml
<!-- Pre-configured plugins -->
<build>
    <plugins>
        <plugin>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-maven-plugin</artifactId>
        </plugin>
    </plugins>
</build>
```

### 3. Resource Filtering

```xml
<!-- application.properties can use Maven properties -->
<resources>
    <resource>
        <directory>src/main/resources</directory>
        <filtering>true</filtering>
    </resource>
</resources>
```

### 4. Compiler Settings

```xml
<properties>
    <java.version>17</java.version>
</properties>
```

---

## Common Starters

### Core Starters

| Starter | Purpose |
|---------|---------|
| `spring-boot-starter` | Core (logging, YAML, etc.) |
| `spring-boot-starter-web` | Web applications (REST APIs) |
| `spring-boot-starter-webflux` | Reactive web applications |
| `spring-boot-starter-test` | Testing (JUnit, Mockito, etc.) |

### Data Starters

| Starter | Purpose |
|---------|---------|
| `spring-boot-starter-data-jpa` | JPA/Hibernate |
| `spring-boot-starter-data-mongodb` | MongoDB |
| `spring-boot-starter-data-redis` | Redis |
| `spring-boot-starter-data-elasticsearch` | Elasticsearch |
| `spring-boot-starter-jdbc` | Plain JDBC |

### Security & Messaging

| Starter | Purpose |
|---------|---------|
| `spring-boot-starter-security` | Spring Security |
| `spring-boot-starter-oauth2-client` | OAuth2 client |
| `spring-boot-starter-amqp` | RabbitMQ |
| `spring-boot-starter-kafka` | Apache Kafka |

### Operations

| Starter | Purpose |
|---------|---------|
| `spring-boot-starter-actuator` | Production monitoring |
| `spring-boot-starter-cache` | Caching abstraction |
| `spring-boot-starter-validation` | Bean validation |

---

## How Dependency Management Works

Spring Boot's parent inherits from `spring-boot-dependencies`:

```xml
<!-- spring-boot-dependencies pom.xml (simplified) -->
<dependencyManagement>
    <dependencies>
        <!-- Spring Framework -->
        <dependency>
            <groupId>org.springframework</groupId>
            <artifactId>spring-core</artifactId>
            <version>6.1.0</version>
        </dependency>

        <!-- Jackson -->
        <dependency>
            <groupId>com.fasterxml.jackson.core</groupId>
            <artifactId>jackson-databind</artifactId>
            <version>2.15.3</version>
        </dependency>

        <!-- HikariCP -->
        <dependency>
            <groupId>com.zaxxer</groupId>
            <artifactId>HikariCP</artifactId>
            <version>5.0.1</version>
        </dependency>

        <!-- Hundreds more with tested versions -->
    </dependencies>
</dependencyManagement>
```

When you add a dependency without a version, Maven looks it up in `dependencyManagement`.

---

## Using Without Parent

Can't use the parent POM? Import the BOM instead:

```xml
<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-dependencies</artifactId>
            <version>3.2.0</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>
```

You get version management without the parent.

---

## Customizing Versions

Need a different version? Override it:

```xml
<properties>
    <jackson.version>2.16.0</jackson.version>  <!-- Override default -->
</properties>
```

Or specify directly:

```xml
<dependency>
    <groupId>com.fasterxml.jackson.core</groupId>
    <artifactId>jackson-databind</artifactId>
    <version>2.16.0</version>  <!-- Explicit version overrides -->
</dependency>
```

**Warning**: Overriding versions may break compatibility. Test thoroughly.

---

## Excluding Dependencies

Sometimes you need to exclude transitive dependencies:

### Swap Embedded Server

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
    <exclusions>
        <exclusion>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-tomcat</artifactId>
        </exclusion>
    </exclusions>
</dependency>

<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-jetty</artifactId>
</dependency>
```

### Remove Logging Framework

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter</artifactId>
    <exclusions>
        <exclusion>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-logging</artifactId>
        </exclusion>
    </exclusions>
</dependency>

<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-log4j2</artifactId>
</dependency>
```

---

## Creating Custom Starters

You can create starters for your own libraries:

### Structure

```
my-library-spring-boot-starter/
├── pom.xml
└── src/main/resources/
    └── META-INF/
        └── spring/
            └── org.springframework.boot.autoconfigure.AutoConfiguration.imports
```

### The POM

```xml
<project>
    <groupId>com.example</groupId>
    <artifactId>my-library-spring-boot-starter</artifactId>
    <version>1.0.0</version>

    <dependencies>
        <!-- Your library -->
        <dependency>
            <groupId>com.example</groupId>
            <artifactId>my-library</artifactId>
            <version>1.0.0</version>
        </dependency>

        <!-- Spring Boot auto-configuration support -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-autoconfigure</artifactId>
        </dependency>
    </dependencies>
</project>
```

### Naming Convention

- Official starters: `spring-boot-starter-{name}`
- Third-party starters: `{name}-spring-boot-starter`

Examples:
- `spring-boot-starter-web` (official)
- `mybatis-spring-boot-starter` (third-party)

---

## Viewing Effective Dependencies

See what's actually included:

```bash
# Maven
mvn dependency:tree

# Gradle
gradle dependencies
```

Output:

```
[INFO] com.example:myapp:jar:1.0.0
[INFO] +- org.springframework.boot:spring-boot-starter-web:jar:3.2.0:compile
[INFO] |  +- org.springframework.boot:spring-boot-starter:jar:3.2.0:compile
[INFO] |  |  +- org.springframework.boot:spring-boot:jar:3.2.0:compile
[INFO] |  |  +- org.springframework.boot:spring-boot-autoconfigure:jar:3.2.0:compile
[INFO] |  |  +- org.springframework.boot:spring-boot-starter-logging:jar:3.2.0:compile
[INFO] |  |  |  +- ch.qos.logback:logback-classic:jar:1.4.11:compile
...
```

---

## Key Takeaways

1. **Starters bundle compatible dependencies** — no version management
2. **The parent POM provides defaults** — plugins, properties, encoding
3. **Dependency management is inherited** — from spring-boot-dependencies
4. **Override versions via properties** — but test carefully
5. **Exclude and replace dependencies** — like swapping Tomcat for Jetty
6. **Create custom starters** for your own libraries
7. **Use `dependency:tree`** to see what's included

---

*Next: [Chapter 17: The Main Method Journey](./17-main-method-journey.md)*
