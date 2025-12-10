# Chapter 13: Conflict Resolution

> *"In distributed systems, conflicts aren't bugs—they're features you haven't handled yet."*

---

## When Do Conflicts Occur?

Conflicts happen when:
1. Two writes happen to the same data concurrently
2. A network partition causes split-brain scenarios
3. Async replication allows conflicting changes

### Single-Primary vs Multi-Primary

| Topology | Conflict Scenario |
|----------|-------------------|
| Single-Primary | Rare (only during failover) |
| Multi-Primary | Common (concurrent writes anywhere) |
| Multi-Region | Very common (latency between regions) |

---

## Conflict Types

### Write-Write Conflict

```
Region A: UPDATE users SET name = 'Alice' WHERE id = 1;
Region B: UPDATE users SET name = 'Alicia' WHERE id = 1;

Both succeed locally. Which value wins?
```

### Insert-Insert Conflict

```
Region A: INSERT INTO users (id, name) VALUES (1, 'Alice');
Region B: INSERT INTO users (id, name) VALUES (1, 'Bob');

Same primary key, different data.
```

### Update-Delete Conflict

```
Region A: UPDATE users SET name = 'Alice2' WHERE id = 1;
Region B: DELETE FROM users WHERE id = 1;

Update a deleted row?
```

---

## Resolution Strategy 1: Last Writer Wins (LWW)

The simplest approach: highest timestamp wins.

### Implementation

```sql
-- Add timestamp to every row
ALTER TABLE users ADD COLUMN last_modified TIMESTAMP DEFAULT NOW();

-- On conflict, compare timestamps
CREATE OR REPLACE FUNCTION resolve_lww()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.last_modified > OLD.last_modified THEN
        RETURN NEW;
    ELSE
        RETURN OLD;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_lww_trigger
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION resolve_lww();
```

### The Problem with LWW

```
Time 0:    User value = 100
Time 1ms:  Region A sets value = 150
Time 2ms:  Region B sets value = 120 (didn't see A's update)

LWW result: value = 120 (newer timestamp wins)
But user in Region A expected: value = 150

User's work is silently lost!
```

### When LWW Is Acceptable

- Session data (latest session matters)
- User preferences (last choice wins)
- Status fields (current status matters)

### When LWW Is Dangerous

- Financial data (money shouldn't disappear)
- Counters (like counts, inventory)
- Collaborative editing (user work lost)

---

## Resolution Strategy 2: Merge on Read

Don't resolve at write time—store all versions and let the application decide.

### Implementation

```sql
-- Store multiple versions
CREATE TABLE user_data (
    user_id INT,
    field_name VARCHAR(50),
    field_value TEXT,
    vector_clock JSONB,  -- For causal ordering
    PRIMARY KEY (user_id, field_name, vector_clock)
);

-- Insert both conflicting values
INSERT INTO user_data VALUES
    (1, 'name', 'Alice', '{"A": 1}'::jsonb),
    (1, 'name', 'Alicia', '{"B": 1}'::jsonb);

-- Read returns all versions
SELECT * FROM user_data WHERE user_id = 1 AND field_name = 'name';
-- Application must merge or prompt user
```

### Application-Level Merge

```python
def get_user_name(user_id):
    versions = db.query("""
        SELECT field_value, vector_clock
        FROM user_data
        WHERE user_id = %s AND field_name = 'name'
    """, user_id)

    if len(versions) == 1:
        return versions[0].field_value

    # Multiple versions - need resolution
    if user_is_online():
        # Ask user to resolve
        return prompt_user_to_choose(versions)
    else:
        # Automatic resolution fallback
        return max(versions, key=lambda v: v.vector_clock).field_value
```

---

## Resolution Strategy 3: CRDTs (Conflict-Free Replicated Data Types)

Data structures mathematically guaranteed to merge without conflicts.

### G-Counter (Grow-Only Counter)

```sql
-- Each node has its own counter
CREATE TABLE g_counter (
    entity_id INT,
    node_id VARCHAR(20),
    count INT DEFAULT 0,
    PRIMARY KEY (entity_id, node_id)
);

-- Node A increments
UPDATE g_counter SET count = count + 1
WHERE entity_id = 1 AND node_id = 'A';

-- Node B increments
UPDATE g_counter SET count = count + 1
WHERE entity_id = 1 AND node_id = 'B';

-- Total is always sum of all nodes
SELECT entity_id, SUM(count) as total
FROM g_counter
GROUP BY entity_id;
```

**Why it works:** Each node only increments its own counter. No conflicts possible.

### PN-Counter (Positive-Negative Counter)

```sql
-- Supports both increment and decrement
CREATE TABLE pn_counter (
    entity_id INT,
    node_id VARCHAR(20),
    positive INT DEFAULT 0,
    negative INT DEFAULT 0,
    PRIMARY KEY (entity_id, node_id)
);

-- Increment at Node A
UPDATE pn_counter SET positive = positive + 1
WHERE entity_id = 1 AND node_id = 'A';

-- Decrement at Node B
UPDATE pn_counter SET negative = negative + 1
WHERE entity_id = 1 AND node_id = 'B';

-- Value is sum(positive) - sum(negative)
SELECT entity_id,
       SUM(positive) - SUM(negative) as value
FROM pn_counter
GROUP BY entity_id;
```

### LWW-Register (Last-Writer-Wins Register)

```sql
CREATE TABLE lww_register (
    key VARCHAR(50) PRIMARY KEY,
    value TEXT,
    timestamp TIMESTAMP WITH TIME ZONE
);

-- Merge function: take higher timestamp
CREATE OR REPLACE FUNCTION merge_lww_register(
    key_in VARCHAR,
    value_in TEXT,
    timestamp_in TIMESTAMP WITH TIME ZONE
) RETURNS VOID AS $$
BEGIN
    INSERT INTO lww_register (key, value, timestamp)
    VALUES (key_in, value_in, timestamp_in)
    ON CONFLICT (key) DO UPDATE
    SET value = CASE
            WHEN EXCLUDED.timestamp > lww_register.timestamp
            THEN EXCLUDED.value
            ELSE lww_register.value
        END,
        timestamp = GREATEST(EXCLUDED.timestamp, lww_register.timestamp);
END;
$$ LANGUAGE plpgsql;
```

### OR-Set (Observed-Remove Set)

```sql
-- Set that supports add and remove without conflicts
CREATE TABLE or_set (
    set_id INT,
    element TEXT,
    add_tag UUID,
    removed BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (set_id, element, add_tag)
);

-- Add element
INSERT INTO or_set (set_id, element, add_tag)
VALUES (1, 'apple', gen_random_uuid());

-- Remove element (marks all adds as removed)
UPDATE or_set SET removed = TRUE
WHERE set_id = 1 AND element = 'apple';

-- Query current members
SELECT DISTINCT element FROM or_set
WHERE set_id = 1
GROUP BY element
HAVING bool_or(NOT removed);
```

---

## Resolution Strategy 4: Operational Transformation

Used in collaborative editing (Google Docs).

### The Idea

Instead of storing state, store operations and transform them.

```
Initial: "Hello"

User A: Insert 'X' at position 0 → "XHello"
User B: Insert 'Y' at position 5 → "HelloY"

If B's operation arrives at A:
  Original: Insert 'Y' at position 5
  Transformed: Insert 'Y' at position 6 (account for X)
  Result at A: "XHelloY"

If A's operation arrives at B:
  Original: Insert 'X' at position 0
  No transformation needed
  Result at B: "XHelloY"

Both converge to same state!
```

### When to Use

- Real-time collaboration
- Text editing
- Document editing

---

## Lab: Implement a CRDT Counter

```sql
-- Create the CRDT counter table
CREATE TABLE crdt_likes (
    post_id INT,
    node_id VARCHAR(20),
    like_count INT DEFAULT 0,
    PRIMARY KEY (post_id, node_id)
);

-- Initialize counters for a post (one per "node")
INSERT INTO crdt_likes VALUES
    (1, 'server_us', 0),
    (1, 'server_eu', 0),
    (1, 'server_asia', 0);

-- Simulate likes from different regions
UPDATE crdt_likes SET like_count = like_count + 5
WHERE post_id = 1 AND node_id = 'server_us';

UPDATE crdt_likes SET like_count = like_count + 3
WHERE post_id = 1 AND node_id = 'server_eu';

UPDATE crdt_likes SET like_count = like_count + 7
WHERE post_id = 1 AND node_id = 'server_asia';

-- Get total likes (always correct, regardless of replication order)
SELECT post_id, SUM(like_count) as total_likes
FROM crdt_likes
GROUP BY post_id;
-- Returns 15 - correct!

-- Even if data replicates out of order, sum is always correct
```

---

## Choosing a Resolution Strategy

| Scenario | Recommended Strategy |
|----------|---------------------|
| User preferences | LWW |
| Counters (likes, views) | CRDT Counter |
| Shopping carts | OR-Set |
| Collaborative editing | Operational Transformation |
| Financial transactions | Avoid conflicts (use single leader) |
| Comments/posts | LWW with vector clocks |

---

## Key Takeaways

1. **Conflicts are inevitable** in distributed systems
2. **LWW is simple but lossy** — use when losing data is acceptable
3. **CRDTs are powerful** — mathematically conflict-free
4. **Application context matters** — choose strategy based on use case
5. **Sometimes avoid conflicts** — single leader for critical data

---

## What's Next?

Now that you understand replication and consistency locally, let's explore cloud options that provide these features at scale—while staying within your $100 budget.

---

*Next: [AWS RDS & Aurora](../PART-5-CLOUD-OPTIONS/14-aws-rds-aurora.md)*
