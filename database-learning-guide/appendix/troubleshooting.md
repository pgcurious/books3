# Appendix: Troubleshooting Guide

> *"Every database error message is a learning opportunity in disguise."*

---

## PostgreSQL Issues

### Can't Connect to PostgreSQL

**Symptom:**
```
psql: error: connection to server failed: Connection refused
```

**Solutions:**

```bash
# 1. Check if PostgreSQL is running
sudo systemctl status postgresql

# 2. Start if not running
sudo systemctl start postgresql

# 3. Check listening port
sudo ss -tlnp | grep 5432

# 4. Check pg_hba.conf for authentication
sudo cat /etc/postgresql/15/main/pg_hba.conf
```

### Authentication Failed

**Symptom:**
```
psql: error: FATAL: password authentication failed for user "labuser"
```

**Solutions:**

```bash
# 1. Connect as postgres superuser
sudo -u postgres psql

# 2. Reset password
ALTER USER labuser WITH PASSWORD 'newpassword';

# 3. Check pg_hba.conf authentication method
# Should have: local all all scram-sha-256
# Or: local all all md5
```

### Permission Denied

**Symptom:**
```
ERROR: permission denied for table users
```

**Solutions:**

```sql
-- Connect as superuser
sudo -u postgres psql labdb

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO labuser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO labuser;

-- For future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL ON TABLES TO labuser;
```

---

## MySQL Issues

### Can't Connect to MySQL

**Symptom:**
```
ERROR 2002 (HY000): Can't connect to local MySQL server through socket
```

**Solutions:**

```bash
# 1. Check if MySQL is running
sudo systemctl status mysql

# 2. Start if not running
sudo systemctl start mysql

# 3. Check socket location
mysql --help | grep socket

# 4. Try TCP connection
mysql -h 127.0.0.1 -u labuser -p
```

### Access Denied

**Symptom:**
```
ERROR 1045 (28000): Access denied for user 'labuser'@'localhost'
```

**Solutions:**

```bash
# 1. Connect as root
sudo mysql

# 2. Check user exists
SELECT user, host FROM mysql.user WHERE user = 'labuser';

# 3. Reset password
ALTER USER 'labuser'@'localhost' IDENTIFIED BY 'newpassword';
FLUSH PRIVILEGES;

# 4. Grant privileges
GRANT ALL PRIVILEGES ON labdb.* TO 'labuser'@'localhost';
FLUSH PRIVILEGES;
```

---

## Docker Issues

### Container Won't Start

**Symptom:**
```
ERROR: for pg-primary Cannot start service primary: driver failed programming external connectivity
```

**Solutions:**

```bash
# 1. Check if port is already in use
sudo ss -tlnp | grep 5432

# 2. Stop conflicting service
sudo systemctl stop postgresql

# 3. Check Docker logs
docker logs pg-primary

# 4. Remove and recreate container
docker-compose down
docker-compose up -d
```

### Replica Won't Connect to Primary

**Symptom:**
```
FATAL: could not connect to the primary server
```

**Solutions:**

```bash
# 1. Check primary is running
docker exec pg-primary pg_isready

# 2. Check network connectivity
docker exec pg-replica ping -c 3 primary

# 3. Check replication settings on primary
docker exec pg-primary psql -U labuser -c "SHOW max_wal_senders;"
docker exec pg-primary psql -U labuser -c "SHOW wal_level;"

# 4. Check pg_hba.conf allows replication
docker exec pg-primary cat /var/lib/postgresql/data/pg_hba.conf | grep replication

# 5. Restart replica
docker-compose restart replica
```

### Network Delay (tc) Not Working

**Symptom:**
```
RTNETLINK answers: Operation not permitted
```

**Solutions:**

```bash
# 1. Run container with privileges
docker run --privileged ...

# 2. Or use Docker Compose with cap_add
# In docker-compose.yml:
services:
  replica:
    cap_add:
      - NET_ADMIN

# 3. Install iproute2 in container
docker exec pg-replica apt-get update && apt-get install -y iproute2
```

---

## AWS RDS Issues

### Can't Connect to RDS

**Symptom:**
```
Connection timed out
```

**Solutions:**

1. **Check Security Group:**
   - Go to RDS → Select instance → Security groups
   - Add inbound rule: PostgreSQL (5432), Source: Your IP

2. **Check Public Accessibility:**
   - RDS → Modify → Public accessibility: Yes

3. **Check VPC/Subnet:**
   - Ensure RDS is in public subnet
   - Internet gateway attached to VPC

```bash
# Test connectivity
nc -zv your-rds-endpoint.rds.amazonaws.com 5432
```

### Read Replica Creation Fails

**Symptom:**
```
Cannot create a read replica for a DB instance that has backup disabled
```

**Solutions:**

```bash
# Enable automated backups
aws rds modify-db-instance \
    --db-instance-identifier my-instance \
    --backup-retention-period 1 \
    --apply-immediately
```

---

## PlanetScale Issues

### Can't Connect

**Symptom:**
```
Error: unable to connect to branch
```

**Solutions:**

```bash
# 1. Check authentication
pscale auth login

# 2. Check branch exists
pscale branch list learning-db

# 3. Use shell command (handles connection)
pscale shell learning-db main

# 4. Check organization
pscale org list
pscale org switch your-org
```

### Schema Change Blocked

**Symptom:**
```
Error: schema change would break compatibility
```

**Solutions:**

1. Use branches for schema changes:
```bash
pscale branch create learning-db schema-fix
pscale shell learning-db schema-fix
# Make changes
pscale deploy-request create learning-db schema-fix
```

2. Check for breaking changes:
```bash
pscale deploy-request diff learning-db <number>
```

---

## CockroachDB Issues

### Connection SSL Error

**Symptom:**
```
SSL error: certificate verify failed
```

**Solutions:**

```bash
# 1. Download CA certificate from console
# 2. Specify in connection string
psql "postgresql://user:pass@host:26257/db?sslmode=verify-full&sslrootcert=/path/to/ca.crt"

# 3. Or use require mode (less secure)
psql "postgresql://user:pass@host:26257/db?sslmode=require"
```

### Transaction Retry Required

**Symptom:**
```
ERROR: restart transaction: TransactionRetryWithProtoRefreshError
```

**Solutions:**

```sql
-- This is expected behavior for serializable isolation!
-- Wrap in retry logic:

-- In application code:
while True:
    try:
        execute_transaction()
        break
    except TransactionRetryError:
        continue  # Retry
```

```sql
-- Or use lower isolation (not recommended):
SET default_transaction_isolation = 'read committed';
```

---

## General Performance Issues

### Query Is Slow

**Diagnosis:**

```sql
-- PostgreSQL
EXPLAIN ANALYZE SELECT ...;

-- Look for:
-- - Seq Scan on large tables (missing index)
-- - High "Rows Removed by Filter" (missing index)
-- - Sort using disk (need more work_mem)
```

**Solutions:**

```sql
-- Add missing index
CREATE INDEX idx_column ON table(column);

-- Increase work_mem for sorts
SET work_mem = '256MB';

-- Update statistics
ANALYZE table_name;
```

### Running Out of Disk Space

**Diagnosis:**

```sql
-- PostgreSQL
SELECT
    pg_size_pretty(pg_database_size(current_database())) as db_size;

SELECT
    relname,
    pg_size_pretty(pg_total_relation_size(relid)) as size
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 10;
```

**Solutions:**

```sql
-- Remove bloat
VACUUM FULL table_name;

-- Delete old data
DELETE FROM logs WHERE created_at < NOW() - INTERVAL '30 days';

-- Truncate test tables
TRUNCATE TABLE test_data;
```

---

## Quick Diagnostic Commands

### PostgreSQL

```sql
-- Check connections
SELECT * FROM pg_stat_activity;

-- Check locks
SELECT * FROM pg_locks WHERE NOT granted;

-- Check replication status
SELECT * FROM pg_stat_replication;

-- Check table sizes
SELECT relname, pg_size_pretty(pg_relation_size(relid))
FROM pg_stat_user_tables ORDER BY pg_relation_size(relid) DESC;
```

### MySQL

```sql
-- Check connections
SHOW PROCESSLIST;

-- Check locks
SHOW ENGINE INNODB STATUS;

-- Check replication status
SHOW SLAVE STATUS\G

-- Check table sizes
SELECT table_name, ROUND(data_length/1024/1024, 2) AS size_mb
FROM information_schema.tables
WHERE table_schema = 'labdb'
ORDER BY data_length DESC;
```

### Docker

```bash
# Check container status
docker-compose ps

# View logs
docker-compose logs -f primary
docker-compose logs -f replica

# Execute command in container
docker exec -it pg-primary psql -U labuser -d labdb

# Check resource usage
docker stats
```

---

## Getting Help

### PostgreSQL
- Documentation: https://www.postgresql.org/docs/
- Community: https://www.postgresql.org/community/

### MySQL
- Documentation: https://dev.mysql.com/doc/
- Forums: https://forums.mysql.com/

### Docker
- Documentation: https://docs.docker.com/
- Forums: https://forums.docker.com/

### Cloud Services
- AWS RDS: https://docs.aws.amazon.com/rds/
- PlanetScale: https://docs.planetscale.com/
- CockroachDB: https://www.cockroachlabs.com/docs/

---

*Back to: [README](../README.md)*
