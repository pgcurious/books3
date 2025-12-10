# Relational Database Deep Dive: A Hands-On Learning Guide

## Master Databases Through Practice, Not Theory

---

> *"I hear and I forget. I see and I remember. I do and I understand."*
> — Confucian proverb

---

## Why This Guide Exists

Most database tutorials teach you SQL syntax. They show you `SELECT * FROM users` and call it a day. But you won't *feel* why indexes matter until you watch a query take 30 seconds, add an index, and see it drop to 3 milliseconds. You won't *understand* eventual consistency until you write to one node and read stale data from another.

**This guide is different. You will:**

- Set up real databases (local and cloud)
- Run experiments that demonstrate core concepts
- Break things intentionally to understand failure modes
- Experience eventual consistency firsthand with multi-node setups
- Stay within a $100 budget (most labs are free)

## Who This Guide Is For

This guide is for developers who:

- Want to *feel* database concepts, not just read about them
- Have basic SQL knowledge but want deeper understanding
- Want hands-on experience with replication and consistency
- Prefer learning by doing over learning by reading

## Budget Overview: $100

| Component | Cost | Purpose |
|-----------|------|---------|
| Local PostgreSQL | $0 | Primary learning environment |
| Local MySQL | $0 | Compare behaviors |
| Docker (multi-node) | $0 | Replication labs |
| AWS RDS Free Tier | $0 | Managed database experience |
| AWS Aurora Read Replicas | ~$30-50 | Feel replication lag |
| PlanetScale Free Tier | $0 | Distributed MySQL |
| CockroachDB Serverless | $0 | Distributed PostgreSQL |
| **Total Estimated** | **$30-50** | **Well under budget** |

You can complete 90% of this guide for free. The paid portions ($30-50) give you real cloud experience with replication lag you can measure.

---

## How to Use This Guide

### The Structure

| Part | Theme | What You'll Experience |
|------|-------|----------------------|
| 1 | Local Setup | Install PostgreSQL & MySQL, understand the basics |
| 2 | ACID & Transactions | See isolation levels fail, understand locking |
| 3 | Indexing | Watch queries go from 30s to 3ms |
| 4 | Replication & Consistency | **Feel eventual consistency with real lag** |
| 5 | Cloud Options | Production-like environments within budget |

### Each Chapter Includes

1. **The Concept** — What we're exploring
2. **The Setup** — Exact commands to run
3. **The Experiment** — Hands-on labs
4. **What You Should See** — Expected results
5. **Break It** — Intentional failure scenarios
6. **First Principles** — Why this works the way it does

### Suggested Path

**Week 1: Foundation**
- Part 1: Set up local databases
- Part 2: ACID experiments

**Week 2: Performance**
- Part 3: Indexing labs (this will change how you think about queries)

**Week 3: Distribution**
- Part 4: Replication with Docker (free)
- Part 4: Cloud replication labs ($30-50)

**Week 4: Production Patterns**
- Part 5: Cloud databases
- Synthesis: Build a system that handles consistency trade-offs

---

## Prerequisites

### Required
- A computer (Linux, Mac, or Windows with WSL2)
- Basic SQL knowledge (`SELECT`, `INSERT`, `UPDATE`, `WHERE`)
- Comfort with command line
- Docker installed (for multi-node labs)

### Helpful but Not Required
- Basic understanding of networking
- Experience with cloud platforms
- Familiarity with PostgreSQL or MySQL

---

## What You'll Build

By the end of this guide, you'll have:

1. **Local lab environment** with PostgreSQL and MySQL
2. **Multi-node PostgreSQL cluster** demonstrating replication lag
3. **Experiments showing** ACID violations at different isolation levels
4. **Benchmarks proving** index effectiveness
5. **Cloud setups** demonstrating real-world eventual consistency
6. **Scripts and tools** for ongoing database exploration

---

## The First-Principles Approach

Throughout this guide, we ask "why" until we hit fundamental truths:

- Why do indexes work? → B-trees reduce search from O(n) to O(log n)
- Why does replication lag exist? → Networks have latency; physics wins
- Why can't we have perfect consistency AND availability? → CAP theorem (proven mathematics)

Every lab is designed to make these truths *visceral*, not academic.

---

## Table of Contents

### Part 1: Local Setup & First Principles
- [01. Installing PostgreSQL](./PART-1-LOCAL-SETUP/01-installing-postgresql.md)
- [02. Installing MySQL](./PART-1-LOCAL-SETUP/02-installing-mysql.md)
- [03. First Principles of Storage](./PART-1-LOCAL-SETUP/03-storage-first-principles.md)

### Part 2: ACID & Transactions
- [04. Understanding ACID](./PART-2-ACID-TRANSACTIONS/04-understanding-acid.md)
- [05. Isolation Levels Lab](./PART-2-ACID-TRANSACTIONS/05-isolation-levels-lab.md)
- [06. Deadlocks & Locking](./PART-2-ACID-TRANSACTIONS/06-deadlocks-locking.md)

### Part 3: Indexing & Query Optimization
- [07. How Indexes Work](./PART-3-INDEXING/07-how-indexes-work.md)
- [08. Index Performance Lab](./PART-3-INDEXING/08-index-performance-lab.md)
- [09. Query Plans & EXPLAIN](./PART-3-INDEXING/09-query-plans-explain.md)

### Part 4: Replication & Eventual Consistency
- [10. Replication Fundamentals](./PART-4-REPLICATION-CONSISTENCY/10-replication-fundamentals.md)
- [11. Docker Multi-Node Lab](./PART-4-REPLICATION-CONSISTENCY/11-docker-multi-node-lab.md)
- [12. Feeling Eventual Consistency](./PART-4-REPLICATION-CONSISTENCY/12-feeling-eventual-consistency.md)
- [13. Conflict Resolution](./PART-4-REPLICATION-CONSISTENCY/13-conflict-resolution.md)

### Part 5: Cloud Options (Within Budget)
- [14. AWS RDS & Aurora](./PART-5-CLOUD-OPTIONS/14-aws-rds-aurora.md)
- [15. PlanetScale (Distributed MySQL)](./PART-5-CLOUD-OPTIONS/15-planetscale.md)
- [16. CockroachDB Serverless](./PART-5-CLOUD-OPTIONS/16-cockroachdb.md)

### Appendix
- [Budget Breakdown](./appendix/budget-breakdown.md)
- [Lab Scripts](./labs/)
- [Troubleshooting Guide](./appendix/troubleshooting.md)

---

## Quick Start

If you want to jump in immediately:

```bash
# Install PostgreSQL (Ubuntu/Debian)
sudo apt update && sudo apt install postgresql postgresql-contrib

# Start PostgreSQL
sudo systemctl start postgresql

# Create your lab database
sudo -u postgres createdb labdb

# Connect
sudo -u postgres psql labdb
```

Then proceed to [Part 1](./PART-1-LOCAL-SETUP/01-installing-postgresql.md) for the full experience.

---

*Let's stop reading about databases and start feeling them.*
