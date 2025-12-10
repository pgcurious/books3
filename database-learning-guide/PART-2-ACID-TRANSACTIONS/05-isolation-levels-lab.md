# Chapter 5: Isolation Levels Lab

> *"Isolation levels are not about correctness—they're about what kind of incorrectness you're willing to tolerate."*

---

## The Four Standard Isolation Levels

SQL standard defines four isolation levels, each allowing different anomalies:

| Level | Dirty Read | Non-Repeatable Read | Phantom Read |
|-------|------------|--------------------|--------------|
| READ UNCOMMITTED | Possible | Possible | Possible |
| READ COMMITTED | No | Possible | Possible |
| REPEATABLE READ | No | No | Possible* |
| SERIALIZABLE | No | No | No |

*PostgreSQL's REPEATABLE READ also prevents phantoms.

Let's experience each anomaly.

---

## Setup

```sql
-- Create test table
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    price DECIMAL(10, 2),
    stock INT
);

INSERT INTO products (name, price, stock) VALUES
    ('Widget', 10.00, 100),
    ('Gadget', 25.00, 50),
    ('Gizmo', 15.00, 75);
```

---

## Anomaly 1: Dirty Read

A dirty read occurs when Transaction A reads uncommitted changes from Transaction B.

### Experience It (MySQL Only)

PostgreSQL doesn't allow dirty reads even at READ UNCOMMITTED. MySQL does.

**Terminal 1 (MySQL):**
```sql
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
BEGIN;
UPDATE products SET price = 999.99 WHERE id = 1;
-- Don't commit yet!
```

**Terminal 2 (MySQL):**
```sql
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT price FROM products WHERE id = 1;
-- Shows 999.99 (uncommitted data!)
```

**Terminal 1:**
```sql
ROLLBACK;
```

**Terminal 2:**
```sql
SELECT price FROM products WHERE id = 1;
-- Back to 10.00 - we read data that never "existed"
```

**First Principle:** Dirty reads let you see the future that might never happen. This is almost never acceptable.

---

## Anomaly 2: Non-Repeatable Read

A non-repeatable read occurs when the same query returns different results within a transaction.

### Experience It

**Terminal 1 (PostgreSQL):**
```sql
-- PostgreSQL default is READ COMMITTED
BEGIN;
SELECT stock FROM products WHERE id = 1;
-- Shows 100

-- Wait for Terminal 2 to commit, then:
SELECT stock FROM products WHERE id = 1;
-- Shows 95 (different!)
COMMIT;
```

**Terminal 2 (PostgreSQL):**
```sql
BEGIN;
UPDATE products SET stock = 95 WHERE id = 1;
COMMIT;
```

**Why this matters:**
```sql
-- Imagine this business logic:
BEGIN;
SELECT stock FROM products WHERE id = 1;  -- Returns 100
-- "Great, we have enough!"
-- ... other operations ...
SELECT stock FROM products WHERE id = 1;  -- Returns 95!
-- Now our assumption is wrong
COMMIT;
```

### Prevent It

**Terminal 1:**
```sql
-- Use REPEATABLE READ
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT stock FROM products WHERE id = 1;
-- Shows current value (let's say 95)

-- Even after Terminal 2 commits changes, same query returns 95
SELECT stock FROM products WHERE id = 1;
-- Still 95 (snapshot consistency!)
COMMIT;
```

**First Principle:** REPEATABLE READ gives you a consistent snapshot. The world can change, but your view doesn't.

---

## Anomaly 3: Phantom Read

A phantom occurs when a query returns different *rows* (not just values) within a transaction.

### Experience It (MySQL)

**Terminal 1 (MySQL):**
```sql
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN;
SELECT COUNT(*) FROM products WHERE price > 20;
-- Returns 1 (Gadget)
```

**Terminal 2 (MySQL):**
```sql
BEGIN;
INSERT INTO products (name, price, stock) VALUES ('Expensive', 100.00, 10);
COMMIT;
```

**Terminal 1:**
```sql
SELECT COUNT(*) FROM products WHERE price > 20;
-- MySQL REPEATABLE READ: Still returns 1 (no phantom, but see note)
-- But try this:

SELECT COUNT(*) FROM products WHERE price > 20 FOR UPDATE;
-- May return 2! (phantom detected when locking)
COMMIT;
```

**Note:** MySQL's REPEATABLE READ handles phantoms differently than PostgreSQL. Locking queries can still see phantoms.

### PostgreSQL Prevents Phantoms at REPEATABLE READ

**Terminal 1 (PostgreSQL):**
```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT COUNT(*) FROM products WHERE price > 20;
-- Returns 1
```

**Terminal 2 (PostgreSQL):**
```sql
INSERT INTO products (name, price, stock) VALUES ('Expensive2', 150.00, 5);
```

**Terminal 1:**
```sql
SELECT COUNT(*) FROM products WHERE price > 20;
-- Still returns 1 (PostgreSQL snapshot is comprehensive)
COMMIT;
```

---

## Anomaly 4: Write Skew (SERIALIZABLE prevents this)

Write skew is a subtle anomaly where two transactions read overlapping data, make decisions, then write without conflict—but the combined result violates a constraint.

### Classic Example: On-Call Doctors

```sql
-- Setup
CREATE TABLE doctors (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    on_call BOOLEAN
);

INSERT INTO doctors (name, on_call) VALUES
    ('Alice', true),
    ('Bob', true);

-- Constraint: At least one doctor must be on call
-- (Can't be enforced with CHECK constraint!)
```

**Terminal 1:**
```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT COUNT(*) FROM doctors WHERE on_call = true;
-- Returns 2, so it's safe for Alice to go off-call
UPDATE doctors SET on_call = false WHERE name = 'Alice';
COMMIT;  -- Succeeds
```

**Terminal 2 (simultaneously):**
```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT COUNT(*) FROM doctors WHERE on_call = true;
-- Returns 2, so it's safe for Bob to go off-call
UPDATE doctors SET on_call = false WHERE name = 'Bob';
COMMIT;  -- Succeeds
```

```sql
-- Result:
SELECT * FROM doctors WHERE on_call = true;
-- Empty! Both doctors are off-call. Constraint violated.
```

### Prevent with SERIALIZABLE

**Terminal 1:**
```sql
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT COUNT(*) FROM doctors WHERE on_call = true;
-- Returns 2
UPDATE doctors SET on_call = false WHERE name = 'Alice';
COMMIT;  -- Succeeds (first to commit wins)
```

**Terminal 2:**
```sql
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT COUNT(*) FROM doctors WHERE on_call = true;
-- Returns 2
UPDATE doctors SET on_call = false WHERE name = 'Bob';
COMMIT;
-- ERROR: could not serialize access due to read/write dependencies
```

**First Principle:** SERIALIZABLE makes transactions behave as if they ran one after another. PostgreSQL detects conflicts and aborts one transaction.

---

## PostgreSQL vs MySQL: Default Differences

```sql
-- PostgreSQL default
SHOW transaction_isolation;
-- read committed

-- MySQL default
SELECT @@transaction_isolation;
-- REPEATABLE-READ
```

**This means identical code behaves differently!**

```sql
-- This code pattern:
BEGIN;
SELECT balance FROM accounts WHERE id = 1;
-- ... calculations ...
UPDATE accounts SET balance = calculated_value WHERE id = 1;
COMMIT;

-- In PostgreSQL (READ COMMITTED): May use stale balance
-- In MySQL (REPEATABLE READ): Uses consistent snapshot
```

---

## Choosing the Right Isolation Level

### READ COMMITTED (PostgreSQL default)
**Use when:**
- Individual queries need current data
- Long transactions shouldn't block
- You handle conflicts at application level

**Watch out for:**
- Non-repeatable reads within transaction
- Multiple queries may see different snapshots

### REPEATABLE READ
**Use when:**
- Reports need consistent snapshot
- Business logic depends on stable reads
- Analytics queries

**Watch out for:**
- Serialization failures (retry needed)
- Long transactions hold old snapshots

### SERIALIZABLE
**Use when:**
- Absolute correctness required
- Complex constraints that can't be in DB
- Financial calculations

**Watch out for:**
- Performance cost
- Must handle serialization failures
- Retry logic required

---

## Lab: Build Intuition

### Exercise 1: Lost Update

Two users try to increment a counter. Without proper isolation, one update gets lost.

```sql
CREATE TABLE counter (id INT PRIMARY KEY, value INT);
INSERT INTO counter VALUES (1, 0);

-- Terminal 1:
BEGIN;
SELECT value FROM counter WHERE id = 1;  -- Returns 0
-- Calculate: 0 + 1 = 1

-- Terminal 2:
BEGIN;
SELECT value FROM counter WHERE id = 1;  -- Returns 0
-- Calculate: 0 + 1 = 1
UPDATE counter SET value = 1 WHERE id = 1;
COMMIT;

-- Terminal 1:
UPDATE counter SET value = 1 WHERE id = 1;  -- Overwrites!
COMMIT;

SELECT value FROM counter WHERE id = 1;
-- Shows 1, but should be 2!
```

**Fix:** Use `UPDATE counter SET value = value + 1` (atomic) or SELECT FOR UPDATE.

### Exercise 2: SELECT FOR UPDATE

```sql
-- Terminal 1:
BEGIN;
SELECT * FROM products WHERE id = 1 FOR UPDATE;
-- Row is locked!

-- Terminal 2:
BEGIN;
SELECT * FROM products WHERE id = 1 FOR UPDATE;
-- Blocks! Waits for Terminal 1's lock.

-- Terminal 1:
UPDATE products SET stock = stock - 1 WHERE id = 1;
COMMIT;
-- Terminal 2 unblocks and gets the updated row
```

---

## Summary

| Isolation Level | PostgreSQL | MySQL | Best For |
|-----------------|------------|-------|----------|
| READ UNCOMMITTED | Upgraded to RC | Allows dirty reads | Never use |
| READ COMMITTED | Default | Available | General OLTP |
| REPEATABLE READ | Full snapshot | Some phantoms | Reports, analytics |
| SERIALIZABLE | Full serializability | Gap locking | Critical correctness |

---

*Next: [Deadlocks & Locking](./06-deadlocks-locking.md)*
