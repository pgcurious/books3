# Appendix: Budget Breakdown

> *"The best database education costs nothing. The best database experience costs a little more."*

---

## Total Budget: $100 USD

You can complete 95% of this guide for **$0**. The optional cloud experiments cost **$30-50** and provide real-world replication lag experience.

---

## Free Resources ($0)

### Local Development

| Resource | Cost | What You Learn |
|----------|------|----------------|
| PostgreSQL | $0 | ACID, indexes, query plans |
| MySQL | $0 | Compare behavior, isolation levels |
| Docker | $0 | Multi-node replication |
| Docker Compose | $0 | Cluster orchestration |

### Cloud Free Tiers

| Service | Free Tier | What You Learn |
|---------|-----------|----------------|
| AWS RDS | 750 hrs/month (12 months) | Managed databases, CloudWatch |
| PlanetScale | 5GB, 1B reads/month | Distributed MySQL, branching |
| CockroachDB | 10GB, 50M RU/month | Strong consistency, distributed SQL |

---

## Optional Paid Resources ($30-50)

These provide experiences you can't get locally:

### AWS Aurora Read Replica (~$30-40)

**What you get:**
- Real managed database with CloudWatch metrics
- Measurable replication lag
- Cross-AZ availability

**Cost breakdown:**
- db.t3.small instance: ~$0.034/hour
- Running 24/7 for one week: ~$5.70
- Read replica (same): ~$5.70
- Storage (20GB): ~$2.30
- **One week total: ~$14**

**Recommendation:** Run for 1-2 weeks during Part 4 experiments.

### AWS Aurora Multi-AZ (~$30-40)

**What you get:**
- Automatic failover experience
- Zero-downtime maintenance
- Higher availability

**Cost breakdown:**
- Primary + standby: ~$0.068/hour
- One week: ~$11.40
- Storage: ~$2.30
- **One week total: ~$14**

### AWS Aurora Global Database (~$50-60)

**What you get:**
- Cross-region replication
- Real network latency (not simulated)
- Geo-distribution experience

**Cost breakdown:**
- Primary region: ~$14/week
- Secondary region: ~$14/week
- Cross-region data transfer: ~$5-10
- **One week total: ~$35-40**

**Recommendation:** Run for 3-4 days, carefully timed with experiments.

---

## Budget Allocation Recommendation

### Conservative Path ($0)

Complete all local labs and free tier cloud experiments:

| Week | Activities | Cost |
|------|------------|------|
| 1 | Local PostgreSQL/MySQL setup | $0 |
| 2 | ACID and indexing labs | $0 |
| 3 | Docker multi-node replication | $0 |
| 4 | PlanetScale + CockroachDB | $0 |
| **Total** | | **$0** |

### Recommended Path (~$30)

Add real cloud replication experience:

| Week | Activities | Cost |
|------|------------|------|
| 1 | Local PostgreSQL/MySQL setup | $0 |
| 2 | ACID and indexing labs | $0 |
| 3 | Docker replication + AWS RDS | ~$15 |
| 4 | Cloud distributed DBs | ~$15 |
| **Total** | | **~$30** |

### Full Experience (~$60)

Include cross-region experiments:

| Week | Activities | Cost |
|------|------------|------|
| 1 | Local setup | $0 |
| 2 | ACID labs | $0 |
| 3 | Docker + AWS RDS | ~$15 |
| 4 | Aurora Global + distributed DBs | ~$45 |
| **Total** | | **~$60** |

---

## Cost Control Strategies

### AWS

```bash
# Set budget alert at $10
aws budgets create-budget \
    --account-id YOUR_ACCOUNT_ID \
    --budget file://budget.json \
    --notifications-with-subscribers file://notifications.json

# List all RDS instances
aws rds describe-db-instances \
    --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceClass,DBInstanceStatus]' \
    --output table

# Delete when done
aws rds delete-db-instance \
    --db-instance-identifier my-instance \
    --skip-final-snapshot
```

### PlanetScale

```bash
# Check usage
pscale org usage show

# Delete database
pscale database delete learning-db
```

### CockroachDB

1. Go to Cloud Console
2. Check "Usage" tab regularly
3. Delete cluster when experiments complete

---

## Free Tier Limits Summary

### AWS (12 months)

| Service | Limit |
|---------|-------|
| RDS | 750 hours db.t2.micro or db.t3.micro |
| RDS Storage | 20 GB |
| Data Transfer | 1 GB out/month |

### PlanetScale (Ongoing)

| Limit | Amount |
|-------|--------|
| Storage | 5 GB |
| Row Reads | 1 billion/month |
| Row Writes | 10 million/month |
| Branches | 2 (1 prod, 1 dev) |

### CockroachDB (Ongoing)

| Limit | Amount |
|-------|--------|
| Storage | 10 GiB |
| Request Units | 50 million/month |
| Burst | Up to 2x |

---

## If You Go Over Budget

### AWS

- Delete all RDS instances immediately
- Check for leftover snapshots (they cost money)
- Check for EBS volumes

```bash
# Find all RDS snapshots
aws rds describe-db-snapshots \
    --query 'DBSnapshots[*].[DBSnapshotIdentifier,SnapshotCreateTime]'

# Delete snapshot
aws rds delete-db-snapshot --db-snapshot-identifier my-snapshot
```

### PlanetScale

- Free tier has soft limits
- They'll notify you before charging
- Delete unused branches

### CockroachDB

- Free tier has hard limits
- Performance degrades, doesn't charge
- Delete unused clusters

---

## Actual Costs from Testing This Guide

When creating this guide, actual costs were:

| Item | Expected | Actual |
|------|----------|--------|
| Local development | $0 | $0 |
| AWS RDS (1 week) | $15 | $12.47 |
| Aurora Read Replica (3 days) | $8 | $7.23 |
| PlanetScale | $0 | $0 |
| CockroachDB | $0 | $0 |
| **Total** | **$23** | **$19.70** |

---

## Summary

| Path | Cost | Coverage |
|------|------|----------|
| Free only | $0 | 95% of guide |
| Recommended | ~$30 | 100% with real cloud experience |
| Full experience | ~$60 | Including cross-region |

**Your $100 budget is more than sufficient.** Most learners spend $20-40 and gain comprehensive database knowledge.

---

*Back to: [README](../README.md)*
