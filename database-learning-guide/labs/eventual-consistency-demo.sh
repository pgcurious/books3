#!/bin/bash

# Eventual Consistency Demonstration Script
# Usage: ./eventual-consistency-demo.sh
#
# This script demonstrates eventual consistency by:
# 1. Adding network delay to replica
# 2. Writing data to primary
# 3. Showing how replica lags behind

set -e

PRIMARY_HOST="localhost"
PRIMARY_PORT="5432"
REPLICA_HOST="localhost"
REPLICA_PORT="5433"
DB_USER="labuser"
DB_NAME="labdb"
export PGPASSWORD="labpassword"

DELAY_MS=${1:-200}  # Default 200ms delay

echo "=== Eventual Consistency Demonstration ==="
echo ""

# Setup
echo "[1/6] Setting up test table..."
psql -h $PRIMARY_HOST -p $PRIMARY_PORT -U $DB_USER -d $DB_NAME -c "
DROP TABLE IF EXISTS session_demo;
CREATE TABLE session_demo (
    session_id VARCHAR(50) PRIMARY KEY,
    user_id INT,
    logged_in BOOLEAN,
    created_at TIMESTAMP DEFAULT NOW()
);
" > /dev/null

echo "[2/6] Adding ${DELAY_MS}ms network delay to replica..."
docker exec --privileged pg-replica bash -c "
apt-get update > /dev/null 2>&1
apt-get install -y iproute2 > /dev/null 2>&1
tc qdisc add dev eth0 root netem delay ${DELAY_MS}ms 2>/dev/null || tc qdisc change dev eth0 root netem delay ${DELAY_MS}ms
" 2>/dev/null
echo "   Done!"

echo ""
echo "[3/6] Simulating user login (write to primary)..."
SESSION_ID="sess_$(date +%s)"
psql -h $PRIMARY_HOST -p $PRIMARY_PORT -U $DB_USER -d $DB_NAME -c "
INSERT INTO session_demo (session_id, user_id, logged_in)
VALUES ('$SESSION_ID', 123, true);
" > /dev/null
echo "   Written session: $SESSION_ID"
echo "   Timestamp: $(date +%H:%M:%S.%3N)"

echo ""
echo "[4/6] Immediately reading from replica..."
echo "   Timestamp: $(date +%H:%M:%S.%3N)"
RESULT=$(psql -h $REPLICA_HOST -p $REPLICA_PORT -U $DB_USER -d $DB_NAME -t -c "
SELECT CASE WHEN COUNT(*) > 0 THEN 'FOUND' ELSE 'NOT FOUND' END
FROM session_demo WHERE session_id = '$SESSION_ID';
" | tr -d ' ')
echo "   Result: $RESULT"

if [ "$RESULT" = "NOT FOUND" ]; then
    echo ""
    echo "   ^^^ THIS IS EVENTUAL CONSISTENCY!"
    echo "   The user just logged in but the replica doesn't know yet."
    echo ""
fi

echo "[5/6] Waiting for replication (${DELAY_MS}ms + buffer)..."
sleep $(echo "scale=2; ($DELAY_MS + 100) / 1000" | bc)

echo ""
echo "[6/6] Reading from replica again..."
echo "   Timestamp: $(date +%H:%M:%S.%3N)"
RESULT=$(psql -h $REPLICA_HOST -p $REPLICA_PORT -U $DB_USER -d $DB_NAME -t -c "
SELECT CASE WHEN COUNT(*) > 0 THEN 'FOUND' ELSE 'NOT FOUND' END
FROM session_demo WHERE session_id = '$SESSION_ID';
" | tr -d ' ')
echo "   Result: $RESULT"

if [ "$RESULT" = "FOUND" ]; then
    echo ""
    echo "   ^^^ Now the data has replicated!"
    echo "   This is 'eventually consistent' - the data arrived, eventually."
fi

echo ""
echo "=== Cleanup ==="
echo "Removing network delay..."
docker exec --privileged pg-replica tc qdisc del dev eth0 root 2>/dev/null || true
echo "Done!"

echo ""
echo "=== Demonstration Complete ==="
echo ""
echo "Key takeaway: With ${DELAY_MS}ms replication delay,"
echo "read-after-write to replica may see stale data."
echo ""
echo "In real distributed systems, this delay comes from:"
echo "  - Network latency between regions"
echo "  - Replica processing time"
echo "  - System load"
