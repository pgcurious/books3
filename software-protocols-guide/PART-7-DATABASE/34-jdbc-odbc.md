# Chapter 34: JDBC/ODBC—Universal Adapters

## Abstracting Database Differences

---

> *"Write once, connect to any database. That was the dream."*
> — Enterprise developers

---

## The Frustration

Your application works with MySQL. Now a customer wants PostgreSQL. Another wants Oracle. A third wants SQL Server.

```
Without abstraction:
- Rewrite connection code for each database
- Handle different SQL dialects
- Learn four different APIs
- Maintain four code paths
```

What if there was one API that worked with any database?

## The Insight: Driver-Based Abstraction

ODBC (Open Database Connectivity, 1992) and JDBC (Java Database Connectivity, 1997) introduced a standard API layer:

```
Application
    │
    ▼
┌──────────────────────┐
│   ODBC/JDBC API      │  ← Standard interface
└──────────────────────┘
    │
    ▼
┌──────────────────────┐
│   Database Driver    │  ← Database-specific implementation
└──────────────────────┘
    │
    ▼
    Database
```

The application speaks a standard API. The driver translates to the database's native protocol.

## ODBC: The Original

### Architecture

```
Application → ODBC Driver Manager → Database Driver → Database

Driver Manager:
- Loads appropriate driver
- Routes calls
- Handles some common functionality

Driver:
- Implements ODBC API
- Speaks database's native protocol
```

### ODBC API Example

```c
SQLHENV env;
SQLHDBC dbc;
SQLHSTMT stmt;

// Allocate handles
SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &env);
SQLSetEnvAttr(env, SQL_ATTR_ODBC_VERSION, (void*)SQL_OV_ODBC3, 0);
SQLAllocHandle(SQL_HANDLE_DBC, env, &dbc);

// Connect using DSN
SQLConnect(dbc, "MyDataSource", SQL_NTS, "user", SQL_NTS, "pass", SQL_NTS);

// Execute query
SQLAllocHandle(SQL_HANDLE_STMT, dbc, &stmt);
SQLExecDirect(stmt, "SELECT name FROM users WHERE id = 1", SQL_NTS);

// Fetch results
while (SQLFetch(stmt) == SQL_SUCCESS) {
    char name[100];
    SQLGetData(stmt, 1, SQL_C_CHAR, name, sizeof(name), NULL);
    printf("Name: %s\n", name);
}

// Cleanup
SQLFreeHandle(SQL_HANDLE_STMT, stmt);
SQLDisconnect(dbc);
SQLFreeHandle(SQL_HANDLE_DBC, dbc);
SQLFreeHandle(SQL_HANDLE_ENV, env);
```

Low-level, C-style API. Powerful but verbose.

## JDBC: Java's Answer

### Simpler API

```java
// Load driver (automatic in modern Java)
// Connection string specifies driver

String url = "jdbc:postgresql://localhost/mydb";
try (Connection conn = DriverManager.getConnection(url, "user", "pass");
     PreparedStatement stmt = conn.prepareStatement(
         "SELECT name FROM users WHERE id = ?")) {

    stmt.setInt(1, 42);
    ResultSet rs = stmt.executeQuery();

    while (rs.next()) {
        System.out.println("Name: " + rs.getString("name"));
    }
}
```

### JDBC Architecture

```
Application
    │
    ▼
┌──────────────────────┐
│     JDBC API         │  java.sql package
└──────────────────────┘
    │
    ▼
┌──────────────────────┐
│   JDBC Driver        │  Vendor-specific JAR
└──────────────────────┘
    │
    ▼
    Database
```

### JDBC Driver Types

**Type 1: JDBC-ODBC Bridge**
```
JDBC API → ODBC Driver → Database
Deprecated. Performance issues.
```

**Type 2: Native API Driver**
```
JDBC API → Native library (C) → Database
Requires native code installation.
```

**Type 3: Network Protocol Driver**
```
JDBC API → Middleware server → Database
Middleware translates. Less common now.
```

**Type 4: Pure Java Driver**
```
JDBC API → Java driver → Database (native protocol)
Most common. No native dependencies.
```

## Connection Strings

Databases identified by URL/DSN:

### JDBC URLs
```
jdbc:postgresql://host:5432/database
jdbc:mysql://host:3306/database?useSSL=true
jdbc:oracle:thin:@host:1521:SID
jdbc:sqlserver://host:1433;databaseName=db
jdbc:h2:mem:testdb
```

### ODBC DSN
```
[MyDataSource]
Driver=PostgreSQL ODBC Driver(UNICODE)
Server=localhost
Port=5432
Database=mydb
```

## What Abstraction Gives You

### 1. Database Portability
```java
// Change only the connection string
String url = "jdbc:mysql://...";  // or
String url = "jdbc:postgresql://...";

// Same code works (mostly)
```

### 2. Connection Pooling Integration
```java
// DataSource handles pooling
DataSource ds = createDataSource();
try (Connection conn = ds.getConnection()) {
    // Connection from pool
}
// Returned to pool
```

### 3. Transaction Management
```java
conn.setAutoCommit(false);
try {
    stmt1.executeUpdate("...");
    stmt2.executeUpdate("...");
    conn.commit();
} catch (SQLException e) {
    conn.rollback();
}
```

### 4. Prepared Statements
```java
PreparedStatement stmt = conn.prepareStatement(
    "INSERT INTO users (name, email) VALUES (?, ?)");
stmt.setString(1, name);
stmt.setString(2, email);
stmt.executeUpdate();

// SQL injection prevented by parameter binding
```

## What Abstraction Can't Hide

### SQL Dialects
```sql
-- PostgreSQL
SELECT * FROM users LIMIT 10 OFFSET 20;

-- SQL Server
SELECT * FROM users OFFSET 20 ROWS FETCH NEXT 10 ROWS ONLY;

-- Oracle (older)
SELECT * FROM (SELECT ROWNUM rn, u.* FROM users u) WHERE rn BETWEEN 21 AND 30;
```

ORM frameworks (Hibernate, SQLAlchemy) handle this.

### Database-Specific Features
```sql
-- PostgreSQL arrays
SELECT * FROM users WHERE tags @> ARRAY['admin'];

-- MySQL JSON
SELECT * FROM users WHERE JSON_CONTAINS(roles, '"admin"');
```

### Performance Characteristics
```
PostgreSQL: Great at complex queries
MySQL: Different query optimization
SQLite: Single-writer limitation

The abstraction doesn't make them perform the same.
```

## Modern Alternatives

### Language-Specific Libraries
```
Python: psycopg2 (PostgreSQL), mysql-connector
Node.js: pg, mysql2
Go: database/sql with drivers
```

### ORMs
```
Java: Hibernate, JPA
Python: SQLAlchemy
Ruby: ActiveRecord
.NET: Entity Framework
```

### Query Builders
```python
# SQLAlchemy
session.query(User).filter(User.id == 42).first()

# Generates database-appropriate SQL
```

## The Tradeoffs

| Decision | What We Got | What We Gave Up |
|----------|-------------|-----------------|
| Standard API | Portability | Some features |
| Driver abstraction | Single interface | Slight overhead |
| Connection pooling | Performance | Configuration |
| Prepared statements | Security, speed | Slight complexity |

## The Principle

> **JDBC and ODBC solved the database portability problem by defining a standard API that drivers implement. This abstraction enables database switching (theoretically) without code changes, while drivers handle the complexity of native protocols.**

The abstraction isn't perfect—SQL dialects and database-specific features leak through—but it's valuable nonetheless.

---

## Summary

- ODBC (C) and JDBC (Java) provide standard database access APIs
- Drivers translate standard API to native database protocols
- JDBC Type 4 drivers (pure Java) are most common
- Connection strings specify which database and driver
- Abstraction enables portability but doesn't hide SQL dialects
- ORMs build on top of JDBC/ODBC for higher abstraction

---

*Beyond standardized access, each database has unique protocol features. Let's look at native protocols.*
