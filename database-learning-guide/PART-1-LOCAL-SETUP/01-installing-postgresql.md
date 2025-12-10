# Chapter 1: Installing PostgreSQL

> *"The best database is the one you understand."*

---

## Why PostgreSQL?

PostgreSQL is our primary learning environment because:

1. **It's standards-compliant** — Learning PostgreSQL teaches you SQL properly
2. **It's feature-rich** — ACID compliance, advanced indexing, JSON support
3. **It's honest about trade-offs** — Clear documentation about consistency behaviors
4. **It's free** — No budget impact

---

## Installation

### Linux (Ubuntu/Debian)

```bash
# Update package list
sudo apt update

# Install PostgreSQL and utilities
sudo apt install postgresql postgresql-contrib

# Start the service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Verify installation
psql --version
```

### Linux (RHEL/CentOS/Fedora)

```bash
# Install PostgreSQL
sudo dnf install postgresql-server postgresql-contrib

# Initialize the database
sudo postgresql-setup --initdb

# Start and enable
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

### macOS

```bash
# Using Homebrew
brew install postgresql@15

# Start the service
brew services start postgresql@15

# Add to PATH (add to ~/.zshrc or ~/.bashrc)
echo 'export PATH="/opt/homebrew/opt/postgresql@15/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Windows (WSL2 Recommended)

If you're on Windows, use WSL2 with Ubuntu for the best experience:

```bash
# In WSL2 Ubuntu terminal
sudo apt update && sudo apt install postgresql postgresql-contrib
sudo service postgresql start
```

### Docker (Universal)

```bash
# Pull and run PostgreSQL
docker run --name pg-lab \
  -e POSTGRES_PASSWORD=labpassword \
  -p 5432:5432 \
  -d postgres:15

# Connect
docker exec -it pg-lab psql -U postgres
```

---

## First Connection

```bash
# Switch to postgres user and connect
sudo -u postgres psql

# You should see:
# psql (15.x)
# Type "help" for help.
# postgres=#
```

### Create Your Lab Database

```sql
-- Create a dedicated lab database
CREATE DATABASE labdb;

-- Create a lab user
CREATE USER labuser WITH PASSWORD 'labpassword';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE labdb TO labuser;

-- Connect to lab database
\c labdb

-- Grant schema privileges
GRANT ALL ON SCHEMA public TO labuser;
```

### Configure for Remote Access (Optional)

Edit `postgresql.conf`:
```bash
sudo nano /etc/postgresql/15/main/postgresql.conf
```

Change:
```
listen_addresses = '*'
```

Edit `pg_hba.conf`:
```bash
sudo nano /etc/postgresql/15/main/pg_hba.conf
```

Add:
```
host    all    all    0.0.0.0/0    scram-sha-256
```

Restart:
```bash
sudo systemctl restart postgresql
```

---

## Your First Lab: Feeling the Database

Let's verify everything works and start building intuition.

### Experiment 1: Create and Query Data

```sql
-- Connect as labuser
\c labdb labuser

-- Create a simple table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert some data
INSERT INTO users (name, email) VALUES
    ('Alice', 'alice@example.com'),
    ('Bob', 'bob@example.com'),
    ('Charlie', 'charlie@example.com');

-- Query it
SELECT * FROM users;
```

**What you should see:**
```
 id |  name   |       email        |         created_at
----+---------+--------------------+----------------------------
  1 | Alice   | alice@example.com  | 2024-01-15 10:30:00.123456
  2 | Bob     | bob@example.com    | 2024-01-15 10:30:00.123456
  3 | Charlie | charlie@example.com| 2024-01-15 10:30:00.123456
```

### Experiment 2: Where Does Data Actually Live?

```sql
-- Find the data directory
SHOW data_directory;
```

**Output:**
```
      data_directory
---------------------------
 /var/lib/postgresql/15/main
```

```bash
# Look at what's in there
sudo ls -la /var/lib/postgresql/15/main/

# Find your table's file
sudo -u postgres psql labdb -c "SELECT pg_relation_filepath('users');"
```

**First Principle:** Your table is literally a file on disk. PostgreSQL organizes data in pages (8KB by default). When you query, it reads these pages.

### Experiment 3: Measure Query Time

```sql
-- Enable timing
\timing on

-- Run a query
SELECT * FROM users WHERE email = 'bob@example.com';
```

**Output:**
```
 id | name |      email       |         created_at
----+------+------------------+----------------------------
  2 | Bob  | bob@example.com  | 2024-01-15 10:30:00.123456
(1 row)

Time: 0.543 ms
```

With 3 rows, this is instant. But what happens with millions? We'll find out in Part 3.

---

## Useful Commands Reference

```sql
-- List databases
\l

-- Connect to database
\c database_name

-- List tables
\dt

-- Describe table structure
\d table_name

-- Show current database
SELECT current_database();

-- Show current user
SELECT current_user;

-- Show PostgreSQL version
SELECT version();

-- Exit psql
\q
```

---

## Verification Checklist

Before proceeding, verify:

- [ ] PostgreSQL is installed and running
- [ ] You can connect via `psql`
- [ ] `labdb` database exists
- [ ] `labuser` can connect and create tables
- [ ] You've created the `users` table

---

## What's Next?

We'll also install MySQL to compare behaviors. Different databases make different trade-offs—understanding these differences deepens your understanding of database design itself.

---

*Next: [Installing MySQL](./02-installing-mysql.md)*
