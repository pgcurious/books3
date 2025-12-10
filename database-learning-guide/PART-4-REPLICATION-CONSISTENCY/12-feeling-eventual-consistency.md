# Chapter 12: Feeling Eventual Consistency

> *"Eventual consistency isn't a bug—it's physics manifesting in software."*

---

## What Does "Eventually Consistent" Actually Feel Like?

In theory, eventual consistency means "replicas converge over time." In practice, it means:

- You write data and immediately read stale data
- Different users see different versions of truth
- Your app logic must handle temporal uncertainty

Let's make this visceral.

---

## Experiment 1: The Disappearing Write

Using our Docker setup from the previous chapter:

### Setup

```bash
# Ensure cluster is running
cd ~/db-replication-lab
docker-compose up -d

# Reset data
docker exec -it pg-primary psql -U labuser -d labdb -c "
DROP TABLE IF EXISTS user_sessions;
CREATE TABLE user_sessions (
    session_id VARCHAR(50) PRIMARY KEY,
    user_id INT,
    data JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);
"
```

### The Scenario

```bash
# Simulate a user logging in
# Write goes to Primary
docker exec -it pg-primary psql -U labuser -d labdb -c "
INSERT INTO user_sessions (session_id, user_id, data)
VALUES ('sess_12345', 100, '{\"logged_in\": true}');
"

# User's next request is load-balanced to Replica
# Query happens before replication
docker exec -it pg-replica psql -U labuser -d labdb -c "
SELECT * FROM user_sessions WHERE session_id = 'sess_12345';
"
```

**Possible outcomes:**
- If lag < request timing: Session found
- If lag > request timing: **Session not found!** User appears logged out.

### Make It Reproducible

```bash
# Add artificial delay to replica
docker exec --privileged pg-replica bash -c "tc qdisc add dev eth0 root netem delay 200ms 2>/dev/null || true"

# Write to primary
docker exec -it pg-primary psql -U labuser -d labdb -c "
INSERT INTO user_sessions (session_id, user_id, data)
VALUES ('sess_abcde', 200, '{\"logged_in\": true}');
SELECT 'Written at', NOW();
"

# Immediately read from replica
docker exec -it pg-replica psql -U labuser -d labdb -c "
SELECT 'Reading at', NOW();
SELECT * FROM user_sessions WHERE session_id = 'sess_abcde';
"
# Likely returns empty due to 200ms delay!

# Wait and try again
sleep 1
docker exec -it pg-replica psql -U labuser -d labdb -c "
SELECT * FROM user_sessions WHERE session_id = 'sess_abcde';
"
# Now it appears!

# Clean up delay
docker exec --privileged pg-replica bash -c "tc qdisc del dev eth0 root 2>/dev/null || true"
```

---

## Experiment 2: Read-Your-Writes Violation

### The Scenario: User Updates Profile

```bash
# User updates their name on Primary
docker exec -it pg-primary psql -U labuser -d labdb -c "
CREATE TABLE IF NOT EXISTS profiles (
    user_id INT PRIMARY KEY,
    name VARCHAR(100),
    updated_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO profiles VALUES (1, 'Original Name', NOW())
ON CONFLICT (user_id) DO UPDATE SET name = 'Original Name', updated_at = NOW();
"

# Add delay
docker exec --privileged pg-replica bash -c "tc qdisc add dev eth0 root netem delay 500ms 2>/dev/null || true"

# User changes name (write to Primary)
echo "User changes name..."
docker exec -it pg-primary psql -U labuser -d labdb -c "
UPDATE profiles SET name = 'New Name', updated_at = NOW() WHERE user_id = 1;
SELECT 'Updated to New Name at', NOW();
"

# User refreshes page (read from Replica)
echo "User reads their profile..."
docker exec -it pg-replica psql -U labuser -d labdb -c "
SELECT 'Reading at', NOW(), name FROM profiles WHERE user_id = 1;
"
# Shows "Original Name" - user thinks update failed!

# Clean up
docker exec --privileged pg-replica bash -c "tc qdisc del dev eth0 root 2>/dev/null || true"
```

**User experience:** "I just changed my name but it still shows the old one. Is this site broken?"

---

## Experiment 3: Counter Inconsistency

### The Scenario: Like Counter

```bash
# Setup
docker exec -it pg-primary psql -U labuser -d labdb -c "
CREATE TABLE IF NOT EXISTS posts (
    post_id INT PRIMARY KEY,
    likes INT DEFAULT 0
);

INSERT INTO posts VALUES (1, 100) ON CONFLICT DO NOTHING;
"

# Add moderate delay
docker exec --privileged pg-replica bash -c "tc qdisc add dev eth0 root netem delay 100ms 2>/dev/null || true"
```

### Simulate Multiple Users

```bash
# User A likes the post (write to Primary)
docker exec -it pg-primary psql -U labuser -d labdb -c "
UPDATE posts SET likes = likes + 1 WHERE post_id = 1;
"

# User A sees result (read from Primary)
echo "User A sees:"
docker exec -it pg-primary psql -U labuser -d labdb -t -c "
SELECT likes FROM posts WHERE post_id = 1;
"
# Shows 101

# User B loads page (read from Replica)
echo "User B sees:"
docker exec -it pg-replica psql -U labuser -d labdb -t -c "
SELECT likes FROM posts WHERE post_id = 1;
"
# Might show 100 (stale!)

# Clean up
docker exec --privileged pg-replica bash -c "tc qdisc del dev eth0 root 2>/dev/null || true"
```

---

## Experiment 4: Causal Consistency Violation

### The Scenario: Comment Thread

User A posts a message. User B replies. User C sees the reply but not the original message.

```bash
# Setup
docker exec -it pg-primary psql -U labuser -d labdb -c "
CREATE TABLE IF NOT EXISTS comments (
    id SERIAL PRIMARY KEY,
    parent_id INT REFERENCES comments(id),
    author VARCHAR(50),
    content TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);
"

# Add delay
docker exec --privileged pg-replica bash -c "tc qdisc add dev eth0 root netem delay 300ms 2>/dev/null || true"
```

### Run the Scenario

```bash
# User A posts original message (Primary)
docker exec -it pg-primary psql -U labuser -d labdb -c "
INSERT INTO comments (author, content) VALUES ('UserA', 'Original post') RETURNING id;
"
# Returns id = 1

# User B replies immediately (Primary)
docker exec -it pg-primary psql -U labuser -d labdb -c "
INSERT INTO comments (parent_id, author, content) VALUES (1, 'UserB', 'This is a reply') RETURNING id;
"

# User C loads page (Replica) during replication
# Due to timing, might see reply but not original!
docker exec -it pg-replica psql -U labuser -d labdb -c "
SELECT id, parent_id, author, content FROM comments ORDER BY id;
"
# Possible result: Only see the reply with parent_id=1, but no id=1!

# Clean up
docker exec --privileged pg-replica bash -c "tc qdisc del dev eth0 root 2>/dev/null || true"
```

---

## Experiment 5: Measuring Real-World Lag

### Create a Lag Measurement Script

```bash
cat > measure_lag.sh << 'EOF'
#!/bin/bash

# Write a timestamped record to Primary
WRITE_TIME=$(date +%s.%N)
docker exec pg-primary psql -U labuser -d labdb -t -c "
INSERT INTO lag_test (write_time) VALUES ($WRITE_TIME) RETURNING id;
" | tr -d ' '

# Poll Replica until we see it
while true; do
    READ_TIME=$(date +%s.%N)
    FOUND=$(docker exec pg-replica psql -U labuser -d labdb -t -c "
    SELECT COUNT(*) FROM lag_test WHERE write_time = $WRITE_TIME;
    " | tr -d ' ')

    if [ "$FOUND" = "1" ]; then
        LAG=$(echo "$READ_TIME - $WRITE_TIME" | bc)
        echo "Replication lag: ${LAG}s"
        break
    fi

    sleep 0.01
done
EOF

chmod +x measure_lag.sh

# Setup table
docker exec -it pg-primary psql -U labuser -d labdb -c "
CREATE TABLE IF NOT EXISTS lag_test (
    id SERIAL PRIMARY KEY,
    write_time NUMERIC
);
"

# Run measurement
./measure_lag.sh
./measure_lag.sh
./measure_lag.sh
```

---

## How Applications Handle Eventual Consistency

### Pattern 1: Read-Your-Writes with Session Affinity

```python
# Pseudocode
def get_connection(user_session):
    if user_session.recently_wrote:
        return primary_connection  # Route to primary
    else:
        return replica_connection  # OK to use replica

def write_data(user_session, data):
    primary_connection.execute(data)
    user_session.recently_wrote = True
    user_session.write_timestamp = now()

def read_data(user_session, query):
    # If wrote recently, read from primary
    if user_session.recently_wrote and (now() - user_session.write_timestamp) < 5_seconds:
        return primary_connection.execute(query)
    else:
        return replica_connection.execute(query)
```

### Pattern 2: Optimistic UI

```javascript
// Frontend code
async function likePost(postId) {
    // Immediately update UI (optimistic)
    setLikeCount(currentCount + 1);

    // Send to server
    try {
        await api.likePost(postId);
    } catch (error) {
        // Revert on failure
        setLikeCount(currentCount);
    }
}
```

### Pattern 3: Version Vectors / Timestamps

```sql
-- Include version in responses
SELECT id, name, updated_at, pg_current_wal_lsn() as version
FROM profiles WHERE user_id = 1;

-- Client sends version back
-- Server ensures reading from replica that's caught up to that version
```

### Pattern 4: Conflict Detection

```sql
-- Optimistic locking with version numbers
UPDATE profiles
SET name = 'New Name', version = version + 1
WHERE user_id = 1 AND version = 5;  -- Expected version

-- If affected_rows = 0, someone else modified it
```

---

## Key Takeaways

After these experiments, you've experienced:

1. **Writes can "disappear"** — Query replica too fast after writing to primary
2. **Read-your-writes is not guaranteed** — Must be implemented explicitly
3. **Different users see different data** — At the same moment in time
4. **Causal order can be violated** — Replies before original posts
5. **Lag is variable** — Sometimes milliseconds, sometimes seconds

---

## The Mental Model

Think of eventual consistency like shipping packages:

```
You:      "I sent the package" (write committed)
Replica:  "Package not arrived yet" (replication lag)
You:      "Where's my package?!" (read-your-writes violation)
Later:    "Package arrived" (eventually consistent)
```

The package was always going to arrive. But "sent" doesn't mean "received."

---

## What's Next?

Now that you've felt eventual consistency locally, let's explore how to handle conflicts when they occur.

---

*Next: [Conflict Resolution](./13-conflict-resolution.md)*
