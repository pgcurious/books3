# Chapter 4: Understanding ACID

> *"ACID isn't a feature. It's a promise. Understanding when that promise holds—and when it doesn't—separates developers from engineers."*

---

## What Is ACID?

ACID is an acronym for four properties that database transactions can guarantee:

- **A**tomicity — All or nothing
- **C**onsistency — Valid state to valid state
- **I**solation — Transactions don't interfere
- **D**urability — Committed means committed

Let's make each one tangible.

---

## Atomicity: All or Nothing

### The Problem It Solves

You're transferring $100 from Account A to Account B:

```sql
UPDATE accounts SET balance = balance - 100 WHERE id = 'A';
-- Power failure here
UPDATE accounts SET balance = balance + 100 WHERE id = 'B';
```

Without atomicity, Account A loses $100 but Account B never receives it. Money vanishes.

### Feel Atomicity

```sql
-- Create accounts table
CREATE TABLE accounts (
    id VARCHAR(10) PRIMARY KEY,
    balance DECIMAL(10, 2)
);

INSERT INTO accounts VALUES ('A', 1000), ('B', 500);

-- Successful atomic transfer
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 'A';
UPDATE accounts SET balance = balance + 100 WHERE id = 'B';
COMMIT;

SELECT * FROM accounts;
-- A: 900, B: 600 (correct)
```

Now simulate failure:

```sql
-- Reset
UPDATE accounts SET balance = 1000 WHERE id = 'A';
UPDATE accounts SET balance = 500 WHERE id = 'B';

-- Failed transfer
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 'A';
-- Simulate error
ROLLBACK;

SELECT * FROM accounts;
-- A: 1000, B: 500 (unchanged - atomicity protected us)
```

**First Principle:** Atomicity transforms a multi-step operation into a single logical operation that either fully happens or fully doesn't.

---

## Consistency: Valid State to Valid State

### The Problem It Solves

Consistency means the database moves from one valid state to another. "Valid" is defined by your constraints.

### Feel Consistency

```sql
-- Add a constraint: balance can't go negative
ALTER TABLE accounts ADD CONSTRAINT positive_balance CHECK (balance >= 0);

-- Try to overdraft
BEGIN;
UPDATE accounts SET balance = balance - 2000 WHERE id = 'A';
-- ERROR: new row for relation "accounts" violates check constraint

ROLLBACK;

SELECT * FROM accounts;
-- Unchanged - consistency protected us
```

### Consistency vs Eventual Consistency

**Database consistency** (the C in ACID): Constraints are never violated.

**Eventual consistency** (distributed systems): Different nodes may temporarily disagree.

These are different concepts! A system can be:
- ACID consistent AND eventually consistent (distributed PostgreSQL)
- ACID consistent but NOT eventually consistent (single-node PostgreSQL)
- Eventually consistent but NOT ACID consistent (many NoSQL systems)

---

## Isolation: Transactions Don't Interfere

### The Problem It Solves

Two transactions running simultaneously shouldn't corrupt each other's view of data.

### Feel Isolation Failure

This requires two terminal sessions. Let's see what happens without proper isolation:

**Terminal 1:**
```sql
\c labdb
BEGIN;
SELECT balance FROM accounts WHERE id = 'A';
-- Shows 900

-- Pause here, go to Terminal 2
```

**Terminal 2:**
```sql
\c labdb
BEGIN;
UPDATE accounts SET balance = balance - 50 WHERE id = 'A';
COMMIT;
SELECT balance FROM accounts WHERE id = 'A';
-- Shows 850
```

**Terminal 1 (continue):**
```sql
SELECT balance FROM accounts WHERE id = 'A';
-- What does this show?
-- Depends on isolation level!
COMMIT;
```

With **READ COMMITTED** (PostgreSQL default): Shows 850 (sees committed changes)
With **REPEATABLE READ** (MySQL default): Shows 900 (snapshot at transaction start)

**First Principle:** Isolation levels determine what one transaction can see of another's changes. There's no "correct" level—only trade-offs.

---

## Durability: Committed Means Committed

### The Problem It Solves

Once a transaction commits successfully, the data survives:
- Power failures
- Crashes
- Reboots

### Feel Durability

```sql
-- Insert critical data
BEGIN;
INSERT INTO accounts VALUES ('C', 10000);
COMMIT;
-- Success returned to client

-- Now simulate crash
-- (Don't actually do this in production!)
```

```bash
# Force kill PostgreSQL without clean shutdown
sudo pkill -9 postgres

# Restart
sudo systemctl start postgresql
```

```sql
-- Check if data survived
SELECT * FROM accounts WHERE id = 'C';
-- Shows the $10,000 - durability worked!
```

**First Principle:** Durability is implemented via WAL (Write-Ahead Logging). The commit doesn't return until the WAL is fsynced to disk.

### Test Durability Settings

```sql
-- Check synchronous commit setting
SHOW synchronous_commit;
-- Default: on (fully durable)

-- You can trade durability for speed
SET synchronous_commit = off;
-- Now commits return before WAL is fsynced
-- Faster, but last few transactions may be lost on crash
```

---

## ACID Costs

ACID isn't free. Each property has a cost:

| Property | Cost |
|----------|------|
| Atomicity | Logging overhead, undo capability |
| Consistency | Constraint checking on every operation |
| Isolation | Locking or versioning overhead |
| Durability | Synchronous disk writes |

This is why:
- NoSQL databases often relax ACID for performance
- Databases offer tunable settings
- Understanding trade-offs matters

---

## When ACID Is Non-Negotiable

**Financial transactions**
```sql
-- Money transfer must be atomic
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE id = 'A';
UPDATE accounts SET balance = balance + 100 WHERE id = 'B';
COMMIT;
```

**Inventory management**
```sql
-- Stock decrement must be consistent
BEGIN;
UPDATE inventory SET quantity = quantity - 1
WHERE product_id = 'X' AND quantity > 0;
-- Check affected rows!
COMMIT;
```

**Order processing**
```sql
-- Order + payment must be atomic
BEGIN;
INSERT INTO orders (customer_id, total) VALUES (123, 99.99);
INSERT INTO payments (order_id, amount) VALUES (currval('orders_id_seq'), 99.99);
COMMIT;
```

---

## When ACID Can Be Relaxed

**Analytics/reporting**
```sql
-- Slight staleness is acceptable
SET TRANSACTION READ ONLY;
SELECT COUNT(*) FROM large_events_table;
```

**Session data**
```sql
-- Lost sessions aren't catastrophic
SET synchronous_commit = off;
INSERT INTO sessions (user_id, data) VALUES (123, '...');
```

**Logs/metrics**
```sql
-- Some loss is acceptable for performance
COPY events FROM STDIN WITH (FORMAT csv);
-- Bulk operations with relaxed durability
```

---

## Summary Table

| Property | Guarantee | Mechanism | Cost |
|----------|-----------|-----------|------|
| Atomicity | All or nothing | Undo logs | Space, time |
| Consistency | Constraints hold | Constraint checks | CPU |
| Isolation | No interference | MVCC/Locks | Memory, CPU |
| Durability | Survives crashes | WAL + fsync | Latency |

---

## Verification: You Understand When...

- [ ] You can explain each ACID property with an example
- [ ] You know the difference between ACID consistency and eventual consistency
- [ ] You understand that ACID has costs
- [ ] You can identify when ACID can be relaxed

---

## What's Next?

Now let's dive deep into Isolation—the most complex and nuanced ACID property. Different isolation levels produce dramatically different behaviors, and understanding them is crucial for building correct systems.

---

*Next: [Isolation Levels Lab](./05-isolation-levels-lab.md)*
