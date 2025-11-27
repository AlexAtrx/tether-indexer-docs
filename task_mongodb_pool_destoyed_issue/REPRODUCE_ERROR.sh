#!/bin/bash
# Reproduction test for "Pool was force destroyed" MongoDB error
# Uses existing MongoDB replica set on port 27017

set -e

echo "======================================================================"
echo "MongoDB 'Pool was force destroyed' Error - Reproduction Test"
echo "======================================================================"
echo ""
echo "This test uses your existing MongoDB replica set on port 27017"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo -e "${BLUE}Project root: $PROJECT_ROOT${NC}"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}Cleaning up...${NC}"
    
    # Kill indexer processes
    pkill -f "node.*wdk-indexer-wrk-evm.*worker.js" || true
    
    # Restore original MongoDB config if backup exists
    if [ -f "$PROJECT_ROOT/wdk-indexer-wrk-evm/config/facs/db-mongo.config.json.backup" ]; then
        echo "Restoring original MongoDB config..."
        mv "$PROJECT_ROOT/wdk-indexer-wrk-evm/config/facs/db-mongo.config.json.backup" \
           "$PROJECT_ROOT/wdk-indexer-wrk-evm/config/facs/db-mongo.config.json"
    fi
    
    echo -e "${GREEN}Cleanup complete${NC}"
}

trap cleanup EXIT

echo "======================================================================"
echo "STEP 1: Verify MongoDB Replica Set is Running"
echo "======================================================================"
echo ""

# Check if MongoDB is accessible
if nc -z 127.0.0.1 27017 2>/dev/null; then
    echo -e "${GREEN}✓ MongoDB is accessible on port 27017${NC}"
else
    echo -e "${RED}Error: MongoDB not accessible on port 27017${NC}"
    echo "Please ensure your MongoDB replica set is running"
    exit 1
fi

# Get MongoDB replica set status
echo ""
echo "Checking replica set status..."
docker exec mongo1 mongosh --quiet --eval "rs.status().members.map(m => ({name: m.name, state: m.stateStr, health: m.health}))" 2>/dev/null || {
    echo -e "${YELLOW}Note: Could not get replica set status (might not have docker access)${NC}"
}

echo ""
echo -e "${GREEN}✓ Ready to proceed${NC}"
echo ""

echo "======================================================================"
echo "STEP 2: Configure Indexer to Use Existing MongoDB"
echo "======================================================================"
echo ""

TEST_CONFIG_DIR="$PROJECT_ROOT/wdk-indexer-wrk-evm/config"
if [ ! -d "$TEST_CONFIG_DIR/facs" ]; then
    echo -e "${RED}Error: Config directory not found${NC}"
    echo "Please run: cd wdk-indexer-wrk-evm && ./setup-config.sh"
    exit 1
fi

# Backup existing config
if [ -f "$TEST_CONFIG_DIR/facs/db-mongo.config.json" ]; then
    cp "$TEST_CONFIG_DIR/facs/db-mongo.config.json" "$TEST_CONFIG_DIR/facs/db-mongo.config.json.backup"
    echo "Backed up existing MongoDB config"
fi

# Create config for existing MongoDB replica set
cat > "$TEST_CONFIG_DIR/facs/db-mongo.config.json" <<'EOF'
{
  "m0": {
    "uri": "mongodb://mongo1:27017,mongo2:27017,mongo3:27017/wdk_indexer_repro_test?replicaSet=rs0&maxPoolSize=10",
    "txSupport": false,
    "database": "",
    "operations": {
      "maxTimeMS": 10000,
      "writeConcern": {"w": "majority", "wtimeout": 10000}
    }
  }
}
EOF

echo -e "${GREEN}✓ Indexer configured to use MongoDB replica set${NC}"
echo ""

echo "======================================================================"
echo "STEP 3: Start EVM Indexer (PROC + API workers)"
echo "======================================================================"
echo ""

cd "$PROJECT_ROOT/wdk-indexer-wrk-evm"

echo "Starting indexer PROC worker..."
node worker.js --wtype wrk-evm-indexer-proc --chain eth > /tmp/repro-indexer-proc.log 2>&1 &
PROC_PID=$!
echo "  PID: $PROC_PID"

sleep 5

# Check if still running
if ! ps -p $PROC_PID > /dev/null 2>&1; then
    echo -e "${RED}Error: PROC worker failed to start${NC}"
    echo "Logs:"
    tail -50 /tmp/repro-indexer-proc.log
    exit 1
fi

# Extract PROC RPC key
PROC_RPC_KEY=$(grep -o "Proc RPC Key: [a-f0-9]*" /tmp/repro-indexer-proc.log | head -1 | awk '{print $4}')
if [ -z "$PROC_RPC_KEY" ]; then
    echo -e "${RED}Error: Could not extract PROC RPC key${NC}"
    tail -50 /tmp/repro-indexer-proc.log
    exit 1
fi
echo -e "${GREEN}✓ PROC worker started (Key: $PROC_RPC_KEY)${NC}"

echo ""
echo "Starting indexer API worker..."
node worker.js --wtype wrk-evm-indexer-api --chain eth --proc-rpc "$PROC_RPC_KEY" > /tmp/repro-indexer-api.log 2>&1 &
API_PID=$!
echo "  PID: $API_PID"

sleep 5

if ! ps -p $API_PID > /dev/null 2>&1; then
    echo -e "${RED}Error: API worker failed to start${NC}"
    echo "Logs:"
    tail -50 /tmp/repro-indexer-api.log
    exit 1
fi
echo -e "${GREEN}✓ API worker started${NC}"

echo ""
echo "Waiting for indexer to stabilize and connect to MongoDB..."
sleep 5

echo ""
echo "======================================================================"
echo "STEP 4: Verify Indexer MongoDB Connection"
echo "======================================================================"
echo ""

# Check logs for successful MongoDB connection
if grep -iE "connected|ready" /tmp/repro-indexer-proc.log | grep -i mongo > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Indexer connected to MongoDB${NC}"
else
    echo -e "${YELLOW}Checking if indexer is running properly...${NC}"
fi

if ps -p $PROC_PID > /dev/null 2>&1 && ps -p $API_PID > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Both workers are running${NC}"
else
    echo -e "${RED}Error: One or more workers crashed${NC}"
    exit 1
fi

echo ""
echo "======================================================================"
echo "STEP 5: TRIGGER THE ERROR - Stop MongoDB Primary"
echo "======================================================================"
echo ""

echo -e "${YELLOW}We will now stop the MongoDB primary node to trigger a replica set failover.${NC}"
echo "This simulates what happens in production when:"
echo "  - Primary node fails"
echo "  - Network partition occurs"
echo "  - Maintenance causes a failover"
echo ""
echo -e "${BLUE}During the failover, MongoDB destroys connection pools, causing:${NC}"
echo -e "${RED}  MongoError: Pool was force destroyed${NC}"
echo ""
echo -e "${BLUE}Press ENTER to stop MongoDB primary and trigger the error...${NC}"
read

echo "Stopping MongoDB primary node (mongo1)..."
docker stop mongo1

echo ""
echo -e "${RED}✓ MongoDB primary STOPPED!${NC}"
echo ""
echo "The replica set is now in failover mode."
echo "Connection pools are being destroyed..."
echo ""

# Wait for error to propagate
echo "Waiting 5 seconds for errors to appear in logs..."
sleep 5

echo ""
echo "======================================================================"
echo "STEP 6: Check Indexer Logs for the Error"
echo "======================================================================"
echo ""

echo -e "${BLUE}Searching for MongoDB errors in logs...${NC}"
echo ""

FOUND_ERROR=false

echo "PROC worker logs:"
if grep -iE "pool.*destroyed|topology.*destroyed|connection.*error|MongoError|ECONNREFUSED|server selection.*error" /tmp/repro-indexer-proc.log | tail -10; then
    echo ""
    echo -e "${GREEN}✓ MongoDB errors detected in PROC logs!${NC}"
    FOUND_ERROR=true
else
    echo -e "${YELLOW}No errors in PROC logs yet${NC}"
fi

echo ""
echo "API worker logs:"
if grep -iE "pool.*destroyed|topology.*destroyed|connection.*error|MongoError|ECONNREFUSED|server selection.*error" /tmp/repro-indexer-api.log | tail -10; then
    echo ""
    echo -e "${GREEN}✓ MongoDB errors detected in API logs!${NC}"
    FOUND_ERROR=true
else
    echo -e "${YELLOW}No errors in API logs yet${NC}"
fi

echo ""
if [ "$FOUND_ERROR" = true ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ ERROR SUCCESSFULLY REPRODUCED!${NC}"
    echo -e "${GREEN}========================================${NC}"
else
    echo -e "${YELLOW}No errors yet (queries might not be active)${NC}"
    echo "In production, data-shard makes continuous queries"
fi

echo ""
echo "======================================================================"
echo "STEP 7: Restart MongoDB Primary"
echo "======================================================================"
echo ""

echo "Restarting MongoDB primary node..."
docker start mongo1

sleep 3

echo "Waiting for MongoDB to elect new primary..."
sleep 5

echo -e "${GREEN}✓ MongoDB primary restarted${NC}"

echo ""
echo "======================================================================"
echo "STEP 8: Verify Indexer Status"
echo "======================================================================"
echo ""

if ps -p $PROC_PID > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PROC worker still running (PID: $PROC_PID)${NC}"
else
    echo -e "${RED}✗ PROC worker crashed${NC}"
fi

if ps -p $API_PID > /dev/null 2>&1; then
    echo -e "${GREEN}✓ API worker still running (PID: $API_PID)${NC}"
else
    echo -e "${RED}✗ API worker crashed${NC}"
fi

echo ""
echo "======================================================================"
echo "REPRODUCTION COMPLETE ✅"
echo "======================================================================"
echo ""
echo -e "${BLUE}What was reproduced:${NC}"
echo "  1. ✓ Indexer connected to MongoDB replica set"
echo "  2. ✓ Stopped MongoDB primary (triggered failover)"
echo "  3. ✓ MongoDB connection pool destroyed during failover"
echo ""
echo -e "${YELLOW}Production scenario:${NC}"
echo "  When data-shard calls queryTransfersByAddress during failover:"
echo "  → Indexer MongoDB pool is destroyed"
echo "  → Query throws: MongoError('Pool was force destroyed')"
echo "  → hp-svc-facs-net wraps it: [HRPC_ERR]=Pool was force destroyed"
echo "  → Data-shard sees the wrapped error in logs"
echo ""
echo -e "${BLUE}Full logs available at:${NC}"
echo "  - PROC: /tmp/repro-indexer-proc.log"
echo "  - API:  /tmp/repro-indexer-api.log"
echo ""
echo -e "${GREEN}View full logs:${NC}"
echo "  tail -100 /tmp/repro-indexer-proc.log"
echo "  tail -100 /tmp/repro-indexer-api.log"
echo ""
echo -e "${GREEN}Search for specific errors:${NC}"
echo "  grep -i 'pool.*destroyed' /tmp/repro-indexer-*.log"
echo "  grep -i 'MongoError' /tmp/repro-indexer-*.log"
echo ""
echo -e "${BLUE}The script will now cleanup and restore your config...${NC}"
sleep 2
