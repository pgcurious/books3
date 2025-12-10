# Chapter 16: CockroachDB Serverless

> *"CockroachDB is what happens when you take CAP theorem personally and decide to engineer around it."*

---

## What Is CockroachDB?

CockroachDB is a distributed SQL database that provides:
- PostgreSQL compatibility
- Strong consistency (serializable isolation)
- Automatic sharding and replication
- Survives node, zone, and region failures

### Why CockroachDB for Learning?

- **Free Tier**: 10 GiB storage, 50M Request Units/month
- **PostgreSQL compatible**: Use psql and existing tools
- **Demonstrates consistency**: Counter-example to eventual consistency
- **Multi-region**: Experience geo-distribution

**Budget impact:** $0 (free tier)

---

## The CockroachDB Philosophy

### Eventual Consistency? No Thanks.

Most distributed databases choose availability over consistency (AP in CAP terms). CockroachDB chooses **consistency over availability** (CP).

```
Traditional distributed DB:
Write → Node A → [Async] → Node B
                 ↓
          Client gets ACK before replication

CockroachDB:
Write → Node A → [Consensus with Node B, C] → Client gets ACK
                 ↓
          Guaranteed replicated before ACK
```

### How It Achieves This

1. **Raft consensus**: Every write requires majority acknowledgment
2. **Time-based ordering**: Hybrid Logical Clocks (HLC) for ordering
3. **Serializable isolation**: Default isolation level (strongest)

---

## Setting Up CockroachDB Serverless

### Step 1: Create Account and Cluster

1. Go to [cockroachlabs.com/cloud](https://cockroachlabs.com/cloud)
2. Sign up with GitHub
3. Create cluster:
   - Plan: **Serverless** (free tier)
   - Cloud provider: AWS or GCP
   - Region: Closest to you

### Step 2: Get Connection String

1. Click "Connect"
2. Select "General connection string"
3. Download CA certificate
4. Copy connection string:
   ```
   postgresql://username:password@free-tier.gcp-us-central1.cockroachlabs.cloud:26257/defaultdb?sslmode=verify-full&sslrootcert=/path/to/ca.crt
   ```

### Step 3: Connect with psql

```bash
# Set environment variable for convenience
export COCKROACH_URL="postgresql://username:password@host:26257/defaultdb?sslmode=verify-full"

# Connect
psql "$COCKROACH_URL"
```

### Alternative: Install CockroachDB CLI

```bash
# macOS
brew install cockroachdb/tap/cockroach

# Linux
curl https://binaries.cockroachdb.com/cockroach-latest.linux-amd64.tgz | tar xz
sudo mv cockroach-*/cockroach /usr/local/bin/

# Connect
cockroach sql --url "$COCKROACH_URL"
```

---

## Lab: Experience Strong Consistency

### Setup

```sql
CREATE TABLE bank_accounts (
    id INT PRIMARY KEY,
    balance DECIMAL(10, 2)
);

INSERT INTO bank_accounts VALUES (1, 1000), (2, 1000);
```

### Experiment: Serializable by Default

```sql
-- Check isolation level
SHOW transaction_isolation;
-- Returns: serializable (strongest!)

-- This is the default. In PostgreSQL, default is read committed.
```

### Experiment: Transfer Cannot Violate Consistency

**Terminal 1:**
```sql
BEGIN;
SELECT balance FROM bank_accounts WHERE id = 1;
-- Returns 1000

-- Wait here, go to Terminal 2
```

**Terminal 2:**
```sql
BEGIN;
UPDATE bank_accounts SET balance = balance - 100 WHERE id = 1;
UPDATE bank_accounts SET balance = balance + 100 WHERE id = 2;
COMMIT;
-- Success
```

**Terminal 1:**
```sql
-- Try to use the old balance
UPDATE bank_accounts SET balance = balance - 500 WHERE id = 1;
COMMIT;
-- ERROR: restart transaction: TransactionRetryWithProtoRefreshError:
-- CockroachDB detected concurrent modification and forces retry
```

**Key observation:** CockroachDB prevents write skew anomalies that PostgreSQL (at default settings) would allow!

---

## Lab: Multi-Region Consistency

### Understanding CockroachDB Regions

In CockroachDB Serverless, you can see replication across zones:

```sql
-- Show where your data is replicated
SHOW RANGES FROM TABLE bank_accounts;

-- Show cluster regions
SHOW REGIONS;
```

### Experiment: Consistent Reads Across Regions

Even in a distributed setup, CockroachDB guarantees:

```sql
-- Any node in any region returns the same consistent view
SELECT * FROM bank_accounts WHERE id = 1;
-- Always returns the committed value, never stale data
```

Compare to eventual consistency systems where this read might return old data.

---

## Lab: Follower Reads (Trading Consistency for Latency)

CockroachDB allows opting into slightly stale reads for lower latency:

```sql
-- Normal read: goes to leaseholder (might be far)
SELECT * FROM bank_accounts WHERE id = 1;

-- Follower read: can read from any replica (might be stale by 4.8s)
SELECT * FROM bank_accounts AS OF SYSTEM TIME follower_read_timestamp() WHERE id = 1;

-- Or specify exact staleness
SELECT * FROM bank_accounts AS OF SYSTEM TIME '-5s' WHERE id = 1;
```

### Measure the Difference

```sql
-- Time normal read
\timing on
SELECT * FROM bank_accounts WHERE id = 1;
-- Might be 50-100ms if leaseholder is far

-- Time follower read
SELECT * FROM bank_accounts AS OF SYSTEM TIME follower_read_timestamp() WHERE id = 1;
-- Might be 5-20ms if local replica exists
```

---

## Lab: Automatic Rebalancing

### Observe Data Distribution

```sql
-- See how data is distributed
SELECT
    start_key,
    end_key,
    lease_holder,
    replicas
FROM [SHOW RANGES FROM TABLE bank_accounts];

-- See replica locations
SHOW RANGES FROM TABLE bank_accounts WITH DETAILS;
```

### Experiment: Insert Data and Watch Rebalancing

```sql
-- Insert substantial data
INSERT INTO bank_accounts (id, balance)
SELECT generate_series(3, 10000), 100;

-- Watch ranges split
SELECT count(*) FROM [SHOW RANGES FROM TABLE bank_accounts];
-- Initially 1, grows as data increases
```

---

## Lab: Distributed Transactions

CockroachDB supports transactions that span multiple ranges (shards):

```sql
-- Create tables that will be on different ranges
CREATE TABLE orders (
    id INT PRIMARY KEY,
    customer_id INT,
    total DECIMAL(10, 2)
);

CREATE TABLE inventory (
    product_id INT PRIMARY KEY,
    quantity INT
);

INSERT INTO inventory VALUES (1, 100);

-- Atomic cross-table transaction
BEGIN;
INSERT INTO orders (id, customer_id, total) VALUES (1, 100, 99.99);
UPDATE inventory SET quantity = quantity - 1 WHERE product_id = 1;
COMMIT;
-- This is atomic even though data might be on different nodes!
```

### Why This Matters

In many distributed databases (like PlanetScale/Vitess), cross-shard transactions are either:
- Not supported
- Eventually consistent
- Require special handling

CockroachDB provides them with ACID guarantees automatically.

---

## CockroachDB vs PostgreSQL Differences

| Aspect | PostgreSQL | CockroachDB |
|--------|------------|-------------|
| Default isolation | READ COMMITTED | SERIALIZABLE |
| Distributed | No (without extensions) | Built-in |
| Auto-sharding | No | Yes |
| Foreign keys | Full support | Supported |
| Sequences | Native | Supported but distributed |
| JSON | Full support | Full support |
| Window functions | Full | Most supported |

### Unsupported Features

```sql
-- Some PostgreSQL features not in CockroachDB:
-- - Full-text search (use external service)
-- - Many extensions (PostGIS, pg_trgm)
-- - Some procedural languages
```

---

## Cost Management

### Free Tier Limits

| Metric | Free Limit |
|--------|------------|
| Storage | 10 GiB |
| Request Units | 50 million/month |
| Burst | Up to 2x |

### Monitor Usage

```sql
-- Check table sizes
SELECT
    table_name,
    pg_size_pretty(pg_total_relation_size(table_name::text)) AS size
FROM information_schema.tables
WHERE table_schema = 'public';
```

### In Web Console

1. Go to CockroachDB Cloud Console
2. Select cluster
3. View "Usage" tab

---

## When to Use CockroachDB

### Good For
- Financial transactions (strong consistency)
- Multi-region with consistency requirements
- PostgreSQL compatibility needed
- Automatic sharding desired

### Not Ideal For
- Full-text search heavy workloads
- PostGIS/geospatial
- Maximum write throughput (consensus has overhead)
- Cost-sensitive high-volume workloads

---

## Comparison: CockroachDB vs PlanetScale

| Aspect | CockroachDB | PlanetScale |
|--------|-------------|-------------|
| SQL dialect | PostgreSQL | MySQL |
| Consistency | Strong (serializable) | Eventual (read replicas) |
| Foreign keys | Supported | Not supported |
| Schema changes | Standard DDL | Branch + deploy |
| Distributed TX | Full ACID | Limited |
| Free tier | 10 GiB, 50M RU | 5 GB, 1B reads |

**Choose CockroachDB when:** Consistency is non-negotiable
**Choose PlanetScale when:** Scale and speed matter more than strong consistency

---

## Key Takeaways

1. **Strong consistency is possible** — But with latency trade-offs
2. **Serializable by default** — Prevents anomalies other DBs allow
3. **Distributed transactions work** — ACID across shards
4. **Follower reads opt-in** — Choose consistency vs latency per query
5. **PostgreSQL compatible** — Easy migration path

---

## What's Next?

We've covered local and cloud database setups. The appendix provides a budget breakdown and all lab scripts in one place.

---

*Next: [Budget Breakdown](../appendix/budget-breakdown.md)*
