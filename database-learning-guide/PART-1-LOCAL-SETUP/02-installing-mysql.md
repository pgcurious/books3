# Chapter 2: Installing MySQL

> *"Compare and contrast reveals truth that singularity hides."*

---

## Why Install Both PostgreSQL and MySQL?

Running both databases lets you:

1. **Compare behaviors** — Same query, different results
2. **Understand trade-offs** — MySQL's speed vs PostgreSQL's correctness
3. **See defaults matter** — Default isolation levels differ significantly
4. **Build flexibility** — Real-world systems use multiple databases

---

## Installation

### Linux (Ubuntu/Debian)

```bash
# Install MySQL
sudo apt update
sudo apt install mysql-server mysql-client

# Start the service
sudo systemctl start mysql
sudo systemctl enable mysql

# Secure the installation
sudo mysql_secure_installation

# Verify installation
mysql --version
```

### Linux (RHEL/CentOS/Fedora)

```bash
# Install MySQL
sudo dnf install mysql-server

# Start and enable
sudo systemctl start mysqld
sudo systemctl enable mysqld

# Get temporary root password
sudo grep 'temporary password' /var/log/mysqld.log

# Secure installation
sudo mysql_secure_installation
```

### macOS

```bash
# Using Homebrew
brew install mysql

# Start the service
brew services start mysql

# Secure the installation
mysql_secure_installation
```

### Docker (Universal)

```bash
# Pull and run MySQL
docker run --name mysql-lab \
  -e MYSQL_ROOT_PASSWORD=labpassword \
  -p 3306:3306 \
  -d mysql:8

# Connect
docker exec -it mysql-lab mysql -u root -plabpassword
```

---

## First Connection

```bash
# Connect as root
sudo mysql -u root -p

# Or without password (default on some systems)
sudo mysql
```

### Create Your Lab Database

```sql
-- Create lab database
CREATE DATABASE labdb;

-- Create lab user
CREATE USER 'labuser'@'localhost' IDENTIFIED BY 'labpassword';

-- Grant privileges
GRANT ALL PRIVILEGES ON labdb.* TO 'labuser'@'localhost';
FLUSH PRIVILEGES;

-- Switch to lab database
USE labdb;
```

---

## First Lab: Compare PostgreSQL and MySQL

Let's create the same table in MySQL and observe differences.

### Experiment 1: Create Equivalent Table

```sql
-- Connect as labuser
mysql -u labuser -plabpassword labdb

-- Create users table
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Insert same data
INSERT INTO users (name, email) VALUES
    ('Alice', 'alice@example.com'),
    ('Bob', 'bob@example.com'),
    ('Charlie', 'charlie@example.com');

-- Query
SELECT * FROM users;
```

### Experiment 2: Spot the Differences

```sql
-- PostgreSQL
SELECT * FROM users WHERE name = 'alice';
-- Returns: nothing (case-sensitive by default)

-- MySQL
SELECT * FROM users WHERE name = 'alice';
-- Returns: Alice row (case-insensitive by default!)
```

**First Principle:** MySQL's default collation (`utf8mb4_0900_ai_ci`) is case-insensitive. PostgreSQL is case-sensitive. This isn't good or bad—it's a design choice with consequences.

### Experiment 3: Check Default Isolation Levels

```sql
-- PostgreSQL (connect via psql)
SHOW transaction_isolation;
-- Returns: read committed

-- MySQL
SELECT @@transaction_isolation;
-- Returns: REPEATABLE-READ
```

**First Principle:** Different defaults mean identical code behaves differently across databases. This will matter significantly in Part 2.

---

## Key Differences Summary

| Aspect | PostgreSQL | MySQL (InnoDB) |
|--------|------------|----------------|
| Default isolation | READ COMMITTED | REPEATABLE READ |
| Case sensitivity | Case-sensitive | Case-insensitive (default) |
| Serial type | `SERIAL` | `AUTO_INCREMENT` |
| Boolean type | Native `BOOLEAN` | `TINYINT(1)` |
| JSON support | Native, indexable | Native since 5.7 |
| Full-text search | Built-in | Built-in |
| Replication | Streaming | Binary log |

---

## Useful MySQL Commands

```sql
-- Show databases
SHOW DATABASES;

-- Use a database
USE database_name;

-- Show tables
SHOW TABLES;

-- Describe table
DESCRIBE table_name;

-- Show create statement
SHOW CREATE TABLE table_name;

-- Show current database
SELECT DATABASE();

-- Show current user
SELECT USER();

-- Show MySQL version
SELECT VERSION();

-- Exit mysql
EXIT;
```

---

## Storage Engine Differences

MySQL has multiple storage engines. InnoDB is the default and only one supporting ACID:

```sql
-- Check available engines
SHOW ENGINES;

-- Check table engine
SHOW TABLE STATUS WHERE Name = 'users';

-- Always use InnoDB for ACID compliance
CREATE TABLE important_data (
    id INT PRIMARY KEY
) ENGINE=InnoDB;
```

**First Principle:** MySQL's pluggable storage engine architecture means different tables can have different guarantees. InnoDB provides ACID; MyISAM does not. Always know your engine.

---

## Verification Checklist

- [ ] MySQL is installed and running
- [ ] You can connect via `mysql` command
- [ ] `labdb` database exists
- [ ] `labuser` can connect and create tables
- [ ] You've observed case-sensitivity difference
- [ ] You've checked default isolation levels

---

## What's Next?

Now that we have both databases running, let's understand *why* they work the way they do. We'll explore the first principles of storage—how data actually lives on disk and why this matters for everything we'll learn.

---

*Next: [First Principles of Storage](./03-storage-first-principles.md)*
