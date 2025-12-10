# Chapter 14: AWS RDS & Aurora

> *"The cloud doesn't eliminate complexity—it relocates it to someone else's data center and charges by the hour."*

---

## Why AWS for Learning?

AWS offers:
- **Free Tier**: 750 hours/month of RDS for 12 months
- **Real-world relevance**: Most common cloud database platform
- **Full-featured**: Read replicas, multi-AZ, monitoring

**Budget impact:** $0 with Free Tier (careful with settings)

---

## AWS RDS Free Tier Details

| Resource | Free Tier Limit |
|----------|----------------|
| Instance hours | 750 hours/month (db.t2.micro or db.t3.micro) |
| Storage | 20 GB General Purpose SSD |
| Backup | 20 GB |
| Data transfer | 1 GB outbound/month |

**Key constraint:** Must use `db.t2.micro` or `db.t3.micro` instance class.

---

## Setting Up RDS PostgreSQL

### Step 1: Create RDS Instance (Console)

1. Go to AWS Console → RDS → Create Database
2. Choose:
   - **Engine**: PostgreSQL
   - **Template**: Free tier
   - **DB Instance Class**: db.t3.micro
   - **Storage**: 20 GB (SSD)
   - **Multi-AZ**: No (costs extra)
   - **Public Access**: Yes (for learning; No for production)

3. Note your:
   - Endpoint (hostname)
   - Port (5432)
   - Username/Password

### Step 2: Configure Security Group

1. Find the security group attached to your RDS instance
2. Add inbound rule:
   - Type: PostgreSQL
   - Source: Your IP (or `0.0.0.0/0` for learning only)

### Step 3: Connect

```bash
# Install psql if needed
sudo apt install postgresql-client

# Connect
psql -h your-instance.xxxxxxxxx.us-east-1.rds.amazonaws.com \
     -U yourusername \
     -d postgres
```

---

## Creating a Read Replica (Within Free Tier)

RDS allows read replicas on `db.t3.micro`, which stays in Free Tier!

### Create Read Replica (Console)

1. Select your RDS instance
2. Actions → Create read replica
3. Settings:
   - Instance class: db.t3.micro (Free Tier)
   - Multi-AZ: No
   - Region: Same region (cross-region costs money)

4. Wait for creation (~10-15 minutes)

### Connect to Read Replica

```bash
# Connect to primary (read-write)
psql -h primary.xxxxxxxxx.us-east-1.rds.amazonaws.com -U labuser -d labdb

# Connect to replica (read-only)
psql -h replica.xxxxxxxxx.us-east-1.rds.amazonaws.com -U labuser -d labdb
```

---

## Lab: Experience RDS Replication Lag

### Setup

```sql
-- On Primary
CREATE TABLE lag_experiment (
    id SERIAL PRIMARY KEY,
    data TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);
```

### Measure Lag

```bash
# Terminal 1: Write to primary
while true; do
    psql -h primary.xxx.rds.amazonaws.com -U labuser -d labdb -c \
        "INSERT INTO lag_experiment (data) VALUES ('$(date +%s.%N)');"
    sleep 0.5
done
```

```bash
# Terminal 2: Read from replica and compare
while true; do
    PRIMARY=$(psql -h primary.xxx.rds.amazonaws.com -U labuser -d labdb -t -c \
        "SELECT MAX(created_at) FROM lag_experiment;")
    REPLICA=$(psql -h replica.xxx.rds.amazonaws.com -U labuser -d labdb -t -c \
        "SELECT MAX(created_at) FROM lag_experiment;")
    echo "Primary: $PRIMARY | Replica: $REPLICA"
    sleep 1
done
```

### Check Lag via CloudWatch

1. Go to CloudWatch → Metrics → RDS
2. Select your replica instance
3. Find `ReplicaLag` metric
4. Observe lag in seconds

---

## AWS Aurora: The Premium Option

Aurora is AWS's enhanced PostgreSQL/MySQL-compatible database.

### Aurora vs Standard RDS

| Feature | RDS PostgreSQL | Aurora PostgreSQL |
|---------|---------------|-------------------|
| Performance | Standard | 3x faster (claimed) |
| Storage | Manual scaling | Auto-scaling (10GB → 128TB) |
| Replicas | Up to 5 | Up to 15 |
| Failover | 60-120 seconds | <30 seconds |
| Cost | ~$15/month | ~$30/month (minimum) |

### Aurora Serverless v2 (Budget-Friendly)

Aurora Serverless v2 scales to zero when not in use:

- **Minimum**: 0.5 ACU (~$43/month if running 24/7)
- **Better for**: Sporadic usage, development

**Budget consideration:** Even minimum Aurora costs ~$40-50/month. Only use if you want to specifically learn Aurora features.

---

## Lab: Aurora Global Database (Cross-Region)

If you want to experience true cross-region replication (costs apply):

### Setup Global Database

1. Create Aurora cluster in us-east-1
2. Actions → Add AWS Region
3. Select us-west-2 (or eu-west-1)
4. Wait for secondary region setup (~30 min)

### Experience Cross-Region Lag

```bash
# Write to primary region (us-east-1)
psql -h primary.us-east-1.rds.amazonaws.com -U labuser -c \
    "INSERT INTO messages (content) VALUES ('Cross-region test');"

# Immediately read from secondary region (us-west-2)
psql -h secondary.us-west-2.rds.amazonaws.com -U labuser -c \
    "SELECT * FROM messages ORDER BY id DESC LIMIT 1;"
```

**Expected lag:** 100-500ms (speed of light + processing)

---

## Cost Management Tips

### Stay in Free Tier

```bash
# Check instance class (must be t2.micro or t3.micro)
aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceClass]'

# Check storage (must be ≤20GB)
aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,AllocatedStorage]'
```

### Set Billing Alerts

1. AWS Console → Billing → Budgets
2. Create budget
3. Set threshold: $1 (get alerted early)

### Delete When Done

```bash
# Delete read replica first
aws rds delete-db-instance \
    --db-instance-identifier my-replica \
    --skip-final-snapshot

# Then delete primary
aws rds delete-db-instance \
    --db-instance-identifier my-primary \
    --skip-final-snapshot
```

---

## CLI Reference

```bash
# Create RDS instance
aws rds create-db-instance \
    --db-instance-identifier my-postgres \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --master-username labuser \
    --master-user-password labpassword123 \
    --allocated-storage 20

# Create read replica
aws rds create-db-instance-read-replica \
    --db-instance-identifier my-replica \
    --source-db-instance-identifier my-postgres \
    --db-instance-class db.t3.micro

# Check replication status
aws rds describe-db-instances \
    --db-instance-identifier my-replica \
    --query 'DBInstances[0].StatusInfos'

# Promote replica to standalone
aws rds promote-read-replica \
    --db-instance-identifier my-replica
```

---

## Key Takeaways

1. **Free Tier is generous** — 750 hours of db.t3.micro per month
2. **Read replicas are free** — Same instance class, same region
3. **Replication lag is real** — Measure it with CloudWatch
4. **Aurora is premium** — Only use if budget allows
5. **Always set billing alerts** — Cloud surprises are expensive

---

## What's Next?

AWS is great but expensive beyond Free Tier. Let's explore PlanetScale—a distributed MySQL database with a generous free tier.

---

*Next: [PlanetScale (Distributed MySQL)](./15-planetscale.md)*
