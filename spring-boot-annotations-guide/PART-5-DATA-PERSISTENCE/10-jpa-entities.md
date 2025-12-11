# JPA Entity Annotations

## Mapping Java Objects to Database Tables

---

## Overview

| Annotation | Purpose |
|------------|---------|
| `@Entity` | Mark class as JPA entity |
| `@Table` | Customize table mapping |
| `@Id` | Mark primary key |
| `@GeneratedValue` | Auto-generate ID values |
| `@Column` | Customize column mapping |
| `@Enumerated` | Map enum fields |
| `@Temporal` | Map date/time fields |
| `@Transient` | Exclude from persistence |
| `@Embedded`/`@Embeddable` | Composite values |

---

## @Entity - Marking a Persistent Class

### Basic Usage

```java
@Entity
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;
    private String email;

    // Default constructor required by JPA
    protected User() { }

    public User(String name, String email) {
        this.name = name;
        this.email = email;
    }

    // Getters and setters
}
```

### Entity Requirements

1. Must have `@Entity` annotation
2. Must have a no-arg constructor (can be `protected`)
3. Must have an `@Id` field
4. Cannot be `final`
5. No `final` methods or persistent fields

---

## @Table - Customizing Table Mapping

### Basic Usage

```java
@Entity
@Table(name = "users")  // Table name
public class User { }
```

### Full Customization

```java
@Entity
@Table(
    name = "app_users",
    schema = "public",
    catalog = "myapp",
    uniqueConstraints = {
        @UniqueConstraint(
            name = "uk_user_email",
            columnNames = { "email" }
        ),
        @UniqueConstraint(
            name = "uk_user_username",
            columnNames = { "username" }
        )
    },
    indexes = {
        @Index(
            name = "idx_user_status",
            columnList = "status"
        ),
        @Index(
            name = "idx_user_created",
            columnList = "created_at DESC"
        )
    }
)
public class User { }
```

---

## @Id and @GeneratedValue - Primary Keys

### Auto-Increment (Most Common)

```java
@Entity
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
}
```

### Generation Strategies

```java
// Database auto-increment
@GeneratedValue(strategy = GenerationType.IDENTITY)

// Sequence (PostgreSQL, Oracle)
@GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "user_seq")
@SequenceGenerator(name = "user_seq", sequenceName = "user_sequence", allocationSize = 1)

// Table-based (portable but slow)
@GeneratedValue(strategy = GenerationType.TABLE, generator = "user_gen")
@TableGenerator(name = "user_gen", table = "id_generator", pkColumnValue = "user_id")

// Let Hibernate decide
@GeneratedValue(strategy = GenerationType.AUTO)
```

### UUID Primary Key

```java
@Entity
public class Document {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
}

// Or manual UUID
@Entity
public class Document {

    @Id
    private UUID id = UUID.randomUUID();
}
```

### Composite Primary Key

```java
// Using @IdClass
@Entity
@IdClass(OrderItemId.class)
public class OrderItem {

    @Id
    private Long orderId;

    @Id
    private Long productId;

    private int quantity;
}

public class OrderItemId implements Serializable {
    private Long orderId;
    private Long productId;

    // equals() and hashCode() required
}

// Using @EmbeddedId
@Entity
public class OrderItem {

    @EmbeddedId
    private OrderItemId id;

    private int quantity;
}

@Embeddable
public class OrderItemId implements Serializable {
    private Long orderId;
    private Long productId;

    // equals() and hashCode() required
}
```

---

## @Column - Field Mapping

### Basic Usage

```java
@Entity
public class User {

    @Column(name = "user_name")
    private String name;

    @Column(name = "email_address", nullable = false, unique = true)
    private String email;
}
```

### All Options

```java
@Column(
    name = "description",           // Column name
    nullable = false,               // NOT NULL constraint
    unique = true,                  // UNIQUE constraint
    length = 500,                   // For VARCHAR
    precision = 10,                 // For DECIMAL
    scale = 2,                      // For DECIMAL
    insertable = true,              // Include in INSERT
    updatable = false,              // Exclude from UPDATE
    columnDefinition = "TEXT",      // Raw SQL type
    table = "secondary_table"       // For @SecondaryTable
)
private String description;
```

### Common Patterns

```java
@Entity
public class Product {

    @Column(nullable = false, length = 100)
    private String name;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(precision = 10, scale = 2)
    private BigDecimal price;

    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
}
```

---

## @Enumerated - Enum Mapping

### String Storage (Recommended)

```java
public enum Status {
    ACTIVE, INACTIVE, PENDING
}

@Entity
public class User {

    @Enumerated(EnumType.STRING)  // Stored as "ACTIVE", "INACTIVE", etc.
    @Column(length = 20)
    private Status status;
}
```

### Ordinal Storage (Avoid)

```java
@Enumerated(EnumType.ORDINAL)  // Stored as 0, 1, 2 - fragile!
private Status status;
```

**Why avoid ORDINAL?** Adding/reordering enum values breaks existing data.

---

## Date/Time Mapping

### Java 8+ Date/Time (No Annotation Needed)

```java
@Entity
public class Event {

    private LocalDate eventDate;        // DATE
    private LocalTime eventTime;        // TIME
    private LocalDateTime createdAt;    // TIMESTAMP
    private Instant timestamp;          // TIMESTAMP
    private ZonedDateTime zonedTime;    // TIMESTAMP
}
```

### Legacy Date Types

```java
@Entity
public class LegacyEntity {

    @Temporal(TemporalType.DATE)
    private java.util.Date birthDate;

    @Temporal(TemporalType.TIMESTAMP)
    private java.util.Date createdAt;

    @Temporal(TemporalType.TIME)
    private java.util.Date eventTime;
}
```

---

## @Transient - Excluding Fields

### Basic Usage

```java
@Entity
public class User {

    private String firstName;
    private String lastName;

    @Transient  // Not persisted
    private String fullName;

    public String getFullName() {
        return firstName + " " + lastName;
    }
}
```

### Also Excludes

```java
@Entity
public class User {

    // These are NOT persisted:
    @Transient
    private String tempValue;

    private transient String anotherTemp;  // Java transient keyword

    private static String staticField;     // Static fields
}
```

---

## @Embedded and @Embeddable - Value Objects

### Define Embeddable

```java
@Embeddable
public class Address {

    private String street;
    private String city;
    private String state;

    @Column(name = "zip_code")
    private String zipCode;

    // Default constructor required
    protected Address() { }

    public Address(String street, String city, String state, String zipCode) {
        this.street = street;
        this.city = city;
        this.state = state;
        this.zipCode = zipCode;
    }
}
```

### Use in Entity

```java
@Entity
public class Customer {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;

    @Embedded
    private Address address;  // Columns: street, city, state, zip_code
}
```

### Multiple Embeddables of Same Type

```java
@Entity
public class Customer {

    @Embedded
    @AttributeOverrides({
        @AttributeOverride(name = "street", column = @Column(name = "billing_street")),
        @AttributeOverride(name = "city", column = @Column(name = "billing_city")),
        @AttributeOverride(name = "state", column = @Column(name = "billing_state")),
        @AttributeOverride(name = "zipCode", column = @Column(name = "billing_zip"))
    })
    private Address billingAddress;

    @Embedded
    @AttributeOverrides({
        @AttributeOverride(name = "street", column = @Column(name = "shipping_street")),
        @AttributeOverride(name = "city", column = @Column(name = "shipping_city")),
        @AttributeOverride(name = "state", column = @Column(name = "shipping_state")),
        @AttributeOverride(name = "zipCode", column = @Column(name = "shipping_zip"))
    })
    private Address shippingAddress;
}
```

---

## Relationship Annotations

### @OneToMany / @ManyToOne

```java
@Entity
public class Department {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;

    @OneToMany(mappedBy = "department", cascade = CascadeType.ALL)
    private List<Employee> employees = new ArrayList<>();
}

@Entity
public class Employee {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "department_id")
    private Department department;
}
```

### @ManyToMany

```java
@Entity
public class Student {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToMany
    @JoinTable(
        name = "student_course",
        joinColumns = @JoinColumn(name = "student_id"),
        inverseJoinColumns = @JoinColumn(name = "course_id")
    )
    private Set<Course> courses = new HashSet<>();
}

@Entity
public class Course {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToMany(mappedBy = "courses")
    private Set<Student> students = new HashSet<>();
}
```

### @OneToOne

```java
@Entity
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    @JoinColumn(name = "profile_id")
    private UserProfile profile;
}

@Entity
public class UserProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(mappedBy = "profile")
    private User user;
}
```

---

## Fetch Types and Cascading

### Fetch Types

```java
// Eager - loaded immediately (default for @ManyToOne, @OneToOne)
@ManyToOne(fetch = FetchType.EAGER)
private Department department;

// Lazy - loaded on access (default for @OneToMany, @ManyToMany)
@OneToMany(fetch = FetchType.LAZY)
private List<Order> orders;
```

### Cascade Types

```java
@OneToMany(cascade = CascadeType.ALL)  // All operations cascade
@OneToMany(cascade = CascadeType.PERSIST)  // Only INSERT
@OneToMany(cascade = CascadeType.MERGE)    // Only UPDATE
@OneToMany(cascade = CascadeType.REMOVE)   // Only DELETE
@OneToMany(cascade = CascadeType.REFRESH)  // Only refresh
@OneToMany(cascade = CascadeType.DETACH)   // Only detach

// Multiple
@OneToMany(cascade = { CascadeType.PERSIST, CascadeType.MERGE })
```

### Orphan Removal

```java
@Entity
public class Order {

    @OneToMany(
        mappedBy = "order",
        cascade = CascadeType.ALL,
        orphanRemoval = true  // Delete items when removed from list
    )
    private List<OrderItem> items = new ArrayList<>();

    public void removeItem(OrderItem item) {
        items.remove(item);  // Item is deleted from DB
        item.setOrder(null);
    }
}
```

---

## Auditing Annotations

### Basic Auditing

```java
@Entity
@EntityListeners(AuditingEntityListener.class)
public class User {

    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    private LocalDateTime updatedAt;

    @CreatedBy
    @Column(updatable = false)
    private String createdBy;

    @LastModifiedBy
    private String updatedBy;
}

// Enable auditing
@Configuration
@EnableJpaAuditing
public class JpaConfig { }
```

### Base Entity Pattern

```java
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    private LocalDateTime updatedAt;

    @Version
    private Long version;
}

@Entity
public class User extends BaseEntity {
    private String name;
    private String email;
}
```

---

## Key Takeaways

1. **@Entity + @Id are required** for all JPA entities
2. **Use @GeneratedValue(IDENTITY)** for auto-increment
3. **@Enumerated(STRING)** is safer than ORDINAL
4. **Java 8 date/time** doesn't need @Temporal
5. **@Embedded/@Embeddable** for value objects
6. **Prefer LAZY fetch** to avoid N+1 queries
7. **Use @MappedSuperclass** for shared fields

---

*Next: [Repository & Transaction Annotations](./11-repository-transactions.md)*
