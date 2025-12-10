# Chapter 15: PlanetScale (Distributed MySQL)

> *"PlanetScale is MySQL that took distributed systems classes."*

---

## What Is PlanetScale?

PlanetScale is a serverless MySQL-compatible database built on Vitess (the technology powering YouTube's database infrastructure).

### Why PlanetScale for Learning?

- **Free Tier**: 5GB storage, 1 billion row reads/month
- **Branch-based workflow**: Like Git for your database
- **Built-in sharding**: Experience distributed database concepts
- **No connection pooling needed**: Serverless-friendly

**Budget impact:** $0 (free tier)

---

## Key Concepts

### Database Branches

PlanetScale treats schemas like code branches:

```
main (production)
  └── dev (development)
       └── feature-add-users (feature branch)
```

Changes are merged through **deploy requests** (like pull requests).

### Non-Blocking Schema Changes

PlanetScale applies schema changes without locking tables:

```sql
-- This doesn't block reads/writes
ALTER TABLE users ADD COLUMN age INT;
```

Traditional MySQL would lock the table. PlanetScale doesn't.

---

## Setting Up PlanetScale

### Step 1: Create Account and Database

1. Go to [planetscale.com](https://planetscale.com)
2. Sign up with GitHub
3. Create organization
4. Create database:
   - Name: `learning-db`
   - Region: Closest to you
   - Plan: Free

### Step 2: Install CLI

```bash
# macOS
brew install planetscale/tap/pscale

# Linux
curl -L https://github.com/planetscale/cli/releases/latest/download/pscale_linux_amd64.tar.gz | tar xz
sudo mv pscale /usr/local/bin/

# Authenticate
pscale auth login
```

### Step 3: Connect

```bash
# Open a MySQL shell to your database
pscale shell learning-db main

# Or get connection string
pscale connect learning-db main --port 3309
# Then connect with any MySQL client:
mysql -h 127.0.0.1 -P 3309 -u root
```

---

## Lab: Experience Distributed MySQL

### Create Test Schema

```bash
pscale shell learning-db main
```

```sql
-- Create tables
CREATE TABLE users (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    email VARCHAR(255) UNIQUE,
    name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE posts (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT,
    title VARCHAR(255),
    content TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_user_id (user_id)
);

-- Insert test data
INSERT INTO users (email, name) VALUES
    ('alice@example.com', 'Alice'),
    ('bob@example.com', 'Bob');

INSERT INTO posts (user_id, title, content) VALUES
    (1, 'First Post', 'Hello from Alice'),
    (2, 'Bob''s Post', 'Hello from Bob');
```

### Observe: No Foreign Keys

```sql
-- This will fail on PlanetScale!
ALTER TABLE posts ADD CONSTRAINT fk_user
FOREIGN KEY (user_id) REFERENCES users(id);

-- Error: PlanetScale doesn't support foreign key constraints
```

**Why?** Foreign keys require cross-shard transactions in a distributed database. PlanetScale trades foreign keys for horizontal scalability.

**Alternative:** Enforce relationships in application code.

---

## Lab: Branch-Based Development

### Create Development Branch

```bash
# Create branch from main
pscale branch create learning-db dev

# Connect to dev branch
pscale shell learning-db dev
```

### Make Schema Changes on Branch

```sql
-- On dev branch
ALTER TABLE users ADD COLUMN phone VARCHAR(20);
ALTER TABLE users ADD COLUMN verified BOOLEAN DEFAULT FALSE;

-- Verify
DESCRIBE users;
```

### Create Deploy Request

```bash
# Create deploy request (like a PR)
pscale deploy-request create learning-db dev

# List deploy requests
pscale deploy-request list learning-db

# Deploy to main
pscale deploy-request deploy learning-db <deploy-request-number>
```

### Verify on Main

```bash
pscale shell learning-db main
```

```sql
DESCRIBE users;
-- Now has phone and verified columns!
```

---

## Lab: Experience Non-Blocking Schema Changes

### Setup

```sql
-- Create a large table
CREATE TABLE large_table (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    data VARCHAR(255)
);

-- Insert 100,000 rows
INSERT INTO large_table (data)
SELECT CONCAT('data_', seq)
FROM (
    SELECT @row := @row + 1 as seq
    FROM (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3) t1,
         (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3) t2,
         (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3) t3,
         (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3) t4,
         (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3) t5,
         (SELECT @row := 0) r
) numbers
LIMIT 100000;
```

### Run Schema Change While Querying

**Terminal 1:** Continuous reads
```bash
pscale shell learning-db main
```
```sql
-- Run continuously
SELECT COUNT(*) FROM large_table;
-- Keep running and note response times
```

**Terminal 2:** Schema change (branch workflow)
```bash
pscale branch create learning-db schema-change
pscale shell learning-db schema-change
```
```sql
ALTER TABLE large_table ADD COLUMN new_column INT;
```

**Observe:** Terminal 1 queries continue without blocking!

---

## Lab: Multi-Region (Paid Feature Demo)

PlanetScale supports multi-region deployments for global distribution.

### Conceptual Architecture

```
US-East (Primary)
    ├── Read Replica: US-West
    ├── Read Replica: EU-West
    └── Read Replica: Asia-Pacific

Write → US-East → Replicated to all regions
Read → Routed to nearest region
```

### What You'd Experience

- Write in US-East: ~20ms
- Read in US-West (from US-West replica): ~5ms
- Read in EU-West (from EU replica): ~10ms
- Read in Asia-Pacific (from Asia replica): ~15ms

**Replication lag:** Typically 100-500ms between regions.

### Demo Script (Conceptual)

```python
# Pseudocode for multi-region experience
import planetscale

# Connection automatically routes to nearest replica for reads
db = planetscale.connect("learning-db")

# Write goes to primary (might be far)
db.execute("INSERT INTO events (data) VALUES ('test')")  # ~100ms from EU

# Read from local replica (fast)
db.execute("SELECT * FROM events")  # ~10ms from EU replica

# But might get stale data due to replication lag!
```

---

## PlanetScale Insights (Monitoring)

### View Query Analytics

```bash
# Via CLI
pscale shell learning-db main
```

```sql
-- Show slow queries (PlanetScale-specific)
SHOW QUERIES;
```

### Web Dashboard

1. Go to PlanetScale dashboard
2. Select your database
3. Click "Insights"
4. View:
   - Query latency
   - Rows read/written
   - Connections

---

## Cost Management

### Free Tier Limits

| Metric | Free Limit |
|--------|------------|
| Storage | 5 GB |
| Row reads | 1 billion/month |
| Row writes | 10 million/month |
| Branches | 1 production, 1 development |

### Check Usage

```bash
pscale org usage show
```

### Stay Under Limits

```sql
-- Monitor your table sizes
SELECT
    table_name,
    ROUND(data_length / 1024 / 1024, 2) AS data_mb,
    table_rows
FROM information_schema.tables
WHERE table_schema = 'learning-db';
```

---

## Key Differences from Traditional MySQL

| Feature | Traditional MySQL | PlanetScale |
|---------|-------------------|-------------|
| Foreign keys | Supported | Not supported |
| Connections | Connection pooling needed | Serverless |
| Schema changes | Blocking | Non-blocking |
| Backups | Manual | Automatic |
| Scaling | Vertical | Horizontal (Vitess) |

---

## Key Takeaways

1. **Branch workflow is powerful** — Schema changes like code changes
2. **No foreign keys** — Trade-off for horizontal scalability
3. **Non-blocking DDL** — Schema changes don't lock tables
4. **Generous free tier** — 5GB storage, 1B reads/month
5. **Good for learning** — Experience distributed database patterns

---

## What's Next?

Let's explore CockroachDB—a distributed PostgreSQL-compatible database that provides strong consistency across regions.

---

*Next: [CockroachDB Serverless](./16-cockroachdb.md)*
