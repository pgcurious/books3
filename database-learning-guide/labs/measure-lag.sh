#!/bin/bash

# Replication Lag Measurement Script
# Usage: ./measure-lag.sh [iterations]
#
# This script measures the actual replication lag between
# PostgreSQL primary and replica containers.

set -e

ITERATIONS=${1:-10}
PRIMARY_HOST="localhost"
PRIMARY_PORT="5432"
REPLICA_HOST="localhost"
REPLICA_PORT="5433"
DB_USER="labuser"
DB_NAME="labdb"
export PGPASSWORD="labpassword"

echo "=== PostgreSQL Replication Lag Measurement ==="
echo "Primary: $PRIMARY_HOST:$PRIMARY_PORT"
echo "Replica: $REPLICA_HOST:$REPLICA_PORT"
echo "Iterations: $ITERATIONS"
echo ""

# Create test table if not exists
psql -h $PRIMARY_HOST -p $PRIMARY_PORT -U $DB_USER -d $DB_NAME -c "
CREATE TABLE IF NOT EXISTS lag_measurement (
    id SERIAL PRIMARY KEY,
    write_timestamp NUMERIC,
    write_time TIMESTAMP DEFAULT NOW()
);
" 2>/dev/null

echo "Iteration | Write Time | Replication Lag"
echo "----------|------------|----------------"

total_lag=0
min_lag=999999
max_lag=0

for i in $(seq 1 $ITERATIONS); do
    # Get precise write time
    WRITE_TIME=$(date +%s.%N)

    # Write to primary
    psql -h $PRIMARY_HOST -p $PRIMARY_PORT -U $DB_USER -d $DB_NAME -t -c "
    INSERT INTO lag_measurement (write_timestamp) VALUES ($WRITE_TIME) RETURNING id;
    " > /dev/null

    # Poll replica until we see it
    while true; do
        READ_TIME=$(date +%s.%N)
        FOUND=$(psql -h $REPLICA_HOST -p $REPLICA_PORT -U $DB_USER -d $DB_NAME -t -c "
        SELECT COUNT(*) FROM lag_measurement WHERE write_timestamp = $WRITE_TIME;
        " | tr -d ' ')

        if [ "$FOUND" = "1" ]; then
            LAG=$(echo "scale=6; $READ_TIME - $WRITE_TIME" | bc)
            LAG_MS=$(echo "scale=2; $LAG * 1000" | bc)

            printf "%9d | %10.3f | %8.2f ms\n" $i $WRITE_TIME $LAG_MS

            # Update statistics
            total_lag=$(echo "$total_lag + $LAG_MS" | bc)
            if (( $(echo "$LAG_MS < $min_lag" | bc -l) )); then
                min_lag=$LAG_MS
            fi
            if (( $(echo "$LAG_MS > $max_lag" | bc -l) )); then
                max_lag=$LAG_MS
            fi
            break
        fi

        # Small sleep to avoid hammering the replica
        sleep 0.001
    done

    # Small delay between iterations
    sleep 0.1
done

# Calculate average
avg_lag=$(echo "scale=2; $total_lag / $ITERATIONS" | bc)

echo ""
echo "=== Summary ==="
echo "Minimum lag: ${min_lag} ms"
echo "Maximum lag: ${max_lag} ms"
echo "Average lag: ${avg_lag} ms"
echo ""

# Cleanup
psql -h $PRIMARY_HOST -p $PRIMARY_PORT -U $DB_USER -d $DB_NAME -c "
TRUNCATE lag_measurement;
" > /dev/null

echo "Test data cleaned up."
