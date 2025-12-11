# Repository & Transaction Annotations

## Data Access and Transaction Management

---

## Overview

| Annotation | Purpose |
|------------|---------|
| `@Repository` | Mark data access component |
| `@Transactional` | Define transaction boundaries |
| `@Query` | Custom JPQL/SQL queries |
| `@Modifying` | For UPDATE/DELETE queries |
| `@Param` | Named query parameters |
| `@EnableJpaRepositories` | Enable Spring Data JPA |

---

## Spring Data JPA Repositories

### Basic Repository

```java
public interface UserRepository extends JpaRepository<User, Long> {
    // Built-in methods: save, findById, findAll, delete, count, etc.
}
```

### Repository Hierarchy

```
Repository (marker interface)
    └── CrudRepository (basic CRUD)
        └── PagingAndSortingRepository (+ pagination)
            └── JpaRepository (+ JPA-specific: flush, batch)
```

### Query Methods

```java
public interface UserRepository extends JpaRepository<User, Long> {

    // Find by single field
    Optional<User> findByEmail(String email);
    List<User> findByStatus(Status status);

    // Multiple conditions
    List<User> findByStatusAndRole(Status status, Role role);
    List<User> findByStatusOrRole(Status status, Role role);

    // Comparison operators
    List<User> findByAgeGreaterThan(int age);
    List<User> findByAgeLessThanEqual(int age);
    List<User> findByAgeBetween(int min, int max);

    // String matching
    List<User> findByNameContaining(String name);
    List<User> findByNameStartingWith(String prefix);
    List<User> findByNameEndingWith(String suffix);
    List<User> findByNameIgnoreCase(String name);

    // Null checks
    List<User> findByMiddleNameIsNull();
    List<User> findByMiddleNameIsNotNull();

    // Collection checks
    List<User> findByRoleIn(Collection<Role> roles);
    List<User> findByRoleNotIn(Collection<Role> roles);

    // Boolean
    List<User> findByActiveTrue();
    List<User> findByActiveFalse();

    // Ordering
    List<User> findByStatusOrderByCreatedAtDesc(Status status);

    // Limiting results
    User findFirstByOrderByCreatedAtDesc();
    List<User> findTop10ByStatus(Status status);

    // Distinct
    List<User> findDistinctByStatus(Status status);

    // Count and exists
    long countByStatus(Status status);
    boolean existsByEmail(String email);

    // Delete
    void deleteByStatus(Status status);
}
```

---

## @Query - Custom Queries

### JPQL Queries

```java
public interface UserRepository extends JpaRepository<User, Long> {

    @Query("SELECT u FROM User u WHERE u.email = :email")
    Optional<User> findByEmailAddress(@Param("email") String email);

    @Query("SELECT u FROM User u WHERE u.status = :status AND u.createdAt > :date")
    List<User> findRecentActiveUsers(
        @Param("status") Status status,
        @Param("date") LocalDateTime date
    );

    @Query("SELECT u FROM User u WHERE u.name LIKE %:keyword%")
    List<User> searchByName(@Param("keyword") String keyword);

    @Query("SELECT u FROM User u JOIN u.roles r WHERE r.name = :roleName")
    List<User> findByRoleName(@Param("roleName") String roleName);
}
```

### Native SQL Queries

```java
public interface UserRepository extends JpaRepository<User, Long> {

    @Query(
        value = "SELECT * FROM users WHERE email = :email",
        nativeQuery = true
    )
    Optional<User> findByEmailNative(@Param("email") String email);

    @Query(
        value = "SELECT * FROM users ORDER BY created_at DESC LIMIT :limit",
        nativeQuery = true
    )
    List<User> findRecentUsers(@Param("limit") int limit);

    // With pagination
    @Query(
        value = "SELECT * FROM users WHERE status = :status",
        countQuery = "SELECT count(*) FROM users WHERE status = :status",
        nativeQuery = true
    )
    Page<User> findByStatusNative(@Param("status") String status, Pageable pageable);
}
```

### Projections

```java
// Interface-based projection
public interface UserSummary {
    String getName();
    String getEmail();
}

public interface UserRepository extends JpaRepository<User, Long> {

    @Query("SELECT u.name as name, u.email as email FROM User u WHERE u.status = :status")
    List<UserSummary> findSummaryByStatus(@Param("status") Status status);

    // Or method name query
    List<UserSummary> findByStatus(Status status);
}

// Class-based projection (DTO)
public record UserDto(String name, String email) { }

@Query("SELECT new com.example.UserDto(u.name, u.email) FROM User u WHERE u.status = :status")
List<UserDto> findDtoByStatus(@Param("status") Status status);
```

---

## @Modifying - Update/Delete Operations

### Update Query

```java
public interface UserRepository extends JpaRepository<User, Long> {

    @Modifying
    @Query("UPDATE User u SET u.status = :status WHERE u.id = :id")
    int updateStatus(@Param("id") Long id, @Param("status") Status status);

    @Modifying
    @Query("UPDATE User u SET u.lastLogin = :time WHERE u.id = :id")
    void updateLastLogin(@Param("id") Long id, @Param("time") LocalDateTime time);

    // Bulk update
    @Modifying
    @Query("UPDATE User u SET u.status = :status WHERE u.lastLogin < :date")
    int deactivateInactiveUsers(
        @Param("status") Status status,
        @Param("date") LocalDateTime date
    );
}
```

### Delete Query

```java
public interface UserRepository extends JpaRepository<User, Long> {

    @Modifying
    @Query("DELETE FROM User u WHERE u.status = :status")
    int deleteByStatus(@Param("status") Status status);

    @Modifying
    @Query("DELETE FROM User u WHERE u.createdAt < :date AND u.status = 'PENDING'")
    int deletePendingOlderThan(@Param("date") LocalDateTime date);
}
```

### Clear Persistence Context

```java
@Modifying(clearAutomatically = true)  // Clear after query
@Query("UPDATE User u SET u.status = :status WHERE u.id = :id")
void updateStatus(@Param("id") Long id, @Param("status") Status status);

@Modifying(flushAutomatically = true)  // Flush before query
@Query("DELETE FROM User u WHERE u.status = 'DELETED'")
int purgeDeletedUsers();
```

---

## @Transactional - Transaction Management

### Basic Usage

```java
@Service
public class UserService {

    private final UserRepository userRepository;

    @Transactional
    public User createUser(CreateUserRequest request) {
        User user = new User(request.getName(), request.getEmail());
        return userRepository.save(user);
    }

    @Transactional(readOnly = true)  // Optimization for reads
    public User findById(Long id) {
        return userRepository.findById(id)
            .orElseThrow(() -> new UserNotFoundException(id));
    }
}
```

### Transaction Attributes

```java
@Transactional(
    propagation = Propagation.REQUIRED,     // Default
    isolation = Isolation.READ_COMMITTED,   // Default varies by DB
    timeout = 30,                           // Seconds
    readOnly = false,                       // Default
    rollbackFor = Exception.class,          // Rollback on this exception
    noRollbackFor = ValidationException.class  // Don't rollback
)
public void complexOperation() { }
```

### Propagation Levels

```java
// REQUIRED (default) - Use existing or create new
@Transactional(propagation = Propagation.REQUIRED)
public void methodA() {
    methodB();  // Uses same transaction
}

// REQUIRES_NEW - Always create new (suspends existing)
@Transactional(propagation = Propagation.REQUIRES_NEW)
public void auditLog(String message) {
    // Separate transaction - committed even if caller rolls back
}

// MANDATORY - Must have existing transaction
@Transactional(propagation = Propagation.MANDATORY)
public void mustBeInTransaction() { }

// SUPPORTS - Use if exists, otherwise non-transactional
@Transactional(propagation = Propagation.SUPPORTS)
public User findUser(Long id) { }

// NOT_SUPPORTED - Suspend transaction if exists
@Transactional(propagation = Propagation.NOT_SUPPORTED)
public void nonTransactionalOperation() { }

// NEVER - Throw if transaction exists
@Transactional(propagation = Propagation.NEVER)
public void mustNotBeInTransaction() { }

// NESTED - Nested transaction (savepoint)
@Transactional(propagation = Propagation.NESTED)
public void nestedOperation() { }
```

### Isolation Levels

```java
// READ_UNCOMMITTED - Dirty reads possible
@Transactional(isolation = Isolation.READ_UNCOMMITTED)

// READ_COMMITTED - No dirty reads (most common)
@Transactional(isolation = Isolation.READ_COMMITTED)

// REPEATABLE_READ - Same read returns same data
@Transactional(isolation = Isolation.REPEATABLE_READ)

// SERIALIZABLE - Full isolation (slowest)
@Transactional(isolation = Isolation.SERIALIZABLE)
```

### Rollback Behavior

```java
// Rollback on specific exceptions
@Transactional(rollbackFor = { BusinessException.class, ValidationException.class })
public void process() { }

// Don't rollback on specific exceptions
@Transactional(noRollbackFor = WarningException.class)
public void processWithWarnings() { }

// Default: Rollback on RuntimeException and Error
// Default: Commit on checked Exception
```

---

## Common Patterns

### Service Layer Transactions

```java
@Service
@Transactional(readOnly = true)  // Default for all methods
public class OrderService {

    private final OrderRepository orderRepository;
    private final PaymentService paymentService;

    public List<Order> findAll() {
        return orderRepository.findAll();  // Read-only transaction
    }

    public Order findById(Long id) {
        return orderRepository.findById(id)
            .orElseThrow(() -> new OrderNotFoundException(id));
    }

    @Transactional  // Override: read-write transaction
    public Order createOrder(CreateOrderRequest request) {
        Order order = new Order(request);
        order = orderRepository.save(order);
        paymentService.processPayment(order);
        return order;
    }

    @Transactional
    public void cancelOrder(Long id) {
        Order order = findById(id);
        order.setStatus(Status.CANCELLED);
        paymentService.refund(order);
    }
}
```

### Programmatic Transactions

```java
@Service
public class ComplexService {

    private final TransactionTemplate transactionTemplate;
    private final PlatformTransactionManager transactionManager;

    // Using TransactionTemplate
    public User createUserWithTemplate(CreateUserRequest request) {
        return transactionTemplate.execute(status -> {
            User user = new User(request);
            return userRepository.save(user);
        });
    }

    // Manual transaction management
    public void complexOperation() {
        TransactionDefinition def = new DefaultTransactionDefinition();
        TransactionStatus status = transactionManager.getTransaction(def);

        try {
            // Do work
            transactionManager.commit(status);
        } catch (Exception e) {
            transactionManager.rollback(status);
            throw e;
        }
    }
}
```

### Avoiding Common Pitfalls

```java
@Service
public class UserService {

    // WRONG: @Transactional on private method (ignored!)
    @Transactional
    private void privateMethod() { }

    // WRONG: Self-invocation bypasses proxy
    public void methodA() {
        methodB();  // @Transactional on methodB is ignored!
    }

    @Transactional
    public void methodB() { }

    // RIGHT: Inject self or use TransactionTemplate
    @Autowired
    private UserService self;

    public void methodAFixed() {
        self.methodB();  // Transaction works!
    }
}
```

---

## Repository Configuration

### Enable JPA Repositories

```java
@Configuration
@EnableJpaRepositories(
    basePackages = "com.myapp.repository",
    entityManagerFactoryRef = "entityManagerFactory",
    transactionManagerRef = "transactionManager"
)
public class JpaConfig { }
```

### Custom Repository Implementation

```java
// Custom interface
public interface UserRepositoryCustom {
    List<User> findByComplexCriteria(UserSearchCriteria criteria);
}

// Implementation
public class UserRepositoryImpl implements UserRepositoryCustom {

    @PersistenceContext
    private EntityManager em;

    @Override
    public List<User> findByComplexCriteria(UserSearchCriteria criteria) {
        CriteriaBuilder cb = em.getCriteriaBuilder();
        // Build dynamic query
    }
}

// Main repository extends both
public interface UserRepository extends JpaRepository<User, Long>, UserRepositoryCustom {
    // Method queries + custom methods
}
```

---

## Key Takeaways

1. **Spring Data JPA** generates implementations from method names
2. **@Query for complex queries** - JPQL or native SQL
3. **@Modifying required** for UPDATE/DELETE queries
4. **@Transactional on service layer** - not repository
5. **readOnly = true** for query-only methods
6. **Propagation.REQUIRES_NEW** for independent transactions
7. **Private methods ignore @Transactional** - use public methods

---

*Next: [Async Processing](../PART-6-ASYNC-EVENTS/12-async-processing.md)*
