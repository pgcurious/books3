# Chapter 6: Deadlocks & Locking

> *"A deadlock is two polite people at a door, each insisting the other go first—forever."*

---

## What Is a Deadlock?

A deadlock occurs when two or more transactions wait for each other indefinitely:

```
Transaction A: Holds lock on Row 1, wants lock on Row 2
Transaction B: Holds lock on Row 2, wants lock on Row 1

Both wait forever. Nobody proceeds.
```

---

## Experience a Deadlock

### Setup

```sql
CREATE TABLE inventory (
    product_id VARCHAR(10) PRIMARY KEY,
    quantity INT
);

INSERT INTO inventory VALUES ('A', 100), ('B', 100);
```

### Create the Deadlock

**Terminal 1:**
```sql
BEGIN;
UPDATE inventory SET quantity = quantity - 10 WHERE product_id = 'A';
-- Holds lock on row A
-- Now wait...
```

**Terminal 2:**
```sql
BEGIN;
UPDATE inventory SET quantity = quantity - 10 WHERE product_id = 'B';
-- Holds lock on row B
-- Now try to get A:
UPDATE inventory SET quantity = quantity + 10 WHERE product_id = 'A';
-- Blocks! Waiting for Terminal 1's lock on A
```

**Terminal 1:**
```sql
UPDATE inventory SET quantity = quantity + 10 WHERE product_id = 'B';
-- Tries to get B, but Terminal 2 has it
-- DEADLOCK!
```

### What Happens

PostgreSQL detects the deadlock within ~1 second and kills one transaction:

```
ERROR:  deadlock detected
DETAIL:  Process 12345 waits for ShareLock on transaction 67890;
         blocked by process 67891.
         Process 67891 waits for ShareLock on transaction 12345;
         blocked by process 12345.
HINT:  See server log for query details.
```

**First Principle:** Databases detect deadlocks automatically and abort one transaction (the "victim"). Your code must handle this and retry.

---

## Understanding Lock Types

### Row-Level Locks

```sql
-- Shared lock (multiple readers allowed)
SELECT * FROM inventory WHERE product_id = 'A' FOR SHARE;

-- Exclusive lock (only one holder)
SELECT * FROM inventory WHERE product_id = 'A' FOR UPDATE;
```

### Lock Compatibility Matrix

| Held \ Requested | FOR SHARE | FOR UPDATE |
|-----------------|-----------|------------|
| FOR SHARE | OK | BLOCKED |
| FOR UPDATE | BLOCKED | BLOCKED |

### See Current Locks

```sql
-- View all locks
SELECT
    l.locktype,
    l.relation::regclass AS table,
    l.mode,
    l.granted,
    a.query
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE l.relation IS NOT NULL;
```

---

## Preventing Deadlocks

### Strategy 1: Consistent Lock Ordering

Always acquire locks in the same order:

```sql
-- WRONG: Different transactions lock in different orders
-- Transaction 1: A then B
-- Transaction 2: B then A
-- Result: Deadlock possible

-- RIGHT: Both transactions lock A first, then B
BEGIN;
SELECT * FROM inventory WHERE product_id = 'A' FOR UPDATE;
SELECT * FROM inventory WHERE product_id = 'B' FOR UPDATE;
-- Now do work...
COMMIT;
```

### Strategy 2: Lock Timeout

```sql
-- PostgreSQL: Set lock timeout
SET lock_timeout = '5s';

BEGIN;
SELECT * FROM inventory WHERE product_id = 'A' FOR UPDATE;
-- If lock not acquired in 5 seconds, fail instead of waiting
```

### Strategy 3: NOWAIT

```sql
-- Fail immediately if lock not available
BEGIN;
SELECT * FROM inventory WHERE product_id = 'A' FOR UPDATE NOWAIT;
-- Either gets lock immediately or fails with:
-- ERROR: could not obtain lock on row in relation "inventory"
```

### Strategy 4: SKIP LOCKED

```sql
-- Process only unlocked rows (great for job queues)
SELECT * FROM jobs WHERE status = 'pending'
ORDER BY created_at
LIMIT 1
FOR UPDATE SKIP LOCKED;
```

---

## Lab: Job Queue Without Deadlocks

Let's build a robust job queue that multiple workers can process safely.

### Setup

```sql
CREATE TABLE jobs (
    id SERIAL PRIMARY KEY,
    payload JSONB,
    status VARCHAR(20) DEFAULT 'pending',
    worker_id VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW(),
    started_at TIMESTAMP,
    completed_at TIMESTAMP
);

-- Insert test jobs
INSERT INTO jobs (payload)
SELECT jsonb_build_object('task', 'process_' || i)
FROM generate_series(1, 100) AS i;
```

### Worker Pattern (Safe)

```sql
-- Each worker runs this:
BEGIN;

-- Claim a job atomically (SKIP LOCKED prevents conflicts)
UPDATE jobs
SET
    status = 'processing',
    worker_id = 'worker_1',  -- Use actual worker ID
    started_at = NOW()
WHERE id = (
    SELECT id FROM jobs
    WHERE status = 'pending'
    ORDER BY created_at
    LIMIT 1
    FOR UPDATE SKIP LOCKED
)
RETURNING *;

-- Process the job (application logic here)

-- Mark complete
UPDATE jobs
SET status = 'completed', completed_at = NOW()
WHERE id = <job_id>;

COMMIT;
```

**Why this works:**
- `FOR UPDATE` locks the row we're claiming
- `SKIP LOCKED` means other workers skip locked rows
- No deadlocks because each worker only holds one row lock

---

## Advisory Locks

For application-level locking (not tied to rows):

```sql
-- Acquire lock (blocks if unavailable)
SELECT pg_advisory_lock(12345);

-- Try to acquire (returns immediately)
SELECT pg_try_advisory_lock(12345);
-- Returns true if acquired, false if not

-- Release
SELECT pg_advisory_unlock(12345);

-- Session-level: held until session ends or explicit unlock
-- Transaction-level: released at end of transaction
SELECT pg_advisory_xact_lock(12345);
```

### Use Case: Prevent Duplicate Cron Jobs

```sql
-- At start of cron job:
SELECT pg_try_advisory_lock(hashtext('daily_report'));
-- If returns false, another instance is running - exit

-- Do work...

SELECT pg_advisory_unlock(hashtext('daily_report'));
```

---

## Table-Level Locks

```sql
-- Exclusive table lock (blocks all other access)
LOCK TABLE inventory IN EXCLUSIVE MODE;

-- Access share (allows reads, blocks schema changes)
LOCK TABLE inventory IN ACCESS SHARE MODE;
```

### Lock Modes and Conflicts

```sql
-- See all lock modes
SELECT * FROM pg_locks WHERE relation = 'inventory'::regclass;
```

| Mode | Conflicts With |
|------|---------------|
| ACCESS SHARE | ACCESS EXCLUSIVE |
| ROW SHARE | EXCLUSIVE, ACCESS EXCLUSIVE |
| ROW EXCLUSIVE | SHARE, SHARE ROW EXCLUSIVE, EXCLUSIVE, ACCESS EXCLUSIVE |
| SHARE | ROW EXCLUSIVE, SHARE ROW EXCLUSIVE, EXCLUSIVE, ACCESS EXCLUSIVE |
| ACCESS EXCLUSIVE | All modes |

---

## Deadlock Detection Settings

```sql
-- Check deadlock detection timeout
SHOW deadlock_timeout;
-- Default: 1s (PostgreSQL checks for deadlocks after this delay)

-- Adjust if needed
SET deadlock_timeout = '500ms';
```

---

## Handling Deadlocks in Application Code

```python
# Python example (pseudocode)
import psycopg2
import time

MAX_RETRIES = 3
RETRY_DELAY = 0.1  # seconds

def transfer_funds(from_account, to_account, amount):
    for attempt in range(MAX_RETRIES):
        try:
            with connection.cursor() as cur:
                cur.execute("BEGIN")

                # Lock in consistent order (lower ID first)
                accounts = sorted([from_account, to_account])
                for acc in accounts:
                    cur.execute(
                        "SELECT balance FROM accounts WHERE id = %s FOR UPDATE",
                        (acc,)
                    )

                # Do the transfer
                cur.execute(
                    "UPDATE accounts SET balance = balance - %s WHERE id = %s",
                    (amount, from_account)
                )
                cur.execute(
                    "UPDATE accounts SET balance = balance + %s WHERE id = %s",
                    (amount, to_account)
                )

                cur.execute("COMMIT")
                return True

        except psycopg2.errors.DeadlockDetected:
            connection.rollback()
            if attempt < MAX_RETRIES - 1:
                time.sleep(RETRY_DELAY * (2 ** attempt))  # Exponential backoff
                continue
            raise

        except psycopg2.errors.LockNotAvailable:
            connection.rollback()
            # Handle timeout - maybe retry or return error
            raise

    return False
```

---

## Monitoring Lock Contention

```sql
-- Find blocked queries
SELECT
    blocked.pid AS blocked_pid,
    blocked.query AS blocked_query,
    blocking.pid AS blocking_pid,
    blocking.query AS blocking_query
FROM pg_stat_activity blocked
JOIN pg_locks blocked_locks ON blocked.pid = blocked_locks.pid
JOIN pg_locks blocking_locks ON blocked_locks.locktype = blocking_locks.locktype
    AND blocked_locks.relation = blocking_locks.relation
    AND blocked_locks.pid != blocking_locks.pid
JOIN pg_stat_activity blocking ON blocking_locks.pid = blocking.pid
WHERE NOT blocked_locks.granted;

-- Find long-held locks
SELECT
    pid,
    now() - pg_stat_activity.query_start AS duration,
    query,
    state
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes'
  AND state != 'idle';
```

---

## Key Takeaways

1. **Deadlocks are normal** — Expect them, handle them with retries
2. **Consistent ordering** — Lock resources in the same order everywhere
3. **Use timeouts** — Don't wait forever for locks
4. **SKIP LOCKED** — For queue patterns, skip what you can't lock
5. **Monitor locks** — Identify contention before it becomes a problem

---

## Verification Checklist

- [ ] You've experienced a real deadlock
- [ ] You understand the difference between FOR UPDATE and FOR SHARE
- [ ] You can explain SKIP LOCKED and when to use it
- [ ] You know how to handle deadlocks in application code
- [ ] You can query current locks in the database

---

*Next: [How Indexes Work](../PART-3-INDEXING/07-how-indexes-work.md)*
