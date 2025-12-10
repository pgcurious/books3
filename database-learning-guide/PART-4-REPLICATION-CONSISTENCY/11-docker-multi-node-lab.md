# Chapter 11: Docker Multi-Node Lab

> *"You don't understand replication until you've watched a write disappear into the void between nodes."*

---

## Lab Overview

In this lab, you will:
1. Set up a PostgreSQL Primary + Replica using Docker
2. Watch replication happen in real-time
3. Measure replication lag
4. Simulate failures and observe behavior

**Cost:** $0 (Docker only)
**Time:** 45-60 minutes

---

## Prerequisites

- Docker installed
- Docker Compose installed
- Basic command line skills

```bash
# Verify Docker
docker --version
docker-compose --version
```

---

## Step 1: Create the Docker Compose Setup

Create a directory for this lab:

```bash
mkdir -p ~/db-replication-lab
cd ~/db-replication-lab
```

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  primary:
    image: postgres:15
    container_name: pg-primary
    environment:
      POSTGRES_USER: labuser
      POSTGRES_PASSWORD: labpassword
      POSTGRES_DB: labdb
    command: |
      postgres
      -c wal_level=replica
      -c max_wal_senders=3
      -c max_replication_slots=3
      -c hot_standby=on
    ports:
      - "5432:5432"
    volumes:
      - primary_data:/var/lib/postgresql/data
    networks:
      - pgnet

  replica:
    image: postgres:15
    container_name: pg-replica
    environment:
      POSTGRES_USER: labuser
      POSTGRES_PASSWORD: labpassword
      POSTGRES_DB: labdb
      PGUSER: labuser
      PGPASSWORD: labpassword
    depends_on:
      - primary
    ports:
      - "5433:5432"
    volumes:
      - replica_data:/var/lib/postgresql/data
    networks:
      - pgnet
    command: |
      bash -c "
      until pg_isready -h primary -p 5432 -U labuser; do
        echo 'Waiting for primary...'
        sleep 2
      done

      # Check if already initialized as replica
      if [ ! -f /var/lib/postgresql/data/standby.signal ]; then
        rm -rf /var/lib/postgresql/data/*
        PGPASSWORD=labpassword pg_basebackup -h primary -U labuser -D /var/lib/postgresql/data -Fp -Xs -P -R
      fi

      postgres -c hot_standby=on
      "

volumes:
  primary_data:
  replica_data:

networks:
  pgnet:
    driver: bridge
```

---

## Step 2: Configure Replication Access

Create `init-primary.sh`:

```bash
#!/bin/bash
# Run this after primary is up to configure replication

docker exec -it pg-primary psql -U labuser -d labdb -c "
-- Check if replication user exists, create if not
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'replicator') THEN
        CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD 'replpassword';
    END IF;
END
\$\$;
"

# Add replication entry to pg_hba.conf
docker exec -it pg-primary bash -c "echo 'host replication replicator 0.0.0.0/0 scram-sha-256' >> /var/lib/postgresql/data/pg_hba.conf"

# Reload configuration
docker exec -it pg-primary psql -U labuser -c "SELECT pg_reload_conf();"

echo "Primary configured for replication"
```

Make it executable:
```bash
chmod +x init-primary.sh
```

---

## Step 3: Start the Cluster

```bash
# Start primary first
docker-compose up -d primary

# Wait for primary to be ready
sleep 10

# Initialize replication settings
./init-primary.sh

# Start replica
docker-compose up -d replica

# Check status
docker-compose ps
```

---

## Step 4: Verify Replication

### Check Replica Status

```bash
# Connect to replica
docker exec -it pg-replica psql -U labuser -d labdb -c "SELECT pg_is_in_recovery();"
```

**Expected:** `t` (true) - this node is a replica

### Check Primary for Connected Replicas

```bash
docker exec -it pg-primary psql -U labuser -d labdb -c "
SELECT client_addr, state, sent_lsn, replay_lsn,
       pg_wal_lsn_diff(sent_lsn, replay_lsn) as lag_bytes
FROM pg_stat_replication;"
```

**Expected:** One row showing the connected replica

---

## Step 5: Experiment - Basic Replication

### Write to Primary

```bash
# Terminal 1: Connect to Primary
docker exec -it pg-primary psql -U labuser -d labdb

# Create test table
CREATE TABLE messages (
    id SERIAL PRIMARY KEY,
    content TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

# Insert data
INSERT INTO messages (content) VALUES ('Hello from Primary!');
```

### Read from Replica

```bash
# Terminal 2: Connect to Replica
docker exec -it pg-replica psql -U labuser -d labdb

# Query the data
SELECT * FROM messages;
```

**Expected:** You should see the message (possibly with tiny delay)

---

## Step 6: Experiment - Measure Replication Lag

### Create a Lag Monitoring Query

```bash
# On Primary - Create a function to measure lag
docker exec -it pg-primary psql -U labuser -d labdb -c "
CREATE OR REPLACE FUNCTION measure_replication_lag()
RETURNS TABLE(replica_addr inet, lag_bytes bigint, lag_time interval) AS \$\$
SELECT
    client_addr,
    pg_wal_lsn_diff(sent_lsn, replay_lsn),
    NOW() - backend_start
FROM pg_stat_replication;
\$\$ LANGUAGE sql;
"
```

### Run Continuous Lag Check

```bash
# In a new terminal, watch replication lag
watch -n 1 "docker exec pg-primary psql -U labuser -d labdb -t -c \"
SELECT
    client_addr as replica,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) as lag_bytes
FROM pg_stat_replication;\""
```

### Generate Load and Observe

```bash
# Insert many rows quickly
docker exec -it pg-primary psql -U labuser -d labdb -c "
INSERT INTO messages (content)
SELECT 'Message ' || i FROM generate_series(1, 10000) AS i;
"

# Watch the lag monitor - you should see lag_bytes spike then drop
```

---

## Step 7: Experiment - Feel Eventual Consistency

This is the key experiment. Open three terminals:

### Terminal 1: Continuous Writes (Primary)

```bash
docker exec -it pg-primary psql -U labuser -d labdb -c "
DO \$\$
DECLARE
    i INTEGER := 0;
BEGIN
    LOOP
        INSERT INTO messages (content) VALUES ('Continuous write ' || i);
        i := i + 1;
        PERFORM pg_sleep(0.1);  -- Insert every 100ms
        EXIT WHEN i > 100;
    END LOOP;
END \$\$;
"
```

### Terminal 2: Continuous Reads (Primary)

```bash
watch -n 0.5 "docker exec pg-primary psql -U labuser -d labdb -t -c \"SELECT MAX(id), content FROM messages GROUP BY content ORDER BY MAX(id) DESC LIMIT 1;\""
```

### Terminal 3: Continuous Reads (Replica)

```bash
watch -n 0.5 "docker exec pg-replica psql -U labuser -d labdb -t -c \"SELECT MAX(id), content FROM messages GROUP BY content ORDER BY MAX(id) DESC LIMIT 1;\""
```

**What you'll observe:**
- Primary shows the latest write immediately
- Replica lags behind by a few writes
- Eventually, replica catches up

**This is eventual consistency!**

---

## Step 8: Experiment - Network Delay Simulation

Let's artificially increase lag to make it more visible:

```bash
# Add network delay to replica container
docker exec --privileged pg-replica bash -c "apt-get update && apt-get install -y iproute2 && tc qdisc add dev eth0 root netem delay 500ms"

# Now repeat the continuous write experiment
# You'll see much more visible lag between Primary and Replica
```

To remove delay:
```bash
docker exec --privileged pg-replica tc qdisc del dev eth0 root
```

---

## Step 9: Experiment - Failover Scenario

### Simulate Primary Failure

```bash
# Stop primary abruptly
docker stop pg-primary
```

### Observe Replica Behavior

```bash
# Check replica status
docker exec -it pg-replica psql -U labuser -d labdb -c "SELECT pg_is_in_recovery();"
# Still true - replica is read-only

# Try to write to replica
docker exec -it pg-replica psql -U labuser -d labdb -c "INSERT INTO messages (content) VALUES ('test');"
# ERROR: cannot execute INSERT in a read-only transaction
```

### Promote Replica to Primary

```bash
# Promote the replica
docker exec -it pg-replica psql -U labuser -d labdb -c "SELECT pg_promote();"

# Check status - should now be false (no longer in recovery)
docker exec -it pg-replica psql -U labuser -d labdb -c "SELECT pg_is_in_recovery();"

# Now writes work!
docker exec -it pg-replica psql -U labuser -d labdb -c "INSERT INTO messages (content) VALUES ('I am the new primary!');"
```

---

## Step 10: Cleanup and Reset

```bash
# Stop all containers
docker-compose down

# Remove volumes (start fresh)
docker-compose down -v

# Start fresh
docker-compose up -d
```

---

## Key Observations

After this lab, you should have observed:

1. **Replication lag is real** — Writes on primary don't instantly appear on replica
2. **Lag varies** — Under load, lag increases; when idle, lag catches up
3. **Network affects lag** — Slower network = more lag
4. **Failover has risks** — If primary fails before shipping WAL, writes are lost
5. **Replicas are read-only** — Until promoted

---

## Troubleshooting

### Replica Won't Connect

```bash
# Check primary is accepting connections
docker exec pg-primary pg_isready

# Check replication settings
docker exec pg-primary psql -U labuser -c "SHOW max_wal_senders;"
docker exec pg-primary psql -U labuser -c "SHOW wal_level;"

# Check pg_hba.conf
docker exec pg-primary cat /var/lib/postgresql/data/pg_hba.conf
```

### Replica Stuck in Recovery

```bash
# Check WAL receiver status on replica
docker exec pg-replica psql -U labuser -c "SELECT * FROM pg_stat_wal_receiver;"
```

---

## What's Next?

You've experienced replication locally. Now let's feel *real* eventual consistency with cloud databases that introduce actual network latency and geographic distribution.

---

*Next: [Feeling Eventual Consistency](./12-feeling-eventual-consistency.md)*
